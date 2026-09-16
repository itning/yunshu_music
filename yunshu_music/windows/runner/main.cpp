#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Name of the mutex that guards against multiple running instances.
constexpr wchar_t kSingleInstanceMutexName[] = L"yunshu_music.instance.mutex";

// Message broadcast by a secondary instance to ask the running instance to
// bring its window to the foreground. See flutter_window.cpp.
constexpr wchar_t kActivateMessageName[] = L"yunshu_music.activate";

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

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

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
