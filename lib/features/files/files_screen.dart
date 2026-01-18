import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/features/files/bloc/files_bloc.dart';
import 'package:speedometer/features/premium/widgets/premium_feature_gate.dart';
import 'package:speedometer/features/premium/widgets/premium_upgrade_dialog.dart';

import '../../utils.dart';

class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FilesBloc()..add(RefreshFiles()),
      child: const _FilesScreenContent(),
    );
  }
}

class _FilesScreenContent extends StatelessWidget {
  const _FilesScreenContent();

  void _showFileOptions(FileSystemEntity file, BuildContext context) {
    final bloc = context.read<FilesBloc>();
    
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  openFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  bloc.add(DeleteFile(file: file));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File deleted')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  bloc.add(ShareFile(file: file));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileGrid(List<FileSystemEntity> files, bool isLoading, BuildContext context) {
    if (isLoading && files.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (files.isEmpty) {
      return const Center(child: Text('No files found'));
    }

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
            IconButton(
              onPressed: () => context.read<FilesBloc>().add(RefreshFiles()),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return Dialog(
                      shadowColor: Colors.grey,
                      backgroundColor: Colors.white,
                      insetPadding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            color: Colors.black,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 360,
                                maxHeight: 420,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Center(
                                        child: Text(
                                          'Files',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 12),
                          
                                      /// Processed
                                      Text(
                                        'Processed Files',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.greenAccent,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'These videos include the speedometer overlay and are ready to view or share directly.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                          height: 1.4,
                                        ),
                                      ),
                          
                                      SizedBox(height: 14),
                          
                                      /// Raw
                                      Text(
                                        'Raw Files',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amberAccent,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Original recordings without the speedometer. Useful if you want a clean video or plan to process it later.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                          height: 1.4,
                                        ),
                                      ),
                          
                                      SizedBox(height: 16),
                          
                                      /// Footer hint
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.lightbulb_outline,
                                            size: 16,
                                            color: Colors.blueAccent,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Tip: If you only need the raw video, check the Raw tab before processing.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.white60,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            )
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Processed'),
              Tab(text: 'Raw Files'),
            ],
          ),
        ),
        body: BlocConsumer<FilesBloc, FilesState>(
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error!)),
              );
            }
          },
          builder: (context, state) {
            return TabBarView(
              children: [
                _buildFileGrid(state.processedFiles, state.isLoading, context),
                Stack(
                  children: [
                    _buildFileGrid(state.rawFiles, state.isLoading, context),
                    Positioned.fill(
                      child: PremiumFeatureGate(
                        premiumContent: const SizedBox.shrink(),
                        freeContent: Container(
                          color: Colors.grey.withOpacity(0.6),
                          child: Center(
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
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
                                      child: const Icon(
                                        Icons.auto_awesome,
                                        size: 48,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Unlock Pro Features',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.coffee,
                                            size: 20,
                                            color: Colors.brown,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Lifetime Pro costs less than your daily coffee.',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
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
                                      onPressed: () =>
                                          PremiumUpgradeDialog.show(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber[700],
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size.fromHeight(56),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Get Pro Now',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
