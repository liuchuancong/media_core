import 'package:built_value/built_value.dart';

part 'platform_audio.g.dart';

/// Describes platform audio capabilities.
///
/// [PlatformAudio] represents available audio
/// features on current runtime platform.
///
/// Responsibilities:
///
/// - audio output capability
/// - audio format support
/// - audio focus capability
///
/// It does not:
///
/// - play audio
/// - manage volume
/// - request system focus
///
/// Those belong to:
///
/// - AudioBackend
/// - PlayerIdentity
abstract class PlatformAudio implements Built<PlatformAudio, PlatformAudioBuilder> {
  /// Builds PlatformAudio from a [updates] callback — the codegen entry.
  factory PlatformAudio([void Function(PlatformAudioBuilder)? updates]) = _$PlatformAudio;

  /// Creates PlatformAudio from the fields it describes.
  factory PlatformAudio.of({
    bool enabled = true,
    bool output = true,
    bool volumeControl = true,
    bool muteControl = true,
    bool audioFocus = false,
    bool bluetooth = false,
    bool speaker = true,
    bool headphones = true,
    int maxChannels = 2,
    List<int> sampleRates = const <int>[44100, 48000],
  }) {
    return PlatformAudio(
      (builder) => builder
        ..enabled = enabled
        ..output = output
        ..volumeControl = volumeControl
        ..muteControl = muteControl
        ..audioFocus = audioFocus
        ..bluetooth = bluetooth
        ..speaker = speaker
        ..headphones = headphones
        ..maxChannels = maxChannels
        ..sampleRates = sampleRates,
    );
  }

  PlatformAudio._();

  /// Anything the platform does not report keeps the documented default
  /// rather than turning into null.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlatformAudioBuilder builder) => builder
    ..enabled = true
    ..output = true
    ..volumeControl = true
    ..muteControl = true
    ..audioFocus = false
    ..bluetooth = false
    ..speaker = true
    ..headphones = true
    ..maxChannels = 2
    ..sampleRates = const <int>[44100, 48000];

  /// Whether audio playback is enabled.
  bool get enabled;

  /// Whether audio output is supported.
  bool get output;

  /// Whether system volume control is supported.
  bool get volumeControl;

  /// Whether mute control is supported.
  bool get muteControl;

  /// Whether audio focus is supported.
  ///
  /// Example:
  ///
  /// - Android AudioFocus
  /// - iOS AVAudioSession
  bool get audioFocus;

  /// Whether bluetooth audio is supported.
  bool get bluetooth;

  /// Whether speaker output is supported.
  bool get speaker;

  /// Whether headphone output is supported.
  bool get headphones;

  /// Maximum supported audio channels.
  ///
  /// Example:
  ///
  /// - 2 stereo
  /// - 6 surround
  int get maxChannels;

  /// Supported sample rates.
  ///
  /// Example:
  ///
  /// - 44100
  /// - 48000
  List<int> get sampleRates;

  /// Whether audio playback is possible.
  bool get canPlay {
    return enabled && output;
  }

  /// Whether stereo output is supported.
  bool get supportsStereo {
    return maxChannels >= 2;
  }

  /// Whether high quality audio is supported.
  bool get supportsHighQuality {
    return sampleRates.contains(48000);
  }
}
