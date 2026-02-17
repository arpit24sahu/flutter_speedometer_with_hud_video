import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A production-ready service for downloading, caching, and serving
/// remote image assets (e.g. gauge dials and needles).
///
/// **Architecture:**
///   1. **Persistent disk cache** — images are stored in the app's
///      Application Support directory under `cached_assets/`. This
///      survives app restarts and is never auto-cleared by the OS
///      (unlike the temp directory).
///   2. **In-memory cache** — once loaded from disk, the raw bytes
///      are kept in a `Map<String, Uint8List>` for zero-latency access.
///   3. **Pre-warming** — call [preloadUrls] during app initialization
///      to download all known asset URLs in parallel. Only missing
///      assets are fetched.
///
/// **Usage:**
/// ```dart
/// // During app init:
/// await RemoteAssetService().init();
/// await RemoteAssetService().preloadUrls(allGaugeUrls);
///
/// // To get bytes (for Image.memory):
/// final bytes = await RemoteAssetService().getBytes(url);
///
/// // To get a file path (for FFmpeg):
/// final path = await RemoteAssetService().getFilePath(url);
/// ```
class RemoteAssetService {
  RemoteAssetService._internal();

  static final RemoteAssetService _instance = RemoteAssetService._internal();
  factory RemoteAssetService() => _instance;

  /// In-memory cache: URL → raw image bytes.
  final Map<String, Uint8List> _memoryCache = {};

  /// The persistent cache directory on disk.
  Directory? _cacheDir;

  bool _initialized = false;

  // ─── Initialization ───

  /// Initializes the cache directory. Must be called before any
  /// other method. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;

    final appSupportDir = await getApplicationSupportDirectory();
    _cacheDir = Directory('${appSupportDir.path}/cached_assets');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    _initialized = true;
    debugPrint('[RemoteAssetService] Cache dir: ${_cacheDir!.path}');
  }

  // ─── Pre-warming ───

  /// Downloads and caches all the given URLs that are not already
  /// present on disk. Downloads happen in parallel for speed.
  ///
  /// Failed downloads are logged but do not throw — the missing
  /// assets will be retried on next access.
  Future<void> preloadUrls(List<String> urls) async {
    _ensureInitialized();

    final futures = <Future>[];
    for (final url in urls) {
      if (url.isEmpty) continue;
      futures.add(_ensureCached(url));
    }

    await Future.wait(futures);
    debugPrint('[RemoteAssetService] Preload complete: '
        '${_memoryCache.length} assets in memory');
  }

  // ─── Public API ───

  /// Returns the raw image bytes for the given URL.
  ///
  /// Lookup order:
  ///   1. In-memory cache (instant)
  ///   2. Disk cache (fast I/O)
  ///   3. Network download (saved to both caches)
  ///
  /// Returns `null` if the image cannot be obtained from any source.
  Future<Uint8List?> getBytes(String url) async {
    _ensureInitialized();
    if (url.isEmpty) return null;

    // 1. Memory
    if (_memoryCache.containsKey(url)) {
      return _memoryCache[url];
    }

    // 2. Disk → memory
    final file = _diskFile(url);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      _memoryCache[url] = bytes;
      return bytes;
    }

    // 3. Network → disk → memory
    return _downloadAndCache(url);
  }

  /// Returns the local file path for the given URL.
  ///
  /// This is useful for FFmpeg, which needs a real file path
  /// rather than raw bytes. If the file is not cached, it will
  /// be downloaded first.
  ///
  /// Returns `null` if the image cannot be obtained from any source.
  Future<String?> getFilePath(String url) async {
    _ensureInitialized();
    if (url.isEmpty) return null;

    final file = _diskFile(url);
    if (await file.exists()) {
      // Also populate memory cache while we're at it
      if (!_memoryCache.containsKey(url)) {
        _memoryCache[url] = await file.readAsBytes();
      }
      return file.path;
    }

    // Download first, then return the path
    final bytes = await _downloadAndCache(url);
    if (bytes != null) {
      return file.path;
    }
    return null;
  }

  /// Checks if a URL is already cached (either in memory or on disk).
  Future<bool> isCached(String url) async {
    if (url.isEmpty) return false;
    if (_memoryCache.containsKey(url)) return true;
    if (_cacheDir == null) return false;
    return _diskFile(url).exists();
  }

  /// Clears both the in-memory and on-disk caches.
  Future<void> clearCache() async {
    _memoryCache.clear();
    if (_cacheDir != null && await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
    }
    debugPrint('[RemoteAssetService] Cache cleared');
  }

  // ─── Private Helpers ───

  void _ensureInitialized() {
    assert(_initialized,
        'RemoteAssetService.init() must be called before using the service');
  }

  /// Ensures a URL is cached on disk and in memory.
  /// Does nothing if the file already exists.
  Future<void> _ensureCached(String url) async {
    // Already in memory → done
    if (_memoryCache.containsKey(url)) return;

    // Already on disk → load into memory
    final file = _diskFile(url);
    if (await file.exists()) {
      try {
        _memoryCache[url] = await file.readAsBytes();
        debugPrint('[RemoteAssetService] Loaded from disk: '
            '${_fileNameForUrl(url)}');
      } catch (e) {
        debugPrint('[RemoteAssetService] Failed to read from disk: $e');
      }
      return;
    }

    // Not cached → download
    await _downloadAndCache(url);
  }

  /// Downloads the image at [url] and writes it to the disk cache
  /// and the in-memory cache. Returns the bytes, or `null` on failure.
  Future<Uint8List?> _downloadAndCache(String url) async {
    try {
      debugPrint('[RemoteAssetService] Downloading: $url');
      final uri = Uri.parse(url);
      final httpClient = HttpClient();

      // Follow redirects (ibb.co uses 302)
      httpClient.autoUncompress = true;

      final request = await httpClient.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200 ||
          response.statusCode == 301 ||
          response.statusCode == 302) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        httpClient.close();

        if (bytes.isEmpty) {
          debugPrint('[RemoteAssetService] Downloaded 0 bytes for: $url');
          return null;
        }

        // Write to disk
        final file = _diskFile(url);
        await file.writeAsBytes(bytes, flush: true);

        // Populate memory cache
        _memoryCache[url] = bytes;

        debugPrint('[RemoteAssetService] Cached: '
            '${_fileNameForUrl(url)} (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
        return bytes;
      } else {
        debugPrint('[RemoteAssetService] HTTP ${response.statusCode} for: $url');
        httpClient.close();
        return null;
      }
    } catch (e) {
      debugPrint('[RemoteAssetService] Download failed for $url: $e');
      return null;
    }
  }

  /// Maps a URL to a deterministic, filesystem-safe filename
  /// using an MD5 hash. The original file extension is preserved
  /// for debugging convenience.
  File _diskFile(String url) {
    return File('${_cacheDir!.path}/${_fileNameForUrl(url)}');
  }

  String _fileNameForUrl(String url) {
    final hash = md5.convert(utf8.encode(url)).toString();
    // Preserve the original extension (e.g. .png, .jpg)
    final uri = Uri.tryParse(url);
    String ext = '.png'; // default
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last;
      final dotIndex = lastSegment.lastIndexOf('.');
      if (dotIndex != -1) {
        ext = lastSegment.substring(dotIndex);
      }
    }
    return '$hash$ext';
  }
}
