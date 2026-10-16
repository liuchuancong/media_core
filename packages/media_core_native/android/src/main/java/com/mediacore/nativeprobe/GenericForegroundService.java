package com.mediacore.nativeprobe;

/**
 * Keeps work the runtime cannot name alive while the app is in the background.
 *
 * This is what {@code BackgroundExecutionKind.generic} — and any host that starts
 * a session through the channel itself — gets. It keeps the id and channel the
 * single service used to have ({@code media_core.background}), so a user who
 * already silenced "background tasks" keeps that choice; recording and download
 * moved out to their own lines and their own locks.
 */
public final class GenericForegroundService extends JobForegroundService {

  @Override
  Feature feature() {
    return Feature.GENERIC;
  }
}
