import 'package:equatable/equatable.dart';

/// One engine configuration item, spelled in the engine's own vocabulary.
///
/// The framework transports these verbatim and never invents values:
/// `key` is an mpv property name on media_kit (`hwdec`, `cache-secs`),
/// an mdk property name on fvp (`avio.http_proxy`), an ijkplayer option
/// name on ijk (`mediacodec`, `reconnect`) — whatever the engine itself
/// would accept.
///
/// [domain] separates option namespaces on engines that have them: ijk
/// partitions options into `player`, `format`, `codec`, `host`, `sws` and
/// `swr` categories. Engines without namespaces ignore it.
///
/// Values are kept as [Object] and normalized by the adapter that owns
/// the engine (`bool` becomes `yes`/`no` for mpv, `1`/`0` for ijk).
final class EngineOption extends Equatable {
  /// Creates one engine option.
  const EngineOption(this.key, this.value, {this.domain});

  /// The option name, exactly as the engine spells it.
  final String key;

  /// The option value; normalized by the adapter.
  final Object? value;

  /// Option namespace, for engines that partition their options.
  final String? domain;

  /// Identity is (domain, key): a later option with the same pair replaces
  /// an earlier one, which is what "last value wins" persistence needs.
  @override
  List<Object?> get props => <Object?>[domain, key];

  @override
  String toString() => '${domain == null ? '' : '$domain.'}$key=$value';
}

/// What an adapter did with one [EngineOption].
enum EngineOptionOutcome {
  /// Written to the live engine; effective on the current playback now.
  appliedLive,

  /// Accepted by the engine instance but only consumed at the next open
  /// (ijkplayer consumes most options at `prepareAsync`).
  stagedForNextOpen,

  /// The current engine instance cannot take this option at all; only a
  /// fresh instance built with it can.
  needsRebuild,

  /// This backend has no surface for the option.
  unsupported,
}

/// How hard an engine-option apply may work to make an option effective.
enum EngineOptionEffect {
  /// Rebuild the engine (same backend) when an option cannot apply live.
  immediate,

  /// Never rebuild: options that cannot apply live wait for the next open
  /// or engine creation.
  nextOpen,
}

/// The aggregate outcome of one engine-option apply call.
final class EngineOptionReport {
  /// Creates a report.
  const EngineOptionReport({
    this.appliedLive = const <EngineOption>[],
    this.stagedForNextOpen = const <EngineOption>[],
    this.rebuiltFor = const <EngineOption>[],
    this.unsupported = const <EngineOption>[],
  });

  /// Options written to the live engine, effective now.
  final List<EngineOption> appliedLive;

  /// Options the engine instance accepted for its next open.
  final List<EngineOption> stagedForNextOpen;

  /// Options that required an engine rebuild; the rebuild already happened.
  final List<EngineOption> rebuiltFor;

  /// Options this backend has no surface for.
  final List<EngineOption> unsupported;

  @override
  String toString() {
    return 'EngineOptionReport(live: ${appliedLive.length}, '
        'staged: ${stagedForNextOpen.length}, rebuilt: ${rebuiltFor.length}, '
        'unsupported: ${unsupported.length})';
  }
}
