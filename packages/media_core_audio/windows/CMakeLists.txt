cmake_minimum_required(VERSION 3.14)
project(media_core_audio LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(PLUGIN_NAME "media_core_audio_plugin")
add_library(${PLUGIN_NAME} SHARED
  "media_core_audio_plugin.cc" "media_core_audio_plugin_c_api.cc"
  "desktop_lyric_window.cc")
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE
  FLUTTER_PLUGIN_IMPL _DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)
target_compile_options(${PLUGIN_NAME} PRIVATE "/utf-8")
target_include_directories(${PLUGIN_NAME}
  INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
# gdiplus draws the overlay's text and controls; the window itself is a layered
# window with per-pixel alpha, which needs no other dependency.
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin gdiplus)
set(media_core_audio_bundled_libraries "" PARENT_SCOPE)
