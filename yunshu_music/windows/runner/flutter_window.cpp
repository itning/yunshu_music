#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Must match the name used in main.cpp.
constexpr wchar_t kActivateMessageName[] = L"yunshu_music.activate";

// Returns the registered message id broadcast by a secondary instance.
UINT GetActivateMessage() {
  static const UINT message = ::RegisterWindowMessageW(kActivateMessageName);
  return message;
}

// Restores, shows and foregrounds |window|, even when it is hidden to the tray.
void BringWindowToFront(HWND window) {
  if (window == nullptr) {
    return;
  }

  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  } else {
    ::ShowWindow(window, SW_SHOW);
  }

  // Attach to the foreground thread so the foreground request is honored.
  HWND foreground = ::GetForegroundWindow();
  DWORD foreground_thread =
      foreground ? ::GetWindowThreadProcessId(foreground, nullptr) : 0;
  DWORD current_thread = ::GetCurrentThreadId();
  if (foreground_thread != 0 && foreground_thread != current_thread) {
    ::AttachThreadInput(foreground_thread, current_thread, TRUE);
    ::SetForegroundWindow(window);
    ::AttachThreadInput(foreground_thread, current_thread, FALSE);
  } else {
    ::SetForegroundWindow(window);
  }
  ::SetFocus(window);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // A secondary instance was launched; show this instance instead.
  const UINT activate_message = GetActivateMessage();
  if (activate_message != 0 && message == activate_message) {
    BringWindowToFront(hwnd);
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_CLOSE:
      ShowWindow(GetHandle(), SW_HIDE);
      return 0;
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
