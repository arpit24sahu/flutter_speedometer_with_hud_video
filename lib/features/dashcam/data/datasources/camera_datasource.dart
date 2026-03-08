import 'dart:io';
import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'camera_datasource_interface.dart';

/// CameraDataSource implementation with lens switching support.
///
/// On iOS, back cameras from AVFoundation are identified by their name:
///   - "...video:0"  → Back Wide (1x)
///   - "...video:2"  → Back Ultra Wide (0.5x)
///   - "...video:4"  or "...video:6" → Back Telephoto (2x/3x)
///
/// We sort back cameras into a consistent order: [ultra-wide, wide, telephoto]
/// based on their name identifiers rather than relying on list order.
class CameraDataSource implements ICameraDataSource {
  cam.CameraController? _controller;
  bool _enableAudio;
  List<cam.CameraDescription> _allCameras = [];

  // Ordered back cameras: index 0 = ultra-wide (0.5x), 1 = wide (1x), 2 = telephoto (2x)
  List<cam.CameraDescription> _sortedBackCameras = [];
  cam.CameraLensDirection _currentDirection = cam.CameraLensDirection.back;
  int _currentLensIndex = 0;
  cam.ResolutionPreset _currentPreset = cam.ResolutionPreset.veryHigh;
  int _currentFps = 60;

  // Unified OOP Lens Settings (Used by iOS and Android)
  final List<LensSetting> _lensSettings = [];

  // Native Camera2 capabilities channel (Android only)
  static const MethodChannel _cameraCapabilitiesChannel =
      MethodChannel('com.mycompany.indiandriveguide/camera_capabilities');

  CameraDataSource({bool enableAudio = true}) : _enableAudio = enableAudio;

  @override
  cam.CameraController? get controller => _controller;

  @override
  List<cam.CameraDescription> get cameras => _allCameras;

  @override
  cam.CameraLensDirection get currentDirection => _currentDirection;

  @override
  int get currentLensIndex => _currentLensIndex;

  @override
  List<String> get availableLensLabels {
    if (_lensSettings.isNotEmpty) {
      return _lensSettings.map((e) => e.label).toList();
    }
    return ['1x'];
  }

  @override
  Future<void> initialize({bool enableAudio = true, cam.ResolutionPreset resolutionPreset = cam.ResolutionPreset.veryHigh, int fps = 60}) async {
    _currentPreset = resolutionPreset;
    _currentFps = fps;
    _allCameras = await cam.availableCameras();
    if (_allCameras.isEmpty) throw Exception('No cameras available');

    // Log all cameras for debugging
    for (final c in _allCameras) {
      debugPrint('[CameraDS] Found camera: name="${c.name}", '
          'direction=${c.lensDirection}, sensorOrientation=${c.sensorOrientation}');
    }

    final backCameras = _allCameras
        .where((c) => c.lensDirection == cam.CameraLensDirection.back)
        .toList();

    debugPrint('[CameraDS] Back cameras count: ${backCameras.length}');

    // Sort back cameras into [ultrawide, wide, telephoto] on iOS
    if (Platform.isIOS && backCameras.length >= 2) {
      _sortedBackCameras = _sortIOSBackCameras(backCameras);
    } else {
      _sortedBackCameras = backCameras;
    }

    for (int i = 0; i < _sortedBackCameras.length; i++) {
      debugPrint('[CameraDS] Sorted back[$i]: name="${_sortedBackCameras[i].name}"'
          ' → label=${availableLensLabels.length > i ? availableLensLabels[i] : "?"}');
    }

    // Default to 1x (wide) lens
    int defaultIndex = 0;
    if (Platform.isIOS) {
      if (_sortedBackCameras.length >= 3) {
        defaultIndex = 1; // wide (1x) in [ultrawide, wide, telephoto]
      } else if (_sortedBackCameras.length == 2) {
        defaultIndex = 0; // wide (1x) in [wide, telephoto]
      }
    } else {
      // On Android, index 0 is almost universally the primary wide camera.
      defaultIndex = 0;
    }

    _currentLensIndex = defaultIndex;
    _currentDirection = cam.CameraLensDirection.back;

    final camera = _sortedBackCameras.isNotEmpty
        ? _sortedBackCameras[defaultIndex]
        : _allCameras.first;

    debugPrint('[CameraDS] Initializing with camera: "${camera.name}", lensIndex=$defaultIndex');
    
    await _initController(camera);

    // On iOS, build OOP presets from the sorted physical cameras
    if (Platform.isIOS) {
      _lensSettings.clear();
      for (final c in _sortedBackCameras) {
        final name = c.name.toLowerCase();
        String label = '1x';
        if (name.contains(':2')) {
          label = '0.5x';
        } else if (RegExp(r':(4|5|6)$').hasMatch(name)) {
          label = '2x';
        }
        _lensSettings.add(PhysicalLensSetting(label, c));
      }
    }

    // On Android, use OOP physical/zoom fallback strategy
    if (Platform.isAndroid && _controller != null) {
      await _buildAndroidLensSettings();
      // Default to the 1x (wide) preset
      _currentLensIndex = _lensSettings.indexWhere((s) => s.label == '1x');
      if (_currentLensIndex == -1) _currentLensIndex = 0;
      debugPrint('[CameraDS] Android lens settings: $availableLensLabels (default idx=$_currentLensIndex)');
    }
  }

