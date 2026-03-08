import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/dashcam_telemetry.dart';
import 'metadata_datasource_interface.dart';

/// Production-grade MetadataDataSource using native EventChannel for GPS telemetry.
///
/// Architecture: Delegates ALL location permission/service checks to the native
/// telemetry handlers (iOS: AppDelegate, Android: NativeTelemetryHandler.kt).
/// This avoids the Geolocator ↔ LocationManager API mismatch on Android
/// where Google Play Fused Location can report "service disabled" even when
/// raw GPS is fully functional in GPS-only mode.
///
/// Responsibilities:
///   1. Stream forwarding: native EventChannel → broadcast StreamController
///   2. Telemetry file I/O: write GPS data to JSON alongside recorded video
///   3. Error resilience: auto-reconnect on stream errors, guarded writes
class MetadataDataSource implements IMetadataDataSource {
  // ─── Constants ──────────────────────────────────────────────────
  static const String _tag = '[MetadataDS]';
  static const EventChannel _telemetryChannel =
      EventChannel('com.mycompany.indiandriveguide/telemetry');

  // ─── Stream state ──────────────────────────────────────────────
  final StreamController<DashcamTelemetry> _telemetryCtrl =
      StreamController.broadcast();
  StreamSubscription<dynamic>? _nativeSubscription;
  bool _isStreaming = false;

  // ─── File I/O state ────────────────────────────────────────────
  IOSink? _fileSink;
  bool _isFirstEntry = true;

  // ─── Public API ────────────────────────────────────────────────

  @override
  Stream<DashcamTelemetry> get telemetryStream => _telemetryCtrl.stream;

  @override
  Future<void> startStreaming() async {
    if (_isStreaming) {
      debugPrint('$_tag Already streaming, skipping duplicate start');
      return;
    }

    // NOTE: Location permission is requested at the UI layer (DashcamPage)
    // with a Prominent Disclosure dialog, as required by Google Play policy.
    // This datasource assumes permission is already granted or denied.
    // If denied, the native telemetry stream simply returns zero values.

    await _connectToNativeStream();
    _isStreaming = true;
    debugPrint('$_tag Telemetry streaming started');
  }

  @override
  Future<void> stopStreaming() async {
    _isStreaming = false;
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    debugPrint('$_tag Telemetry streaming stopped');
  }

  @override
  Future<void> startWriting(String filePath) async {
    _isFirstEntry = true;
    final file = File(filePath);
    _fileSink = file.openWrite();
    _fileSink!.write('[');
    debugPrint('$_tag Started writing telemetry to: $filePath');
  }

  @override
  Future<void> stopWriting() async {
    if (_fileSink == null) return;
    try {
      _fileSink!.write(']');
      await _fileSink!.flush();
      await _fileSink!.close();
      debugPrint('$_tag Telemetry file closed successfully');
    } catch (e) {
      debugPrint('$_tag Error closing telemetry file: $e');
    } finally {
      _fileSink = null;
    }
  }

  @override
  Future<void> dispose() async {
    await stopStreaming();
    await stopWriting();
    if (!_telemetryCtrl.isClosed) {
      await _telemetryCtrl.close();
    }
    debugPrint('$_tag Disposed');
  }

  // ─── Private: Native stream connection ─────────────────────────

  /// Connects to the platform-specific telemetry EventChannel.
  ///
  /// The native handlers manage their own LocationManager/CLLocationManager
  /// permissions and handle SecurityException (Android) / authorization
  /// denial (iOS) gracefully. No Dart-side pre-checks needed.
  Future<void> _connectToNativeStream() async {
    await _nativeSubscription?.cancel();

    _nativeSubscription = _telemetryChannel.receiveBroadcastStream().listen(
      _onNativeEvent,
      onError: _onNativeError,
      onDone: _onNativeDone,
    );
  }

  /// Parses each native telemetry event and forwards to the broadcast stream.
  void _onNativeEvent(dynamic event) {
    try {
      final data = event as Map<Object?, Object?>;
      final telemetry = DashcamTelemetry(
        speedKmh: (data['speedKmh'] as num?)?.toDouble() ?? 0.0,
        lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.now().toIso8601String(),
      );

      // Forward to Dart listeners (BLoC)
      if (!_telemetryCtrl.isClosed) {
        _telemetryCtrl.add(telemetry);
      }

      // Persist to JSON file alongside active recording
      _writeTelemetryEntry(telemetry);
    } catch (e) {
      debugPrint('$_tag Error parsing native telemetry event: $e');
    }
  }

  /// Handles native stream errors with auto-reconnect.
  void _onNativeError(dynamic error) {
    debugPrint('$_tag Native telemetry stream error: $error');

    // Auto-reconnect if we are still supposed to be streaming.
    // This handles transient errors like brief GPS provider restarts.
    if (_isStreaming) {
      debugPrint('$_tag Attempting reconnect in 1s...');
      Future.delayed(const Duration(seconds: 1), () {
        if (_isStreaming) {
          _connectToNativeStream();
        }
      });
    }
  }

  /// Handles native stream completion.
  void _onNativeDone() {
    debugPrint('$_tag Native telemetry stream completed');
  }

  // ─── Private: File I/O ─────────────────────────────────────────

  /// Appends a telemetry entry to the active JSON file.
  ///
  /// No-op if no recording is active (fileSink == null).
  /// Guarded to prevent I/O errors from crashing the telemetry pipeline.
  void _writeTelemetryEntry(DashcamTelemetry telemetry) {
    if (_fileSink == null) return;
    try {
      if (!_isFirstEntry) _fileSink!.write(',');
      _isFirstEntry = false;
      _fileSink!.write(jsonEncode({
        'speed': telemetry.speedKmh,
        'lat': telemetry.lat,
        'lng': telemetry.lng,
        'ts': telemetry.timestamp,
      }));
    } catch (e) {
      debugPrint('$_tag Error writing telemetry entry: $e');
    }
  }
}
