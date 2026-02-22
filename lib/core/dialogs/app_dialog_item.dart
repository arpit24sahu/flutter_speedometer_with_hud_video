import 'package:flutter/material.dart';

class AppDialogItem {
  final Widget dialogWidget;
  final String? soundPath;
  final bool barrierDismissible;
  final int priority;

  AppDialogItem({
    required this.dialogWidget,
    this.soundPath,
    this.barrierDismissible = false,
    this.priority = 0,
  });
}
