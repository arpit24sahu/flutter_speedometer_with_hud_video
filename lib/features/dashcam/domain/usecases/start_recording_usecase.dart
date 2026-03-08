import '../../core/result.dart';
import '../entities/dashcam_failure.dart';
import '../repositories/dashcam_repository.dart';

/// Orchestrates the recording start flow:
/// 1. Check storage capacity
/// 2. Start recording
class StartRecordingUseCase {
  final DashcamRepository _repository;

  const StartRecordingUseCase(this._repository);

  Future<Result<void, DashcamFailure>> call() async {
    final settings = await _repository.getSettings();

    final storageResult = await _repository.checkStorageCapAndClean(settings.maxStorageGb);
    if (storageResult.isFailure) return storageResult;

    return _repository.startRecording();
  }
}
