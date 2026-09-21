import 'dart:async';

import 'package:media_core/media_core.dart';

import 'media_core_presentation.dart';

/// Bridges a [MediaCorePresentation] driver into the core
/// presentation module's [PresentationAdapter] contract.
///
/// Use this when wiring through `PresentationController` /
/// `PresentationCoordinator` instead of (or alongside) the kernel
/// `attachPresentation` path:
///
/// ```dart
/// final driver = MediaCorePresentation();
/// await driver.initialize();
///
/// final adapter = KernelPresentationAdapter(driver);
/// final controller = PresentationController();
/// // PresentationRequest flows: controller → adapter → driver → platform
/// ```
final class KernelPresentationAdapter extends PresentationAdapterBase {
  /// Creates the adapter wrapping [driver].
  KernelPresentationAdapter(this.driver)
    : super(initialCapabilities: _capabilitiesFor(driver));

  /// The wrapped capability driver.
  final MediaCorePresentation driver;

  static PresentationCapabilities _capabilitiesFor(MediaCorePresentation driver) {
    return PresentationCapabilities(
      fullscreen: true,
      // PiP is only served on desktop (floating window) for now.
      pip: driver.supportsFloatingWindow,
      floating: driver.supportsFloatingWindow,
    );
  }

  @override
  Future<void> apply(PresentationRequest request) async {
    // The adapter contract has no player identity; the driver's
    // window-level operations do not need one on desktop.
    final playerId = PlayerId('presentation-adapter');
    await driver.apply(playerId, request);
    emit(PresentationEvent.changed(mode: request.mode));
  }

  @override
  Future<void> refreshCapabilities() async {
    updateCapabilities(_capabilitiesFor(driver));
  }

  @override
  Future<void> onDispose() async {
    await driver.dispose();
  }
}
