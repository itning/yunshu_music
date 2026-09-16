#pragma once

#include <windows.h>

#include <shobjidl_core.h>

#include <cstdint>

namespace yunshu {

enum class TaskbarProgressState {
  kNone,
  kIndeterminate,
  kNormal,
  kError,
  kPaused,
};

// Thin wrapper around ITaskbarList3 for the taskbar button progress indicator.
// Replaces the windows_taskbar plugin on Windows.
class TaskbarProgress {
 public:
  TaskbarProgress();
  ~TaskbarProgress();

  TaskbarProgress(const TaskbarProgress&) = delete;
  TaskbarProgress& operator=(const TaskbarProgress&) = delete;

  bool SetProgress(HWND hwnd, uint64_t completed, uint64_t total);
  bool SetState(HWND hwnd, TaskbarProgressState state);

 private:
  ITaskbarList3* taskbar_ = nullptr;
};

}  // namespace yunshu
