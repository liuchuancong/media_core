/// UPnP `H:MM:SS[.fff]` clock strings, as used by Seek targets and
/// position responses.
abstract final class DurationCodec {
  /// Formats [value] as `HH:MM:SS`. Hours run past two digits when the
  /// media is longer than a day; minutes and seconds are zero-padded.
  static String format(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes % 60;
    final seconds = value.inSeconds % 60;
    return '${_pad(hours)}:${_pad(minutes)}:${_pad(seconds)}';
  }

  /// Parses a clock string, returning null when it is not one.
  ///
  /// Devices return `NOT_IMPLEMENTED`, empty strings and other junk in
  /// position fields; a caller that assumed a parse would then treat
  /// its own crash as the device's fault. The fraction, when present,
  /// survives to the millisecond.
  static Duration? tryParse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length != 3) {
      return null;
    }
    final hours = int.tryParse(parts[0].trim());
    final minutes = int.tryParse(parts[1].trim());
    final seconds = double.tryParse(parts[2].trim());
    if (hours == null || minutes == null || seconds == null) {
      return null;
    }
    final wholeSeconds = seconds.floor();
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: wholeSeconds,
      milliseconds: ((seconds - wholeSeconds) * 1000).round(),
    );
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
