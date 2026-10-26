// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_lifecycle.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlatformLifecycle extends PlatformLifecycle {
  @override
  final bool backgroundPlayback;
  @override
  final bool pauseOnInactive;
  @override
  final bool pauseOnBackground;
  @override
  final bool resumeOnForeground;
  @override
  final bool keepAudioAlive;
  @override
  final bool suspendAllowed;
  @override
  final bool restoreAfterSuspend;

  factory _$PlatformLifecycle([
    void Function(PlatformLifecycleBuilder)? updates,
  ]) => (PlatformLifecycleBuilder()..update(updates))._build();

  _$PlatformLifecycle._({
    required this.backgroundPlayback,
    required this.pauseOnInactive,
    required this.pauseOnBackground,
    required this.resumeOnForeground,
    required this.keepAudioAlive,
    required this.suspendAllowed,
    required this.restoreAfterSuspend,
  }) : super._();
  @override
  PlatformLifecycle rebuild(void Function(PlatformLifecycleBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlatformLifecycleBuilder toBuilder() =>
      PlatformLifecycleBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlatformLifecycle &&
        backgroundPlayback == other.backgroundPlayback &&
        pauseOnInactive == other.pauseOnInactive &&
        pauseOnBackground == other.pauseOnBackground &&
        resumeOnForeground == other.resumeOnForeground &&
        keepAudioAlive == other.keepAudioAlive &&
        suspendAllowed == other.suspendAllowed &&
        restoreAfterSuspend == other.restoreAfterSuspend;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, backgroundPlayback.hashCode);
    _$hash = $jc(_$hash, pauseOnInactive.hashCode);
    _$hash = $jc(_$hash, pauseOnBackground.hashCode);
    _$hash = $jc(_$hash, resumeOnForeground.hashCode);
    _$hash = $jc(_$hash, keepAudioAlive.hashCode);
    _$hash = $jc(_$hash, suspendAllowed.hashCode);
    _$hash = $jc(_$hash, restoreAfterSuspend.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlatformLifecycle')
          ..add('backgroundPlayback', backgroundPlayback)
          ..add('pauseOnInactive', pauseOnInactive)
          ..add('pauseOnBackground', pauseOnBackground)
          ..add('resumeOnForeground', resumeOnForeground)
          ..add('keepAudioAlive', keepAudioAlive)
          ..add('suspendAllowed', suspendAllowed)
          ..add('restoreAfterSuspend', restoreAfterSuspend))
        .toString();
  }
}

class PlatformLifecycleBuilder
    implements Builder<PlatformLifecycle, PlatformLifecycleBuilder> {
  _$PlatformLifecycle? _$v;

  bool? _backgroundPlayback;
  bool? get backgroundPlayback => _$this._backgroundPlayback;
  set backgroundPlayback(bool? backgroundPlayback) =>
      _$this._backgroundPlayback = backgroundPlayback;

  bool? _pauseOnInactive;
  bool? get pauseOnInactive => _$this._pauseOnInactive;
  set pauseOnInactive(bool? pauseOnInactive) =>
      _$this._pauseOnInactive = pauseOnInactive;

  bool? _pauseOnBackground;
  bool? get pauseOnBackground => _$this._pauseOnBackground;
  set pauseOnBackground(bool? pauseOnBackground) =>
      _$this._pauseOnBackground = pauseOnBackground;

  bool? _resumeOnForeground;
  bool? get resumeOnForeground => _$this._resumeOnForeground;
  set resumeOnForeground(bool? resumeOnForeground) =>
      _$this._resumeOnForeground = resumeOnForeground;

  bool? _keepAudioAlive;
  bool? get keepAudioAlive => _$this._keepAudioAlive;
  set keepAudioAlive(bool? keepAudioAlive) =>
      _$this._keepAudioAlive = keepAudioAlive;

  bool? _suspendAllowed;
  bool? get suspendAllowed => _$this._suspendAllowed;
  set suspendAllowed(bool? suspendAllowed) =>
      _$this._suspendAllowed = suspendAllowed;

  bool? _restoreAfterSuspend;
  bool? get restoreAfterSuspend => _$this._restoreAfterSuspend;
  set restoreAfterSuspend(bool? restoreAfterSuspend) =>
      _$this._restoreAfterSuspend = restoreAfterSuspend;

  PlatformLifecycleBuilder() {
    PlatformLifecycle._initialize(this);
  }

  PlatformLifecycleBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _backgroundPlayback = $v.backgroundPlayback;
      _pauseOnInactive = $v.pauseOnInactive;
      _pauseOnBackground = $v.pauseOnBackground;
      _resumeOnForeground = $v.resumeOnForeground;
      _keepAudioAlive = $v.keepAudioAlive;
      _suspendAllowed = $v.suspendAllowed;
      _restoreAfterSuspend = $v.restoreAfterSuspend;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlatformLifecycle other) {
    _$v = other as _$PlatformLifecycle;
  }

  @override
  void update(void Function(PlatformLifecycleBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlatformLifecycle build() => _build();

  _$PlatformLifecycle _build() {
    final _$result =
        _$v ??
        _$PlatformLifecycle._(
          backgroundPlayback: BuiltValueNullFieldError.checkNotNull(
            backgroundPlayback,
            r'PlatformLifecycle',
            'backgroundPlayback',
          ),
          pauseOnInactive: BuiltValueNullFieldError.checkNotNull(
            pauseOnInactive,
            r'PlatformLifecycle',
            'pauseOnInactive',
          ),
          pauseOnBackground: BuiltValueNullFieldError.checkNotNull(
            pauseOnBackground,
            r'PlatformLifecycle',
            'pauseOnBackground',
          ),
          resumeOnForeground: BuiltValueNullFieldError.checkNotNull(
            resumeOnForeground,
            r'PlatformLifecycle',
            'resumeOnForeground',
          ),
          keepAudioAlive: BuiltValueNullFieldError.checkNotNull(
            keepAudioAlive,
            r'PlatformLifecycle',
            'keepAudioAlive',
          ),
          suspendAllowed: BuiltValueNullFieldError.checkNotNull(
            suspendAllowed,
            r'PlatformLifecycle',
            'suspendAllowed',
          ),
          restoreAfterSuspend: BuiltValueNullFieldError.checkNotNull(
            restoreAfterSuspend,
            r'PlatformLifecycle',
            'restoreAfterSuspend',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
