#pragma once

#include <windows.h>

#include <deque>
#include <functional>
#include <mutex>

namespace yunshu {

class PlatformTaskQueue {
 public:
  static PlatformTaskQueue& Instance() {
    static PlatformTaskQueue instance;
    return instance;
  }

  bool Start() {
    if (hwnd_ != nullptr) {
      return true;
    }
    WNDCLASS wc = {};
    wc.lpfnWndProc = &PlatformTaskQueue::WndProc;
    wc.hInstance = GetModuleHandle(nullptr);
    wc.lpszClassName = L"yunshu_platform_task_queue";
    RegisterClass(&wc);
    hwnd_ = CreateWindowEx(0, wc.lpszClassName, L"", 0, 0, 0, 0, 0,
                           HWND_MESSAGE, nullptr, wc.hInstance, nullptr);
    return hwnd_ != nullptr;
  }

  void Shutdown() {
    if (hwnd_ != nullptr) {
      DestroyWindow(hwnd_);
      hwnd_ = nullptr;
    }
    Drain();
  }

  void Post(std::function<void()> task) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      tasks_.push_back(std::move(task));
    }
    if (hwnd_ != nullptr) {
      PostMessage(hwnd_, kDrainMsg, 0, 0);
    }
  }

 private:
  static constexpr UINT kDrainMsg = WM_APP + 0x1F;

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == kDrainMsg) {
      Instance().Drain();
      return 0;
    }
    return DefWindowProc(hwnd, msg, wp, lp);
  }

  void Drain() {
    std::deque<std::function<void()>> local;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      local.swap(tasks_);
    }
    for (auto& task : local) {
      task();
    }
  }

  std::mutex mutex_;
  std::deque<std::function<void()>> tasks_;
  HWND hwnd_ = nullptr;
};

}  // namespace yunshu
