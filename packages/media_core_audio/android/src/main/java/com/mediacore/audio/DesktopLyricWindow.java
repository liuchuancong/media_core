package com.mediacore.audio;

import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.Map;

/**
 * The desktop-lyric overlay window on Android.
 *
 * A {@code TYPE_APPLICATION_OVERLAY} window added straight through the
 * WindowManager with the *application* context. That is deliberate:
 *
 * - it does not need an Activity, so the lyric survives navigating away from
 *   the player page, a rotation, or the app going to the background;
 * - it needs no Service of its own — the playback foreground service
 *   (audio_service) already keeps the process alive, and a second
 *   notification for the overlay would be one notification too many;
 * - the window dies with the process, which is exactly the lifetime of the
 *   playback it describes.
 *
 * Locking makes the window click-through ({@code FLAG_NOT_TOUCHABLE}); that is
 * the whole point of a lock on a touch device, where the overlay sits on top
 * of whatever the user is doing. The host unlocks it again through
 * {@code DesktopLyricController.setLocked}.
 *
 * Everything runs on the main thread: WindowManager views and their touch
 * handlers have no other thread.
 */
final class DesktopLyricWindow {

  /** Receives the overlay's own buttons, to be forwarded to Dart. */
  interface ActionSink {
    void onAction(String action);
  }

  private static final int COLOR_BACKGROUND = 0x99000000;
  private static final long LOCK_HINT_MILLIS = 2000L;

  private final Context context;
  private final ActionSink actions;
  private final WindowManager windowManager;
  private final Handler main = new Handler(Looper.getMainLooper());

  private LinearLayout root;
  private LinearLayout controls;
  private TextView lockChip;
  private TextView textView;
  private TextView translationView;
  private TextView nextView;
  private ImageButton playPauseButton;
  private View progressTrack;
  private View progressFill;

  private WindowManager.LayoutParams params;

  private boolean shown;
  private boolean locked;

  /** Lock state the window has already been configured for. */
  private boolean lockedApplied;
  private boolean playing;
  private boolean hasLyrics = true;
  private double progress;
  private int textColor = Color.WHITE;
  private int strokeColor = Color.BLACK;
  private float strokeWidth = 2f;
  private float fontScale = 1f;
  private String alignment = "center";

  /** True while the user is dragging the window. */
  private boolean dragging;

  private float dragStartX;
  private float dragStartY;
  private int dragOriginX;
  private int dragOriginY;

  DesktopLyricWindow(Context context, ActionSink actions) {
    this.context = context.getApplicationContext();
    this.actions = actions;
    this.windowManager = (WindowManager) this.context.getSystemService(Context.WINDOW_SERVICE);
  }

  // ---------------------------------------------------------------------------
  // Method channel surface
  // ---------------------------------------------------------------------------

  boolean isSupported() {
    return true;
  }

  boolean show() {
    if (!canDrawOverlays()) {
      requestOverlayPermission();
      // The permission dialog is asynchronous: the host is expected to offer
      // the feature again once the user is back (the Dart transport returns
      // false here, which is what makes the host's button re-tryable).
      return false;
    }

    if (shown) {
      return true;
    }

    if (root == null) {
      buildViews();
    }

    try {
      windowManager.addView(root, params);
      shown = true;

      return true;
    } catch (RuntimeException error) {
      // Some OEM builds reject the window even with the permission granted.
      root = null;

      return false;
    }
  }

  void hide() {
    if (!shown || root == null) {
      return;
    }

    try {
      windowManager.removeView(root);
    } catch (RuntimeException ignored) {
      // Already detached.
    }

    shown = false;
  }

  void dispose() {
    hide();
    main.removeCallbacksAndMessages(null);
    root = null;
  }

  void update(Object arguments) {
    if (!(arguments instanceof Map)) {
      return;
    }

    final Map<?, ?> map = (Map<?, ?>) arguments;

    final String text = string(map.get("text"));
    final String translation = string(map.get("translation"));
    final String nextLine = string(map.get("nextLine"));

    playing = bool(map.get("playing"), playing);
    hasLyrics = bool(map.get("hasLyrics"), hasLyrics);
    progress = number(map.get("progress"), progress);
    locked = bool(map.get("locked"), locked);

    final Map<?, ?> style = map.get("style") instanceof Map ? (Map<?, ?>) map.get("style") : null;

    if (style != null) {
      textColor = (int) number(style.get("textColor"), textColor);
      strokeColor = (int) number(style.get("strokeColor"), strokeColor);
      strokeWidth = (float) number(style.get("strokeWidth"), strokeWidth);
      final double fontSize = number(style.get("fontSize"), 0);

      if (fontSize > 0) {
        fontScale = (float) (fontSize / 24.0);
      }

      alignment = string(style.get("alignment")) != null ? string(style.get("alignment")) : alignment;
    }

    if (shown && root != null) {
      render(text, translation, nextLine);

      // Only a *change* of the lock state re-applies the window flags: doing
      // it per lyric line would keep postponing the click-through transition
      // for as long as the song keeps singing, so the overlay would never
      // actually become click-through.
      if (locked != lockedApplied) {
        applyLockState();
      }
    }
  }

