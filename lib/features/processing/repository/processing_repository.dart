// processing_repository.dart
import '../../../services/hive_service.dart';
import '../models/processing_job.dart';

class ProcessingRepository {
  final HiveService _hiveService;

  ProcessingRepository(this._hiveService);

  List<ProcessingJob> get pendingJobs {
    final jobs = _hiveService.pendingBox.values.toList();
    jobs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return jobs;
  }

  List<ProcessingJob> get completedJobs {
    final jobs = _hiveService.completedBox.values.toList();
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jobs;
  }

  List<ProcessingJob> get failedJobs {
    final jobs = _hiveService.failedBox.values.toList();
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jobs;
  }

  Future<void> addPendingJob(ProcessingJob job) async {
    await _hiveService.pendingBox.put(job.id, job);
  }

  Future<void> moveToCompleted(ProcessingJob job) async {
    await _hiveService.pendingBox.delete(job.id);
    await _hiveService.completedBox.put(job.id, job);
  }

  Future<void> moveToFailed(ProcessingJob job) async {
    await _hiveService.pendingBox.delete(job.id);
    await _hiveService.failedBox.put(job.id, job);
  }

  Future<void> retryJob(ProcessingJob job) async {
    await _hiveService.failedBox.delete(job.id);
    await _hiveService.pendingBox.put(job.id, job);
  }

  Future<void> deleteJob(String jobId) async {
    await _hiveService.pendingBox.delete(jobId);
    await _hiveService.completedBox.delete(jobId);
    await _hiveService.failedBox.delete(jobId);
  }

  ProcessingJob? getNextPendingJob() {
    if (_hiveService.pendingBox.isEmpty) return null;
    return pendingJobs.first;
  }

  Future<void> clearCompletedJobs() async {
    await _hiveService.completedBox.clear();
  }

  Future<void> clearFailedJobs() async {
    await _hiveService.failedBox.clear();
  }
}