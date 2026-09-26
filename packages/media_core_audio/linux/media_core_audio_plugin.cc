#include "include/media_core_audio/media_core_audio_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>
#include <memory>
#include <string>

#include "desktop_lyric_window.h"

#define MEDIA_CORE_AUDIO_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), media_core_audio_plugin_get_type(), \
                              MediaCoreAudioPlugin))

namespace {

constexpr char kChannelName[] = "media_core_audio/desktop_lyric";

/// Reads a string out of an FlValue map (returns an empty string when absent).
std::string StringAt(FlValue* map, const char* key) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return std::string();
  }

  FlValue* value = fl_value_lookup_string(map, key);

  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return std::string();
  }

  return std::string(fl_value_get_string(value));
}

bool BoolAt(FlValue* map, const char* key, bool fallback) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return fallback;
  }

  FlValue* value = fl_value_lookup_string(map, key);

  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
    return fallback;
  }

  return fl_value_get_bool(value);
}

double NumberAt(FlValue* map, const char* key, double fallback) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return fallback;
  }

  FlValue* value = fl_value_lookup_string(map, key);

  if (value == nullptr) {
    return fallback;
  }

  if (fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT) {
    return fl_value_get_float(value);
  }

  if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
    return static_cast<double>(fl_value_get_int(value));
  }

  return fallback;
}

/// Builds a LyricWindowState out of the Dart-side state map.
media_core_audio::LyricWindowState ParseState(FlValue* arguments) {
  media_core_audio::LyricWindowState state;

  state.text = StringAt(arguments, "text");
  state.translation = StringAt(arguments, "translation");
  state.next_line = StringAt(arguments, "nextLine");
  state.progress = NumberAt(arguments, "progress", 0.0);
  state.playing = BoolAt(arguments, "playing", false);
  state.locked = BoolAt(arguments, "locked", false);
  state.has_lyrics = BoolAt(arguments, "hasLyrics", true);

  if (arguments != nullptr && fl_value_get_type(arguments) == FL_VALUE_TYPE_MAP) {
    FlValue* style = fl_value_lookup_string(arguments, "style");

    if (style != nullptr && fl_value_get_type(style) == FL_VALUE_TYPE_MAP) {
      const std::string family = StringAt(style, "fontFamily");

      if (!family.empty()) {
        state.font_family = family;
      }

      state.font_size = NumberAt(style, "fontSize", state.font_size);
      state.text_color = static_cast<std::uint32_t>(
          NumberAt(style, "textColor", 0xFFFFFFFF));
      state.stroke_color = static_cast<std::uint32_t>(
          NumberAt(style, "strokeColor", 0xFF000000));
      state.stroke_width = NumberAt(style, "strokeWidth", state.stroke_width);
      state.opacity = NumberAt(style, "opacity", state.opacity);
      state.alignment = StringAt(style, "alignment");
    }
  }

  return state;
}

/// Silences Flutter when the map carries no "text" at all (empty lyric line):
/// the overlay then shows its own placeholder.
std::string PlaceholderFor(const media_core_audio::LyricWindowState& state) {
  return state.text.empty() ? std::string("♪") : state.text;
}

}  // namespace

struct _MediaCoreAudioPlugin {
  GObject parent_instance;

  FlMethodChannel* channel;

  // A raw pointer, not a smart one: GObject allocates instances with
  // g_object_new, which zeroes the memory but never runs C++ constructors or
  // destructors — a std::unique_ptr member there would be undefined
  // behaviour. Zeroed memory makes this start out null, and dispose() frees it.
  media_core_audio::DesktopLyricWindow* window;
};

G_DEFINE_TYPE(MediaCoreAudioPlugin, media_core_audio_plugin, g_object_get_type())

/// Sends one of the overlay's buttons to Dart.
static void SendAction(MediaCoreAudioPlugin* self, const std::string& action) {
  if (self->channel == nullptr) {
    return;
  }

  g_autoptr(FlValue) arguments = fl_value_new_map();

  fl_value_set_string_take(arguments, "action",
                           fl_value_new_string(action.c_str()));

  fl_method_channel_invoke_method(self->channel, "action", arguments, nullptr,
                                  nullptr, nullptr);
}

static void media_core_audio_plugin_handle_method_call(
    MediaCoreAudioPlugin* self,
    FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* arguments = fl_method_call_get_args(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "isSupported") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(
        fl_value_new_bool(self->window != nullptr &&
                          self->window->IsSupported())));

    fl_method_call_respond(method_call, response, nullptr);

    return;
  }

  if (strcmp(method, "show") == 0) {
    const bool shown = self->window != nullptr && self->window->Show();

    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(shown)));

    fl_method_call_respond(method_call, response, nullptr);

    return;
  }

  if (strcmp(method, "hide") == 0) {
    if (self->window != nullptr) {
      self->window->Hide();
    }

    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));

    fl_method_call_respond(method_call, response, nullptr);

    return;
  }

  if (strcmp(method, "update") == 0) {
    if (self->window != nullptr) {
      media_core_audio::LyricWindowState state = ParseState(arguments);

      state.text = PlaceholderFor(state);
      self->window->Update(state);
    }

    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));

    fl_method_call_respond(method_call, response, nullptr);

    return;
  }

  if (strcmp(method, "setBounds") == 0) {
    if (self->window != nullptr) {
      self->window->SetBounds(
          static_cast<int>(NumberAt(arguments, "x", 0)),
          static_cast<int>(NumberAt(arguments, "y", 0)),
          static_cast<int>(NumberAt(arguments, "width", 900)),
          static_cast<int>(NumberAt(arguments, "height", 150)));
    }

    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));

    fl_method_call_respond(method_call, response, nullptr);

    return;
  }

  response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());

  fl_method_call_respond(method_call, response, nullptr);
}

static void media_core_audio_plugin_dispose(GObject* object) {
  MediaCoreAudioPlugin* self = MEDIA_CORE_AUDIO_PLUGIN(object);

  if (self->window != nullptr) {
    self->window->Hide();

    delete self->window;
    self->window = nullptr;
  }

  g_clear_object(&self->channel);

  G_OBJECT_CLASS(media_core_audio_plugin_parent_class)->dispose(object);
}

static void media_core_audio_plugin_class_init(
    MediaCoreAudioPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = media_core_audio_plugin_dispose;
}

static void media_core_audio_plugin_init(MediaCoreAudioPlugin* self) {
  self->channel = nullptr;
  self->window = nullptr;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  MediaCoreAudioPlugin* self = MEDIA_CORE_AUDIO_PLUGIN(user_data);

  media_core_audio_plugin_handle_method_call(self, method_call);
}

void media_core_audio_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  MediaCoreAudioPlugin* plugin = MEDIA_CORE_AUDIO_PLUGIN(
      g_object_new(media_core_audio_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  plugin->channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), kChannelName,
      FL_METHOD_CODEC(codec));

  // The overlay's buttons arrive on the GTK main thread, which is the thread
  // Flutter's Linux embedder uses for platform channels, so no marshalling
  // layer is needed here.
  plugin->window = new media_core_audio::DesktopLyricWindow(
      [plugin](const std::string& action) { SendAction(plugin, action); });

  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
