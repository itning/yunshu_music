#include "include/music_channel_windows/music_channel_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

#include "ffmpeg_engine.h"
#include "platform_task_queue.h"
#include "smtc_controller.h"
#include "taskbar_progress.h"
#include "tray_icon.h"

namespace {

const flutter::EncodableValue* ValueOrNull(const flutter::EncodableMap& map,
                                           const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return &(it->second);
}

int GetInt(const flutter::EncodableMap& map, const char* key,
           int fallback = 0) {
  const auto* value = ValueOrNull(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (const auto* v32 = std::get_if<int32_t>(value)) {
    return *v32;
  }
  if (const auto* v64 = std::get_if<int64_t>(value)) {
    return static_cast<int>(*v64);
  }
  return fallback;
}

int64_t GetInt64(const flutter::EncodableMap& map, const char* key,
                 int64_t fallback = 0) {
  const auto* value = ValueOrNull(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (const auto* v32 = std::get_if<int32_t>(value)) {
    return *v32;
  }
  if (const auto* v64 = std::get_if<int64_t>(value)) {
    return *v64;
  }
  return fallback;
}

double GetDouble(const flutter::EncodableMap& map, const char* key,
                 double fallback = 0.0) {
  const auto* value = ValueOrNull(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (const auto* v = std::get_if<double>(value)) {
    return *v;
  }
  if (const auto* v32 = std::get_if<int32_t>(value)) {
    return static_cast<double>(*v32);
  }
  if (const auto* v64 = std::get_if<int64_t>(value)) {
    return static_cast<double>(*v64);
  }
  return fallback;
}

std::wstring Utf8ToWide(const std::string& input) {
  if (input.empty()) {
    return std::wstring();
  }
  int size = MultiByteToWideChar(CP_UTF8, 0, input.data(),
                                 static_cast<int>(input.size()), nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring output(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, input.data(), static_cast<int>(input.size()),
                      output.data(), size);
  return output;
}

// Resolves a Flutter asset key (e.g. "asserts/icon/app_icon.ico") to an
// absolute path under "<exe dir>/data/flutter_assets".
std::wstring ResolveAssetPath(const std::string& relative_path) {
  wchar_t exe_path[MAX_PATH] = {0};
  DWORD length = GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  std::wstring directory(exe_path, length);
  size_t slash = directory.find_last_of(L"\\/");
  if (slash != std::wstring::npos) {
    directory = directory.substr(0, slash + 1);
  }

  std::wstring relative = Utf8ToWide(relative_path);
  for (auto& ch : relative) {
    if (ch == L'/') {
      ch = L'\\';
    }
  }
  return directory + L"data\\flutter_assets\\" + relative;
}

// Returns the DPI scale factor of the monitor hosting |hwnd|.
double GetWindowScale(HWND hwnd) {
  UINT dpi = hwnd != nullptr ? ::GetDpiForWindow(hwnd) : 0;
  if (dpi == 0) {
    dpi = 96;
  }
  return static_cast<double>(dpi) / 96.0;
}

const char* SmtcButtonName(yunshu::SmtcButton button) {
  switch (button) {
    case yunshu::SmtcButton::kPlay:
      return "play";
    case yunshu::SmtcButton::kPause:
      return "pause";
    case yunshu::SmtcButton::kNext:
      return "next";
    case yunshu::SmtcButton::kPrevious:
      return "previous";
    case yunshu::SmtcButton::kStop:
      return "stop";
  }
  return "play";
}

yunshu::TaskbarProgressState TaskbarProgressStateFromString(
    const std::string& state) {
  if (state == "indeterminate") {
    return yunshu::TaskbarProgressState::kIndeterminate;
  }
  if (state == "normal") {
    return yunshu::TaskbarProgressState::kNormal;
  }
  if (state == "error") {
    return yunshu::TaskbarProgressState::kError;
  }
  if (state == "paused") {
    return yunshu::TaskbarProgressState::kPaused;
  }
  return yunshu::TaskbarProgressState::kNone;
}

const char* SmtcRepeatModeName(yunshu::SmtcRepeatMode mode) {
  switch (mode) {
    case yunshu::SmtcRepeatMode::kTrack:
      return "track";
    case yunshu::SmtcRepeatMode::kList:
      return "list";
    case yunshu::SmtcRepeatMode::kNone:
      return "none";
  }
  return "none";
}

class MusicChannelWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  explicit MusicChannelWindowsPlugin(flutter::PluginRegistrarWindows *registrar);

  virtual ~MusicChannelWindowsPlugin();

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void EnsureTrayInitialized();
  void EnsureSmtcInitialized();
  void InvokeOnPlatformThread(const char *method,
                              flutter::EncodableMap args);
  HWND GetMainWindow();

  flutter::PluginRegistrarWindows *registrar_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  yunshu::TrayIcon tray_;
  yunshu::SmtcController smtc_;
  yunshu::TaskbarProgress taskbar_;
  bool smtc_initialized_ = false;
  int window_proc_id_ = -1;

  // Minimum window size in logical pixels; enforced in WM_GETMINMAXINFO.
  POINT minimum_size_{0, 0};
};

// static
void MusicChannelWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<MusicChannelWindowsPlugin>(registrar);
  plugin->channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "music_channel_windows",
          &flutter::StandardMethodCodec::GetInstance());

  plugin->channel_->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));

