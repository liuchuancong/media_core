import 'package:media_core_danmaku/src/model/danmaku_message.dart';

/// Viewer-level suppression rules applied to incoming chat.
///
/// Where the other filters in this module remove *duplicates*, this one
/// removes *senders and words* the viewer asked never to see. It is a pure
/// policy object: it holds no timers, no memory of past messages and no
/// connection state, so the same instance can be shared by several rooms.
///
/// Normalization happens once, here, on construction: entries are trimmed,
/// lowercased and emptied out. Matching is therefore a plain lookup and a
/// plain substring scan, and it is case-insensitive for free. A caller
/// updating the lists constructs a new policy rather than mutating this one,
/// which keeps an in-flight message comparing against one consistent rule set.
///
/// A word the host reads as an expression rather than a string arrives as
/// [blockedPatterns], already compiled. The engine deliberately does not parse
/// the host's word format: which stored word is a pattern, and what makes one
/// safe to run, belongs to whoever shows the viewer that word and can refuse it
/// before it is stored. What it does guarantee is the cost of running one: a
/// pattern never sees more than [patternMatchLength] characters of a message.
final class DanmakuFilterPolicy {
  /// Normalizes [blockedUsers] and [blockedKeywords] once — trim, lowercase,
  /// drop empties — so matching is a plain lookup and substring scan.
  ///
  /// [blockedPatterns] are the same viewer's words that mean an expression;
  /// they are taken as given, because compiling them is the host's decision.
  DanmakuFilterPolicy({
    Iterable<String> blockedUsers = const [],
    Iterable<String> blockedKeywords = const [],
    Iterable<RegExp> blockedPatterns = const [],
  }) : blockedUsers = _normalizeUsers(blockedUsers),
       blockedKeywords = _normalizeKeywords(blockedKeywords),
       blockedPatterns = List.unmodifiable(blockedPatterns);

  /// Const constructor for [none]; the normalizing constructor handles the
  /// public shape.
  const DanmakuFilterPolicy.constant({
    this.blockedUsers = const <String>{},
    this.blockedKeywords = const <String>[],
    this.blockedPatterns = const <RegExp>[],
  });

  /// Empty policy: nothing is suppressed.
  static const DanmakuFilterPolicy none = DanmakuFilterPolicy.constant();

  /// How much of a message one pattern is run against.
  ///
  /// A pattern whose time grows with the text it fails to match is the one way
  /// a viewer's own word can stall the UI isolate, and the engine cannot stop a
  /// Dart regular expression once it has started. The bound is the same figure
  /// the host guards its words with, so a pattern that was refused for being
  /// slow on two hundred characters stays refused here.
  static const int patternMatchLength = 200;

  /// Lowercased display names that are always suppressed.
  ///
  /// Keyed on [DanmakuMessage.userName] because that is what viewers block —
  /// they see a name, not a user id. A viewer renaming themselves therefore
  /// escapes the block, which is the accepted trade-off: keying on ids would
  /// require every platform to expose one.
  final Set<String> blockedUsers;

  /// Lowercased substrings; a message containing any of them is suppressed.
  final List<String> blockedKeywords;

  /// The viewer's words that mean an expression, compiled by the host.
  ///
  /// Matched case-insensitively only if the host compiled them that way, which
  /// is what the word format asks for: a viewer writes `/广告/` and expects it
  /// to read the message as written, not as the platform encoded it.
  final List<RegExp> blockedPatterns;

  /// Whether this policy can suppress anything at all.
  bool get isEmpty => blockedUsers.isEmpty && blockedKeywords.isEmpty && blockedPatterns.isEmpty;

  /// Whether [message] passes the policy.
  bool allows(DanmakuMessage message) => evaluate(message).allowed;

  /// Classifies why [message] would be suppressed.
  ///
  /// Callers that only need the verdict use [allows]; this exists so a host
  /// can explain a suppression (diagnostics, "show blocked" affordances)
  /// without re-implementing the rules.
  DanmakuFilterDecision evaluate(DanmakuMessage message) {
    if (isEmpty) return const DanmakuFilterDecision.allowed();

    final user = message.userName.trim().toLowerCase();
    if (user.isNotEmpty && blockedUsers.contains(user)) {
      return const DanmakuFilterDecision.rejected(DanmakuFilterReason.blockedUser);
    }

    final text = message.text;
    if (text.isNotEmpty) {
      final lower = text.toLowerCase();
      for (final keyword in blockedKeywords) {
        if (lower.contains(keyword)) {
          return DanmakuFilterDecision.rejected(DanmakuFilterReason.blockedKeyword, keyword: keyword);
        }
      }
      if (blockedPatterns.isNotEmpty) {
        // The message is read as written: a pattern's own case rules were
        // decided when the host compiled it, and folding the text here would
        // quietly rewrite what the viewer wrote.
        // The bound is what the viewer's word costs to run: a message that
        // overstates its length cannot turn one lookup into a scan of a
        // megabyte.
        final part = text.length > patternMatchLength ? text.substring(0, patternMatchLength) : text;
        for (final pattern in blockedPatterns) {
          if (pattern.hasMatch(part)) {
            return DanmakuFilterDecision.rejected(DanmakuFilterReason.blockedKeyword, keyword: pattern.pattern);
          }
        }
      }
    }

    return const DanmakuFilterDecision.allowed();
  }

  static Set<String> _normalizeUsers(Iterable<String> users) =>
      users.map((user) => user.trim().toLowerCase()).where((user) => user.isNotEmpty).toSet();

  static List<String> _normalizeKeywords(Iterable<String> keywords) => keywords
      .map((keyword) => keyword.trim().toLowerCase())
      .where((keyword) => keyword.isNotEmpty)
      .toList(growable: false);
}

/// Why a message was suppressed by [DanmakuFilterPolicy].
enum DanmakuFilterReason {
  /// The sender's display name is on the viewer's block list.
  blockedUser,

  /// The message text contains one of the viewer's blocked keywords.
  blockedKeyword,
}

/// Verdict of [DanmakuFilterPolicy.evaluate].
final class DanmakuFilterDecision {
  /// The message passed the policy and should be shown.
  const DanmakuFilterDecision.allowed() : allowed = true, reason = null, keyword = null;

  /// The message was suppressed for [reason], naming the matched [keyword] when
  /// the reason is [DanmakuFilterReason.blockedKeyword].
  const DanmakuFilterDecision.rejected(DanmakuFilterReason this.reason, {this.keyword}) : allowed = false;

  /// Whether the message passed the policy.
  final bool allowed;

  /// `null` when [allowed] is true.
  final DanmakuFilterReason? reason;

  /// The keyword that matched, when [reason] is [DanmakuFilterReason.blockedKeyword].
  final String? keyword;

  @override
  String toString() => allowed
      ? 'DanmakuFilterDecision.allowed'
      : 'DanmakuFilterDecision.rejected(${reason!.name}${keyword == null ? '' : ': $keyword'})';
}
