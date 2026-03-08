import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/repositories/dashcam_repository.dart';
import '../../data/dashcam_preferences.dart';
import '../../../../core/analytics/analytics_tracker.dart';
import '../../../../core/analytics/analytics_events.dart';

class DashcamFrameData {
  final int secondOffset;
  final double speed;
  final double lat;
  final double lng;
  final String timestamp;

  DashcamFrameData({
    required this.secondOffset,
    required this.speed,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });
}

class DashcamPlaybackPage extends StatefulWidget {
  final File videoFile;

  const DashcamPlaybackPage({super.key, required this.videoFile});

  @override
  State<DashcamPlaybackPage> createState() => _DashcamPlaybackPageState();
}

class _DashcamPlaybackPageState extends State<DashcamPlaybackPage> {
  late VideoPlayerController _controller;
  Map<int, DashcamFrameData> _metadataMap = {};
  
  // Map State
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  final ValueNotifier<Set<Marker>> _markersNotifier = ValueNotifier({});
  LatLngBounds? _mapBounds;
  bool _isMapReady = false;

  final ValueNotifier<DashcamFrameData?> _currentFrameNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _showOverlayNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<double> _playbackSpeedNotifier = ValueNotifier(1.0);

  DateTime? _videoStartTime;
  late final String _speedUnit;