  yunshu::FfmpegEngine::Instance()->Init(registrar);
}

MusicChannelWindowsPlugin::MusicChannelWindowsPlugin(
    flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {
  window_proc_id_ = registrar->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM wparam,
             LPARAM lparam) -> std::optional<LRESULT> {
        if (message == WM_GETMINMAXINFO && minimum_size_.x > 0 &&
            minimum_size_.y > 0) {
          auto *info = reinterpret_cast<MINMAXINFO *>(lparam);
          const double scale = GetWindowScale(hwnd);
          info->ptMinTrackSize.x =
              static_cast<LONG>(minimum_size_.x * scale);
          info->ptMinTrackSize.y =
              static_cast<LONG>(minimum_size_.y * scale);
          return 0;
        }
        return tray_.HandleWindowMessage(hwnd, message, wparam, lparam);
      });
}

MusicChannelWindowsPlugin::~MusicChannelWindowsPlugin() {
  tray_.Destroy();
  smtc_.Shutdown();
  if (registrar_ != nullptr && window_proc_id_ != -1) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }
  yunshu::FfmpegEngine::Instance()->Shutdown();
}

HWND MusicChannelWindowsPlugin::GetMainWindow() {
  if (registrar_ == nullptr) {
    return nullptr;
  }
  auto *view = registrar_->GetView();
  if (view == nullptr) {
    return nullptr;
  }
  return ::GetAncestor(view->GetNativeWindow(), GA_ROOT);
}

void MusicChannelWindowsPlugin::EnsureTrayInitialized() {
  if (tray_.has_window()) {
    return;
  }
  tray_.Initialize(
      GetMainWindow(),
      [this](int id) {
        if (channel_ == nullptr) {
          return;
        }
        flutter::EncodableMap args;
        args[flutter::EncodableValue("id")] = flutter::EncodableValue(id);
        channel_->InvokeMethod("onTrayMenuItemClick",
                               std::make_unique<flutter::EncodableValue>(args));
      },
      [this](bool right_button) {
        if (channel_ == nullptr) {
          return;
        }
        channel_->InvokeMethod(
            right_button ? "onTrayIconRightMouseDown" : "onTrayIconMouseDown",
            std::make_unique<flutter::EncodableValue>());
      });
}

void MusicChannelWindowsPlugin::InvokeOnPlatformThread(
    const char *method, flutter::EncodableMap args) {
  // SMTC callbacks arrive on an arbitrary WinRT thread; hop back to the
  // platform thread before touching the method channel.
  yunshu::PlatformTaskQueue::Instance().Post(
      [this, method = std::string(method), args = std::move(args)]() {
        if (channel_ == nullptr) {
          return;
        }
        channel_->InvokeMethod(method,
                               std::make_unique<flutter::EncodableValue>(args));
      });
}

