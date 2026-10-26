/// What role a scheduled clip plays on the combined timeline.
///
/// `kind` is the only thing the schedule machine itself branches on:
/// entering and leaving [advertisement] segments is what interrupts
/// playback and fires tracking, while every other kind flows straight
/// through. What the kinds mean to the user — an ad break versus a
/// filler versus the next episode — is the host's vocabulary, not the
/// composer's.
enum ClipKind {
  /// The program itself: the one clip kind whose internal clock the
  /// schedule tracks so a break can resume exactly where it cut in.
  content,

  /// A paid advertisement. The schedule refuses to cross an
  /// advertisement boundary while the playhead moves, and
  /// `ScheduleNavigator` surfaces skip decisions only for this kind.
  advertisement,

  /// Channel furniture between programs: promos, bumpers, filler.
  /// Passes through like [content] but is not itself resumable.
  filler,
}

/// Extension helpers for [ClipKind].
extension ClipKindX on ClipKind {
  /// Whether playback must be interrupted when entering or leaving
  /// this kind of clip.
  ///
  /// Only [ClipKind.advertisement] interrupts: a filler or a program
  /// continuation is just more timeline. This predicate is the single
  /// definition the navigator branches on, so a new pass-through kind
  /// never has to touch its code.
  bool get isInterruptive => this == ClipKind.advertisement;
}
