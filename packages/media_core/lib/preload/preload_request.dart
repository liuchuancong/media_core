import 'preload_priority.dart';
import '../identity/source_id.dart';

/// Request for preload operation.
final class PreloadRequest {
  const PreloadRequest({required this.sourceId, this.priority = PreloadPriority.normal});

  final SourceId sourceId;

  final PreloadPriority priority;
}
