#pragma once

#include <windows.h>

#include <functional>
#include <optional>
#include <set>
#include <string>
#include <vector>

namespace yunshu {

struct TrayMenuItem {
  int id = 0;
  std::wstring label;
  bool is_separator = false;
};

// Minimal Win32 system tray implementation based on Shell_NotifyIcon.
// Replaces the tray_manager plugin on Windows.
class TrayIcon {
 public:
  using MenuClickCallback = std::function<void(int id)>;
  using MouseCallback = std::function<void(bool right_button)>;

  TrayIcon() = default;
  ~TrayIcon();

  TrayIcon(const TrayIcon&) = delete;
  TrayIcon& operator=(const TrayIcon&) = delete;

  void Initialize(HWND hwnd, MenuClickCallback on_menu_click,
                  MouseCallback on_mouse);

  bool has_window() const { return hwnd_ != nullptr; }

  bool SetIcon(const std::wstring& icon_path);
  bool SetToolTip(const std::wstring& tool_tip);
  void SetContextMenu(const std::vector<TrayMenuItem>& items);
  void PopUpContextMenu();
  void Destroy();

  // Hook for the Flutter top-level window proc delegate.
  std::optional<LRESULT> HandleWindowMessage(HWND hwnd, UINT message,
                                             WPARAM wparam, LPARAM lparam);

 private:
  static constexpr UINT kCallbackMessage = WM_APP + 1;
  static constexpr UINT kIconId = 1;

  void ApplyIcon();

  HWND hwnd_ = nullptr;
  NOTIFYICONDATAW nid_{};
  HMENU menu_ = nullptr;
  HICON icon_ = nullptr;
  bool icon_owned_ = false;
  bool icon_set_ = false;
  UINT taskbar_created_message_ = 0;
  std::set<int> menu_ids_;

  MenuClickCallback on_menu_click_;
  MouseCallback on_mouse_;
};

}  // namespace yunshu