void MusicChannelWindowsPlugin::EnsureSmtcInitialized() {
  if (smtc_initialized_) {
    return;
  }
  HWND hwnd = GetMainWindow();
  if (hwnd == nullptr) {
    return;
  }
  yunshu::SmtcCallbacks callbacks;
  callbacks.on_button = [this](yunshu::SmtcButton button) {
    flutter::EncodableMap args;
    args[flutter::EncodableValue("button")] =
        flutter::EncodableValue(SmtcButtonName(button));
    InvokeOnPlatformThread("onSmtcButton", std::move(args));
  };
  callbacks.on_position_change = [this](int64_t position_ms) {
    flutter::EncodableMap args;
    args[flutter::EncodableValue("position")] =
        flutter::EncodableValue(position_ms);
    InvokeOnPlatformThread("onSmtcSeek", std::move(args));
  };
  callbacks.on_shuffle_change = [this](bool enabled) {
    flutter::EncodableMap args;
    args[flutter::EncodableValue("enabled")] =
        flutter::EncodableValue(enabled);
    InvokeOnPlatformThread("onSmtcShuffle", std::move(args));
  };
  callbacks.on_repeat_change = [this](yunshu::SmtcRepeatMode mode) {
    flutter::EncodableMap args;
    args[flutter::EncodableValue("mode")] =
        flutter::EncodableValue(SmtcRepeatModeName(mode));
    InvokeOnPlatformThread("onSmtcRepeat", std::move(args));
  };
  smtc_.Initialize(hwnd, std::move(callbacks));
  smtc_initialized_ = true;
}

void MusicChannelWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string &method = method_call.method_name();

  if (method.compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else if (method.compare("traySetIcon") == 0) {
    EnsureTrayInitialized();
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    if (args != nullptr) {
      if (const auto *icon_path =
              std::get_if<std::string>(ValueOrNull(*args, "iconPath"))) {
        tray_.SetIcon(ResolveAssetPath(*icon_path));
      }
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("traySetToolTip") == 0) {
    EnsureTrayInitialized();
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    if (args != nullptr) {
      if (const auto *tool_tip =
              std::get_if<std::string>(ValueOrNull(*args, "toolTip"))) {
        tray_.SetToolTip(Utf8ToWide(*tool_tip));
      }
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("traySetContextMenu") == 0) {
    EnsureTrayInitialized();
    std::vector<yunshu::TrayMenuItem> menu_items;
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    if (args != nullptr) {
      if (const auto *items =
              std::get_if<flutter::EncodableList>(ValueOrNull(*args, "items"))) {
        for (const auto &value : *items) {
          const auto *item_map = std::get_if<flutter::EncodableMap>(&value);
          if (item_map == nullptr) {
            continue;
          }
          yunshu::TrayMenuItem item;
          item.id = GetInt(*item_map, "id");
          if (const auto *label =
                  std::get_if<std::string>(ValueOrNull(*item_map, "label"))) {
            item.label = Utf8ToWide(*label);
          }
          if (const auto *separator =
                  std::get_if<bool>(ValueOrNull(*item_map, "separator"))) {
            item.is_separator = *separator;
          }
          menu_items.push_back(std::move(item));
        }
      }
    }
    tray_.SetContextMenu(menu_items);
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("trayPopUpContextMenu") == 0) {
    EnsureTrayInitialized();
    tray_.PopUpContextMenu();
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("trayDestroy") == 0) {
    tray_.Destroy();
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("smtcInit") == 0) {
    EnsureSmtcInitialized();
    result->Success(flutter::EncodableValue(smtc_initialized_));
  } else if (method.compare("smtcSetMetadata") == 0) {
    EnsureSmtcInitialized();
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    if (args != nullptr) {
      const auto *title = std::get_if<std::string>(ValueOrNull(*args, "title"));
      const auto *artist =
          std::get_if<std::string>(ValueOrNull(*args, "artist"));
      smtc_.SetMetadata(title != nullptr ? Utf8ToWide(*title) : std::wstring(),
                        artist != nullptr ? Utf8ToWide(*artist)
                                          : std::wstring());
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("smtcSetCover") == 0) {
    EnsureSmtcInitialized();
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    if (args != nullptr) {
      if (const auto *bytes =
              std::get_if<std::vector<uint8_t>>(ValueOrNull(*args, "bytes"))) {
        smtc_.SetCover(*bytes);
      }
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("smtcSetPlaybackStatus") == 0) {
    EnsureSmtcInitialized();
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    if (args != nullptr) {
      if (const auto *status =
              std::get_if<std::string>(ValueOrNull(*args, "status"))) {
        smtc_.SetPlaybackStatus(*status);
      }
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("smtcSetTimeline") == 0) {
    EnsureSmtcInitialized();
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    if (args != nullptr) {
      smtc_.SetTimeline(GetInt64(*args, "position"), GetInt64(*args, "end"));
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("smtcSetPlayMode") == 0) {
    EnsureSmtcInitialized();
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    if (args != nullptr) {
      const auto *shuffle = std::get_if<bool>(ValueOrNull(*args, "shuffle"));
      const auto *repeat =
          std::get_if<std::string>(ValueOrNull(*args, "repeat"));
      yunshu::SmtcRepeatMode repeat_mode = yunshu::SmtcRepeatMode::kNone;
      if (repeat != nullptr) {
        if (*repeat == "track") {
          repeat_mode = yunshu::SmtcRepeatMode::kTrack;
        } else if (*repeat == "list") {
          repeat_mode = yunshu::SmtcRepeatMode::kList;
        }
      }
      smtc_.SetPlayMode(shuffle != nullptr && *shuffle, repeat_mode);
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("smtcDisable") == 0) {
    smtc_.SetEnabled(false);
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("taskbarSetProgress") == 0) {
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    if (args != nullptr) {
      const uint64_t completed =
          static_cast<uint64_t>(GetInt64(*args, "completed"));
      const uint64_t total = static_cast<uint64_t>(GetInt64(*args, "total"));
      taskbar_.SetProgress(GetMainWindow(), completed, total);
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("quit") == 0) {
    // Ask the runner to shut down gracefully (destroy window + WM_QUIT) instead
    // of hard-terminating the process.
    HWND hwnd = GetMainWindow();
    if (hwnd != nullptr) {
      ::PostMessageW(hwnd, ::RegisterWindowMessageW(L"yunshu_music.quit"), 0, 0);
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("taskbarSetProgressState") == 0) {
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    if (args != nullptr) {
      if (const auto *state =
              std::get_if<std::string>(ValueOrNull(*args, "state"))) {
        taskbar_.SetState(GetMainWindow(), TaskbarProgressStateFromString(*state));
      }
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("windowSetTitle") == 0) {
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    HWND hwnd = GetMainWindow();
    if (args != nullptr && hwnd != nullptr) {
      if (const auto *title =
              std::get_if<std::string>(ValueOrNull(*args, "title"))) {
        ::SetWindowTextW(hwnd, Utf8ToWide(*title).c_str());
      }
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("windowSetMinimumSize") == 0) {
    const auto *args = method_call.arguments()
                           ? std::get_if<flutter::EncodableMap>(
                                 method_call.arguments())
                           : nullptr;
    if (args != nullptr) {
      const double width = GetDouble(*args, "width");
      const double height = GetDouble(*args, "height");
      if (width > 0 && height > 0) {
        minimum_size_.x = static_cast<LONG>(width);
        minimum_size_.y = static_cast<LONG>(height);
      }
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("windowIsVisible") == 0) {
    HWND hwnd = GetMainWindow();
    result->Success(flutter::EncodableValue(hwnd != nullptr &&
                                            ::IsWindowVisible(hwnd) != FALSE));
  } else if (method.compare("windowShow") == 0) {
    HWND hwnd = GetMainWindow();
    if (hwnd != nullptr) {
      if (::IsIconic(hwnd)) {
        // SW_SHOW does not restore a minimized window.
        ::ShowWindow(hwnd, SW_RESTORE);
      } else {
        const LONG style = ::GetWindowLongW(hwnd, GWL_STYLE);
        if ((style & WS_VISIBLE) == 0) {
          ::SetWindowLongW(hwnd, GWL_STYLE, style | WS_VISIBLE);
          ::SetWindowPos(hwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE);
        }
        ::ShowWindowAsync(hwnd, SW_SHOW);
      }
      ::SetForegroundWindow(hwnd);
    }
    result->Success(flutter::EncodableValue(hwnd != nullptr));
  } else if (method.compare("windowIsMinimized") == 0) {
    HWND hwnd = GetMainWindow();
    result->Success(flutter::EncodableValue(hwnd != nullptr &&
                                            ::IsIconic(hwnd) != FALSE));
  } else if (method.compare("windowHide") == 0) {
    HWND hwnd = GetMainWindow();
    if (hwnd != nullptr) {
      ::ShowWindow(hwnd, SW_HIDE);
    }
    result->Success(flutter::EncodableValue(hwnd != nullptr));
  } else {
    result->NotImplemented();
  }
}

}  // namespace

void MusicChannelWindowsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  MusicChannelWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