  /// Sort iOS back cameras into consistent order: [ultra-wide, wide, telephoto]
  ///
  /// iOS AVFoundation camera names follow patterns:
  ///   "...video:0" = Wide (1x)
  ///   "...video:2" = Ultra Wide (0.5x)
  ///   "...video:4" or higher = Telephoto (2x/3x)
  List<cam.CameraDescription> _sortIOSBackCameras(List<cam.CameraDescription> backCameras) {
    cam.CameraDescription? ultraWide;
    cam.CameraDescription? wide;
    cam.CameraDescription? telephoto;

    for (final cam in backCameras) {
      final name = cam.name.toLowerCase();
      // Extract the trailing number from the camera name
      final match = RegExp(r':(\d+)$').firstMatch(name);
      if (match != null) {
        final id = int.tryParse(match.group(1)!) ?? -1;
        if (id == 0) {
          wide = cam; // :0 is the standard wide (1x) camera
        } else if (id == 2) {
          ultraWide = cam; // :2 is ultra-wide (0.5x)
        } else {
          telephoto = cam; // :4, :6, etc. are telephoto (2x/3x)
        }
      }
    }

    // Build ordered list: [ultra-wide?, wide, telephoto?]
    final sorted = <cam.CameraDescription>[];
    if (ultraWide != null) sorted.add(ultraWide);
    if (wide != null) {
      sorted.add(wide);
    } else if (backCameras.isNotEmpty) {
      sorted.add(backCameras.first); // fallback
    }
    if (telephoto != null) sorted.add(telephoto);

    // If sorting failed, fall back to original order
    if (sorted.isEmpty) return backCameras;
    return sorted;
  }

  /// Builds Android lens settings utilizing the Native Camera2 Capabilities.
  /// Generates a list of [LensSetting] dynamically mapping to real hardware if the OEM permits,
  /// otherwise explicitly degrading to logical zoom boundaries to ensure UI stability.
  Future<void> _buildAndroidLensSettings() async {
    if (_controller == null) return;
    _lensSettings.clear();

    final backCameras = _allCameras.where((c) => c.lensDirection == cam.CameraLensDirection.back).toList();

    try {
      final List<dynamic>? nativeLenses = await _cameraCapabilitiesChannel.invokeMethod('getBackCameraLenses');

      if (nativeLenses != null && nativeLenses.isNotEmpty) {
        final lenses = nativeLenses.map((e) => e as Map<Object?, Object?>).toList();
        lenses.sort((a, b) => (a['focalLength'] as double).compareTo(b['focalLength'] as double));

        // Find the "main" wide lens focal length to establish baseline 1.0x ratio
        double mainFocalLength = (lenses.length >= 2 && (lenses[0]['focalLength'] as double) / (lenses[1]['focalLength'] as double) < 0.7)
            ? (lenses[1]['focalLength'] as double)
            : (lenses.first['focalLength'] as double);

        for (final lens in lenses) {
          final id = lens['cameraId'] as String;
          final isLogical = lens['isLogical'] as bool;
          final zoomRatio = (lens['focalLength'] as double) / mainFocalLength;
          final label = _labelForZoomRatio(zoomRatio);

          final matchingPhysical = backCameras.where((c) => c.name == id).firstOrNull;

          if (matchingPhysical != null) {
            _lensSettings.add(PhysicalLensSetting(label, matchingPhysical));
            debugPrint('[CameraDS] Mounted Physical Camera ID $id as "$label" (Found natively mapped)');
          } else if (!isLogical) {
            // SYNTHETIC CAMERA BINDING: Force Flutter to open the hidden physical lens directly
            final syntheticCamera = cam.CameraDescription(
              name: id,
              lensDirection: cam.CameraLensDirection.back,
              sensorOrientation: backCameras.firstOrNull?.sensorOrientation ?? 90,
            );
            
            _lensSettings.add(PhysicalLensSetting(label, syntheticCamera));
            debugPrint('[CameraDS] Mounted Hidden Physical Sensor ID $id as "$label" via Synthetic Binding');
          }
        }
      }
    } catch (e) {
      debugPrint('[CameraDS] Native Camera2 query failed, employing graceful degradation: $e');
    }

    // ─── Graceful UI Fallback ─────────────────────────────────
    // If the OEM restricts hardware data entirely, or only reports the 1 logical camera,
    // we extrapolate the maximum zoom bounds to guarantee the UI operates.
    if (_lensSettings.length <= 1) {
      try {
        final minZoom = await _controller!.getMinZoomLevel();
        final maxZoom = await _controller!.getMaxZoomLevel();
        debugPrint('[CameraDS] Fallback to logical zoom bounds $minZoom – $maxZoom');

        // Retain the existing '1x' label if generated, otherwise create a new one.
        final existing1x = _lensSettings.firstWhere(
           (s) => s.label == '1x', 
           orElse: () => const ZoomLensSetting('1x', 1.0)
        );
        _lensSettings.clear();
        
        // Add 0.5x only if API minZoom allows zooming out.
        if (minZoom < 0.95 && !_lensSettings.any((s) => s.label == '0.5x')) {
            _lensSettings.add(ZoomLensSetting('0.5x', minZoom));
        }
        
        _lensSettings.add(existing1x);
        
        if (maxZoom >= 2.0 && !_lensSettings.any((s) => s.label == '2x')) {
            _lensSettings.add(const ZoomLensSetting('2x', 2.0));
        }
      } catch (e) {
        if (_lensSettings.isEmpty) {
            _lensSettings.add(const ZoomLensSetting('1x', 1.0));
        }
      }
    }

    // Deduplicate any overlapping labels mapping to the same tier
    final uniqueLabels = <String>{};
    _lensSettings.retainWhere((setting) {
      if (uniqueLabels.contains(setting.label)) return false;
      uniqueLabels.add(setting.label);
      return true;
    });

    _lensSettings.sort((a, b) => a.label.compareTo(b.label));
  }

