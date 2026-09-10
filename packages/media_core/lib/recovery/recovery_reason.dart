import 'package:equatable/equatable.dart';

/// Describes why a recovery operation was requested.
///
/// A recovery reason is diagnostic and policy input data.
/// It does not decide which recovery action should be executed.
sealed class RecoveryReason extends Equatable {
  const RecoveryReason();

  const factory RecoveryReason.unknown() = RecoveryReasonUnknown;

  const factory RecoveryReason.network() = RecoveryReasonNetwork;

  const factory RecoveryReason.timeout() = RecoveryReasonTimeout;

  const factory RecoveryReason.decoder() = RecoveryReasonDecoder;

  const factory RecoveryReason.renderer() = RecoveryReasonRenderer;

  const factory RecoveryReason.source() = RecoveryReasonSource;

  const factory RecoveryReason.initialization() = RecoveryReasonInitialization;

  const factory RecoveryReason.interrupted() = RecoveryReasonInterrupted;

  const factory RecoveryReason.resource() = RecoveryReasonResource;

  bool get isUnknown => this is RecoveryReasonUnknown;

  bool get isNetwork => this is RecoveryReasonNetwork;

  bool get isTimeout => this is RecoveryReasonTimeout;

  bool get isDecoder => this is RecoveryReasonDecoder;

  bool get isRenderer => this is RecoveryReasonRenderer;

  bool get isSource => this is RecoveryReasonSource;

  bool get isInitialization => this is RecoveryReasonInitialization;

  bool get isInterrupted => this is RecoveryReasonInterrupted;

  bool get isResource => this is RecoveryReasonResource;

  @override
  List<Object?> get props => [];
}

/// Recovery reason could not be determined.
final class RecoveryReasonUnknown extends RecoveryReason {
  const RecoveryReasonUnknown();

  @override
  String toString() => 'RecoveryReasonUnknown';
}

/// Recovery was triggered by a network failure.
final class RecoveryReasonNetwork extends RecoveryReason {
  const RecoveryReasonNetwork();

  @override
  String toString() => 'RecoveryReasonNetwork';
}

/// Recovery was triggered by an operation timeout.
final class RecoveryReasonTimeout extends RecoveryReason {
  const RecoveryReasonTimeout();

  @override
  String toString() => 'RecoveryReasonTimeout';
}

/// Recovery was triggered by a decoder failure.
final class RecoveryReasonDecoder extends RecoveryReason {
  const RecoveryReasonDecoder();

  @override
  String toString() => 'RecoveryReasonDecoder';
}

/// Recovery was triggered by a renderer failure.
final class RecoveryReasonRenderer extends RecoveryReason {
  const RecoveryReasonRenderer();

  @override
  String toString() => 'RecoveryReasonRenderer';
}

/// Recovery was triggered by a source failure.
final class RecoveryReasonSource extends RecoveryReason {
  const RecoveryReasonSource();

  @override
  String toString() => 'RecoveryReasonSource';
}

/// Recovery was triggered by initialization failure.
final class RecoveryReasonInitialization extends RecoveryReason {
  const RecoveryReasonInitialization();

  @override
  String toString() => 'RecoveryReasonInitialization';
}

/// Recovery was triggered because the operation was interrupted.
final class RecoveryReasonInterrupted extends RecoveryReason {
  const RecoveryReasonInterrupted();

  @override
  String toString() => 'RecoveryReasonInterrupted';
}

/// Recovery was triggered by a resource failure.
final class RecoveryReasonResource extends RecoveryReason {
  const RecoveryReasonResource();

  @override
  String toString() => 'RecoveryReasonResource';
}
