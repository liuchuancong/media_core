// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visibility_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$VisibilityState extends VisibilityState {
  @override
  final bool visible;
  @override
  final double visibility;
  @override
  final bool inViewport;
  @override
  final bool occluded;

  factory _$VisibilityState([void Function(VisibilityStateBuilder)? updates]) =>
      (VisibilityStateBuilder()..update(updates))._build();

  _$VisibilityState._({
    required this.visible,
    required this.visibility,
    required this.inViewport,
    required this.occluded,
  }) : super._();
  @override
  VisibilityState rebuild(void Function(VisibilityStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  VisibilityStateBuilder toBuilder() => VisibilityStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is VisibilityState &&
        visible == other.visible &&
        visibility == other.visibility &&
        inViewport == other.inViewport &&
        occluded == other.occluded;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, visible.hashCode);
    _$hash = $jc(_$hash, visibility.hashCode);
    _$hash = $jc(_$hash, inViewport.hashCode);
    _$hash = $jc(_$hash, occluded.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'VisibilityState')
          ..add('visible', visible)
          ..add('visibility', visibility)
          ..add('inViewport', inViewport)
          ..add('occluded', occluded))
        .toString();
  }
}

class VisibilityStateBuilder
    implements Builder<VisibilityState, VisibilityStateBuilder> {
  _$VisibilityState? _$v;

  bool? _visible;
  bool? get visible => _$this._visible;
  set visible(bool? visible) => _$this._visible = visible;

  double? _visibility;
  double? get visibility => _$this._visibility;
  set visibility(double? visibility) => _$this._visibility = visibility;

  bool? _inViewport;
  bool? get inViewport => _$this._inViewport;
  set inViewport(bool? inViewport) => _$this._inViewport = inViewport;

  bool? _occluded;
  bool? get occluded => _$this._occluded;
  set occluded(bool? occluded) => _$this._occluded = occluded;

  VisibilityStateBuilder() {
    VisibilityState._initialize(this);
  }

  VisibilityStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _visible = $v.visible;
      _visibility = $v.visibility;
      _inViewport = $v.inViewport;
      _occluded = $v.occluded;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(VisibilityState other) {
    _$v = other as _$VisibilityState;
  }

  @override
  void update(void Function(VisibilityStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  VisibilityState build() => _build();

  _$VisibilityState _build() {
    final _$result =
        _$v ??
        _$VisibilityState._(
          visible: BuiltValueNullFieldError.checkNotNull(
            visible,
            r'VisibilityState',
            'visible',
          ),
          visibility: BuiltValueNullFieldError.checkNotNull(
            visibility,
            r'VisibilityState',
            'visibility',
          ),
          inViewport: BuiltValueNullFieldError.checkNotNull(
            inViewport,
            r'VisibilityState',
            'inViewport',
          ),
          occluded: BuiltValueNullFieldError.checkNotNull(
            occluded,
            r'VisibilityState',
            'occluded',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
