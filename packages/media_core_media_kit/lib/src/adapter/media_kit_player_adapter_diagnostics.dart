part of 'media_kit_player_adapter.dart';

enum _MpvDiagnosticComponent { video, audio, either }

final class _MpvDiagnostic {
  const _MpvDiagnostic({required this.code, required this.terminal, this.component = _MpvDiagnosticComponent.either});

  final PlayerErrorCode code;
  final bool terminal;
  final _MpvDiagnosticComponent component;
}

final class _MpvDiagnosticRules {
  const _MpvDiagnosticRules._();

  static const Set<String> prefixes = {'file', 'vd', 'ad', 'ffmpeg/video', 'ffmpeg/audio', 'cplayer', 'stream'};

  static const List<String> notices = ['both surface and native_window are null'];

  static const List<String> lifecycle = [
    'player has been disposed',
    'player has been released',
    'operation was cancelled',
    'operation was canceled',
  ];

  static const List<String> videoOutput = [
    'surface has been released',
    'failed to create surface',
    'failed to create texture',
    'texture is unavailable',
    'egl_bad',
    'vulkan error',
    'gpu context failed',
  ];

  static const List<String> decoderInit = ['no decoder found', 'unsupported codec', 'codec is not supported'];

  static const List<String> transport = [
    'connection timed out',
    'network timeout',
    'network is down',
    'network is unreachable',
    'host is unreachable',
    'connection refused',
    'connection reset',
    'connection aborted',
    'software caused connection abort',
    'broken pipe',
    'no route to host',
    'failed to resolve',
    'could not resolve host',
    'unable to resolve host',
    'no address associated with hostname',
    'getaddrinfo failed',
    'nodename nor servname',
    'no such host is known',
    'temporary failure in name resolution',
    'name or service not known',
    'tls handshake',
    'ssl handshake',
    'certificate verify failed',
    'input/output error',
    'i/o error',
  ];

  static const List<String> sourceOpen = [
    'server returned 401',
    'server returned 403',
    'server returned 404',
    'http error 401',
    'http error 403',
    'http error 404',
    'protocol not found',
    'unknown protocol',
    'no protocol handler',
    'failed to open input',
    'error opening input',
    'unable to open input',
    'invalid data found when processing input',
    'could not find codec parameters',
    'no streams found',
  ];

  static const List<String> decoderRuntime = [
    'mediacodec',
    'decoder',
    'decode',
    'codec',
    'invalid nal',
    'non-existing pps',
    'missing reference picture',
    'corrupt decoded frame',
    'error while decoding',
  ];

  static const List<String> sourceRuntime = [
    'demuxer',
    'failed to open',
    'error opening',
    'unable to open',
    'end of file',
    'unexpected eof',
  ];

  static final RegExp url = RegExp(r'[a-z][a-z0-9+.-]*://\S*');

  static final RegExp httpServerFailure = RegExp(r'(?:server returned|http error)\s+5\d\d(?:\D|$)');

  static bool isActionable(String prefix, String text) {
    final normalized = prefix.trim().toLowerCase();
    final line = text.trimLeft().toLowerCase();
    if (notices.any(line.contains)) return false;
    if (normalized == 'ffmpeg') return line.startsWith('tcp:');
    return prefixes.contains(normalized);
  }

  static _MpvDiagnostic classify(String message, {String? prefix}) {
    final value = message.trim().toLowerCase().replaceAll(url, ' ');
    final component = componentOf(prefix);
    if (_any(value, lifecycle)) {
      return const _MpvDiagnostic(code: PlayerErrorCode.adapterDisposed, terminal: true);
    }
    if (_any(value, videoOutput)) {
      return _MpvDiagnostic(code: PlayerErrorCode.rendererSurfaceFailed, terminal: true, component: component);
    }
    if (_any(value, decoderInit)) {
      return _MpvDiagnostic(code: PlayerErrorCode.codecUnsupported, terminal: true, component: component);
    }
    if (_any(value, transport) || httpServerFailure.hasMatch(value)) {
      return const _MpvDiagnostic(code: PlayerErrorCode.networkConnectionFailed, terminal: true);
    }
    if (_any(value, sourceOpen)) {
      return const _MpvDiagnostic(code: PlayerErrorCode.sourceInvalid, terminal: true);
    }
    if (_any(value, decoderRuntime)) {
      return _MpvDiagnostic(code: PlayerErrorCode.decoderError, terminal: false, component: component);
    }
    if (_any(value, sourceRuntime)) {
      return const _MpvDiagnostic(code: PlayerErrorCode.demuxerError, terminal: false);
    }
    return const _MpvDiagnostic(code: PlayerErrorCode.playbackFailed, terminal: false);
  }

  static _MpvDiagnosticComponent componentOf(String? prefix) => switch (prefix?.trim().toLowerCase()) {
    'ad' || 'ffmpeg/audio' => _MpvDiagnosticComponent.audio,
    'vd' || 'ffmpeg/video' => _MpvDiagnosticComponent.video,
    _ => _MpvDiagnosticComponent.either,
  };

  static bool _any(String value, List<String> markers) => markers.any(value.contains);
}

