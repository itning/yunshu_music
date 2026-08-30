#pragma once

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>

#include "ffmpeg_decoder.h"
#include "platform_task_queue.h"
#include "ring_buffer.h"
#include "wasapi_output.h"

namespace yunshu {

class FfmpegEngine {
 public:
  static FfmpegEngine* Instance();

  bool Init(flutter::PluginRegistrarWindows* registrar);
  void Shutdown();
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetEventSink(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink);

 private:
  void Emit(flutter::EncodableMap event);
  void EmitState(bool playing);
  void SetSource(const std::string& url, bool autoplay);
  void OnDecoderPrepared(int64_t duration_ms);
  void OnDecoderError(const std::string& code, const std::string& message);
  void OnDecoderSeekDone();
  void OnAudioProgress(uint32_t position_ms, uint64_t played_frames);

  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  std::unique_ptr<RingBuffer> ring_;
  std::unique_ptr<WasapiOutput> output_;
  std::unique_ptr<FfmpegDecoder> decoder_;
  std::mutex decoder_mutex_;

  AudioTargetFormat target_{48000, 2};
  size_t block_align_ = 8;
  std::atomic<uint64_t> real_frames_fed_{0};
  std::atomic<bool> complete_emitted_{false};
  bool autoplay_source_ = false;
};

}  // namespace yunshu
