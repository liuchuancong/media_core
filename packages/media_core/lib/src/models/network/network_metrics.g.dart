// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_metrics.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NetworkMetrics extends NetworkMetrics {
  @override
  final int? averageLatency;
  @override
  final int? minimumLatency;
  @override
  final int? maximumLatency;
  @override
  final int? downloadSpeed;
  @override
  final int? uploadSpeed;
  @override
  final int totalRequests;
  @override
  final int successfulRequests;
  @override
  final int failedRequests;
  @override
  final int receivedBytes;
  @override
  final int sentBytes;
  @override
  final DateTime? timestamp;

  factory _$NetworkMetrics([void Function(NetworkMetricsBuilder)? updates]) =>
      (NetworkMetricsBuilder()..update(updates))._build();

  _$NetworkMetrics._({
    this.averageLatency,
    this.minimumLatency,
    this.maximumLatency,
    this.downloadSpeed,
    this.uploadSpeed,
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.receivedBytes,
    required this.sentBytes,
    this.timestamp,
  }) : super._();
  @override
  NetworkMetrics rebuild(void Function(NetworkMetricsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NetworkMetricsBuilder toBuilder() => NetworkMetricsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NetworkMetrics &&
        averageLatency == other.averageLatency &&
        minimumLatency == other.minimumLatency &&
        maximumLatency == other.maximumLatency &&
        downloadSpeed == other.downloadSpeed &&
        uploadSpeed == other.uploadSpeed &&
        totalRequests == other.totalRequests &&
        successfulRequests == other.successfulRequests &&
        failedRequests == other.failedRequests &&
        receivedBytes == other.receivedBytes &&
        sentBytes == other.sentBytes &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, averageLatency.hashCode);
    _$hash = $jc(_$hash, minimumLatency.hashCode);
    _$hash = $jc(_$hash, maximumLatency.hashCode);
    _$hash = $jc(_$hash, downloadSpeed.hashCode);
    _$hash = $jc(_$hash, uploadSpeed.hashCode);
    _$hash = $jc(_$hash, totalRequests.hashCode);
    _$hash = $jc(_$hash, successfulRequests.hashCode);
    _$hash = $jc(_$hash, failedRequests.hashCode);
    _$hash = $jc(_$hash, receivedBytes.hashCode);
    _$hash = $jc(_$hash, sentBytes.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NetworkMetrics')
          ..add('averageLatency', averageLatency)
          ..add('minimumLatency', minimumLatency)
          ..add('maximumLatency', maximumLatency)
          ..add('downloadSpeed', downloadSpeed)
          ..add('uploadSpeed', uploadSpeed)
          ..add('totalRequests', totalRequests)
          ..add('successfulRequests', successfulRequests)
          ..add('failedRequests', failedRequests)
          ..add('receivedBytes', receivedBytes)
          ..add('sentBytes', sentBytes)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class NetworkMetricsBuilder
    implements Builder<NetworkMetrics, NetworkMetricsBuilder> {
  _$NetworkMetrics? _$v;

  int? _averageLatency;
  int? get averageLatency => _$this._averageLatency;
  set averageLatency(int? averageLatency) =>
      _$this._averageLatency = averageLatency;

  int? _minimumLatency;
  int? get minimumLatency => _$this._minimumLatency;
  set minimumLatency(int? minimumLatency) =>
      _$this._minimumLatency = minimumLatency;

  int? _maximumLatency;
  int? get maximumLatency => _$this._maximumLatency;
  set maximumLatency(int? maximumLatency) =>
      _$this._maximumLatency = maximumLatency;

  int? _downloadSpeed;
  int? get downloadSpeed => _$this._downloadSpeed;
  set downloadSpeed(int? downloadSpeed) =>
      _$this._downloadSpeed = downloadSpeed;

  int? _uploadSpeed;
  int? get uploadSpeed => _$this._uploadSpeed;
  set uploadSpeed(int? uploadSpeed) => _$this._uploadSpeed = uploadSpeed;

  int? _totalRequests;
  int? get totalRequests => _$this._totalRequests;
  set totalRequests(int? totalRequests) =>
      _$this._totalRequests = totalRequests;

  int? _successfulRequests;
  int? get successfulRequests => _$this._successfulRequests;
  set successfulRequests(int? successfulRequests) =>
      _$this._successfulRequests = successfulRequests;

  int? _failedRequests;
  int? get failedRequests => _$this._failedRequests;
  set failedRequests(int? failedRequests) =>
      _$this._failedRequests = failedRequests;

  int? _receivedBytes;
  int? get receivedBytes => _$this._receivedBytes;
  set receivedBytes(int? receivedBytes) =>
      _$this._receivedBytes = receivedBytes;

  int? _sentBytes;
  int? get sentBytes => _$this._sentBytes;
  set sentBytes(int? sentBytes) => _$this._sentBytes = sentBytes;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  NetworkMetricsBuilder() {
    NetworkMetrics._initialize(this);
  }

  NetworkMetricsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _averageLatency = $v.averageLatency;
      _minimumLatency = $v.minimumLatency;
      _maximumLatency = $v.maximumLatency;
      _downloadSpeed = $v.downloadSpeed;
      _uploadSpeed = $v.uploadSpeed;
      _totalRequests = $v.totalRequests;
      _successfulRequests = $v.successfulRequests;
      _failedRequests = $v.failedRequests;
      _receivedBytes = $v.receivedBytes;
      _sentBytes = $v.sentBytes;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NetworkMetrics other) {
    _$v = other as _$NetworkMetrics;
  }

  @override
  void update(void Function(NetworkMetricsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NetworkMetrics build() => _build();

  _$NetworkMetrics _build() {
    final _$result =
        _$v ??
        _$NetworkMetrics._(
          averageLatency: averageLatency,
          minimumLatency: minimumLatency,
          maximumLatency: maximumLatency,
          downloadSpeed: downloadSpeed,
          uploadSpeed: uploadSpeed,
          totalRequests: BuiltValueNullFieldError.checkNotNull(
            totalRequests,
            r'NetworkMetrics',
            'totalRequests',
          ),
          successfulRequests: BuiltValueNullFieldError.checkNotNull(
            successfulRequests,
            r'NetworkMetrics',
            'successfulRequests',
          ),
          failedRequests: BuiltValueNullFieldError.checkNotNull(
            failedRequests,
            r'NetworkMetrics',
            'failedRequests',
          ),
          receivedBytes: BuiltValueNullFieldError.checkNotNull(
            receivedBytes,
            r'NetworkMetrics',
            'receivedBytes',
          ),
          sentBytes: BuiltValueNullFieldError.checkNotNull(
            sentBytes,
            r'NetworkMetrics',
            'sentBytes',
          ),
          timestamp: timestamp,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
