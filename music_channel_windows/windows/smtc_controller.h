#pragma once

#include <windows.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace yunshu {

enum class SmtcButton { kPlay, kPause, kNext, kPrevious, kStop };

enum class SmtcRepeatMode { kNone, kTrack, kList };

struct SmtcCallbacks {
  // Invoked for every media button press.
  std::function<void(SmtcButton)> on_button;
  // Invoked when the user drags the system progress bar.
  std::function<void(int64_t position_ms)> on_position_change;
  // Invoked when the user toggles the system shuffle button.
  std::function<void(bool enabled)> on_shuffle_change;
  // Invoked when the user cycles the system repeat button.
  std::function<void(SmtcRepeatMode mode)> on_repeat_change;
};

// Minimal wrapper around the Windows System Media Transport Controls (SMTC),
// implemented with C++/WinRT. Replaces the smtc_windows plugin on Windows.
// Callbacks fire on an arbitrary WinRT thread; the caller is responsible for
// marshalling to the platform thread.
class SmtcController {
 public:
  SmtcController();
  ~SmtcController();

  SmtcController(const SmtcController&) = delete;
  SmtcController& operator=(const SmtcController&) = delete;

  void Initialize(HWND hwnd, SmtcCallbacks callbacks);
  void SetEnabled(bool enabled);
  void SetMetadata(const std::wstring& title, const std::wstring& artist);
  void SetCover(const std::vector<uint8_t>& bytes);
  // |status| is one of "playing", "paused" or "stopped".
  void SetPlaybackStatus(const std::string& status);
  void SetTimeline(int64_t position_ms, int64_t end_ms);
  void SetPlayMode(bool shuffle, SmtcRepeatMode repeat_mode);
  void Shutdown();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace yunshu
