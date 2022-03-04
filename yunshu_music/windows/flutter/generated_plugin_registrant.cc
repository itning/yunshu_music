//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <dart_vlc/dart_vlc_plugin.h>
#include <music_channel_windows/music_channel_windows_plugin.h>
#include <url_launcher_windows/url_launcher_windows.h>
#include <window_size/window_size_plugin.h>
#include <windows_taskbar/windows_taskbar_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  DartVlcPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DartVlcPlugin"));
  MusicChannelWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MusicChannelWindowsPlugin"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
  WindowSizePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowSizePlugin"));
  WindowsTaskbarPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowsTaskbarPlugin"));
}