  void setBounds(Object arguments) {
    if (!(arguments instanceof Map) || !shown || root == null) {
      return;
    }

    final Map<?, ?> map = (Map<?, ?>) arguments;

    params.x = (int) number(map.get("x"), params.x);
    params.y = (int) number(map.get("y"), params.y);
    params.width = (int) number(map.get("width"), params.width);
    params.height = (int) number(map.get("height"), params.height);
    params.gravity = Gravity.TOP | Gravity.START;

    try {
      windowManager.updateViewLayout(root, params);
    } catch (RuntimeException ignored) {
      // Window already gone.
    }
  }

  // ---------------------------------------------------------------------------
  // View construction
  // ---------------------------------------------------------------------------

  private void buildViews() {
    root = new LinearLayout(context);
    root.setOrientation(LinearLayout.VERTICAL);
    root.setPadding(dp(16), dp(8), dp(16), dp(8));
    root.setBackground(rounded(COLOR_BACKGROUND, dp(14)));

    controls = new LinearLayout(context);
    controls.setOrientation(LinearLayout.HORIZONTAL);
    controls.setGravity(Gravity.CENTER);

    controls.addView(iconButton(android.R.drawable.ic_media_previous, "previous"));
    playPauseButton = iconButton(android.R.drawable.ic_media_play, "toggle");
    controls.addView(playPauseButton);
    controls.addView(iconButton(android.R.drawable.ic_media_next, "next"));

    lockChip = textChip("锁定");
    lockChip.setOnClickListener(
        new View.OnClickListener() {
          @Override
          public void onClick(View view) {
            actions.onAction(locked ? "unlock" : "lock");
          }
        });
    controls.addView(lockChip);

    final TextView closeChip = textChip("✕");
    closeChip.setOnClickListener(
        new View.OnClickListener() {
          @Override
          public void onClick(View view) {
            actions.onAction("close");
          }
        });
    controls.addView(closeChip);

    root.addView(controls);

    textView = new TextView(context);
    textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24);
    textView.setSingleLine(true);
    textView.setEllipsize(TextUtils.TruncateAt.END);
    textView.setGravity(Gravity.CENTER);
    textView.setShadowLayer(dp(2), 0, 0, Color.BLACK);
    root.addView(textView);

    translationView = new TextView(context);
    translationView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
    translationView.setSingleLine(true);
    translationView.setEllipsize(TextUtils.TruncateAt.END);
    translationView.setGravity(Gravity.CENTER);
    translationView.setTextColor(0xCCFFFFFF);
    root.addView(translationView);

    nextView = new TextView(context);
    nextView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
    nextView.setSingleLine(true);
    nextView.setEllipsize(TextUtils.TruncateAt.END);
    nextView.setGravity(Gravity.CENTER);
    nextView.setTextColor(0x99FFFFFF);
    root.addView(nextView);

    // A two-view progress track: the fill's weight *is* the progress, which
    // avoids waiting for a layout pass to know the pixel width.
    progressTrack = buildProgressTrack();
    root.addView(progressTrack);

