#pragma once

#include <windows.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace yunshu {

enum class SmtcButton { kPlay, kPause, kNext, kPrevious, kStop };

// Minimal wrapper around the Windows System Media Transport Controls (SMTC),
// implemented with C++/WinRT. Replaces the smtc_windows plugin on Windows.
class SmtcController {
 public:
  // Invoked for every media button press (on an arbitrary WinRT thread; the
  // caller is responsible for marshalling to the platform thread).
  using ButtonCallback = std::function<void(SmtcButton)>;

  SmtcController();
  ~SmtcController();

  SmtcController(const SmtcController&) = delete;
  SmtcController& operator=(const SmtcController&) = delete;

  void Initialize(HWND hwnd, ButtonCallback on_button);
  void SetEnabled(bool enabled);
  void SetMetadata(const std::wstring& title, const std::wstring& artist);
  void SetCover(const std::vector<uint8_t>& bytes);
  // |status| is one of "playing", "paused" or "stopped".
  void SetPlaybackStatus(const std::string& status);
  void SetTimeline(int64_t position_ms, int64_t end_ms);
  void Shutdown();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace yunshu
