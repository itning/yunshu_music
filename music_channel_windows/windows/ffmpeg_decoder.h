#pragma once

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <thread>

#include "ring_buffer.h"

typedef struct AVFormatContext AVFormatContext;
typedef struct AVCodecContext AVCodecContext;
typedef struct SwrContext SwrContext;

namespace yunshu {

struct AudioTargetFormat {
  int sample_rate;
  int channels;
  int sample_format = 3;  // AV_SAMPLE_FMT_FLT
};

class FfmpegDecoder {
 public:
  struct Callbacks {
    std::function<void(int64_t duration_ms)> on_prepared;
    std::function<void(std::string code, std::string message)> on_error;
    std::function<void()> on_seek_done;
    std::function<void(uint32_t target_ms)> on_flush_output;
  };

  FfmpegDecoder(RingBuffer* ring, AudioTargetFormat target, Callbacks callbacks)
      : ring_(ring), target_(target), callbacks_(std::move(callbacks)) {}
  ~FfmpegDecoder();

  void Open(const std::string& url, bool start_paused);
  void Resume();
  void Pause();
  void Seek(int64_t target_ms);
  void Close();
  bool eof() const { return eof_.load(); }

 private:
  enum class State { kIdle, kPlaying, kPaused, kSeeking, kStopped };

  void Run(std::string url, bool start_paused);
  bool Prepare(const std::string& url);
  void DecodeLoop();
  void DoSeek(int64_t target_ms);
  static int InterruptCb(void* opaque);

  RingBuffer* ring_;
  AudioTargetFormat target_;
  Callbacks callbacks_;

  std::thread thread_;
  std::mutex mutex_;
  std::condition_variable cv_;
  State state_ = State::kIdle;
  int64_t pending_seek_ms_ = -1;
  bool resume_after_seek_ = true;
  std::atomic<bool> eof_{false};
  std::atomic<bool> abort_{false};

  AVFormatContext* fmt_ = nullptr;
  AVCodecContext* codec_ = nullptr;
  SwrContext* swr_ = nullptr;
  int stream_index_ = -1;
  uint8_t* swr_buffer_ = nullptr;
  size_t swr_buffer_size_ = 0;
};

}  // namespace yunshu
