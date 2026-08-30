#pragma once

#include <windows.h>
#include <audioclient.h>
#include <mmdeviceapi.h>

#include <atomic>
#include <chrono>
#include <cstdint>
#include <functional>
#include <thread>

namespace yunshu {

class WasapiOutput {
 public:
  using Filler = std::function<size_t(uint8_t* dst, size_t bytes)>;
  using ProgressCb =
      std::function<void(uint32_t position_ms, uint64_t played_frames)>;

  bool Start(Filler filler, ProgressCb on_progress);
  void Stop();
  void Pause();
  void Resume();
  void Flush(uint32_t new_position_ms);
  bool SetVolume(float volume);

  int sample_rate() const { return sample_rate_.load(); }
  int channels() const { return channels_.load(); }

 private:
  void RenderLoop();

  std::atomic<bool> running_{false};
  std::atomic<bool> paused_{true};
  std::thread thread_;
  HANDLE event_ = nullptr;

  IAudioClient* client_ = nullptr;
  IAudioRenderClient* render_ = nullptr;
  ISimpleAudioVolume* simple_volume_ = nullptr;

  UINT32 buffer_frames_ = 0;
  std::atomic<int> sample_rate_{48000};
  std::atomic<int> channels_{2};
  std::atomic<uint32_t> block_align_{8};
  std::atomic<uint64_t> submitted_frames_{0};

  Filler filler_;
  ProgressCb on_progress_;
};

}  // namespace yunshu