    params = new WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        overlayWindowType(),
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
            | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        android.graphics.PixelFormat.TRANSLUCENT);
    params.gravity = Gravity.TOP | Gravity.START;
    params.y = dp(120);

    root.setOnTouchListener(
        new View.OnTouchListener() {
          @Override
          public boolean onTouch(View view, MotionEvent event) {
            return onRootTouch(event);
          }
        });
  }

  private View buildProgressTrack() {
    final LinearLayout track = new LinearLayout(context);
    track.setOrientation(LinearLayout.HORIZONTAL);
    track.setPadding(0, dp(6), 0, 0);

    progressFill = new View(context);
    progressFill.setBackground(rounded(0xCCFFFFFF, dp(2)));
    track.addView(progressFill, new LinearLayout.LayoutParams(0, dp(3), 0f));

    final View rest = new View(context);
    track.addView(rest, new LinearLayout.LayoutParams(0, dp(3), 1f));

    return track;
  }

  private ImageButton iconButton(int drawable, final String action) {
    final ImageButton button = new ImageButton(context);
    button.setImageResource(drawable);
    button.setBackgroundColor(Color.TRANSPARENT);
    button.setPadding(dp(8), dp(4), dp(8), dp(4));
    button.setOnClickListener(
        new View.OnClickListener() {
          @Override
          public void onClick(View view) {
            actions.onAction(action);
          }
        });

    return button;
  }

  private TextView textChip(String label) {
    final TextView chip = new TextView(context);
    chip.setText(label);
    chip.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
    chip.setTextColor(0xE6FFFFFF);
    chip.setPadding(dp(10), dp(6), dp(10), dp(6));
    chip.setGravity(Gravity.CENTER);

    return chip;
  }

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  private void render(String text, String translation, String nextLine) {
    textView.setText(text == null || text.isEmpty() ? "♪" : text);
    textView.setTextColor(textColor);
    textView.setShadowLayer(Math.max(1f, dp(strokeWidth)), 0, 0, strokeColor);
    textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24 * Math.max(0.5f, fontScale));

    translationView.setText(translation == null ? "" : translation);
    translationView.setVisibility(translation == null || translation.isEmpty() ? View.GONE : View.VISIBLE);

    nextView.setText(nextLine == null ? "" : nextLine);
    nextView.setVisibility(nextLine == null || nextLine.isEmpty() ? View.GONE : View.VISIBLE);

    playPauseButton.setImageResource(playing ? android.R.drawable.ic_media_pause : android.R.drawable.ic_media_play);
    lockChip.setText(locked ? "已锁定" : "锁定");

    final int gravity = "left".equals(alignment)
        ? Gravity.START
        : "right".equals(alignment) ? Gravity.END : Gravity.CENTER;

    textView.setGravity(gravity);
    translationView.setGravity(gravity);
    nextView.setGravity(gravity);

    final float clamped = (float) Math.max(0.0, Math.min(1.0, progress));

    final LinearLayout.LayoutParams fillParams = (LinearLayout.LayoutParams) progressFill.getLayoutParams();
    fillParams.weight = clamped;

    final LinearLayout.LayoutParams restParams =
        (LinearLayout.LayoutParams) ((LinearLayout) progressTrack).getChildAt(1).getLayoutParams();
    restParams.weight = Math.max(0.0001f, 1f - clamped);

    progressFill.requestLayout();

    if (!hasLyrics) {
      translationView.setVisibility(View.GONE);
      nextView.setVisibility(View.GONE);
    }
  }

  /**
   * Applies the locked state.
   *
   * Locking means click-through, so a hint is shown *before* the window stops
   * accepting input — otherwise the user would lock it and have no visible
   * explanation of why nothing responds, nor a way back from the overlay
   * itself. After the hint the host is the only unlock path, which is what
   * {@code DesktopLyricController.setLocked(false)} is for.
   */
  private void applyLockState() {
    if (root == null || params == null || !shown) {
      return;
    }

    main.removeCallbacksAndMessages(null);

    lockedApplied = locked;

    if (!locked) {
      controls.setVisibility(View.VISIBLE);
      params.flags &= ~WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
      updateLayout();

      return;
    }

    controls.setVisibility(View.VISIBLE);
    lockChip.setText("已锁定");
    params.flags &= ~WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
    updateLayout();

    main.postDelayed(
        new Runnable() {
          @Override
          public void run() {
            if (!locked || lockedApplied != locked || root == null || params == null) {
              return;
            }

            controls.setVisibility(View.GONE);
            params.flags |= WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
            updateLayout();
          }
        },
        LOCK_HINT_MILLIS);
  }

  private void updateLayout() {
    try {
      windowManager.updateViewLayout(root, params);
    } catch (RuntimeException ignored) {
      // Window already gone.
    }
  }

  // ---------------------------------------------------------------------------
  // Interaction
  // ---------------------------------------------------------------------------

  private boolean onRootTouch(MotionEvent event) {
    if (locked) {
      return false;
    }

    switch (event.getActionMasked()) {
      case MotionEvent.ACTION_DOWN:
        dragging = true;
        dragStartX = event.getRawX();
        dragStartY = event.getRawY();
        dragOriginX = params.x;
        dragOriginY = params.y;

        return true;

      case MotionEvent.ACTION_MOVE:
        if (!dragging) {
          return false;
        }

        params.x = dragOriginX + (int) (event.getRawX() - dragStartX);
        params.y = Math.max(0, dragOriginY + (int) (event.getRawY() - dragStartY));

        // Once dragged, the window owns an explicit position instead of the
        // gravity default, which is what makes the move stick.
        params.gravity = Gravity.TOP | Gravity.START;
        params.width = root.getWidth() > 0 ? root.getWidth() : params.width;

        updateLayout();

        return true;

      case MotionEvent.ACTION_UP:
      case MotionEvent.ACTION_CANCEL:
        dragging = false;

        return true;

      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Platform helpers
  // ---------------------------------------------------------------------------

  private boolean canDrawOverlays() {
    return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context);
  }

  private void requestOverlayPermission() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      return;
    }

    try {
      final Intent intent = new Intent(
          Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
          Uri.parse("package:" + context.getPackageName()));
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      context.startActivity(intent);
    } catch (RuntimeException ignored) {
      // Some TV builds have no such settings screen; show() already reported
      // "unsupported" by returning false.
    }
  }

  private int overlayWindowType() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      return WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY;
    }

    return WindowManager.LayoutParams.TYPE_PHONE;
  }

  private int dp(float value) {
    return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, context.getResources().getDisplayMetrics());
  }

  private GradientDrawable rounded(int color, int radius) {
    final GradientDrawable drawable = new GradientDrawable();
    drawable.setColor(color);
    drawable.setCornerRadius(radius);

    return drawable;
  }

  private static String string(Object value) {
    return value == null ? null : value.toString();
  }

  private static boolean bool(Object value, boolean fallback) {
    return value instanceof Boolean ? (Boolean) value : fallback;
  }

  private static double number(Object value, double fallback) {
    return value instanceof Number ? ((Number) value).doubleValue() : fallback;
  }
}
