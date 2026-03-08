/// Represents the type of audio interruption from the OS.
///
/// [began] — Another audio source (phone call, Siri, alarm) has taken
///           exclusive control of the audio hardware.
/// [ended] — The interrupting audio source has released control and
///           our session can reclaim the microphone.
enum DashcamAudioInterruption { began, ended }

/// Abstraction over the native OS audio session, enabling:
///   1. Concurrent mixing of dashcam recording + background music + Bluetooth
///   2. Observing audio interruptions (phone calls) so the recording pipeline
///      can rotate segments instead of producing corrupt files.
abstract class IAudioSessionService {
  /// Configures the native OS audio session to allow concurrent mixing
  /// of dashboard recording, background music playback, and Bluetooth audio routing.
  Future<void> configureForDashcam();

  /// Whether the audio session is currently interrupted by an external source
  /// (e.g., the user is already on a phone call).
  ///
  /// This is critical for the "already on call when pressing record" edge case:
  /// the [interruptionStream] only fires for NEW interruptions, so we need a
  /// synchronous way to check the current state before starting recording.
  bool get isCurrentlyInterrupted;

  /// A broadcast stream that emits [DashcamAudioInterruption.began] when an
  /// external audio source (phone call, Siri, etc.) interrupts, and
  /// [DashcamAudioInterruption.ended] when the interruption is over.
  ///
  /// The BLoC subscribes to this stream to rotate recording segments
  /// seamlessly without producing corrupt mp4 files.
  Stream<DashcamAudioInterruption> get interruptionStream;

  /// Releases the interruption subscription and stream controller.
  /// Called when the DashcamBloc is closed.
  void dispose() {}
}
