package com.mediacore.remux;

import android.content.Context;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.net.Uri;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Android side of the media_core remuxer.
 *
 * <p>Wire protocol (see {@code AndroidMediaRemuxer} on the Dart side, which is
 * the source of truth):
 *
 * <ul>
 *   <li>{@code isAvailable} — answered with {@code true} while the plugin is
 *       attached, so a Dart caller can decide whether to install this
 *       remuxer on the current platform at all;
 *   <li>{@code remux} with {@code videoUrl}, {@code audioUrl},
 *       {@code headers} (string map applied to both URLs), and
 *       {@code videoOffsetUs} / {@code audioOffsetUs} (per-essence
 *       presentation offsets already normalized onto one shared clock by
 *       {@code MediaTimeline} on the Dart side) — answered with the absolute
 *       path of the merged MP4.
 * </ul>
 *
 * <p>The merge copies compressed samples; it never re-encodes. Each essence
 * gets its own {@link MediaExtractor} and the two sample streams are written
 * into one {@link MediaMuxer} in ascending presentation order, with the
 * caller's per-essence offset added to each timestamp so a DASH audio period
 * that trails the video keeps its alignment inside the merged file.
 *
 * <p>Output lives under {@code cacheDir/remux} with a process-unique name.
 * The cache directory is the right home: the system may evict it under
 * storage pressure, which is acceptable for a derived artifact that can be
 * rebuilt from the same URLs, and no app-visible storage permission is
 * involved.
 *
 * <p>Failure anywhere in the merge deletes the partial file and reports the
 * error to Dart; a half-written MP4 left behind would be played as if it
 * were a success by the next caller that trusted the returned path.
 */
