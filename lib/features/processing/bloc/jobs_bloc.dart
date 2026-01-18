import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/processing_job.dart';
import '../repository/processing_repository.dart';

// Events
abstract class JobsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadJobs extends JobsEvent {}

class AddJob extends JobsEvent {
  final ProcessingJob job;
  AddJob(this.job);
  @override
  List<Object?> get props => [job];
}

class RefreshJobs extends JobsEvent {} 

class DeleteJob extends JobsEvent {
  final String jobId;
  DeleteJob(this.jobId);
  @override
  List<Object?> get props => [jobId];
}

class RetryJob extends JobsEvent {
  final ProcessingJob job;
  RetryJob(this.job);
  @override
  List<Object?> get props => [job];
}

class ClearCompletedJobs extends JobsEvent {}
class ClearFailedJobs extends JobsEvent {}

// State
class JobsState extends Equatable {
  final List<ProcessingJob> pendingJobs;
  final List<ProcessingJob> completedJobs;
  final List<ProcessingJob> failedJobs;
  final bool isLoading;
  final String? error;

  const JobsState({
    this.pendingJobs = const [],
    this.completedJobs = const [],
    this.failedJobs = const [],
    this.isLoading = false,
    this.error,
  });

  JobsState copyWith({
    List<ProcessingJob>? pendingJobs,
    List<ProcessingJob>? completedJobs,
    List<ProcessingJob>? failedJobs,
    bool? isLoading,
    String? error,
  }) {
    return JobsState(
      pendingJobs: pendingJobs ?? this.pendingJobs,
      completedJobs: completedJobs ?? this.completedJobs,
      failedJobs: failedJobs ?? this.failedJobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [pendingJobs, completedJobs, failedJobs, isLoading, error];
}

class JobsBloc extends Bloc<JobsEvent, JobsState> {
  final ProcessingRepository repository;

  JobsBloc({required this.repository}) : super(const JobsState()) {
    on<LoadJobs>(_onLoadJobs);
    on<AddJob>(_onAddJob);
    on<RefreshJobs>(_onLoadJobs);
    on<DeleteJob>(_onDeleteJob);
    on<RetryJob>(_onRetryJob);
    on<ClearCompletedJobs>(_onClearCompletedJobs);
    on<ClearFailedJobs>(_onClearFailedJobs);
  }

  Future<void> _onLoadJobs(JobsEvent event, Emitter<JobsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final pending = repository.pendingJobs;
      final completed = repository.completedJobs;
      final failed = repository.failedJobs;
      print("LoadedJobs -");
      print("pending: ${pending.length}");
      print("completed: ${completed.length}");
      print("failed: ${failed.length}");
      emit(state.copyWith(
        pendingJobs: pending,
        completedJobs: completed,
        failedJobs: failed,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onAddJob(AddJob event, Emitter<JobsState> emit) async {
    try {
      await repository.addPendingJob(event.job);
      add(LoadJobs());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleteJob(DeleteJob event, Emitter<JobsState> emit) async {
    try {
      await repository.deleteJob(event.jobId);
      add(LoadJobs());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRetryJob(RetryJob event, Emitter<JobsState> emit) async {
    try {
      await repository.retryJob(event.job);
      add(LoadJobs());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

   Future<void> _onClearCompletedJobs(ClearCompletedJobs event, Emitter<JobsState> emit) async {
    try {
      await repository.clearCompletedJobs();
      add(LoadJobs());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onClearFailedJobs(ClearFailedJobs event, Emitter<JobsState> emit) async {
    try {
      await repository.clearFailedJobs();
      add(LoadJobs());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
