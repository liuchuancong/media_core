package com.mediacore.nativeprobe;

/**
 * Keeps a live capture alive while the app is in the background.
 *
 * Its own service, so its own notification ({@code media_core.recording}) and its
 * own wake lock; a download starting, finishing or hitting the platform's
 * {@code dataSync} allowance changes nothing here. The type is
 * {@code specialUse} rather than {@code dataSync} because a recording has no
 * useful bound: the six-hour daily cap on {@code dataSync} would end captures the
 * user is still watching.
 *
 * <p>Declared in this plugin's manifest with a subsystem-role justification, which
 * is what Google Play asks {@code specialUse} services to carry.
 */
public final class RecordingForegroundService extends JobForegroundService {

  @Override
  Feature feature() {
    return Feature.RECORDING;
  }
}
