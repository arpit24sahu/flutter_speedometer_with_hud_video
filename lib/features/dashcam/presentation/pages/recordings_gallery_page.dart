import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../bloc/dashcam_bloc.dart';
import '../../domain/entities/recording_metadata.dart';
import 'dashcam_playback_page.dart';
import '../../../../core/analytics/analytics_tracker.dart';
import '../../../../core/analytics/analytics_events.dart';

class RecordingsGalleryPage extends StatefulWidget {
  const RecordingsGalleryPage({super.key});

  @override
  State<RecordingsGalleryPage> createState() => _RecordingsGalleryPageState();
}

class _RecordingsGalleryPageState extends State<RecordingsGalleryPage> {
  List<RecordingMetadata> _recordings = [];
  Map<String, int> _fileSizes = {};
  int _totalStorageBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    AnalyticsTracker().trackScreen(screenName: 'DashcamGallery', screenClass: 'RecordingsGalleryPage');
  }

  Future<void> _loadRecordings() async {
    try {
      Box<Map> box;
      if (Hive.isBoxOpen('dashcam_metadata')) {
        box = Hive.box<Map>('dashcam_metadata');
      } else {
        box = await Hive.openBox<Map>('dashcam_metadata').timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('Hive open box timeout'),
        );
      }
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/dashcam');

      if (await dir.exists()) {
        final entities = await dir.list().toList().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('Directory list timeout'),
        );
        
        int calculatedTotalBytes = 0;
        for (var entity in entities) {
          if (entity is File) {
            try {
              calculatedTotalBytes += await entity.length();
            } catch (_) {}
          }
        }

        final files = entities
            .whereType<File>()
            .where((e) => e.path.endsWith('.mp4'))
            .toList();

        // Filter out corrupt/truncated files (< 10 KB = invalid mp4).
        // These are produced when a phone call interrupts recording before
        // the mp4 moov atom is finalized.
        files.removeWhere((f) {
          try {
            final size = f.lengthSync();
            if (size < 10240) {
              debugPrint('[Gallery] Skipping corrupt file: ${f.path} (${size}B)');
              return true;
            }
          } catch (_) {
            return true; // can't read file — skip it
          }
          return false;
        });

        // Fetch last modified and size asynchronously
        final fileModTimes = <String, DateTime>{};
        final newFileSizes = <String, int>{};
        for (var file in files) {
          try {
            fileModTimes[file.path] = await file.lastModified();
            newFileSizes[file.path] = await file.length();
          } catch (_) {
            fileModTimes[file.path] = DateTime.fromMillisecondsSinceEpoch(0);
            newFileSizes[file.path] = 0;
          }
        }

        files.sort((a, b) {
          final modA =
              fileModTimes[a.path] ?? DateTime.fromMillisecondsSinceEpoch(0);
          final modB =
              fileModTimes[b.path] ?? DateTime.fromMillisecondsSinceEpoch(0);
          return modB.compareTo(modA); // Newest first
        });

        List<RecordingMetadata> metas = [];
        for (var file in files) {
          final fileId = file.path.split('/').last.replaceAll('.mp4', '');
          try {
            final map = box.get(fileId);
            if (map != null) {
              metas
                  .add(RecordingMetadata.fromMap(map));
            } else {
              metas.add(RecordingMetadata(
                  id: fileId,
                  path: file.path,
                  timestamp: (fileModTimes[file.path] ?? DateTime.now())
                      .millisecondsSinceEpoch));
            }
          } catch (e) {
            debugPrint('Error parsing metadata for $fileId: $e');
            metas.add(RecordingMetadata(
                id: fileId,
                path: file.path,
                timestamp: (fileModTimes[file.path] ?? DateTime.now())
                    .millisecondsSinceEpoch));
          }
        }

        if (mounted) {
          setState(() {
            _recordings = metas;
            _fileSizes = newFileSizes;
            _totalStorageBytes = calculatedTotalBytes;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e, st) {
      debugPrint('Error loading recordings: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleLock(RecordingMetadata item) async {
    debugPrint(
        '[RecordingsGallery] _toggleLock UI called for ${item.id}, current state: ${item.isLocked}');

    // 1. Grab bloc directly from GetIt to avoid context lookup issues across routes
    final bloc = GetIt.instance<DashcamBloc>();
    bloc.add(ToggleClipLock(item.id));

    // 2. Prepare the updated model for local UI optimism
    final updatedItem = item.copyWith(isLocked: !item.isLocked);

    // 3. Update the local view instantly
    setState(() {
      final idx = _recordings.indexWhere((e) => e.id == item.id);
      if (idx != -1) {
        _recordings[idx] = updatedItem;
      }
    });
  }

  Future<void> _deleteUnprotectedVideos() async {
    final unprotected = _recordings
        .where((e) => !e.isLocked && !e.path.endsWith('_exported.mp4'))
        .toList();
    if (unprotected.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No unprotected videos to delete.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text('Delete Videos', style: TextStyle(color: Colors.white)),
        content: Text(
            'Are you sure you want to delete ${unprotected.length} unprotected videos? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_delete_video,
        params: {'count': unprotected.length, 'type': 'unprotected_bulk'},
      );
      setState(() => _isLoading = true);
      try {
        if (!Hive.isBoxOpen('dashcam_metadata')) {
          await Hive.openBox<Map>('dashcam_metadata');
        }
        final box = Hive.box<Map>('dashcam_metadata');

        for (final item in unprotected) {
          try {
            final mp4File = File(item.path);
            if (await mp4File.exists()) await mp4File.delete();

            final jsonFile = File(item.path.replaceAll('.mp4', '.json'));
            if (await jsonFile.exists()) await jsonFile.delete();

            await box.delete(item.id);
          } catch (e) {
            debugPrint('Error deleting ${item.id}: $e');
          }
        }
      } catch (e, st) {
        AnalyticsTracker().log(
          AnalyticsEvents.dashcam_delete_video_error,
          params: {
            'operation': 'delete_unprotected_videos',
            'error': e.toString(),
          },
        );
        debugPrint('Error in _deleteUnprotectedVideos: $e\n$st');
      } finally {
        if (mounted) {
          await _loadRecordings();
        }
      }
    }
  }

  Future<void> _deleteVideo(RecordingMetadata item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text('Delete Video', style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to delete this video? This action cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_delete_video,
        params: {'video_id': item.id, 'type': 'single_video'},
      );
      setState(() => _isLoading = true);
      try {
        if (!Hive.isBoxOpen('dashcam_metadata')) {
          await Hive.openBox<Map>('dashcam_metadata');
        }
        final box = Hive.box<Map>('dashcam_metadata');

        final mp4File = File(item.path);
        if (await mp4File.exists()) await mp4File.delete();

        final jsonFile = File(item.path.replaceAll('.mp4', '.json'));
        if (await jsonFile.exists()) await jsonFile.delete();

        await box.delete(item.id);
      } catch (e) {
        AnalyticsTracker().log(
          AnalyticsEvents.dashcam_delete_video_error,
          params: {
            'operation': 'delete_single_video',
            'video_id': item.id,
            'error': e.toString(),
          },
        );
        debugPrint('Error deleting ${item.id}: $e');
      } finally {
        if (mounted) {
          await _loadRecordings();
        }
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "0 MB";
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      final gb = mb / 1024;
      return "${gb.toStringAsFixed(2)} GB";
    }
    return "${mb.toStringAsFixed(1)} MB";
  }

  Widget _buildVideoList(List<RecordingMetadata> list) {
    if (list.isEmpty) {
      return const Center(
          child: Text("No recordings found.",
              style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final date = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
        final isExported = item.path.endsWith('_exported.mp4');
        final sizeBytes = _fileSizes[item.path] ?? 0;
        final sizeStr = _formatSize(sizeBytes);

        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          DashcamPlaybackPage(videoFile: File(item.path))));
              // Refresh when returning from the playback page in case an export happened
              if (mounted) {
                _loadRecordings();
              }
            },
            leading: Icon(isExported ? Icons.movie_filter : Icons.video_file,
                color: isExported ? Colors.greenAccent : Colors.white54,
                size: 40),
            title: Text(item.id,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 2),
                Text(sizeStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isExported)
                  IconButton(
                    icon: Icon(item.isLocked ? Icons.star : Icons.star_border,
                        color: item.isLocked ? Colors.amber : Colors.white54),
                    onPressed: () => _toggleLock(item),
                  ),
                if (isExported || !item.isLocked)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _deleteVideo(item),
                  ),
                if (isExported)
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.blueAccent),
                    onPressed: () => Share.shareXFiles([XFile(item.path)]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Exclude exported videos from the "All" tab to avoid confusion, or include them? The user requested "first will show all video, second will show star marked, 3rd will show exported".
    // I will include all videos in the first tab.
    final starred = _recordings.where((e) => e.isLocked).toList();
    final exported =
        _recordings.where((e) => e.path.endsWith('_exported.mp4')).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            _isLoading
                ? "Recordings"
                : "Recordings • ${_formatSize(_totalStorageBytes)}",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'Delete unprotected videos',
              onPressed: _deleteUnprotectedVideos,
            )
          ],
          bottom: const TabBar(
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: "All"),
              Tab(text: "Starred"),
              Tab(text: "Exported"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.redAccent))
            : TabBarView(
                children: [
                  _buildVideoList(_recordings),
                  _buildVideoList(starred),
                  _buildVideoList(exported),
                ],
              ),
      ),
    );
  }
}
