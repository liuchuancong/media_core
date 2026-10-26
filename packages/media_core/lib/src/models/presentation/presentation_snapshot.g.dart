// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presentation_snapshot.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PresentationSnapshot extends PresentationSnapshot {
  @override
  final PresentationMode mode;
  @override
  final PresentationMode? targetMode;
  @override
  final PresentationCapabilities capabilities;
  @override
  final VideoOrientation orientation;
  @override
  final bool transitioning;
  @override
  final bool enabled;
  @override
  final bool available;
  @override
  final int generation;
  @override
  final String? error;

  factory _$PresentationSnapshot([
    void Function(PresentationSnapshotBuilder)? updates,
  ]) => (PresentationSnapshotBuilder()..update(updates))._build();

  _$PresentationSnapshot._({
    required this.mode,
    this.targetMode,
    required this.capabilities,
    required this.orientation,
    required this.transitioning,
    required this.enabled,
    required this.available,
    required this.generation,
    this.error,
  }) : super._();
  @override
  PresentationSnapshot rebuild(
    void Function(PresentationSnapshotBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PresentationSnapshotBuilder toBuilder() =>
      PresentationSnapshotBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PresentationSnapshot &&
        mode == other.mode &&
        targetMode == other.targetMode &&
        capabilities == other.capabilities &&
        orientation == other.orientation &&
        transitioning == other.transitioning &&
        enabled == other.enabled &&
        available == other.available &&
        generation == other.generation &&
        error == other.error;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mode.hashCode);
    _$hash = $jc(_$hash, targetMode.hashCode);
    _$hash = $jc(_$hash, capabilities.hashCode);
    _$hash = $jc(_$hash, orientation.hashCode);
    _$hash = $jc(_$hash, transitioning.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, available.hashCode);
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, error.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PresentationSnapshot')
          ..add('mode', mode)
          ..add('targetMode', targetMode)
          ..add('capabilities', capabilities)
          ..add('orientation', orientation)
          ..add('transitioning', transitioning)
          ..add('enabled', enabled)
          ..add('available', available)
          ..add('generation', generation)
          ..add('error', error))
        .toString();
  }
}

class PresentationSnapshotBuilder
    implements Builder<PresentationSnapshot, PresentationSnapshotBuilder> {
  _$PresentationSnapshot? _$v;

  PresentationMode? _mode;
  PresentationMode? get mode => _$this._mode;
  set mode(PresentationMode? mode) => _$this._mode = mode;

  PresentationMode? _targetMode;
  PresentationMode? get targetMode => _$this._targetMode;
  set targetMode(PresentationMode? targetMode) =>
      _$this._targetMode = targetMode;

  PresentationCapabilities? _capabilities;
  PresentationCapabilities? get capabilities => _$this._capabilities;
  set capabilities(PresentationCapabilities? capabilities) =>
      _$this._capabilities = capabilities;

  VideoOrientation? _orientation;
  VideoOrientation? get orientation => _$this._orientation;
  set orientation(VideoOrientation? orientation) =>
      _$this._orientation = orientation;

  bool? _transitioning;
  bool? get transitioning => _$this._transitioning;
  set transitioning(bool? transitioning) =>
      _$this._transitioning = transitioning;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  bool? _available;
  bool? get available => _$this._available;
  set available(bool? available) => _$this._available = available;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  String? _error;
  String? get error => _$this._error;
  set error(String? error) => _$this._error = error;

  PresentationSnapshotBuilder() {
    PresentationSnapshot._initialize(this);
  }

  PresentationSnapshotBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mode = $v.mode;
      _targetMode = $v.targetMode;
      _capabilities = $v.capabilities;
      _orientation = $v.orientation;
      _transitioning = $v.transitioning;
      _enabled = $v.enabled;
      _available = $v.available;
      _generation = $v.generation;
      _error = $v.error;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PresentationSnapshot other) {
    _$v = other as _$PresentationSnapshot;
  }

  @override
  void update(void Function(PresentationSnapshotBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PresentationSnapshot build() => _build();

  _$PresentationSnapshot _build() {
    final _$result =
        _$v ??
        _$PresentationSnapshot._(
          mode: BuiltValueNullFieldError.checkNotNull(
            mode,
            r'PresentationSnapshot',
            'mode',
          ),
          targetMode: targetMode,
          capabilities: BuiltValueNullFieldError.checkNotNull(
            capabilities,
            r'PresentationSnapshot',
            'capabilities',
          ),
          orientation: BuiltValueNullFieldError.checkNotNull(
            orientation,
            r'PresentationSnapshot',
            'orientation',
          ),
          transitioning: BuiltValueNullFieldError.checkNotNull(
            transitioning,
            r'PresentationSnapshot',
            'transitioning',
          ),
          enabled: BuiltValueNullFieldError.checkNotNull(
            enabled,
            r'PresentationSnapshot',
            'enabled',
          ),
          available: BuiltValueNullFieldError.checkNotNull(
            available,
            r'PresentationSnapshot',
            'available',
          ),
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'PresentationSnapshot',
            'generation',
          ),
          error: error,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
