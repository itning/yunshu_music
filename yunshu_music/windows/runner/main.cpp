#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <appmodel.h>
#include <knownfolders.h>
#include <propidl.h>
#include <propkey.h>
#include <shlobj.h>
#include <shobjidl_core.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Name of the mutex that guards against multiple running instances.
constexpr wchar_t kSingleInstanceMutexName[] = L"yunshu_music.instance.mutex";

// Message broadcast by a secondary instance to ask the running instance to
// bring its window to the foreground. See flutter_window.cpp.
constexpr wchar_t kActivateMessageName[] = L"yunshu_music.activate";

// AppUserModelID and display name shown by Windows (taskbar, notifications and
// the media controls). Matches the MSIX identity_name.
constexpr wchar_t kAppUserModelId[] = L"top.itning.yunshumusic";
constexpr wchar_t kAppDisplayName[] = L"\u4E91\u8212\u97F3\u4E50";

bool RegistryStringMatches(HKEY key, const wchar_t* name,
                           const std::wstring& expected) {
  DWORD type = 0;
  DWORD size = 0;
  if (::RegQueryValueExW(key, name, nullptr, &type, nullptr, &size) !=
          ERROR_SUCCESS ||
      type != REG_SZ) {
    return false;
  }
  std::wstring value(size / sizeof(wchar_t), L'\0');
  if (::RegQueryValueExW(key, name, nullptr, nullptr,
                         reinterpret_cast<BYTE*>(value.data()),
                         &size) != ERROR_SUCCESS) {
    return false;
  }
  while (!value.empty() && value.back() == L'\0') {
    value.pop_back();
  }
  return value == expected;
}

void WriteRegistryString(HKEY key, const wchar_t* name,
                         const std::wstring& value) {
  if (RegistryStringMatches(key, name, value)) {
    return;
  }
  ::RegSetValueExW(key, name, 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(value.c_str()),
                   static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
}

// Unpackaged Win32 apps have no package identity, so Windows shows "Unknown
// app" in the media controls unless the AppUserModelID is registered under
// HKCU. The packaged (MSIX) build gets its name from the package manifest.
void RegisterAppUserModelId() {
  ::SetCurrentProcessExplicitAppUserModelID(kAppUserModelId);

  wchar_t exe_path[MAX_PATH] = {0};
  DWORD length = ::GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  std::wstring directory(exe_path, length);
  const size_t slash = directory.find_last_of(L"\\/");
  if (slash != std::wstring::npos) {
    directory = directory.substr(0, slash + 1);
  }
  const std::wstring icon_uri =
      directory + L"data\\flutter_assets\\asserts\\icon\\app_icon.ico";

  const std::wstring key_path =
      std::wstring(L"Software\\Classes\\AppUserModelId\\") + kAppUserModelId;
  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, key_path.c_str(), 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr, &key,
                        nullptr) != ERROR_SUCCESS) {
    return;
  }
  WriteRegistryString(key, L"DisplayName", kAppDisplayName);
  WriteRegistryString(key, L"IconUri", icon_uri);
  ::RegCloseKey(key);
}

bool IsRunningPackaged() {
  UINT32 length = 0;
  const LONG result = ::GetCurrentPackageFullName(&length, nullptr);
  return result != APPMODEL_ERROR_NO_PACKAGE;
}

bool ShortcutPointsTo(const std::wstring& shortcut_path,
                      const std::wstring& exe_path) {
  if (::GetFileAttributesW(shortcut_path.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return false;
  }
  IShellLinkW* link = nullptr;
  if (FAILED(::CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&link)))) {
    return false;
  }
  bool matches = false;
  IPersistFile* file = nullptr;
  if (SUCCEEDED(link->QueryInterface(IID_PPV_ARGS(&file)))) {
    if (SUCCEEDED(file->Load(shortcut_path.c_str(), STGM_READ))) {
      wchar_t target[MAX_PATH] = {0};
      if (SUCCEEDED(link->GetPath(target, MAX_PATH, nullptr, SLGP_UNCPRIORITY))) {
        matches = (_wcsicmp(target, exe_path.c_str()) == 0);
      }
    }
    file->Release();
  }
  link->Release();
  return matches;
}