public final class MediaRemuxPlugin
    implements FlutterPlugin, MethodChannel.MethodCallHandler {

  /** Channel name; kept in sync with the Dart implementation. */
  private static final String CHANNEL_NAME = "media_core/remux";

  private static final String TAG = "MediaRemuxPlugin";

  /** Default read buffer when a track does not advertise its own size. */
  private static final int DEFAULT_BUFFER_SIZE = 1 << 20;

  private MethodChannel channel;
  private Context appContext;
  private HandlerThread workerThread;
  private Handler worker;
  private final AtomicLong fileCounter = new AtomicLong();

  @Override
  public void onAttachedToEngine(FlutterPlugin.FlutterPluginBinding binding) {
    appContext = binding.getApplicationContext();
    workerThread = new HandlerThread("media-core-remux");
    workerThread.start();
    worker = new Handler(workerThread.getLooper());
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(FlutterPlugin.FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
    if (worker != null) {
      worker.removeCallbacksAndMessages(null);
      worker = null;
    }
    if (workerThread != null) {
      workerThread.quitSafely();
      workerThread = null;
    }
    appContext = null;
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    switch (call.method) {
      case "isAvailable":
        result.success(true);
        return;
      case "remux":
        handleRemux(call, result);
        return;
      default:
        result.notImplemented();
    }
  }

  private void handleRemux(MethodCall call, MethodChannel.Result result) {
    final String videoUrl = call.argument("videoUrl");
    final String audioUrl = call.argument("audioUrl");
    if (videoUrl == null || videoUrl.isEmpty() || audioUrl == null || audioUrl.isEmpty()) {
      result.error("bad_argument", "remux requires a non-empty videoUrl and audioUrl", null);
      return;
    }
    final Map<String, String> headers = stringMap(call.argument("headers"));
    final long videoOffsetUs = longArg(call.argument("videoOffsetUs"));
    final long audioOffsetUs = longArg(call.argument("audioOffsetUs"));

    // MediaExtractor opens network sources lazily but still does real
    // socket work on read; the whole merge runs off the platform thread.
    worker.post(() -> {
      File output = null;
      try {
        output = doRemux(videoUrl, audioUrl, headers, videoOffsetUs, audioOffsetUs);
        final String path = output.getAbsolutePath();
        // Handler threads deliver the reply on any Looper thread; the
        // MethodChannel protocol allows that.
        result.success(path);
      } catch (Exception error) {
        if (output != null && output.exists() && !output.delete()) {
          Log.w(TAG, "partial remux file left behind: " + output.getAbsolutePath());
        }
        result.error("remux_failed", error.getMessage(), Log.getStackTraceString(error));
      }
    });
  }

  private File doRemux(
      String videoUrl,
      String audioUrl,
      Map<String, String> headers,
      long videoOffsetUs,
      long audioOffsetUs) throws IOException {
    Essence video = null;
    Essence audio = null;
    MediaMuxer muxer = null;
    boolean muxerStarted = false;

    try {
      video = openEssence(videoUrl, headers, "video/", videoOffsetUs);
      audio = openEssence(audioUrl, headers, "audio/", audioOffsetUs);

      File dir = new File(appContext.getCacheDir(), "remux");
      if (!dir.isDirectory() && !dir.mkdirs()) {
        throw new IOException("could not create remux cache directory " + dir.getAbsolutePath());
      }
      File output = new File(dir, "remux_" + System.currentTimeMillis()
          + "_" + fileCounter.incrementAndGet() + ".mp4");

      muxer = new MediaMuxer(
          output.getAbsolutePath(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
      int videoIndex = muxer.addTrack(video.format);
      int audioIndex = muxer.addTrack(audio.format);
      muxer.start();
      muxerStarted = true;

      // Seed both sample cursors, then always write the earlier one.
      if (!video.advance()) {
        throw new IOException("video essence produced no samples");
      }
      if (!audio.advance()) {
        throw new IOException("audio essence produced no samples");
      }

      while (video.hasSample || audio.hasSample) {
        Essence next;
        if (!video.hasSample) {
          next = audio;
        } else if (!audio.hasSample) {
          next = video;
        } else {
          next = video.presentationTimeUs <= audio.presentationTimeUs ? video : audio;
        }
        muxer.writeSampleData(next.muxTrackIndex, next.buffer, next.info);
        if (!next.advance()) {
          next.hasSample = false;
        }
      }

      muxer.stop();
      muxerStarted = false;
      return output;
    } finally {
      if (muxer != null) {
        if (muxerStarted) {
          // A failure between start and stop leaves the muxer unable to
          // finalize; releasing without stop() is what makes the partial
          // file useless, which is exactly what the caller must not play.
          try {
            muxer.stop();
          } catch (IOException ignored) {
            // The caller deletes the partial file; a second failure here
            // changes nothing observable.
          }
        }
        muxer.release();
      }
      if (video != null) {
        video.release();
      }
      if (audio != null) {
        audio.release();
      }
    }
  }

  /** Opens [url] and selects its first track whose mime starts with [mimePrefix]. */
  private Essence openEssence(
      String url,
      Map<String, String> headers,
      String mimePrefix,
      long offsetUs) throws IOException {
    MediaExtractor extractor = new MediaExtractor();
    try {
      extractor.setDataSource(appContext, Uri.parse(url), headers);
      int selected = -1;
      for (int i = 0; i < extractor.getTrackCount(); i++) {
        MediaFormat format = extractor.getTrackFormat(i);
        String mime = format.getString(MediaFormat.KEY_MIME);
        if (mime != null && mime.startsWith(mimePrefix)) {
          selected = i;
          break;
        }
      }
      if (selected < 0) {
        throw new IOException("no " + mimePrefix + "* track found in " + url);
      }
      extractor.selectTrack(selected);
      return new Essence(extractor, selected, offsetUs);
    } catch (IOException | IllegalArgumentException error) {
      extractor.release();
      throw error;
    }
  }

  /**
   * One essence being copied: its extractor, selected track, buffer, and the
   * current sample's presentation time on the merged timeline.
   */
  private static final class Essence {
    final MediaExtractor extractor;
    final int muxTrackIndex;
    final MediaFormat format;
    final ByteBuffer buffer;
    final MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
    final long offsetUs;
    long presentationTimeUs;
    boolean hasSample;

    Essence(MediaExtractor extractor, int track, long offsetUs) {
      this.extractor = extractor;
      this.muxTrackIndex = track;
      this.format = extractor.getTrackFormat(track);
      int advertised = DEFAULT_BUFFER_SIZE;
      if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
        int value = format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE);
        if (value > 0) {
          advertised = value;
        }
      }
      this.buffer = ByteBuffer.allocate(advertised);
      this.offsetUs = offsetUs;
    }

    /** Reads the next sample into [buffer]; false when the essence is done. */
    boolean advance() {
      int size = extractor.readSampleData(buffer, 0);
      if (size < 0) {
        hasSample = false;
        return false;
      }
      info.offset = 0;
      info.size = size;
      long raw = extractor.getSampleTime();
      // Aligned offsets from the Dart side are non-negative; clamping keeps
      // a hand-built timeline with a negative anchor from poisoning the
      // merged file with timestamps the muxer would reject.
      presentationTimeUs = Math.max(0, raw + offsetUs);
      info.presentationTimeUs = presentationTimeUs;
      info.flags = extractor.getSampleFlags();
      hasSample = true;
      extractor.advance();
      return true;
    }

    void release() {
      try {
        extractor.release();
      } catch (RuntimeException ignored) {
        // Release is best-effort cleanup; nothing the caller can do.
      }
    }
  }

  private static Map<String, String> stringMap(Map<Object, Object> raw) {
    Map<String, String> result = new HashMap<>();
    if (raw == null) {
      return result;
    }
    for (Map.Entry<Object, Object> entry : raw.entrySet()) {
      if (entry.getKey() instanceof String && entry.getValue() instanceof String) {
        result.put((String) entry.getKey(), (String) entry.getValue());
      }
    }
    return result;
  }

  private static long longArg(Object value) {
    if (value instanceof Number) {
      return ((Number) value).longValue();
    }
    return 0L;
  }
}
