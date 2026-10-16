package com.mediacore.nativeprobe;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;

/**
 * Outbound status events about sessions the platform is holding.
 *
 * A session's protection is held here and asked for there, and the two ends can
 * disagree: the system stops a foreground service when its allowance runs out, or
 * the user never granted {@code POST_NOTIFICATIONS} so the line is invisible while
 * the lock still holds. Without this path the Dart registry keeps believing it
 * holds something it does not — which is how a recording goes on reporting
 * "protected" for the rest of its life after Android took the service away.
 *
 * <p>Events are {@code {id: handle, status: name}} with the same handle Dart was
 * given on acquire, so a listener can tell whether the event is about its session
 * without asking a second question. Unknown status names must be ignored by the
 * reader: this is a plugin, and an app built against a newer one may say more than
 * the Dart side knows.
 *
 * <p>Everything here runs on the platform's main thread — services and channel
 * callbacks both do — so the sink list needs no locking of its own.
 */
public final class BackgroundStatusPublisher {

  /** Channel name; kept in sync with the Dart side. */
  static final String CHANNEL_NAME = "media_core_native/background_status";

  /** Something is running, but one of the promises was given up. */
  static final String STATUS_DEGRADED = "degraded";

  /** Nothing is held for the session any more, as the caller asked. */
  static final String STATUS_STOPPED = "stopped";

  /**
   * The platform took the protection back while the job kept running.
   *
   * Not {@code stopped}: nobody released it. Not {@code failed}: the job is not
   * over. A host that hears either of those two about a live recording learns the
   * wrong lesson.
   */
  static final String STATUS_PROTECTION_LOST = "protectionLost";

  private static final List<EventChannel.EventSink> SINKS = new ArrayList<EventChannel.EventSink>();

  private BackgroundStatusPublisher() {}

  /**
   * The handler an {@link EventChannel} takes.
   *
   * Several sinks may exist across a process (a re-attached engine), so the list
   * holds them all and an event goes to each. A session whose service is running
   * with no listener is not lost: the state is reported again by whoever asks the
   * platform about it next time.
   */
  static EventChannel.StreamHandler handler() {
    return new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object arguments, EventChannel.EventSink events) {
        SINKS.add(events);
      }

      @Override
      public void onCancel(Object arguments) {
        // EventChannel is single-listener per channel instance: the newest sink is
        // the one that just went away, and a dead sink never receives anything.
        final int last = SINKS.size() - 1;

        if (last >= 0) {
          SINKS.remove(last);
        }
      }
    };
  }

  /** Reports what happened to the session behind {@code handle}. */
  static void publish(int handle, String status) {
    if (SINKS.isEmpty()) {
      return;
    }

    final Map<String, Object> event = new HashMap<String, Object>();
    event.put("id", handle);
    event.put("status", status);

    for (EventChannel.EventSink sink : new ArrayList<EventChannel.EventSink>(SINKS)) {
      sink.success(event);
    }
  }

  /** Forgets every sink; a detached engine must not keep a dead one alive. */
  static void clear() {
    SINKS.clear();
  }
}
