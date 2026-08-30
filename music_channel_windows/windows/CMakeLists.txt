cmake_minimum_required(VERSION 3.18)
set(PROJECT_NAME "music_channel_windows")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "music_channel_windows_plugin")

set(FFMPEG_VERSION "n8.1-latest-win64-lgpl-shared-8.1")
set(FFMPEG_URL "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-${FFMPEG_VERSION}.zip")
set(FFMPEG_SHA256 "639f52d1b5627ee63ac2eac96b11a467c85f0253e81c5aa387605d096b8b2be8")
set(FFMPEG_CACHE_DIR "$ENV{TEMP}/yunshu_music_ffmpeg")
set(FFMPEG_ROOT "${FFMPEG_CACHE_DIR}/ffmpeg-${FFMPEG_VERSION}")

if(NOT EXISTS "${FFMPEG_ROOT}/include/libavformat/avformat.h")
  set(FFMPEG_ZIP "${FFMPEG_CACHE_DIR}/ffmpeg-${FFMPEG_VERSION}.zip")
  file(DOWNLOAD "${FFMPEG_URL}" "${FFMPEG_ZIP}" SHOW_PROGRESS
       EXPECTED_HASH SHA256=${FFMPEG_SHA256})
  file(ARCHIVE_EXTRACT INPUT ${FFMPEG_ZIP} DESTINATION ${FFMPEG_CACHE_DIR})
endif()

file(GLOB FFMPEG_DLLS
  "${FFMPEG_ROOT}/bin/avcodec-*.dll"
  "${FFMPEG_ROOT}/bin/avformat-*.dll"
  "${FFMPEG_ROOT}/bin/avutil-*.dll"
  "${FFMPEG_ROOT}/bin/swresample-*.dll"
)

add_library(${PLUGIN_NAME} SHARED
  "music_channel_windows_plugin.cpp"
  "wasapi_output.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE "${FFMPEG_ROOT}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin ole32
  "${FFMPEG_ROOT}/lib/avcodec.lib"
  "${FFMPEG_ROOT}/lib/avformat.lib"
  "${FFMPEG_ROOT}/lib/avutil.lib"
  "${FFMPEG_ROOT}/lib/swresample.lib"
)

# List of absolute paths to libraries that should be bundled with the plugin
set(music_channel_windows_bundled_libraries
  ${FFMPEG_DLLS}
  PARENT_SCOPE
)
