import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:speedometer/features/labs/models/processed_task.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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

  Future<void> _handleTap(ProcessedTask task) async {
    if (task.savedVideoFilePath == null || !File(task.savedVideoFilePath!).existsSync()) {
      _showFileNotFoundDialog(task);
      return;
    }
    // Open the video file
    final result = await OpenFile.open(task.savedVideoFilePath!);
    debugPrint('OpenFile result: ${result.type}, ${result.message}');
  }

  void _showFileNotFoundDialog(ProcessedTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'File Not Found',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'We couldn\'t find this file. It might have been deleted or moved from its original location.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (task.id != null) {
                await LabsService().deleteProcessedTask(task.id!);
                _loadTasks();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Removed from app'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Remove from App', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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
            Icon(Icons.movie_creation_outlined, size: 64, color: Colors.grey[700]),
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
            onTap: () => _handleTap(_tasks[index]),
          );
        },
      ),
    );
  }
}

class _ExportedTaskTile extends StatelessWidget {
  final ProcessedTask task;
  final VoidCallback onTap;

  const _ExportedTaskTile({required this.task, required this.onTap});

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
    final fileExists = task.savedVideoFilePath != null && File(task.savedVideoFilePath!).existsSync();

    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                        child: Icon(Icons.broken_image, color: Colors.redAccent, size: 32),
                      ),
                    ),
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            style: TextStyle(color: Colors.blueAccent[100], fontSize: 12),
                          ),
                        if (!fileExists) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orangeAccent),
                          const SizedBox(width: 4),
                          const Text(
                            'File missing',
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Chevron
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                fileExists ? Icons.play_circle_outline : Icons.warning_amber_rounded,
                color: fileExists ? Colors.white54 : Colors.orangeAccent,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      child: const Center(child: Icon(Icons.video_file, size: 32, color: Colors.grey)),
    );
  }
}
