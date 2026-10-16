/// The vocabulary a background job is described in.
///
/// A job says what it is doing and what it needs; it does not say which service
/// to start, which lock to take or which notification to post. That is the
/// runtime's decision, and the reason the words live here rather than in the
/// platform package: the download package, the recording package and a host's
/// own code all speak them, and none of them may have to link Android.
///
/// See `doc/media_core_background_runtime_architecture.md` for why media
/// playback is deliberately absent from [BackgroundExecutionKind].
library;

import 'package:meta/meta.dart';

/// What a job is doing, for the runtime that has to keep it alive.
///
/// Media playback is not one of these. It has its own service ownership on
/// Android (`media_core_mediasession` over `audio_service`) and its own control
/// surface, and folding it in here would put `mediaPlayback` on a service that
/// declares `dataSync` — which Android 14 rejects rather than forgiving.
enum BackgroundExecutionKind {
  /// Capturing a stream to disk.
  recording,

  /// Fetching a file.
  download,

  /// Work the runtime knows nothing about.
  generic;

  /// Which service owns this kind's life and death.
  ///
  /// Today every kind is a job, so the answer is always
  /// [BackgroundServiceOwner.jobService]; the method
  /// exists because the mapping is a policy, not a coincidence, and the media
  /// case arrives with a different owner.
  BackgroundServiceOwner get serviceOwner => BackgroundServiceOwner.jobService;
}

/// Which of the runtime's executors a request belongs to.
enum BackgroundServiceOwner {
  /// The job foreground service in `media_core_native`: recording, download and
  /// anything else that is work rather than playback.
  jobService,

  /// The media session backend in `media_core_mediasession`: the platform's
  /// playback surface, its own service and its own notification.
  mediaSession,
}

/// A capability the runtime can grant a session.
///
/// Granting one means "this backend undertakes to hold it for as long as the
/// session lives", not "the system guarantees it". A wake lock does not keep the
/// network up, and a foreground service can still be killed under memory
/// pressure; the lease reports the loss when it happens.
enum BackgroundCapability {
  /// The CPU keeps running with the screen off.
  cpuWakeLock,

  /// The process is exempt from being suspended while the session lives.
  foregroundExecution,

  /// A notification the user can see is held for the session.
  persistentNotification,

  /// Audio keeps playing in the background. Owned by the media session, never
  /// granted by a job lease.
  backgroundAudio,
}

/// Where a session is in its life.
enum BackgroundSessionStatus {
  /// Accepted; the backend has not confirmed it yet.
  starting,

  /// Running with the capabilities the result reported.
  running,

  /// Running, with something given up.
  ///
  /// The job keeps going: a recording whose notification the user declined is a
  /// recording, and failing it over a picture would be the worse outcome.
  degraded,

  /// Releasing; the backend has not finished yet.
  stopping,

  /// Released, and nothing is held for it any more.
  stopped,

  /// Ended without the job completing.
  failed,
}

/// Why a request was not granted.
///
/// Null used to be the whole answer — "no background execution here" — which
/// made an unsupported platform, a refused permission and a rejected service
/// start indistinguishable to the caller, and left a host unable to tell the
/// user what to do about it.
enum BackgroundAcquireFailure {
  /// The platform or the user said no to something the request needs.
  permissionDenied,

  /// This platform has no implementation of the capability at all.
  unsupportedPlatform,

  /// The system refused to start the service (background-start restrictions, a
  /// missing manifest declaration, a foreground-service type it rejects).
  foregroundStartRejected,

  /// The session runs, but not with what was asked for.
  capabilityUnavailable,

  /// The request itself is unusable: an empty id, an empty title.
  invalidRequest,
}

/// What a session already held on this id is worth when the same id comes in
/// again.
///
/// The old path let a repeated acquire add a second reference silently, so one
/// owner's release took the protection away from the other. Duplicate ids are
/// therefore an explicit choice at the door, never an accident.
enum BackgroundDuplicatePolicy {
  /// Refuse the request; the first owner keeps the session.
  reject,

  /// Hand back a handle to the existing session. Releasing that handle lets the
  /// view go, not the session: the owner that acquired it still holds it.
  share,

  /// Replace what the existing session describes and hand back the same session.
  /// Whoever releases it releases it for everyone.
  update,
}

/// One job's request for background execution.
///
/// [id] is the session's identity, not this object's: it must stay the same
/// across a progress update and change between two different jobs, because the
/// registry keys on it and the notification is aggregated from it.
///
/// ```dart
/// const request = BackgroundRequest(
///   id: 'recording/room-42',
///   kind: BackgroundExecutionKind.recording,
///   title: '正在录制',
///   description: 'room-42 · 00:12:34',
/// );
/// ```
@immutable
final class BackgroundRequest {
  /// Creates a request.
  const BackgroundRequest({
    required this.id,
    required this.kind,
    required this.title,
    this.description,
    this.requiresCpuWakeLock = true,
    this.icon,
    this.progress,
    this.priority = 0,
    this.duplicatePolicy = BackgroundDuplicatePolicy.reject,
  });

  /// Stable identity of the session this request is for.
  final String id;

