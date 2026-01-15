import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/premium/widgets/premium_feature_gate.dart';
import 'package:speedometer/features/premium/widgets/premium_upgrade_dialog.dart';
import '../../utils.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<FileSystemEntity>? processedFiles;
  List<FileSystemEntity>? rawFiles;

  @override
  void initState() {
    super.initState();
    loadFiles();
  }

  Future<void> loadFiles() async {
    try {
      String path = await getDownloadsPath();
      final directory = Directory(path);
      final entities = await directory.list().toList();

      final allFiles = entities.whereType<File>().toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      processedFiles = allFiles.where((f) => f.path.split('/').last.startsWith('TurboGauge')).toList();
      rawFiles = allFiles.where((f) => !f.path.split('/').last.startsWith('TurboGauge')).toList();

      AnalyticsService().trackEvent(AnalyticsEvents.filesLoaded,
        properties: {
          "totalFiles": allFiles.length,
          "processedFiles": processedFiles?.length,
          "rawFiles": rawFiles?.length,
        }
      );

      if (mounted) setState(() {});
    } catch(e) {
      print("Error Loading Files: ${e.toString()}");
    }
  }

  void _showFileOptions(FileSystemEntity file, BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open'),
                onTap: () {
                  Navigator.pop(context);
                  openFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await file.delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File deleted')),
                    );
                    loadFiles();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to delete file')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () async {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(file.path)], text: 'Expense Report');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileGrid(List<FileSystemEntity>? files) {
    if (files == null) return const Center(child: CircularProgressIndicator());
    if (files.isEmpty) return const Center(child: Text('No files found'));

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final stat = file.statSync();
        
        return Card(
          child: InkWell(
            onTap: () => openFile(file),
            onLongPress: () => _showFileOptions(file, context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.insert_drive_file, size: 40),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    file.path.split('/').last,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Modified: ${stat.modified.toString().split(' ')[0]}',
                  style: Theme.of(context).textTheme.labelSmall,
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Files'),
          centerTitle: false,
          actions: [
            IconButton(onPressed: loadFiles, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Processed'),
              Tab(text: 'Raw Files'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFileGrid(processedFiles),
            Stack(
              children: [
                _buildFileGrid(rawFiles),
                // ShaderMask(
                //   shaderCallback: (rect) {
                //     return const LinearGradient(
                //       begin: Alignment.topCenter,
                //       end: Alignment.bottomCenter,
                //       colors: [Colors.black, Colors.transparent],
                //     ).createShader(rect);
                //   },
                //   blendMode: BlendMode.dstIn,
                //   child: _buildFileGrid(rawFiles),
                // ),
                Positioned.fill(
                  child: PremiumFeatureGate(
                      premiumContent: SizedBox.shrink(),
                      freeContent: Container(
                        color: Colors.grey.withOpacity(0.6),
                        child: Center(
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            elevation: 8,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.auto_awesome, size: 48, color: Colors.amber),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Unlock Pro Features',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Access raw high-resolution files, enjoy an ad-free experience, and export without watermarks.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, height: 1.4),
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.coffee, size: 20, color: Colors.brown),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Lifetime Pro costs less than your daily coffee.',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  ElevatedButton(
                                    onPressed: () => PremiumUpgradeDialog.show(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber[700],
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(56),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Get Pro Now',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ),
                      )
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}