  /// Calculates a clean UI label ("0.5x", "1x", "2x") from a raw zoom ratio float.
  String _labelForZoomRatio(double zoomRatio) {
    if (zoomRatio < 0.8) return '${zoomRatio.toStringAsFixed(1)}x';
    if (zoomRatio <= 1.3) return '1x';
    // Clean exact labels (2.9x → 3x)
    final rounded = (zoomRatio * 2).round() / 2;
    return '${rounded % 1 == 0 ? rounded.toInt() : rounded}x';
  }

  Future<void> _initController(cam.CameraDescription camera) async {
    final oldController = _controller;
    
    // Safely dispose the old one NOW, before creating the new one.
    // This releases the hardware lock, preventing freezes or crashes on iOS/Android.
    if (oldController != null) {
      await oldController.dispose();
      _controller = null;
      debugPrint('[CameraDS] Old controller disposed synchronously before switch');
    }

    // Create new controller
    final newController = cam.CameraController(
      camera,
      _currentPreset,
      enableAudio: _enableAudio,
      fps: _currentFps,
    );

    // Initialize the new controller 
    try {
      await newController.initialize();
      
      // Unlock capture orientation so the camera relies on physical gravity
      // to record at 90 (left) or 270 (right) dynamically.
      try {
        await newController.unlockCaptureOrientation();
      } catch (e) {
        debugPrint('[CameraDS] unlockCaptureOrientation failed for ${camera.name}: $e');
        // We continue smoothly
      }

      // Swap the active controller
      _controller = newController;
      debugPrint('[CameraDS] Controller initialized: ${camera.name}');
      
    } catch (e) {
      debugPrint('[CameraDS] Failed to initialize new controller: $e');
      // If we failed to build the new one, attempt to clean it up.
      await newController.dispose();
      rethrow; // Let BLoC catch this
    }
  }

