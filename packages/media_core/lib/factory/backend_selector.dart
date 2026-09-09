import 'backend_registry.dart';
import 'backend_descriptor.dart';
import 'backend_selection_result.dart';
import '../source/source_location.dart';
import 'backend_selection_request.dart';

/// Selects the best backend for playback.
///
/// [BackendSelector] evaluates registered backends
/// and chooses the most suitable implementation.
///
/// Responsibilities:
///
/// - capability matching
/// - backend scoring
/// - preference handling
///
/// It does not:
///
/// - create backend instances
/// - execute playback
///
/// Those belong to:
///
/// - BackendFactory
/// - BackendInstance
final class BackendSelector {
  /// Creates a backend selector.
  const BackendSelector(this.registry);

  /// Backend registry.
  final BackendRegistry registry;

  /// Selects backend.
  BackendSelectionResult select(BackendSelectionRequest request) {
    final candidates = registry.enabled;

    if (candidates.isEmpty) {
      return BackendSelectionResult.failure(reason: 'No enabled backend available.');
    }

    final rejected = <BackendSelectionReject>[];

    BackendDescriptor? selected;

    var bestScore = -1;

    for (final backend in candidates) {
      final score = _score(backend, request);

      if (score < 0) {
        rejected.add(BackendSelectionReject(backend: backend, reason: _rejectReason(backend, request)));

        continue;
      }

      if (score > bestScore) {
        bestScore = score;

        selected = backend;
      }
    }

    if (selected == null) {
      return BackendSelectionResult.failure(reason: 'No backend satisfies requirements.', rejected: rejected);
    }

    return BackendSelectionResult.success(backend: selected, score: bestScore);
  }

  int _score(BackendDescriptor backend, BackendSelectionRequest request) {
    final capabilities = backend.capabilities;

    var score = backend.priority;

    if (!backend.enabled) {
      return -1;
    }

    if (request.platform != null && !backend.supportsPlatform(request.platform!)) {
      return -1;
    }

    if (request.requireLive && !capabilities.live) {
      return -1;
    }

    if (request.requireSeek && !capabilities.seek) {
      return -1;
    }

    if (request.requireHardwareDecode && !capabilities.hardwareDecode) {
      return -1;
    }

    if (request.preferredBackend == backend.id) {
      score += 1000;
    }

    if (request.preferHardwareDecode && capabilities.hardwareDecode) {
      score += 100;
    }

    if (request.preferLowLatency && capabilities.live) {
      score += 50;
    }

    if (request.source.location.isNetwork && capabilities.networkStream) {
      score += 30;
    }

    if (request.source.location.isLocal && capabilities.localFile) {
      score += 30;
    }

    if (capabilities.canDecode) {
      score += 10;
    }

    return score;
  }

  String _rejectReason(BackendDescriptor backend, BackendSelectionRequest request) {
    if (!backend.enabled) {
      return 'Backend disabled';
    }

    if (request.platform != null && !backend.supportsPlatform(request.platform!)) {
      return 'Unsupported platform';
    }

    if (request.requireLive && !backend.capabilities.live) {
      return 'Live playback unsupported';
    }

    if (request.requireSeek && !backend.capabilities.seek) {
      return 'Seek unsupported';
    }

    if (request.requireHardwareDecode && !backend.capabilities.hardwareDecode) {
      return 'Hardware decode unsupported';
    }

    return 'Capability mismatch';
  }
}
