/// Describes the lifecycle state of audio focus.
///
/// This is deliberately independent from any platform audio-focus API.
/// Platform adapters translate their native focus/interruption callbacks into
/// these states.
enum AudioFocusStatus {
  /// No focus has been requested or the focus lifecycle is idle.
  idle,

  /// A focus request is currently being processed.
  requesting,

  /// Focus has been granted.
  focused,

  /// Focus has been lost without enough information to classify the loss.
  lost,

  /// Focus was temporarily lost but may be recovered automatically.
  transientLoss,

  /// Focus has been permanently lost and must be requested again.
  permanentLoss,

  /// Focus has been abandoned by the application.
  abandoned,

  /// The focus subsystem encountered an error.
  error,

  /// The focus abstraction has been permanently disposed.
  disposed,
}