final class _MpvDiagnosticGate {
  _MpvDiagnosticGate({required void Function(String message, PlayerErrorCode code) onError}) : _onError = onError;

  final void Function(String message, PlayerErrorCode code) _onError;

  static const Duration _window = Duration(milliseconds: 1200);

  static const Duration _dedupe = Duration(seconds: 2);

  bool _closed = false;
  bool _opening = false;
  bool _videoReady = false;
  bool _audioReady = false;
  bool _playing = false;
  bool _buffering = true;
  int _progress = 0;
  ({String text, String prefix})? _held;
  ({String text, String prefix})? _deferred;
  Timer? _timer;
  String? _pendingText;
  _MpvDiagnostic? _pendingDiagnostic;
  _MpvDiagnosticComponent _pendingComponent = _MpvDiagnosticComponent.either;
  int _pendingProgress = 0;
  String? _lastText;
  DateTime? _lastAt;

  void beginOpen() {
    _opening = true;
    _resetSource();
  }

  void discardSource() {
    _opening = false;
    _resetSource();
  }

  void close() {
    _closed = true;
    _deferred = null;
    _cancelPending();
  }

  void finishOpen() {
    _opening = false;
    final held = _held;
    _held = null;
    if (held == null) return;
    final component = _MpvDiagnosticRules.componentOf(held.prefix);
    if (_ready(component)) return;
    if (component != _MpvDiagnosticComponent.either && !_underWay) {
      _deferred = held;
      return;
    }
    _process(held.text, held.prefix);
  }

  void log(String prefix, String level, String text) {
    if (_closed || level != 'error' || !_MpvDiagnosticRules.isActionable(prefix, text)) return;
    if (_opening) {
      _held = (text: text, prefix: prefix);
      return;
    }
    _process(text, prefix);
  }

  void videoOutput() {
    _videoReady = true;
    _progress++;
    _cancelRecovered(_MpvDiagnosticComponent.video);
    _start();
  }

  void audioOutput() {
    _audioReady = true;
    _progress++;
    _cancelRecovered(_MpvDiagnosticComponent.audio);
    _start();
  }

  void playback({required bool playing, required bool buffering, required bool audioOnly}) {
    _playing = playing;
    _buffering = buffering;
    if (playing && !buffering) {
      _progress++;
      _cancelRecovered(audioOnly ? _MpvDiagnosticComponent.audio : _MpvDiagnosticComponent.video);
    }
    if (playing) _start();
  }

  void positionAdvanced({required bool audioOnly}) {
    if (!_playing || _buffering) return;
    _progress++;
    _cancelRecovered(audioOnly ? _MpvDiagnosticComponent.audio : _MpvDiagnosticComponent.video);
  }

  bool get _underWay => _playing || _videoReady || _audioReady;

  void _resetSource() {
    _cancelPending();
    _videoReady = false;
    _audioReady = false;
    _playing = false;
    _buffering = true;
    _progress = 0;
    _held = null;
    _deferred = null;
    _lastText = null;
    _lastAt = null;
  }

  void _start() {
    final deferred = _deferred;
    if (deferred == null) return;
    _deferred = null;
    if (!_ready(_MpvDiagnosticRules.componentOf(deferred.prefix))) {
      _process(deferred.text, deferred.prefix);
    }
  }

  void _process(String text, String prefix) {
    final diagnostic = _MpvDiagnosticRules.classify(text, prefix: prefix);
    if (diagnostic.terminal) {
      _report(text, diagnostic.code);
      return;
    }
    if (_timer != null) return;
    _pendingText = text;
    _pendingDiagnostic = diagnostic;
    _pendingComponent = diagnostic.component;
    _pendingProgress = _progress;
    _timer = Timer(_window, () {
      _timer = null;
      final pending = _pendingDiagnostic;
      final pendingText = _pendingText;
      _pendingDiagnostic = null;
      _pendingText = null;
      if (pending == null || pendingText == null || _closed) return;
      final recovered = _progress > _pendingProgress && _playing && (_ready(_pendingComponent) || !_buffering);
      if (recovered || (_playing && !_buffering)) return;
      _report(pendingText, pending.code);
    });
  }

  void _report(String text, PlayerErrorCode code) {
    if (_closed) return;
    final now = DateTime.now();
    final last = _lastAt;
    if (_lastText == text && last != null && now.difference(last) < _dedupe) return;
    _lastText = text;
    _lastAt = now;
    MediaCoreLog.warning(LogCategory.error, text);
    _onError(text, code);
  }

  bool _ready(_MpvDiagnosticComponent component) => switch (component) {
    _MpvDiagnosticComponent.video => _videoReady,
    _MpvDiagnosticComponent.audio => _audioReady,
    _MpvDiagnosticComponent.either => _videoReady || _audioReady,
  };

  void _cancelRecovered(_MpvDiagnosticComponent progressed) {
    if (_timer == null) return;
    if (_pendingComponent != _MpvDiagnosticComponent.either && _pendingComponent != progressed) return;
    _cancelPending();
  }

  void _cancelPending() {
    _timer?.cancel();
    _timer = null;
    _pendingText = null;
    _pendingDiagnostic = null;
    _pendingComponent = _MpvDiagnosticComponent.either;
  }
}