// Windows SMTC resolves an AppUserModelID to a display name through a Start
// Menu shortcut (or an MSIX package identity). Unpackaged builds have neither,
// so create the shortcut ourselves; packaged builds are left to the OS.
void EnsureStartMenuShortcut() {
  if (IsRunningPackaged()) {
    return;
  }

  wchar_t exe_path[MAX_PATH] = {0};
  if (::GetModuleFileNameW(nullptr, exe_path, MAX_PATH) == 0) {
    return;
  }

  PWSTR programs_path = nullptr;
  if (FAILED(::SHGetKnownFolderPath(FOLDERID_Programs, KF_FLAG_DEFAULT, nullptr,
                                    &programs_path))) {
    return;
  }
  const std::wstring shortcut_path =
      std::wstring(programs_path) + L"\\" + kAppDisplayName + L".lnk";
  ::CoTaskMemFree(programs_path);

  if (ShortcutPointsTo(shortcut_path, exe_path)) {
    return;
  }

  IShellLinkW* shell_link = nullptr;
  if (FAILED(::CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&shell_link)))) {
    return;
  }
  shell_link->SetPath(exe_path);
  shell_link->SetDescription(kAppDisplayName);

  std::wstring directory(exe_path);
  const size_t slash = directory.find_last_of(L"\\/");
  if (slash != std::wstring::npos) {
    directory = directory.substr(0, slash + 1);
  }
  const std::wstring icon_path =
      directory + L"data\\flutter_assets\\asserts\\icon\\app_icon.ico";
  if (::GetFileAttributesW(icon_path.c_str()) != INVALID_FILE_ATTRIBUTES) {
    shell_link->SetIconLocation(icon_path.c_str(), 0);
  }

  IPropertyStore* store = nullptr;
  if (SUCCEEDED(shell_link->QueryInterface(IID_PPV_ARGS(&store)))) {
    PROPVARIANT value;
    ::PropVariantInit(&value);
    value.vt = VT_LPWSTR;
    value.pwszVal = const_cast<LPWSTR>(kAppUserModelId);
    store->SetValue(PKEY_AppUserModel_ID, value);
    store->Commit();
    store->Release();
  }

  IPersistFile* file = nullptr;
  if (SUCCEEDED(shell_link->QueryInterface(IID_PPV_ARGS(&file)))) {
    file->Save(shortcut_path.c_str(), TRUE);
    file->Release();
  }
  shell_link->Release();
}

// Default window size, in logical pixels.
constexpr int kDefaultWindowWidth = 1200;
constexpr int kDefaultWindowHeight = 900;

// Computes a logical-pixel origin that centers a |width| x |height| window
// within the primary monitor's work area, accounting for DPI scaling.
// Win32Window::CreateAndShow scales the origin back to physical pixels.
Win32Window::Point CenteredOrigin(int width, int height) {
  HMONITOR monitor = ::MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);
  RECT work_area{0, 0, ::GetSystemMetrics(SM_CXSCREEN),
                 ::GetSystemMetrics(SM_CYSCREEN)};
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  if (monitor != nullptr && ::GetMonitorInfoW(monitor, &monitor_info)) {
    work_area = monitor_info.rcWork;
  }

  double scale = 1.0;
  if (monitor != nullptr) {
    scale = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
  }
  if (scale <= 0.0) {
    scale = 1.0;
  }

  // rcWork is in physical pixels; convert to logical before centering.
  const int work_left = static_cast<int>(work_area.left / scale);
  const int work_top = static_cast<int>(work_area.top / scale);
  const int work_width =
      static_cast<int>((work_area.right - work_area.left) / scale);
  const int work_height =
      static_cast<int>((work_area.bottom - work_area.top) / scale);

  int x = work_left + (work_width - width) / 2;
  int y = work_top + (work_height - height) / 2;
  if (x < work_left) {
    x = work_left;
  }
  if (y < work_top) {
    y = work_top;
  }
  return Win32Window::Point(static_cast<unsigned int>(x),
                            static_cast<unsigned int>(y));
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Ensure only a single instance runs. If the mutex already exists, signal the
  // running instance to come to the foreground and exit immediately.
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
  if (instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::CloseHandle(instance_mutex);
    ::PostMessage(HWND_BROADCAST,
                  ::RegisterWindowMessageW(kActivateMessageName), 0, 0);
    return EXIT_SUCCESS;
  }

  RegisterAppUserModelId();

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  EnsureStartMenuShortcut();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  Win32Window::Size size(kDefaultWindowWidth, kDefaultWindowHeight);
  Win32Window::Point origin =
      CenteredOrigin(kDefaultWindowWidth, kDefaultWindowHeight);

  if (!window.CreateAndShow(L"Loading...", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
