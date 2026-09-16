#include "tray_icon.h"

#include <shellapi.h>

namespace yunshu {

TrayIcon::~TrayIcon() { Destroy(); }

void TrayIcon::Initialize(HWND hwnd, MenuClickCallback on_menu_click,
                          MouseCallback on_mouse) {
  hwnd_ = hwnd;
  on_menu_click_ = std::move(on_menu_click);
  on_mouse_ = std::move(on_mouse);
  taskbar_created_message_ = RegisterWindowMessageW(L"TaskbarCreated");
}

bool TrayIcon::SetIcon(const std::wstring& icon_path) {
  HICON icon = static_cast<HICON>(LoadImageW(
      nullptr, icon_path.c_str(), IMAGE_ICON, GetSystemMetrics(SM_CXSMICON),
      GetSystemMetrics(SM_CYSMICON), LR_LOADFROMFILE));
  bool owned = icon != nullptr;
  if (icon == nullptr) {
    icon = LoadIconW(nullptr, IDI_APPLICATION);
  }

  if (icon_owned_ && icon_ != nullptr) {
    DestroyIcon(icon_);
  }
  icon_ = icon;
  icon_owned_ = owned;

  ApplyIcon();
  return icon_ != nullptr;
}

bool TrayIcon::SetToolTip(const std::wstring& tool_tip) {
  wcsncpy_s(nid_.szTip, tool_tip.c_str(), _TRUNCATE);
  if (!icon_set_) {
    return true;
  }
  nid_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  return Shell_NotifyIconW(NIM_MODIFY, &nid_) != FALSE;
}

void TrayIcon::SetContextMenu(const std::vector<TrayMenuItem>& items) {
  if (menu_ == nullptr) {
    menu_ = CreatePopupMenu();
  }
  while (GetMenuItemCount(menu_) > 0) {
    RemoveMenu(menu_, 0, MF_BYPOSITION);
  }
  menu_ids_.clear();

  for (const auto& item : items) {
    if (item.is_separator) {
      AppendMenuW(menu_, MF_SEPARATOR, 0, nullptr);
    } else {
      AppendMenuW(menu_, MF_STRING, static_cast<UINT_PTR>(item.id),
                  item.label.c_str());
      menu_ids_.insert(item.id);
    }
  }
}

void TrayIcon::PopUpContextMenu() {
  if (hwnd_ == nullptr || menu_ == nullptr) {
    return;
  }
  POINT cursor;
  GetCursorPos(&cursor);
  SetForegroundWindow(hwnd_);
  TrackPopupMenu(menu_, TPM_BOTTOMALIGN | TPM_LEFTALIGN, cursor.x, cursor.y, 0,
                 hwnd_, nullptr);
  // Required so the menu is dismissed when clicking elsewhere.
  PostMessageW(hwnd_, WM_NULL, 0, 0);
}

void TrayIcon::Destroy() {
  if (icon_set_) {
    Shell_NotifyIconW(NIM_DELETE, &nid_);
    icon_set_ = false;
  }
  if (icon_owned_ && icon_ != nullptr) {
    DestroyIcon(icon_);
  }
  icon_ = nullptr;
  icon_owned_ = false;
  if (menu_ != nullptr) {
    DestroyMenu(menu_);
    menu_ = nullptr;
  }
  menu_ids_.clear();
}

void TrayIcon::ApplyIcon() {
  if (hwnd_ == nullptr || icon_ == nullptr) {
    return;
  }

  nid_.cbSize = sizeof(NOTIFYICONDATAW);
  nid_.hWnd = hwnd_;
  nid_.uID = kIconId;
  nid_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  nid_.uCallbackMessage = kCallbackMessage;
  nid_.hIcon = icon_;

  if (icon_set_) {
    Shell_NotifyIconW(NIM_MODIFY, &nid_);
  } else {
    Shell_NotifyIconW(NIM_ADD, &nid_);
    icon_set_ = true;
  }
}

std::optional<LRESULT> TrayIcon::HandleWindowMessage(HWND hwnd, UINT message,
                                                     WPARAM wparam,
                                                     LPARAM lparam) {
  if (message == WM_COMMAND && HIWORD(wparam) == 0 && lparam == 0) {
    int id = static_cast<int>(LOWORD(wparam));
    if (menu_ids_.count(id) > 0) {
      if (on_menu_click_) {
        on_menu_click_(id);
      }
      return 0;
    }
  } else if (message == kCallbackMessage) {
    switch (LOWORD(lparam)) {
      case WM_LBUTTONUP:
        if (on_mouse_) {
          on_mouse_(false);
        }
        return 0;
      case WM_RBUTTONUP:
        if (on_mouse_) {
          on_mouse_(true);
        }
        return 0;
      default:
        break;
    }
  } else if (taskbar_created_message_ != 0 &&
             message == taskbar_created_message_) {
    if (icon_set_) {
      icon_set_ = false;
      ApplyIcon();
    }
  } else if (message == WM_POWERBROADCAST) {
    if (wparam == PBT_APMRESUMEAUTOMATIC || wparam == PBT_APMRESUMESUSPEND) {
      if (icon_set_) {
        icon_set_ = false;
        ApplyIcon();
      }
    }
  }
  return std::nullopt;
}

}  // namespace yunshu
