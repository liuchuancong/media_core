import AppKit
import CoreVideo
import Darwin
import FlutterMacOS
import Foundation
import VideoToolbox

/// macOS side of the capability probe.
///
/// Wire protocol (see `PlatformProbeReport` on the Dart side, which is the
/// source of truth): one method, `probe`, answered with a map of up to four
/// sections — info, capabilities, device, codecs.
///
/// The facts come from:
///
/// - `VTIsHardwareDecodeSupported` — the only honest answer to "can this Mac
///   decode HEVC in hardware"; it asks VideoToolbox, which is what mpv, AVPlayer
///   and every other engine end up using;
/// - `sysctlbyname` — physical memory and CPU count;
/// - `NSProcessInfo` and `ProcessInfo.operatingSystemVersion` — the OS version;
/// - `NSScreen` — how many displays are attached.
///
/// Every section is best-effort: a fact that cannot be read is left out, which
/// the Dart side reads as "unknown" rather than as "unsupported".
public class MediaCoreNativePlugin: NSObject, FlutterPlugin {
  /// Channel name; kept in sync with the Dart side.
  private static let channelName = "media_core_native"

  /// Method the probe is requested through.
  private static let probeMethod = "probe"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger)

    let instance = MediaCoreNativePlugin()

    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == Self.probeMethod else {
      result(FlutterMethodNotImplemented)

      return
    }

    result(probe())
  }

  // ---------------------------------------------------------------------------
  // The report
  // ---------------------------------------------------------------------------

  private func probe() -> [String: Any] {
    return [
      "info": info(),
      "capabilities": capabilities(),
      "device": device(),
      "codecs": codecs(),
    ]
  }

  private func info() -> [String: Any] {
    let version = ProcessInfo.processInfo.operatingSystemVersion

    return [
      "type": "macos",
      "name": "macOS",
      "version": "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
      "buildNumber": sysctlString("kern.osversion"),
      "architecture": architecture(),
      "deviceModel": sysctlString("hw.model"),
      "isEmulator": false,
    ]
  }

  private func capabilities() -> [String: Any] {
    let screens = NSScreen.screens

    return [
      "hardwareDecode": anyHardwareDecoder(),
      "softwareDecode": true,
      "videoRendering": true,
      "audioPlayback": true,
      "subtitleRendering": true,
      "fullscreen": true,
      "networkPlayback": true,
      "localPlayback": true,
      // A desktop window keeps playing when it is not focused, and nothing in
      // the platform takes playback away from it.
      "backgroundPlayback": true,
      // macOS serves the small window in-app (media_core_floating) rather than
      // as a system feature, so the platform itself answers no — the same
      // convention the Windows and Linux probes follow.
      "pictureInPicture": false,
      "externalDisplay": screens.count > 1,
    ]
  }

  private func device() -> [String: Any] {
    var device: [String: Any] = [
      // Every Mac this app runs on is 64-bit; reporting otherwise would tune
      // playback down for nothing.
      "supports64BitAbi": true,
      // `isLowRamDevice` is Android's own classification. macOS has none, and
      // inventing one from a memory number would tune devices down on a guess.
      "lowRamDevice": false,
      "reported": true,
    ]

    let cores = ProcessInfo.processInfo.processorCount

    if cores > 0 {
      device["cpuCores"] = cores
    }

    let memory = ProcessInfo.processInfo.physicalMemory

    if memory > 0 {
      device["totalRamMb"] = Int(memory / 1024 / 1024)
    }

    return device
  }

  /// The codec section.
  ///
  /// VideoToolbox answers per codec, so unlike Linux this probe can fill the
  /// matrix in. It reports no size limits: VideoToolbox hardware decoders are
  /// capped by the SoC rather than by a documented video-capability API, and a
  /// fabricated ceiling would refuse streams the machine can play — the Dart
  /// side reads a zero limit as "unknown" and accepts the codec.
  private func codecs() -> [String: Any] {
    var video: [String: Any] = [:]

    for (name, codec) in videoCodecs() {
      if VTIsHardwareDecodeSupported(codec) {
        video[name] = [
          "hardware": true,
          "maxWidth": 0,
          "maxHeight": 0,
          "maxFrameRate": 0,
        ]
      }
    }

    return [
      "reported": true,
      "video": video,
    ]
  }

  private func videoCodecs() -> [String: CMVideoCodecType] {
    return [
      "h264": kCMVideoCodecType_H264,
      "hevc": kCMVideoCodecType_HEVC,
    ]
  }

  /// Whether VideoToolbox has a hardware decoder for any codec we name.
  private func anyHardwareDecoder() -> Bool {
    for (_, codec) in videoCodecs() where VTIsHardwareDecodeSupported(codec) {
      return true
    }

    return false
  }

  private func architecture() -> String {
    let value = sysctlString("hw.machine")

    return value.isEmpty ? "unknown" : value
  }

  /// Reads a string sysctl.
  ///
  /// Absence is answered rather than thrown: a sandbox that refuses a key is a
  /// normal state, and the Dart side treats a missing field as unknown.
  private func sysctlString(_ name: String) -> String {
    var size = 0

    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
      return ""
    }

    var buffer = [CChar](repeating: 0, count: size)

    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
      return ""
    }

    return String(cString: buffer)
  }
}
