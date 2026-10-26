import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/quality/quality_candidate.dart';
import 'package:media_core/src/models/quality/quality_switch_result.dart';

part 'quality_switch_outcome.g.dart';

/// One quality switch's outcome, including where the playhead landed.
///
/// [QualitySwitchOutcome] is what a host logs and what a quality menu
/// marks as current, so it carries both the verdict
/// ([QualitySwitchResult]) and the two candidates the switch moved
/// between: a report that says only "failed" cannot answer whether
/// the viewer is back on the picture they were watching.
abstract class QualitySwitchOutcome implements Built<QualitySwitchOutcome, QualitySwitchOutcomeBuilder> {
  /// Builds an outcome from a [updates] callback — the codegen entry.
  factory QualitySwitchOutcome([void Function(QualitySwitchOutcomeBuilder)? updates]) = _$QualitySwitchOutcome;

  /// Creates an outcome.
  factory QualitySwitchOutcome.of({
    required QualitySwitchResult result,
    required QualityCandidate? from,
    required QualityCandidate to,
    Duration? resumedAt,
    Object? error,
    bool restored = false,
  }) {
    return QualitySwitchOutcome(
      (builder) => builder
        ..result = result
        ..from = from?.toBuilder()
        ..to = to.toBuilder()
        ..resumedAt = resumedAt
        ..error = error
        ..restored = restored,
    );
  }

  QualitySwitchOutcome._();

  /// Nothing was rolled back unless the switch says so.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(QualitySwitchOutcomeBuilder builder) => builder..restored = false;

  /// What happened.
  QualitySwitchResult get result;

  /// The candidate that was current when the switch began, null if
  /// none was.
  QualityCandidate? get from;

  /// The candidate that was requested.
  QualityCandidate get to;

  /// Media time the playhead landed at, when a resume happened.
  Duration? get resumedAt;

  /// The failure, when [QualitySwitchResult.failed] is the result.
  Object? get error;

  /// Whether the previous source was re-opened after a failure.
  bool get restored;

  /// Whether playback is now on [to].
  bool get applied => result == QualitySwitchResult.applied;
}
