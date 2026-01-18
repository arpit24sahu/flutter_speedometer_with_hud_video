import 'dart:async';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:speedometer/features/processing/models/processing_job.dart';

import '../bloc/processor_bloc.dart';
class ProcessingQueue {
  ProcessingQueue._internal(this.processorBloc, this.box);

  static ProcessingQueue? _instance;

  final Box<ProcessingJob> box;
  final ProcessorBloc processorBloc;
  StreamSubscription? _subscription;

  static ProcessingQueue init(
      ProcessorBloc processorBloc,
      Box<ProcessingJob> box,
      ) {
    return _instance ??= ProcessingQueue._internal(processorBloc, box);
  }

  void start() {
    print("Processing Queue Start Called");
    if (_subscription != null) return;

    _tryProcessNext();
    _subscription = box.watch().listen((_) {
      print("New Item Added to Box!");
      _tryProcessNext();
    });
  }

  void _tryProcessNext() {
    if (box.isEmpty) return;
    if (processorBloc.state.status == ProcessorStatus.ongoing) return;

    print("Calling StartProcessing from ProcessingQueue");
    processorBloc.add(StartProcessing());
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}