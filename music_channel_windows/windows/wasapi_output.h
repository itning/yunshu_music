#pragma once

#include <windows.h>
#include <audioclient.h>
#include <mmdeviceapi.h>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <mutex>
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
  int sample_format() const { return sample_format_.load(); }
  uint32_t block_align() const { return block_align_.load(); }

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
  std::atomic<int> sample_format_{3};  // AV_SAMPLE_FMT_FLT
  std::atomic<uint32_t> block_align_{8};
  std::atomic<uint64_t> submitted_frames_{0};

  std::mutex init_mutex_;
  std::condition_variable init_cv_;
  bool init_done_ = false;
  bool initialized_ = false;

  Filler filler_;
  ProgressCb on_progress_;
};

}  // namespace yunshu
