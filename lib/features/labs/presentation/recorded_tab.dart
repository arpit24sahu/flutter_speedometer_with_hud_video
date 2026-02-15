import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speedometer/features/labs/models/processing_task.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';
import 'package:speedometer/features/labs/presentation/task_processing_page.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class RecordedTab extends StatefulWidget {
  const RecordedTab({super.key});

  @override
  State<RecordedTab> createState() => _RecordedTabState();
}

class _RecordedTabState extends State<RecordedTab> {
  List<ProcessingTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    setState(() {
      _tasks = LabsService().getAllProcessingTasks();
    });
  }

  Future<void> _deleteTask(ProcessingTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Task',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently delete this task. This action cannot be undone and the data will not be recoverable.',
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
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && task.id != null) {
      await LabsService().deleteProcessingTask(task.id!);
      _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task deleted'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No recordings yet',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Record a video to get started',
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
          return _RecordedTaskTile(
            task: _tasks[index],
            onDelete: () => _deleteTask(_tasks[index]),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskProcessingPage(task: _tasks[index]),
                ),
              );
              _loadTasks();
            },
          );
        },
      ),
    );
  }
}

class _RecordedTaskTile extends StatelessWidget {
  final ProcessingTask task;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _RecordedTaskTile({
    required this.task,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final videoExists = task.videoFilePath != null && File(task.videoFilePath!).existsSync();
    final hasPositionData = task.positionData != null && task.positionData!.isNotEmpty;
    final isProcessable = videoExists && hasPositionData;

    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isProcessable ? onTap : null,
        onLongPress: (){
          showDialog(
              context: context,
              builder: (BuildContext content) {
                return Center(
                  child: ListView(
                    shrinkWrap: true,
                  children:
                      task.positionData?.entries
                          .map(
                            (e) => Text(
                              '${e.key}ms: ${e.value.speed.toStringAsFixed(2)}',
                            ),
                          )
                          .toList() ??
                      [],
                  ),
                );
              }
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail area
            SizedBox(
              height: 180,
              width: double.infinity,
              child: videoExists
                  ? _VideoThumbnail(
                      videoPath: task.videoFilePath!,
                      sizeInKb: task.sizeInKb,
                      lengthInSeconds: task.lengthInSeconds,
                      hasPositionData: hasPositionData,
                    )
                  : Container(
                      color: Colors.grey[850],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image, color: Colors.redAccent, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              'Video file missing',
                              style: TextStyle(color: Colors.red[300], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.name ?? 'Unnamed Recording',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        _buildStatusChips(videoExists, hasPositionData),
                        if (isProcessable) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.touch_app, size: 14, color: Colors.blueAccent[100]),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to process',
                                style: TextStyle(
                                  color: Colors.blueAccent[100],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isProcessable)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: onDelete,
                      tooltip: 'Delete task',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChips(bool videoExists, bool hasPositionData) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (!videoExists)
          _StatusChip(
            icon: Icons.warning_amber_rounded,
            label: 'Video missing',
            color: Colors.redAccent,
          ),
        if (!hasPositionData)
          _StatusChip(
            icon: Icons.gps_off,
            label: 'No GPS data',
            color: Colors.orangeAccent,
          ),
        if (videoExists)
          _StatusChip(
            icon: Icons.videocam,
            label: 'Video ready',
            color: Colors.greenAccent,
          ),
        if (hasPositionData)
          _StatusChip(
            icon: Icons.gps_fixed,
            label: 'GPS data',
            color: Colors.greenAccent,
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final String videoPath;
  final double? sizeInKb;
  final double? lengthInSeconds;
  final bool hasPositionData;

  const _VideoThumbnail({
    required this.videoPath,
    this.sizeInKb,
    this.lengthInSeconds,
    required this.hasPositionData,
  });

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  String? _thumbnailPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: widget.videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
      );
      if (mounted) {
        setState(() {
          _thumbnailPath = thumbnail;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatSize(double kb) {
    if (kb >= 1024) {
      return '${(kb / 1024).toStringAsFixed(1)} MB';
    }
    return '${kb.toStringAsFixed(0)} KB';
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail image
        if (_loading)
          Container(
            color: Colors.grey[850],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_thumbnailPath != null)
          Image.file(
            File(_thumbnailPath!),
            fit: BoxFit.cover,
          )
        else
          Container(
            color: Colors.grey[850],
            child: const Center(child: Icon(Icons.video_file, size: 48, color: Colors.grey)),
          ),

        // Gradient overlay at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ),
            ),
          ),
        ),

        // Badges
        Positioned(
          bottom: 8,
          left: 8,
          child: Row(
            children: [
              if (widget.sizeInKb != null && widget.sizeInKb! > 0)
                _OverlayBadge(text: _formatSize(widget.sizeInKb!)),
              if (widget.lengthInSeconds != null && widget.lengthInSeconds! > 0) ...[
                const SizedBox(width: 6),
                _OverlayBadge(text: _formatDuration(widget.lengthInSeconds!)),
              ],
            ],
          ),
        ),

        // GPS tick
        if (widget.hasPositionData)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'GPS',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _OverlayBadge extends StatelessWidget {
  final String text;

  const _OverlayBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
