import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import '../../domain/services/audio_session_service_interface.dart';

/// Platform-aware implementation of [IAudioSessionService].
///
/// Wraps the `audio_session` package to:
///   1. Configure AVAudioSession (iOS) / AudioManager (Android) for
///      concurrent dashcam recording + background music + Bluetooth.
///   2. Expose a domain-level [interruptionStream] that the BLoC
///      subscribes to for seamless segment rotation during phone calls.
///   3. Track [isCurrentlyInterrupted] so callers know the mic state
///      even if the interruption began before subscribing.
class AudioSessionServiceImpl implements IAudioSessionService {
  final StreamController<DashcamAudioInterruption> _interruptionCtrl =
      StreamController<DashcamAudioInterruption>.broadcast();

  StreamSubscription? _interruptionSub;
  bool _interrupted = false;

  @override
  bool get isCurrentlyInterrupted => _interrupted;

  @override
  Stream<DashcamAudioInterruption> get interruptionStream =>
      _interruptionCtrl.stream;

  @override
  Future<void> configureForDashcam() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers |
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetoothA2dp,
      avAudioSessionMode: AVAudioSessionMode.videoRecording,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.movie,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType:
          AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ));

    // Subscribe to OS-level audio interruptions (phone calls, Siri, alarms).
    // The `audio_session` package handles both iOS (AVAudioSession interruption
    // notifications) and Android (AudioManager.OnAudioFocusChangeListener).
    _interruptionSub?.cancel();
    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        debugPrint(
            '[AudioSession] ⚠️ Interruption BEGAN (type: ${event.type})');
        _interrupted = true;
        _interruptionCtrl.add(DashcamAudioInterruption.began);
      } else {
        debugPrint(
            '[AudioSession] ✅ Interruption ENDED (shouldResume: ${event.type})');
        _interrupted = false;
        _interruptionCtrl.add(DashcamAudioInterruption.ended);
      }
    });
  }

  @override
  void dispose() {
    _interruptionSub?.cancel();
    _interruptionSub = null;
    _interruptionCtrl.close();
  }
}
