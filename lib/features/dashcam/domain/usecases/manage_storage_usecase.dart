import '../../core/result.dart';
import '../entities/dashcam_failure.dart';
import '../repositories/dashcam_repository.dart';

/// Manages storage: check cap, clean old files, get remaining space.
class ManageStorageUseCase {
  final DashcamRepository _repository;

  const ManageStorageUseCase(this._repository);

  Future<Result<double, DashcamFailure>> getRemainingGb() async {
    final settings = await _repository.getSettings();
    return _repository.getRemainingStorageGb(settings.maxStorageGb);
  }

  Future<Result<double, DashcamFailure>> getGlobalFreeSpaceGb() async {
    return _repository.getGlobalFreeSpaceGb();
  }

  Future<Result<void, DashcamFailure>> cleanIfNeeded() async {
    final settings = await _repository.getSettings();
    return _repository.checkStorageCapAndClean(settings.maxStorageGb);
  }

  Future<Result<void, DashcamFailure>> toggleLock(String fileId) async {
    return _repository.toggleClipLock(fileId);
  }
}
