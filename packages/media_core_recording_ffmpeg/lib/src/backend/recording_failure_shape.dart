/// What the ended process's own words say about why it ended, and what kind
/// of retry that deserves.
///
/// A recording's exit code says almost nothing: 255 is both a kill and a
/// crash, and a CDN rotation, an expired signed URL and a dead network all
/// end as "non-zero". The process's log tail is where the difference shows —
/// an HTTP status FFmpeg was answered with, an input that ran out mid
/// stream, a connection the network refused — and each of those has a
/// different retry shape: an address that was refused needs a fresh one and
/// the room is likely still live (retry fast, and longer, than the plain
/// backoff), while a network that is down refunds the retry budget because
/// no number of fresh attempts fixes it.
enum RecordingFailureShape {
  /// The host answered 401/403/404 — the address works as an address but the
  /// grant is gone: a fresh signed URL is the likely fix.
  addressRefused,

  /// The input ended mid stream without an answer — the CDN cut the
  /// response or the URL expired under it: a fresh URL is the likely fix.
  unexpectedEof,

  /// The request never reached the platform: the network is the problem,
  /// and retrying quickly or often does not help.
  networkUnreachable,

  /// Anything else: the plain backoff and the plain budget.
  other;

  /// Reads the shape from [exitCode] and the process's last [logTail] lines
  /// (most recent last). Only the tail is read: the first lines of a
  /// two-hour capture describe a start that succeeded.
  static RecordingFailureShape classify({required int? exitCode, required Iterable<String> logTail}) {
    var refused = false;
    var eof = false;
    var network = false;
    for (final rawLine in logTail) {
      final line = rawLine.toLowerCase();
      if (line.contains('server returned 401') ||
          line.contains('server returned 403') ||
          line.contains('server returned 404')) {
        refused = true;
      } else if (line.contains('unexpected end of file') || line.contains('connection reset by peer')) {
        eof = true;
      } else if (line.contains('connection refused') ||
          line.contains('could not resolve host') ||
          line.contains('network is unreachable') ||
          line.contains('connection timed out') ||
          line.contains('operation timed out')) {
        network = true;
      }
    }
    if (refused) return RecordingFailureShape.addressRefused;
    if (eof) return RecordingFailureShape.unexpectedEof;
    if (network) return RecordingFailureShape.networkUnreachable;
    // A shape comes from evidence, not from the exit code: a kill (255) with
    // nothing on record is the user's stop or a crash as likely as a CDN
    // rotation, and the plain lane is the honest default.
    return RecordingFailureShape.other;
  }

  /// Whether a fresh signed URL is the likely fix for this shape: those
  /// retries run on the fast lane and get a longer budget.
  bool get refreshesSignedStream => this == RecordingFailureShape.addressRefused || this == RecordingFailureShape.unexpectedEof;
}
