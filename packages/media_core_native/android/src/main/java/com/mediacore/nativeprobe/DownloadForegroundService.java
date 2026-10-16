package com.mediacore.nativeprobe;

/**
 * Keeps a transfer alive while the app is in the background.
 *
 * Its own service, so its own notification ({@code media_core.download}) and its
 * own wake lock: the last file finishing clears the download line and leaves a
 * recording's line untouched. The type stays {@code dataSync} — that is what a
 * transfer is, and Android's allowance is measured against a job that ends when
 * the bytes do.
 */
public final class DownloadForegroundService extends JobForegroundService {

  @Override
  Feature feature() {
    return Feature.DOWNLOAD;
  }
}
