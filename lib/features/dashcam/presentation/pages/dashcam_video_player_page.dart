// import 'dart:convert';
// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
//
// import '../../utils/dashcam_export_utils.dart';
//
// class DashcamVideoPlayerPage extends StatefulWidget {
//   final File videoFile;
//
//   const DashcamVideoPlayerPage({super.key, required this.videoFile});
//
//   @override
//   State<DashcamVideoPlayerPage> createState() => _DashcamVideoPlayerPageState();
// }
//
// class _DashcamVideoPlayerPageState extends State<DashcamVideoPlayerPage> {
//   late VideoPlayerController _controller;
//   bool _isPlaying = false;
//   bool _isInit = false;
//
//   // Metadata track
//   List<Map<String, dynamic>> _metadata = [];
//   Map<String, dynamic>? _currentMetadata;
//
//   @override
//   void initState() {
//     super.initState();
//     _initPlayer();
//     _loadMetadata();
//   }
//
//   Future<void> _initPlayer() async {
//     _controller = VideoPlayerController.file(widget.videoFile);
//     await _controller.initialize();
//
//     // Add listener to sync metadata with playback position
//     _controller.addListener(_syncMetadata);
//
//     setState(() {
//       _isInit = true;
//     });
//   }
//
//   Future<void> _loadMetadata() async {
//     try {
//       final jsonPath = widget.videoFile.path.replaceAll('.mp4', '.json');
//       final jsonFile = File(jsonPath);
//       if (await jsonFile.exists()) {
//         final content = await jsonFile.readAsString();
//         final List<dynamic> rawList = jsonDecode(content);
//         _metadata = rawList.cast<Map<String, dynamic>>();
//       }
//     } catch (e) {
//       debugPrint('Warning: Could not load metadata for video -> $e');
//     }
//   }
//
//   void _syncMetadata() {
//     if (_metadata.isEmpty || !_controller.value.isInitialized) return;
//
//     final currentDuration = _controller.value.position;
//     final currentMs = currentDuration.inMilliseconds;
//
//     // Find closest frame data
//     // Assuming the metadata array is stored linearly alongside the video frames
//     // A more precise way is to match the exact presentation time from native if recorded.
//     // Assuming 30fps = ~33.3ms per frame, we roughly estimate the index.
//     int estimatedIndex = (currentMs / 33.33).round();
//     if (estimatedIndex < 0) estimatedIndex = 0;
//     if (estimatedIndex >= _metadata.length) estimatedIndex = _metadata.length - 1;
//
//     final meta = _metadata[estimatedIndex];
//     if (meta != _currentMetadata) {
//       setState(() {
//         _currentMetadata = meta;
//       });
//     }
//   }
//
//   @override
//   void dispose() {
//     _controller.removeListener(_syncMetadata);
//     _controller.dispose();
//     super.dispose();
//   }
//
//   void _togglePlayPause() {
//     if (_controller.value.isPlaying) {
//       _controller.pause();
//       setState(() => _isPlaying = false);
//     } else {
//       _controller.play();
//       setState(() => _isPlaying = true);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: const Text('Dashcam Playback'),
//         backgroundColor: Colors.black,
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             if (_isInit)
//               Expanded(
//                 child: Center(
//                   child: AspectRatio(
//                     aspectRatio: _controller.value.aspectRatio,
//                     child: Stack(
//                       alignment: Alignment.bottomCenter,
//                       children: [
//                         VideoPlayer(_controller),
//
//                         // Metadata Overlay
//                         if (_currentMetadata != null)
//                           Positioned(
//                             bottom: 20,
//                             left: 20,
//                             child: _buildOverlay(),
//                           ),
//
//                         // Play/Pause Overlay Button
//                         GestureDetector(
//                           onTap: _togglePlayPause,
//                           child: Container(
//                             color: Colors.transparent, // Capture taps
//                             child: Center(
//                               child: AnimatedOpacity(
//                                 opacity: _isPlaying ? 0.0 : 1.0,
//                                 duration: const Duration(milliseconds: 200),
//                                 child: Container(
//                                   padding: const EdgeInsets.all(16),
//                                   decoration: const BoxDecoration(
//                                     color: Colors.black54,
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               )
//             else
//               const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white))),
//
//             // Controls
//             if (_isInit)
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//                 child: Row(
//                   children: [
//                     ValueListenableBuilder(
//                       valueListenable: _controller,
//                       builder: (context, VideoPlayerValue value, child) {
//                         return Text(
//                           _formatDuration(value.position),
//                           style: const TextStyle(color: Colors.white),
//                         );
//                       },
//                     ),
//                     Expanded(
//                       child: VideoProgressIndicator(
//                         _controller,
//                         allowScrubbing: true,
//                         colors: const VideoProgressColors(
//                           playedColor: Colors.red,
//                           bufferedColor: Colors.white24,
//                           backgroundColor: Colors.white38,
//                         ),
//                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//                       ),
//                     ),
//                     Text(
//                       _formatDuration(_controller.value.duration),
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                   ],
//                 ),
//               ),
//
//               // Export Button
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: ElevatedButton.icon(
//                   onPressed: () async {
//                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export started...')));
//                     final exportedPath = await DashcamExportUtils.exportVideoWithOverlays(widget.videoFile);
//                     if (!context.mounted) return;
//                     if (exportedPath != null) {
//                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to: $exportedPath')));
//                     } else {
//                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export failed!')));
//                     }
//                   },
//                   icon: const Icon(Icons.share),
//                   label: const Text('Export Video with Overlays'),
//                   style: ElevatedButton.styleFrom(
//                     minimumSize: const Size.fromHeight(50),
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                   ),
//                 ),
//               )
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildOverlay() {
//     final speed = _currentMetadata?['speed'] ?? 0.0;
//     final lat = _currentMetadata?['lat'] ?? 0.0;
//     final lng = _currentMetadata?['lng'] ?? 0.0;
//
//     // We can format it explicitly
//     return Text(
//       'Speed: ${speed.toStringAsFixed(1)} km/h  Lat: ${lat.toStringAsFixed(5)}  Lng: ${lng.toStringAsFixed(5)}',
//       style: const TextStyle(
//         color: Colors.white,
//         fontSize: 16,
//         fontWeight: FontWeight.bold,
//         shadows: [
//           Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
//         ],
//       ),
//     );
//   }
//
//   String _formatDuration(Duration duration) {
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     final minutes = twoDigits(duration.inMinutes.remainder(60));
//     final seconds = twoDigits(duration.inSeconds.remainder(60));
//     return '$minutes:$seconds';
//   }
// }
