// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RecordingResult extends RecordingResult {
  @override
  final bool success;
  @override
  final String? outputPath;
  @override
  final Duration duration;
  @override
  final int bytesWritten;
  @override
  final Object? error;

  factory _$RecordingResult([void Function(RecordingResultBuilder)? updates]) =>
      (RecordingResultBuilder()..update(updates))._build();

  _$RecordingResult._({
    required this.success,
    this.outputPath,
    required this.duration,
    required this.bytesWritten,
    this.error,
  }) : super._();
  @override
  RecordingResult rebuild(void Function(RecordingResultBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RecordingResultBuilder toBuilder() => RecordingResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RecordingResult &&
        success == other.success &&
        outputPath == other.outputPath &&
        duration == other.duration &&
        bytesWritten == other.bytesWritten &&
        error == other.error;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, success.hashCode);
    _$hash = $jc(_$hash, outputPath.hashCode);
    _$hash = $jc(_$hash, duration.hashCode);
    _$hash = $jc(_$hash, bytesWritten.hashCode);
    _$hash = $jc(_$hash, error.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RecordingResult')
          ..add('success', success)
          ..add('outputPath', outputPath)
          ..add('duration', duration)
          ..add('bytesWritten', bytesWritten)
          ..add('error', error))
        .toString();
  }
}

class RecordingResultBuilder
    implements Builder<RecordingResult, RecordingResultBuilder> {
  _$RecordingResult? _$v;

  bool? _success;
  bool? get success => _$this._success;
  set success(bool? success) => _$this._success = success;

  String? _outputPath;
  String? get outputPath => _$this._outputPath;
  set outputPath(String? outputPath) => _$this._outputPath = outputPath;

  Duration? _duration;
  Duration? get duration => _$this._duration;
  set duration(Duration? duration) => _$this._duration = duration;

  int? _bytesWritten;
  int? get bytesWritten => _$this._bytesWritten;
  set bytesWritten(int? bytesWritten) => _$this._bytesWritten = bytesWritten;

  Object? _error;
  Object? get error => _$this._error;
  set error(Object? error) => _$this._error = error;

  RecordingResultBuilder() {
    RecordingResult._initialize(this);
  }

  RecordingResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _success = $v.success;
      _outputPath = $v.outputPath;
      _duration = $v.duration;
      _bytesWritten = $v.bytesWritten;
      _error = $v.error;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RecordingResult other) {
    _$v = other as _$RecordingResult;
  }

  @override
  void update(void Function(RecordingResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RecordingResult build() => _build();

  _$RecordingResult _build() {
    final _$result =
        _$v ??
        _$RecordingResult._(
          success: BuiltValueNullFieldError.checkNotNull(
            success,
            r'RecordingResult',
            'success',
          ),
          outputPath: outputPath,
          duration: BuiltValueNullFieldError.checkNotNull(
            duration,
            r'RecordingResult',
            'duration',
          ),
          bytesWritten: BuiltValueNullFieldError.checkNotNull(
            bytesWritten,
            r'RecordingResult',
            'bytesWritten',
          ),
          error: error,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