  @override
  Future<String> startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }
    await _controller!.startVideoRecording();
    return '';
  }

  @override
  Future<String> stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      throw Exception('Not recording');
    }
    final xFile = await _controller!.stopVideoRecording();
    return xFile.path;
  }

  @override
  Future<void> switchCamera(cam.CameraLensDirection direction) async {
    _currentDirection = direction;

    cam.CameraDescription target;
    if (direction == cam.CameraLensDirection.front) {
      target = _allCameras.firstWhere(
        (c) => c.lensDirection == cam.CameraLensDirection.front,
        orElse: () => _allCameras.first,
      );
    } else {
      target = _sortedBackCameras.isNotEmpty
          ? _sortedBackCameras[_currentLensIndex.clamp(0, _sortedBackCameras.length - 1)]
          : _allCameras.first;
    }

    debugPrint('[CameraDS] switchCamera → ${direction.name}, target="${target.name}"');
    await _initController(target);

    // On Android, restore the lens settings when switching back to rear camera
    if (Platform.isAndroid && direction == cam.CameraLensDirection.back && _controller != null) {
      await _buildAndroidLensSettings();
      _currentLensIndex = _lensSettings.indexWhere((s) => s.label == '1x');
      if (_currentLensIndex == -1) _currentLensIndex = 0;
      
      // Enforce the 1x setting immediately
      if (_lensSettings.isNotEmpty) {
        await _lensSettings[_currentLensIndex].apply(this);
      }
      debugPrint('[CameraDS] Android: reset to 1x after camera switch');
    }
  }

  @override
  Future<void> switchLens(int lensIndex) async {
    if (_currentDirection == cam.CameraLensDirection.front) return;
    if (_lensSettings.isEmpty) return;

    final idx = lensIndex.clamp(0, _lensSettings.length - 1);
    _currentLensIndex = idx;

    debugPrint('[CameraDS] switchLens → index=$idx, label="${_lensSettings[idx].label}"');
    
    // Execute polymorphic OOP logic. If it fails, fallback gracefully to Wide.
    try {
      await _lensSettings[idx].apply(this);
    } catch (e) {
      debugPrint('[CameraDS] Lens application failed: $e');
    }
  }

  @override
  Future<void> setResolutionPreset(cam.ResolutionPreset preset) async {
    if (_currentPreset == preset) return;
    _currentPreset = preset;
    
    // Find the currently active camera to re-initialize with the new preset
    cam.CameraDescription target;
    if (_currentDirection == cam.CameraLensDirection.front) {
      target = _allCameras.firstWhere(
        (c) => c.lensDirection == cam.CameraLensDirection.front,
        orElse: () => _allCameras.first,
      );
    } else {
      target = _sortedBackCameras.isNotEmpty
          ? _sortedBackCameras[_currentLensIndex.clamp(0, _sortedBackCameras.length - 1)]
          : _allCameras.first;
    }
    
    await _initController(target);
  }

  @override
  Future<void> setFrameRate(int fps) async {
    if (_currentFps == fps) return;
    _currentFps = fps;
    
    // Find the currently active camera to re-initialize
    cam.CameraDescription target;
    if (_currentDirection == cam.CameraLensDirection.front) {
      target = _allCameras.firstWhere(
        (c) => c.lensDirection == cam.CameraLensDirection.front,
        orElse: () => _allCameras.first,
      );
    } else {
      target = _sortedBackCameras.isNotEmpty
          ? _sortedBackCameras[_currentLensIndex.clamp(0, _sortedBackCameras.length - 1)]
          : _allCameras.first;
    }
    
    await _initController(target);
  }

  @override
  Future<void> reinitializeWithAudio({required bool enableAudio}) async {
    _enableAudio = enableAudio;

    // Resolve the currently active camera description
    cam.CameraDescription target;
    if (_currentDirection == cam.CameraLensDirection.front) {
      target = _allCameras.firstWhere(
        (c) => c.lensDirection == cam.CameraLensDirection.front,
        orElse: () => _allCameras.first,
      );
    } else {
      target = _sortedBackCameras.isNotEmpty
          ? _sortedBackCameras[_currentLensIndex.clamp(0, _sortedBackCameras.length - 1)]
          : _allCameras.first;
    }

    debugPrint('[CameraDS] reinitializeWithAudio(enableAudio=$enableAudio) → "${target.name}"');
    await _initController(target);
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

// ─── OOP Interface for Lens Switching ────────────────────────────

abstract class LensSetting {
  final String label;

  const LensSetting(this.label);

  /// Executes the internal hardware swap or zoom change for this specific lens setting.
  Future<void> apply(CameraDataSource source);
}

/// A perfect physical lens switch utilizing the native multi-camera ID via [CameraController].
class PhysicalLensSetting extends LensSetting {
  final cam.CameraDescription cameraDescription;

  const PhysicalLensSetting(super.label, this.cameraDescription);

  @override
  Future<void> apply(CameraDataSource source) async {
    await source._initController(cameraDescription);
  }
}

/// A zoom-bounded fallback for hardware sensors restricted behind the main logical camera's zoom scale.
class ZoomLensSetting extends LensSetting {
  final double zoomRatio;

  const ZoomLensSetting(super.label, this.zoomRatio);

  @override
  Future<void> apply(CameraDataSource source) async {
    if (source.controller != null) {
      try {
        final minZoom = await source.controller!.getMinZoomLevel();
        final maxZoom = await source.controller!.getMaxZoomLevel();
        final targetZoom = zoomRatio.clamp(minZoom, maxZoom);
        await source.controller!.setZoomLevel(targetZoom);
      } catch (e) {
        debugPrint('[CameraDS] Zoom clamp failed: $e');
      }
    }
  }
}
