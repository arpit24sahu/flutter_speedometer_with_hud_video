import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:speedometer/features/processing/bloc/processor_bloc.dart';
import '../bloc/jobs_bloc.dart';
import '../models/processing_job.dart';

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Processing Jobs'),
          centerTitle: false,
          actions: [
            IconButton(
              onPressed: ()async{
                context.read<JobsBloc>().add(LoadJobs());
              },
              icon: Icon(Icons.refresh),
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
                                maxHeight: 440,
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
                                          'Processing Jobs',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 12),

                                      Text(
                                        'How it works',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Each recorded video is treated as a job. Jobs are processed one by one in the background to ensure stability and accuracy.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                          height: 1.4,
                                        ),
                                      ),

                                      SizedBox(height: 16),

                                      /// Pending
                                      Text(
                                        'Pending',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amberAccent,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Jobs waiting to be processed. If a job appears stuck, you can manually start it.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                          height: 1.4,
                                        ),
                                      ),

                                      SizedBox(height: 14),

                                      /// Completed
                                      Text(
                                        'Completed',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.greenAccent,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Successfully processed jobs. You can play the final video with the speedometer or access the original raw video.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                          height: 1.4,
                                        ),
                                      ),

                                      SizedBox(height: 14),

                                      /// Failed
                                      Text(
                                        'Failed',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Jobs that could not be processed due to an error. You can retry them as long as the raw video files are still available and not corrupted.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                          height: 1.4,
                                        ),
                                      ),

                                      SizedBox(height: 16),

                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 16,
                                            color: Colors.blueAccent,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Tip: Keeping raw files intact allows you to retry failed jobs anytime.',
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
              Tab(text: 'Pending'),
              Tab(text: 'Completed'),
              Tab(text: 'Failed'),
            ],
          ),
        ),
        body: BlocBuilder<JobsBloc, JobsState>(
          builder: (context, state) {
            if (state.isLoading && 
                state.pendingJobs.isEmpty && 
                state.completedJobs.isEmpty && 
                state.failedJobs.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return TabBarView(
              children: [
                _JobsListView(jobs: state.pendingJobs, emptyMessage: 'No pending jobs', jobStatus: ProcessingJobStatus.pending),
                _JobsListView(jobs: state.completedJobs, emptyMessage: 'No completed jobs', jobStatus: ProcessingJobStatus.success),
                _JobsListView(jobs: state.failedJobs, emptyMessage: 'No failed jobs', jobStatus: ProcessingJobStatus.failure),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _JobsListView extends StatelessWidget {
  final List<ProcessingJob> jobs;
  final String emptyMessage;
  final ProcessingJobStatus jobStatus;

  const _JobsListView({
    required this.jobs,
    required this.emptyMessage,
    required this.jobStatus
  });

  Future<bool> canProcess(ProcessingJob job)async{
    bool videoFileExists = await File(job.videoFilePath).exists();
    bool widgetFileExists = await File(job.overlayFilePath).exists();

    return videoFileExists && widgetFileExists;
  }

  Future<bool> canPlay(String filePath)async{
    bool videoFileExists = await File(filePath).exists();
    return videoFileExists;
  }


  Widget _buildSubtitle(BuildContext context, int index){
    final ProcessingJob job = jobs[index];

    switch(jobStatus) {
      case ProcessingJobStatus.failure: {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MaterialButton(
              color: Colors.green,
              onPressed: ()async{
                if(!(await canProcess(job))){
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Cannot Process. Video file missing."))
                  );
                  return;
                }
                if(context.mounted) context.read<JobsBloc>().add(RetryJob(job));
                await Future.delayed(Duration(milliseconds: 500), (){
                  if(context.mounted) context.read<ProcessorBloc>().add(StartProcessing());
                });
              },
              child: Text("Retry"),
            ),
            MaterialButton(
              color: Colors.blue,
              shape: StadiumBorder(),
              onPressed: ()async{
                if(!(await canPlay(job.videoFilePath))){
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Video file not found"))
                  );
                  return;
                }
                final result = await OpenFile.open(job.videoFilePath);
                debugPrint('OpenFile result: ${result.type}, ${result.message}');
              },
              child: Text("Play Raw Video"),
            ),
          ],
        );
      }
      case ProcessingJobStatus.pending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MaterialButton(
              color: Colors.green,
              shape: StadiumBorder(),
              onPressed: ()async{
                if(!(await canProcess(job))){
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Cannot Process. Video file missing."))
                  );
                  return;
                }
                context.read<ProcessorBloc>().add(StartProcessing(job: job));
              },
              child: Text("Start Processing"),
            ),
            MaterialButton(
              color: Colors.blue,
              shape: StadiumBorder(),
              onPressed: ()async{
                if(!(await canPlay(job.videoFilePath))){
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Video file not found"))
                  );
                  return;
                }
                final result = await OpenFile.open(job.videoFilePath);
                debugPrint('OpenFile result: ${result.type}, ${result.message}');
              },
              child: Text("Play Raw Video"),
            ),
          ],
        );
      case ProcessingJobStatus.processing:
        // TODO: Handle this case.
        return SizedBox.shrink();
      case ProcessingJobStatus.success:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MaterialButton(
              color: Colors.green,
              shape: StadiumBorder(),
              onPressed: ()async{
                if(!(await canPlay(job.processedFilePath!))){
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Processed video file not found"))
                  );
                  return;
                }
                final result = await OpenFile.open(job.processedFilePath);
                debugPrint('OpenFile result: ${result.type}, ${result.message}');
              },
              child: Text("Play Processed Video"),
            ),
            MaterialButton(
              color: Colors.blue,
              shape: StadiumBorder(),
              onPressed: ()async{
                if(!(await canPlay(job.videoFilePath))){
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Video file not found"))
                  );
                  return;
                }
                final result = await OpenFile.open(job.videoFilePath);
                debugPrint('OpenFile result: ${result.type}, ${result.message}');
              },
              child: Text("Play Raw Video"),
            ),
          ],
        );
    }
  }


  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            child: ListTile(
              title: Text(job.processedFilePath ?? job.id),
              subtitle: Align(alignment: Alignment.centerLeft, child: _buildSubtitle(context, index)),
              // onLongPress: (){
              //   context.read<ProcessorBloc>().add(StartProcessing(job: job));
              // },
              // trailing: job.status == ProcessingJobStatus.failure
              //   ? IconButton(
              //       icon: const Icon(Icons.refresh),
              //       onPressed: () => context.read<JobsBloc>().add(RetryJob(job)),
              //     )
              //   : null,
            ),
          ),
        );
      },
    );
  }
}