  bool _isInit = false;
  bool _isFullscreen = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _speedUnit = GetIt.instance<DashcamPreferences>().speedUnit;
    _initialize();
    AnalyticsTracker().trackScreen(screenName: 'DashcamPlayback', screenClass: 'DashcamPlaybackPage');
    AnalyticsTracker().log(
      AnalyticsEvents.dashcam_video_playback_started,
      params: {AnalyticsParams.videoPath: widget.videoFile.path},
    );
  }

  Future<void> _initialize() async {
    await _loadMetadata();

    _controller = VideoPlayerController.file(widget.videoFile);
    try {
      await _controller.initialize().timeout(const Duration(seconds: 10));
      _controller.addListener(_onVideoPositionChanged);
    } catch (e) {
      debugPrint('[Playback] Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
    
    if (mounted) {
      setState(() {
        _isInit = true;
      });
    }
  }

  Future<void> _loadMetadata() async {
    final jsonPath = widget.videoFile.path.replaceAll('.mp4', '.json');
    debugPrint('[Playback] Looking for metadata at: $jsonPath');
    final file = File(jsonPath);
    
    if (!await file.exists()) {
      debugPrint('[Playback] Metadata file NOT FOUND: $jsonPath');
      return;
    }
    
    debugPrint('[Playback] Metadata file FOUND. Reading contents...');

    final Map<int, DashcamFrameData> map = {};

    try {
      String jsonString = await file.readAsString();
      
      // Handle potentially unclosed JSON array if recording was interrupted
      jsonString = jsonString.trim();
      if (jsonString.startsWith('[') && !jsonString.endsWith(']')) {
        if (jsonString.endsWith(',')) {
          jsonString = jsonString.substring(0, jsonString.length - 1);
        }
        jsonString += ']';
      }

      final List<dynamic> entries = jsonDecode(jsonString);
      
      final List<LatLng> routePoints = [];
      double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;

      for (final dynamic data in entries) {
        if (data is! Map<String, dynamic>) continue;
        
        try {
          // Use modern keys ('ts', 'speed') but fallback to old keys just in case
          final timestampStr = (data['ts'] ?? data['timestamp']) as String;
          final dt = DateTime.parse(timestampStr);
          
          _videoStartTime ??= dt;
          final offset = dt.difference(_videoStartTime!).inSeconds;
          
          final speed = (data['speed'] as num?)?.toDouble() ?? (data['speed_kmh'] as num?)?.toDouble() ?? 0.0;
          final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
          final lng = (data['lng'] as num?)?.toDouble() ?? 0.0;

          if (lat != 0.0 && lng != 0.0) {
            routePoints.add(LatLng(lat, lng));
            if (lat < minLat) minLat = lat;
            if (lat > maxLat) maxLat = lat;
            if (lng < minLng) minLng = lng;
            if (lng > maxLng) maxLng = lng;
          }

          map[offset] = DashcamFrameData(
            secondOffset: offset,
            speed: speed,
            lat: lat,
            lng: lng,
            timestamp: timestampStr,
          );
        } catch (e) {
          debugPrint('[Playback] Error parsing entry: $data - $e');
        }
      }

      if (routePoints.isNotEmpty) {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route_polyline'),
            points: routePoints,
            color: Colors.blue,
            width: 5,
          )
        };
        _mapBounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );
      }

      debugPrint('[Playback] Successfully parsed ${map.length} unique second offsets.');

      _metadataMap = map;
    } catch (e) {
      debugPrint("Error loading metadata: $e");
    }
  }

  void _onVideoPositionChanged() {
    if (!_controller.value.isInitialized) return;

    // Update play state
    if (_isPlayingNotifier.value != _controller.value.isPlaying) {
      _isPlayingNotifier.value = _controller.value.isPlaying;
    }

    // Sync metadata
    final currentSecond = _controller.value.position.inSeconds;
    DashcamFrameData? frame = _metadataMap[currentSecond];
    
    // If we have data, but no explicit point for this second (e.g. GPS was stationary)
    // we interpolate a frame where the timestamp dynamically ticks with the video
    if (frame == null && _metadataMap.isNotEmpty && _videoStartTime != null) {
      final validKeys = _metadataMap.keys.where((k) => k <= currentSecond).toList();
      DashcamFrameData baseFrame;
      if (validKeys.isNotEmpty) {
        validKeys.sort();
        baseFrame = _metadataMap[validKeys.last]!;
      } else {
        baseFrame = _metadataMap.values.first;
      }

      final dynamicDt = _videoStartTime!.add(Duration(seconds: currentSecond));
      frame = DashcamFrameData(
        secondOffset: currentSecond,
        speed: baseFrame.speed,
        lat: baseFrame.lat,
        lng: baseFrame.lng,
        timestamp: dynamicDt.toIso8601String(),
      );
    }
    
    // To prevent rapid rebuilds, only notify if the data itself actually meaningfully changed
    if (_currentFrameNotifier.value?.timestamp != frame?.timestamp || _currentFrameNotifier.value?.speed != frame?.speed) {
      _currentFrameNotifier.value = frame;
      
      if (frame != null && frame.lat != 0.0 && frame.lng != 0.0) {
        final newPosition = LatLng(frame.lat, frame.lng);
        _markersNotifier.value = {
          Marker(
            markerId: const MarkerId('car_marker'),
            position: newPosition,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            zIndexInt: 10, // Ensure it's above polyline
          )
        };
        
        if (_isMapReady && _mapController != null && !_isFullscreen) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(newPosition));
        }
      }
    }
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _cyclePlaybackSpeed() {
    final current = _playbackSpeedNotifier.value;
    double next = current == 1.0 ? 1.5 : (current == 1.5 ? 2.0 : 1.0);
    _playbackSpeedNotifier.value = next;
    _controller.setPlaybackSpeed(next);
  }

  Future<void> _exportVideo() async {
    final exportProgress = ValueNotifier<double>(0.0);

    // Show non-dismissible loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Exporting video with burned metadata..."),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: exportProgress,
                builder: (context, progress, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        color: Colors.redAccent,
                        backgroundColor: Colors.grey.shade800,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        progress > 0 
                            ? '${(progress * 100).toStringAsFixed(1)}%' 
                            : 'Preparing...',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                "This may take a moment depending on the length.", 
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_export_started,
        params: {'video_path': widget.videoFile.path},
      );
      final repo = GetIt.instance<DashcamRepository>();
      final result = await repo.exportVideo(
        widget.videoFile,
        onProgress: (progress) {
          exportProgress.value = progress;
        },
      );
      
      // Close dialog
      if (mounted) Navigator.of(context).pop();

      result.fold(
        (exportedPath) {
          if (mounted) {
            AnalyticsTracker().log(
              AnalyticsEvents.dashcam_export_completed,
              params: {
              'exported_path': exportedPath,
              'original_video_path': widget.videoFile.path,
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Export complete! Video saved to device gallery.'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        (failure) {
          if (mounted) {
            AnalyticsTracker().log(
              AnalyticsEvents.dashcam_export_error,
              params: {
              'error_message': failure.toString(),
              'operation': 'export_video',
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Export failed: ${failure.toString()}')),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        AnalyticsTracker().log(
          AnalyticsEvents.dashcam_export_error,
          params: {
          'error_message': e.toString(),
          'operation': 'export_video_exception',
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_hasError) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text("Failed to load video", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage, style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    } else {
      content = _isInit
          ? Column(
              children: [
                // Standard AppBar replacing the custom back button for better layout
                if (!_isFullscreen)
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                    title: const Text('Dashcam Playback', style: TextStyle(color: Colors.white)),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        tooltip: 'Export burned video',
                        onPressed: _exportVideo,
                      ),
                    ],
                  ),
                  
                Expanded(
                  child: _isFullscreen
                      ? Center(child: _buildVideoPlayerArea())
                      : Column(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Center(child: _buildVideoPlayerArea()),
                            ),
                            if(false) Expanded(
                              flex: 4,
                              child: _buildMapArea(),
                            ),
                          ],
                        ),
                ),
                
                if (!_isFullscreen)
                  _buildControlsArea(),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.redAccent));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: content,
      ),
    );
  }

  Widget _buildControlsArea() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(value.position), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: value.position.inMilliseconds.toDouble(),
                        max: value.duration.inMilliseconds.toDouble() > 0 ? value.duration.inMilliseconds.toDouble() : 1.0,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white30,
                        onChanged: (val) {
                          _controller.seekTo(Duration(milliseconds: val.toInt()));
                        },
                      ),
                    ),
                  ),
                  Text(_formatDuration(value.duration), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Overlay Toggle
              ValueListenableBuilder<bool>(
                valueListenable: _showOverlayNotifier,
                builder: (context, showOverlay, child) {
                  return TextButton.icon(
                    onPressed: () => _showOverlayNotifier.value = !showOverlay,
                    icon: Icon(showOverlay ? Icons.visibility : Icons.visibility_off, color: Colors.white),
                    label: Text(showOverlay ? "HUD ON" : "HUD OFF", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  );
                },
              ),
              
              Row(
                children: [
                  // Playback Speed
                  ValueListenableBuilder<double>(
                    valueListenable: _playbackSpeedNotifier,
                    builder: (context, speed, child) {
                      return TextButton(
                        onPressed: _cyclePlaybackSpeed,
                        child: Text("${speed}x", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  
                  // Fullscreen toggle
                  IconButton(
                    icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                    onPressed: _toggleFullscreen,
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerArea() {
    return AspectRatio(
      aspectRatio: _isFullscreen ? MediaQuery.of(context).size.aspectRatio : _controller.value.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(_controller),
          
          // Overlay HUD fixed to the exact dimensions of the video box
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<bool>(
                valueListenable: _showOverlayNotifier,
                builder: (context, showOverlay, child) {
                  if (!showOverlay) return const SizedBox.shrink();
                  return ValueListenableBuilder<DashcamFrameData?>(
                    valueListenable: _currentFrameNotifier,
                    builder: (context, frame, child) {
                      if (frame == null) return const SizedBox.shrink();
                      return _OverlayHud(frameData: frame, speedUnit: _speedUnit);
                    },
                  );
                },
              ),
            ),
          ),

          // Play/Pause Gesture Overlay
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isPlayingNotifier,
                  builder: (context, isPlaying, child) {
                    return AnimatedOpacity(
                      opacity: isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          
          // Bottom Control Overlay over the video in fullscreen
          if (_isFullscreen)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildControlsArea(),
            )
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    if (_metadataMap.isEmpty) {
      return const Center(
        child: Text("No GPS metadata available for this video.", style: TextStyle(color: Colors.white54)),
      );
    }
    
    CameraPosition initialCameraPosition = const CameraPosition(
      target: LatLng(20.5937, 78.9629),
      zoom: 5,
    );
    
    if (_polylines.isNotEmpty) {
       initialCameraPosition = CameraPosition(
         target: _polylines.first.points.first,
         zoom: 15,
       );
    }

    return ValueListenableBuilder<Set<Marker>>(
      valueListenable: _markersNotifier,
      builder: (context, markers, child) {
        return GoogleMap(
          initialCameraPosition: initialCameraPosition,
          polylines: _polylines,
          markers: markers,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          onMapCreated: (controller) {
             _mapController = controller;
             _isMapReady = true;
             
             if (_mapBounds != null) {
               Future.delayed(const Duration(milliseconds: 200), () {
                 if (mounted && _mapController != null) {
                   _mapController!.animateCamera(CameraUpdate.newLatLngBounds(_mapBounds!, 50));
                 }
               });
             }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoPositionChanged);
    _controller.dispose();
    _currentFrameNotifier.dispose();
    _showOverlayNotifier.dispose();
    _isPlayingNotifier.dispose();
    _playbackSpeedNotifier.dispose();
    _markersNotifier.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}

class _OverlayHud extends StatelessWidget {
  final DashcamFrameData frameData;
  final String speedUnit;

  const _OverlayHud({required this.frameData, required this.speedUnit});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top Center: Timestamp and GPS Stacked
        Positioned(
          top: 20, // Shifted upward slightly
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildOutlinedText(
                _formatTimestamp(frameData.timestamp),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(height: 4),
              _buildOutlinedText(
                "${frameData.lat.toStringAsFixed(5)}° N, ${frameData.lng.toStringAsFixed(5)}° E",
                fontSize: 10,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ],
          ),
        ),
        
        // Bottom Right: Speed — premium HUD style matching dashcam_page
        Positioned(
          bottom: 16,
          right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (speedUnit == 'mph' ? frameData.speed * 0.621371 : frameData.speed).toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  height: 1,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  speedUnit,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    height: 1,
                    shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Bottom Left: TurboGauge Logo
        Positioned(
          bottom: 8,
          left: 8,
          child: Opacity(
            opacity: 0.8,
            child: Image.asset(
              'assets/icon/icon.jpg',
              width: 70, // Reduced for preview screen logical pixels
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutlinedText(String text, {required double fontSize, FontWeight? fontWeight, String? fontFamily}) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
        shadows: [
          Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 1, offset: const Offset(1, 1)),
          Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 1, offset: const Offset(-1, -1)),
          Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 1, offset: const Offset(1, -1)),
          Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 1, offset: const Offset(-1, 1)),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    if (timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm:ss a').format(dt);
    } catch (_) {
      return timestamp.split('.').first.replaceAll('T', ' ');
    }
  }
}
