#include "taskbar_progress.h"

namespace yunshu {

namespace {

// CLSID_TaskbarList, defined inline to avoid a uuid.lib dependency.
const CLSID kTaskbarListClsid = {
    0x56FDF344, 0xFD6D, 0x11D0, {0x95, 0x8A, 0x00, 0x60, 0x97, 0xC9, 0xA0, 0x90}};

TBPFLAG ToTbpf(TaskbarProgressState state) {
  switch (state) {
    case TaskbarProgressState::kIndeterminate:
      return TBPF_INDETERMINATE;
    case TaskbarProgressState::kNormal:
      return TBPF_NORMAL;
    case TaskbarProgressState::kError:
      return TBPF_ERROR;
    case TaskbarProgressState::kPaused:
      return TBPF_PAUSED;
    case TaskbarProgressState::kNone:
    default:
      return TBPF_NOPROGRESS;
  }
}

}  // namespace

TaskbarProgress::TaskbarProgress() {
  if (FAILED(::CoCreateInstance(kTaskbarListClsid, nullptr, CLSCTX_INPROC_SERVER,
                                __uuidof(ITaskbarList3),
                                reinterpret_cast<void**>(&taskbar_)))) {
    taskbar_ = nullptr;
    return;
  }
  if (FAILED(taskbar_->HrInit())) {
    taskbar_->Release();
    taskbar_ = nullptr;
  }
}

TaskbarProgress::~TaskbarProgress() {
  if (taskbar_ != nullptr) {
    taskbar_->Release();
    taskbar_ = nullptr;
  }
}

bool TaskbarProgress::SetProgress(HWND hwnd, uint64_t completed,
                                  uint64_t total) {
  if (taskbar_ == nullptr || hwnd == nullptr) {
    return false;
  }
  return SUCCEEDED(taskbar_->SetProgressValue(hwnd, completed, total));
}

bool TaskbarProgress::SetState(HWND hwnd, TaskbarProgressState state) {
  if (taskbar_ == nullptr || hwnd == nullptr) {
    return false;
  }
  return SUCCEEDED(taskbar_->SetProgressState(hwnd, ToTbpf(state)));
}

}  // namespace yunshu
