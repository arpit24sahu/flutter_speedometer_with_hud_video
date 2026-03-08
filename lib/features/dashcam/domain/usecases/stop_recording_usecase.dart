import '../../core/result.dart';
import '../entities/dashcam_failure.dart';
import '../repositories/dashcam_repository.dart';

/// Stops recording and returns the result.
class StopRecordingUseCase {
  final DashcamRepository _repository;

  const StopRecordingUseCase(this._repository);

  Future<Result<void, DashcamFailure>> call() async {
    return _repository.stopRecording();
  }
}