  /// What the job is doing.
  final BackgroundExecutionKind kind;

  /// First line: what is running.
  ///
  /// The host's own words — a room title, a file name. The library ships the
  /// mechanism, not the text, and an aggregate built out of "Recording" tells a
  /// user nothing they can act on.
  final String title;

  /// Second line: what it is working on. Null shows a bare title.
  final String? description;

  /// Whether the CPU must keep running with the screen off.
  ///
  /// A short upload passes false and saves the battery; a recording that stops
  /// when the screen does is not a recording.
  final bool requiresCpuWakeLock;

  /// Name of a drawable the **host app** ships, for the platforms that draw one.
  ///
  /// The same convention the media notification uses. Null lets the backend pick
  /// the glyph for [kind]; a name that does not resolve falls back to that glyph
  /// rather than to a broken notification.
  final String? icon;

  /// How far along the job is, on the platforms that can draw it.
  ///
  /// Null shows no bar. A live recording has no total, so the honest shape is
  /// [BackgroundJobProgress.indeterminate] rather than "0 of 0" — a percentage a
  /// job cannot know makes the platform draw a number that means nothing.
  final BackgroundJobProgress? progress;

  /// Ordering among the sessions that are running at once.
  ///
  /// Higher wins the first line of the aggregate; it is a display rule, and
  /// never a way to take another session's protection away.
  final int priority;

  /// What to do when [id] is already held.
  final BackgroundDuplicatePolicy duplicatePolicy;

  /// What is wrong with this request, or null when it is usable.
  ///
  /// Returned rather than thrown because a caller usually has a fallback: an
  /// unnamed job can be named by its id, and a host that built the request out
  /// of user input would rather fix the input than catch an exception.
  String? validationError() {
    if (id.isEmpty) {
      return 'a background session id cannot be empty: it is what release() acts on';
    }

    if (title.isEmpty) {
      return 'the title of "${_shortId(id)}" is empty: it is the whole of the first line';
    }

    if (priority < _minPriority || priority > _maxPriority) {
      return 'priority must be between $_minPriority and $_maxPriority';
    }

    return null;
  }

  static const int _minPriority = -1000;
  static const int _maxPriority = 1000;

  static String _shortId(String id) => id.length <= 40 ? id : '${id.substring(0, 40)}…';

  /// The same request with some fields replaced.
  ///
  /// Null means "keep", which is why [description] cannot be cleared here; a job
  /// that wants a bare title builds a new request.
  BackgroundRequest copyWith({
    String? id,
    BackgroundExecutionKind? kind,
    String? title,
    String? description,
    bool? requiresCpuWakeLock,
    String? icon,
    BackgroundJobProgress? progress,
    int? priority,
    BackgroundDuplicatePolicy? duplicatePolicy,
  }) {
    return BackgroundRequest(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      description: description ?? this.description,
      requiresCpuWakeLock: requiresCpuWakeLock ?? this.requiresCpuWakeLock,
      icon: icon ?? this.icon,
      progress: progress ?? this.progress,
      priority: priority ?? this.priority,
      duplicatePolicy: duplicatePolicy ?? this.duplicatePolicy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundRequest &&
          other.id == id &&
          other.kind == kind &&
          other.title == title &&
          other.description == description &&
          other.requiresCpuWakeLock == requiresCpuWakeLock &&
          other.icon == icon &&
          other.progress == progress &&
          other.priority == priority &&
          other.duplicatePolicy == duplicatePolicy;

  @override
  int get hashCode =>
      Object.hash(id, kind, title, description, requiresCpuWakeLock, icon, progress, priority, duplicatePolicy);

  @override
  String toString() =>
      'BackgroundRequest($id, ${kind.name}, title: $title, description: $description, '
      'wakeLock: $requiresCpuWakeLock, icon: $icon, progress: $progress, priority: $priority)';
}

/// How far along a job is, in the units the job counts in.
///
/// Bytes, segments, messages — whatever [BackgroundRequest.progress] means for
/// that job; a platform only draws the fraction. The units are the host's, and
/// the library never converts them into a claim about speed or time left.
@immutable
final class BackgroundJobProgress {
  /// The end is not known: the platform shows an activity indicator.
  const BackgroundJobProgress.indeterminate() : this._(null, null);

  /// The end is known: [current] of [total].
  const BackgroundJobProgress.determinate({required int current, required int total}) : this._(current, total);

  const BackgroundJobProgress._(this.current, this.total)
    : assert(total == null || total > 0, 'a determinate progress needs a positive total');

  /// Completed units, or null when the end is unknown.
  final int? current;

  /// Units in total, or null when the end is unknown.
  final int? total;

  /// Whether the end is unknown.
  bool get isIndeterminate => total == null;

  /// Fraction complete in `0..1`, or null when indeterminate.
  double? get fraction => total == null ? null : (current ?? 0) / total!;

  @override
  bool operator ==(Object other) => other is BackgroundJobProgress && other.current == current && other.total == total;

  @override
  int get hashCode => Object.hash(current, total);

  @override
  String toString() =>
      isIndeterminate ? 'BackgroundJobProgress.indeterminate()' : 'BackgroundJobProgress($current/$total)';
}
