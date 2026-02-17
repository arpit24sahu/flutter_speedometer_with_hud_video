import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speedometer/features/labs/models/processed_task.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';
import 'package:speedometer/packages/gal.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';

class ExportedTab extends StatefulWidget {
  const ExportedTab({super.key});

  @override
  State<ExportedTab> createState() => _ExportedTabState();
}

class _ExportedTabState extends State<ExportedTab> {
  List<ProcessedTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    setState(() {
      _tasks = LabsService().getAllProcessedTasks();
    });
  }

  Future<void> _openFile(ProcessedTask task) async {
    if (task.savedVideoFilePath == null ||
        !File(task.savedVideoFilePath!).existsSync()) {
      _showSnackBar('Video file not found', isError: true);
      return;
    }
    final result = await OpenFile.open(task.savedVideoFilePath!);
    AnalyticsService().trackEvent(
      AnalyticsEvents.playRecordedVideo,
      properties: {
        'file_path': task.savedVideoFilePath,
        'size_kb': task.sizeInKb,
        'duration_seconds': task.lengthInSeconds,
        'source': 'ExportedTab',
      },
    );
    debugPrint('OpenFile result: ${result.type}, ${result.message}');
  }

  Future<void> _shareTask(ProcessedTask task) async {
    if (task.savedVideoFilePath == null ||
        !File(task.savedVideoFilePath!).existsSync()) {
      _showSnackBar('Video file not found', isError: true);
      return;
    }
    await Share.shareXFiles([XFile(task.savedVideoFilePath!)]);
    AnalyticsService().trackEvent(
      AnalyticsEvents.shareRecordedVideo,
      properties: {
        'file_path': task.savedVideoFilePath,
        'size_kb': task.sizeInKb,
        'duration_seconds': task.lengthInSeconds,
        'source': 'ExportedTab',
      },
    );
  }

  Future<void> _exportToGallery(ProcessedTask task) async {
    if (task.savedVideoFilePath == null ||
        !File(task.savedVideoFilePath!).existsSync()) {
      _showSnackBar('Video file not found', isError: true);
      return;
    }
    try {
      final galService = GetIt.I<GalService>();
      await galService.saveVideoToGallery(
        task.savedVideoFilePath!,
        albumName: 'TurboGauge Exports',
      );
      _showSnackBar('Video saved to gallery');
    } catch (e) {
      _showSnackBar('Failed to save to gallery: $e', isError: true);
    }
  }

  Future<void> _deleteTask(ProcessedTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Delete Export',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
        content: const Text(
              'This will permanently delete this exported video. This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
                onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text(
                  'Delete',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && task.id != null) {
      if (task.savedVideoFilePath != null) {
        final file = File(task.savedVideoFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await LabsService().deleteProcessedTask(task.id!);
      _loadTasks();
      _showSnackBar('Export deleted');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showActionsSheet(ProcessedTask task) {
    final fileExists =
        task.savedVideoFilePath != null &&
        File(task.savedVideoFilePath!).existsSync();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _SheetAction(
                    label: 'Open File',
                    enabled: fileExists,
                    onTap: () {
                      Navigator.pop(context);
                      _openFile(task);
                    },
                  ),
                  _SheetAction(
                    label: 'Share',
                    enabled: fileExists,
                    onTap: () {
                      Navigator.pop(context);
                      _shareTask(task);
                    },
                  ),
                  _SheetAction(
                    label: 'Export to Gallery',
                    enabled: fileExists,
                    onTap: () {
                      Navigator.pop(context);
                      _exportToGallery(task);
                    },
                  ),
                  _SheetAction(
                    label: 'Delete',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      _deleteTask(task);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_creation_outlined,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'No exports yet',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Process a recorded video to see it here',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadTasks(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          return _ExportedTaskTile(
            task: _tasks[index],
            onTap: () => _openFile(_tasks[index]),
            onLongPress: () => _showActionsSheet(_tasks[index]),
          );
        },
      ),
    );
  }
}

// ─── Compact Bottom Sheet Action ───

class _SheetAction extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SheetAction({
    required this.label,
    this.enabled = true,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        !enabled
            ? Colors.grey[600]!
            : isDestructive
            ? Colors.redAccent
            : Colors.white;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Exported Task Tile ───

class _ExportedTaskTile extends StatelessWidget {
  final ProcessedTask task;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ExportedTaskTile({
    required this.task,
    required this.onTap,
    required this.onLongPress,
  });

  String _formatSize(double kb) {
    if (kb >= 1024) {
      return '${(kb / 1024).toStringAsFixed(1)} MB';
    }
    return '${kb.toStringAsFixed(0)} KB';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fileExists =
        task.savedVideoFilePath != null &&
        File(task.savedVideoFilePath!).existsSync();

    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Row(
          children: [
            // Thumbnail
            SizedBox(
              width: 120,
              height: 90,
              child: fileExists
                  ? _ExportThumbnail(videoPath: task.savedVideoFilePath!)
                  : Container(
                      color: Colors.grey[850],
                      child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.redAccent,
                            size: 32,
                          ),
                      ),
                    ),
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name ?? 'Export',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (task.createdAt != null)
                      Text(
                        _formatDate(task.createdAt!),
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (task.sizeInKb != null && task.sizeInKb! > 0)
                          Text(
                            _formatSize(task.sizeInKb!),
                            style: TextStyle(
                              color: Colors.blueAccent[100],
                              fontSize: 12,
                            ),
                          ),
                        if (!fileExists) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'File missing',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // More options button
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              onPressed: onLongPress,
              tooltip: 'More options',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Export Thumbnail ───

class _ExportThumbnail extends StatefulWidget {
  final String videoPath;

  const _ExportThumbnail({required this.videoPath});

  @override
  State<_ExportThumbnail> createState() => _ExportThumbnailState();
}

class _ExportThumbnailState extends State<_ExportThumbnail> {
  String? _thumbnailPath;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final path = await VideoThumbnail.thumbnailFile(
        video: widget.videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 50,
      );
      if (mounted) setState(() => _thumbnailPath = path);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnailPath != null) {
      return Image.file(File(_thumbnailPath!), fit: BoxFit.cover);
    }
    return Container(
      color: Colors.grey[850],
      child: const Center(
        child: Icon(Icons.video_file, size: 32, color: Colors.grey),
      ),
    );
  }
}
