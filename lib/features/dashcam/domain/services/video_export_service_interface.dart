import 'dart:io';

abstract class IVideoExportService {
  Future<String?> exportVideoWithOverlays(File inputVideo, {void Function(double)? onProgress});
}
