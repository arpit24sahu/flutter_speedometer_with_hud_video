import '../../core/result.dart';
import '../entities/dashcam_failure.dart';
import '../repositories/dashcam_repository.dart';

/// Rotates the current recording segment:
/// 1. Rotate segment in repository
/// 2. Clean storage if over cap
class RotateSegmentUseCase {
  final DashcamRepository _repository;

  const RotateSegmentUseCase(this._repository);

  Future<Result<void, DashcamFailure>> call() async {
    final result = await _repository.rotateSegment();
    if (result.isFailure) return result;

    final settings = await _repository.getSettings();
    return _repository.checkStorageCapAndClean(settings.maxStorageGb);
  }
}
