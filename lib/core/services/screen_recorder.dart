import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:screen_recorder/screen_recorder.dart';


class ScreenRecorderController {
  ScreenRecorderController({
    Exporter? exporter,
    this.pixelRatio = 0.5,
    this.skipFramesBetweenCaptures = 2,
    SchedulerBinding? binding,
  })  : _containerKey = GlobalKey(),
        _binding = binding ?? SchedulerBinding.instance,
        _exporter = exporter ?? Exporter();

  GlobalKey get containerKey => _containerKey;
  final GlobalKey _containerKey;
  final SchedulerBinding _binding;
  final Exporter _exporter;

  Exporter get exporter => _exporter;

  /// The pixelRatio describes the scale between the logical pixels and the size
  /// of the output image. Specifying 1.0 will give you a 1:1 mapping between
  /// logical pixels and the output pixels in the image. The default is a pixel
  /// ration of 3 and a value below 1 is not recommended.
  ///
  /// See [RenderRepaintBoundary](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html)
  /// for the underlying implementation.
  final double pixelRatio;

  /// Describes how many frames are skipped between caputerd frames.
  /// For example if it's `skipFramesBetweenCaptures = 2` screen_recorder
  /// captures a frame, skips the next two frames and then captures the next
  /// frame again.
  final int skipFramesBetweenCaptures;

  int skipped = 0;

  bool _record = false;

  void start() {
    // only start a video, if no recording is in progress
    if (_record == true) {
      return;
    }
    _record = true;
    _binding.addPostFrameCallback(postFrameCallback);
  }

  void stop() {
    _record = false;
  }

  void postFrameCallback(Duration timestamp) async {
    if (_record == false) {
      return;
    }
    if (skipped > 0) {
      // count down frames which should be skipped
      skipped = skipped - 1;
      // add a new PostFrameCallback to know about the next frame
      _binding.addPostFrameCallback(postFrameCallback);
      // but we do nothing, because we skip this frame
      return;
    }
    if (skipped == 0) {
      // reset skipped frame counter
      skipped = skipped + skipFramesBetweenCaptures;
    }
    try {
      final image = capture();
      if (image == null) {
        debugPrint('capture returned null');
        return;
      }
      _exporter.onNewFrame(Frame(timestamp, image));
    } catch (e) {
      debugPrint(e.toString());
    }
    _binding.addPostFrameCallback(postFrameCallback);
  }

  ui.Image? capture() {
    if(_containerKey.currentContext==null){
      print("Yesssssss!! containerkey is null");
      return null;
    }
    final renderObject = _containerKey.currentContext!.findRenderObject()
    as RenderRepaintBoundary;

    return renderObject.toImageSync(pixelRatio: pixelRatio);
  }
}

class ScreenRecorder extends StatelessWidget {
  const ScreenRecorder({
    super.key,
    required this.child,
    required this.controller,
    required this.width,
    required this.height,
    this.background = Colors.transparent,
  });

  final Widget child;
  final ScreenRecorderController controller;
  final double width;
  final double height;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: controller.containerKey,
      child: Container(
        width: width,
        height: height,
        color: background,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
