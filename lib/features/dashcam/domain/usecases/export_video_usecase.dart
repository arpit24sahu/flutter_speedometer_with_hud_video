import 'dart:io';
import '../../core/result.dart';
import '../entities/dashcam_failure.dart';
import '../repositories/dashcam_repository.dart';

/// Exports a video with GPS/speed overlays burned in.
class ExportVideoUseCase {
  final DashcamRepository _repository;

  const ExportVideoUseCase(this._repository);

  Future<Result<String, DashcamFailure>> call(File videoFile, {void Function(double)? onProgress}) async {
    return _repository.exportVideo(videoFile, onProgress: onProgress);
  }
}
