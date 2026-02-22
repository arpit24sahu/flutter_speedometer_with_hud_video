import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import 'app_dialog_item.dart';
import '../../services/deeplink_service.dart';

class DialogManager {
  // Singleton
  DialogManager._internal();
  static final DialogManager _instance = DialogManager._internal();
  factory DialogManager() => _instance;

  final List<AppDialogItem> _dialogQueue = [];
  bool _isDialogShowing = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  void showDialog(AppDialogItem dialog) {
    _dialogQueue.add(dialog);
    // Sort ascending by priority so smaller priority values (easier) come first
    _dialogQueue.sort((a, b) => a.priority.compareTo(b.priority));
    _showNext();
  }

  Future<void> _showNext() async {
    if (_isDialogShowing || _dialogQueue.isEmpty) return;

    final BuildContext? context = DeeplinkService.navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      // Cannot show dialog yet, will try again later or optionally wait
      return;
    }

    _isDialogShowing = true;
    final AppDialogItem nextDialog = _dialogQueue.removeAt(0);

    // Play sound if provided
    if (nextDialog.soundPath != null) {
      String path = nextDialog.soundPath!;
      if (path.startsWith('assets/')) {
        path = path.substring('assets/'.length);
      }
      _audioPlayer.play(AssetSource(path));
      HapticFeedback.mediumImpact();
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: nextDialog.barrierDismissible,
      barrierLabel: 'AppDialog',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return nextDialog.dialogWidget;
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        );
      },
    );

    _isDialogShowing = false;
    _showNext();
  }
}
