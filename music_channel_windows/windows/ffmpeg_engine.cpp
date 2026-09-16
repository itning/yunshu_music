#include "ffmpeg_engine.h"

#include <flutter/standard_method_codec.h>

extern "C" {
#include <libavformat/avformat.h>
#include <libavutil/samplefmt.h>
}

namespace yunshu {

namespace {

class EngineStreamHandler
    : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  explicit EngineStreamHandler(FfmpegEngine* engine) : engine_(engine) {}

 protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
  OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
      override {
    engine_->SetEventSink(std::move(events));
    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
  OnCancelInternal(const flutter::EncodableValue* arguments) override {
    engine_->SetEventSink(nullptr);
    return nullptr;
  }

 private:
  FfmpegEngine* engine_;
};

std::string GetStr(const flutter::EncodableValue* args, const char* key) {
  if (args == nullptr) {
    return {};
  }
  const auto* map = std::get_if<flutter::EncodableMap>(args);
  if (map == nullptr) {
    return {};
  }
  auto it = map->find(flutter::EncodableValue(key));
  if (it == map->end()) {
    return {};
  }
  const auto* s = std::get_if<std::string>(&it->second);
  return s != nullptr ? *s : std::string();
}

int64_t GetInt(const flutter::EncodableValue* args, const char* key,
               int64_t fallback) {
  if (args == nullptr) {
    return fallback;
  }
  const auto* map = std::get_if<flutter::EncodableMap>(args);
  if (map == nullptr) {
    return fallback;
  }
  auto it = map->find(flutter::EncodableValue(key));
  if (it == map->end()) {
    return fallback;
  }
  if (const auto* i = std::get_if<int32_t>(&it->second)) {
    return *i;
  }
  if (const auto* l = std::get_if<int64_t>(&it->second)) {
    return *l;
  }
  return fallback;
}

double GetDouble(const flutter::EncodableValue* args, const char* key,
                 double fallback) {
  if (args == nullptr) {
    return fallback;
  }
  const auto* map = std::get_if<flutter::EncodableMap>(args);
  if (map == nullptr) {
    return fallback;
  }
  auto it = map->find(flutter::EncodableValue(key));
  if (it == map->end()) {
    return fallback;
  }
  if (const auto* d = std::get_if<double>(&it->second)) {
    return *d;
  }
  return fallback;
}

}  // namespace

FfmpegEngine* FfmpegEngine::Instance() {
  static FfmpegEngine engine;
  return &engine;
}

bool FfmpegEngine::Init(flutter::PluginRegistrarWindows* registrar) {
  if (registrar_ != nullptr) {
    return true;
  }
  if (!PlatformTaskQueue::Instance().Start()) {
    return false;
  }
  avformat_network_init();
  registrar_ = registrar;

  method_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "music_channel_windows/audio",
          &flutter::StandardMethodCodec::GetInstance());
  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "music_channel_windows/audio/events",
          &flutter::StandardMethodCodec::GetInstance());
  event_channel_->SetStreamHandler(
      std::make_unique<EngineStreamHandler>(this));

  output_ = std::make_unique<WasapiOutput>();
  auto filler = [this](uint8_t* dst, size_t bytes) -> size_t {
    size_t got = ring_->Read(dst, bytes);
    if (got > 0 && block_align_ > 0) {
      real_frames_fed_ += got / block_align_;
    }
    return got;
  };
  auto progress = [this](uint32_t pos_ms, uint64_t played) {
    OnAudioProgress(pos_ms, played);
  };
  if (!output_->Start(filler, progress)) {
    return false;
  }
  target_ = {output_->sample_rate(), output_->channels(),
             output_->sample_format()};
  int bytes_per_sample = av_get_bytes_per_sample(
      static_cast<AVSampleFormat>(target_.sample_format));
  if (bytes_per_sample <= 0) {
    bytes_per_sample = static_cast<int>(sizeof(float));
    target_.sample_format = AV_SAMPLE_FMT_FLT;
  }
  block_align_ = static_cast<size_t>(target_.channels) * bytes_per_sample;
  ring_ = std::make_unique<RingBuffer>(
      static_cast<size_t>(target_.sample_rate) * block_align_ / 2);
  return true;
}

void FfmpegEngine::Shutdown() {
  if (registrar_ == nullptr) {
    return;
  }
  {
    std::lock_guard<std::mutex> lock(decoder_mutex_);
    if (decoder_) {
      decoder_->Close();
      decoder_.reset();
    }
  }
  if (output_) {
    output_->Stop();
  }
  event_sink_.reset();
  event_channel_.reset();
  method_channel_.reset();
  PlatformTaskQueue::Instance().Shutdown();
  registrar_ = nullptr;
}

void FfmpegEngine::SetEventSink(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink) {
  event_sink_ = std::move(sink);
}

void FfmpegEngine::Emit(flutter::EncodableMap event) {
  PlatformTaskQueue::Instance().Post([this, event]() {
    if (event_sink_) {
      event_sink_->Success(flutter::EncodableValue(event));
    }
  });
}

void FfmpegEngine::EmitState(bool playing) {
  flutter::EncodableMap e;
  e[flutter::EncodableValue("event")] = flutter::EncodableValue("state");
  e[flutter::EncodableValue("playing")] = flutter::EncodableValue(playing);
  Emit(std::move(e));
}

void FfmpegEngine::SetSource(const std::string& url, bool autoplay) {
  std::lock_guard<std::mutex> lock(decoder_mutex_);
  if (decoder_) {
    decoder_->Close();
    decoder_.reset();
  }
  ring_->ResetAbort();
  ring_->Clear();
  complete_emitted_ = false;
  real_frames_fed_ = 0;
  autoplay_source_ = autoplay;
  if (output_) {
    output_->Flush(0);
  }

  FfmpegDecoder::Callbacks cbs;
  cbs.on_prepared = [this](int64_t duration_ms) {
    PlatformTaskQueue::Instance().Post(
        [this, duration_ms] { OnDecoderPrepared(duration_ms); });
  };
  cbs.on_error = [this](std::string code, std::string message) {
    PlatformTaskQueue::Instance().Post(
        [this, code, message] { OnDecoderError(code, message); });
  };
  cbs.on_seek_done = [this]() {
    PlatformTaskQueue::Instance().Post([this] { OnDecoderSeekDone(); });
  };
  cbs.on_flush_output = [this](uint32_t target_ms) {
    if (output_) {
      output_->Flush(target_ms);
    }
  };
  decoder_ = std::make_unique<FfmpegDecoder>(ring_.get(), target_,
                                             std::move(cbs));
  decoder_->Open(url, !autoplay);
  if (autoplay) {
    output_->Resume();
  }
}

void FfmpegEngine::OnDecoderPrepared(int64_t duration_ms) {
  flutter::EncodableMap e;
  e[flutter::EncodableValue("event")] = flutter::EncodableValue("prepared");
  e[flutter::EncodableValue("durationMs")] =
      duration_ms < 0 ? flutter::EncodableValue()
                      : flutter::EncodableValue(duration_ms);
  Emit(std::move(e));
  EmitState(autoplay_source_);
}

void FfmpegEngine::OnDecoderError(const std::string& code,
                                  const std::string& message) {
  flutter::EncodableMap e;
  e[flutter::EncodableValue("event")] = flutter::EncodableValue("error");
  e[flutter::EncodableValue("code")] = flutter::EncodableValue(code);
  e[flutter::EncodableValue("message")] = flutter::EncodableValue(message);
  Emit(std::move(e));
}

void FfmpegEngine::OnDecoderSeekDone() {
  real_frames_fed_ = 0;
  complete_emitted_ = false;
  flutter::EncodableMap e;
  e[flutter::EncodableValue("event")] =
      flutter::EncodableValue("seekComplete");
  Emit(std::move(e));
}

void FfmpegEngine::OnAudioProgress(uint32_t position_ms,
                                   uint64_t played_frames) {
  flutter::EncodableMap e;
  e[flutter::EncodableValue("event")] = flutter::EncodableValue("position");
  e[flutter::EncodableValue("positionMs")] =
      flutter::EncodableValue(static_cast<int64_t>(position_ms));
  Emit(std::move(e));

  std::lock_guard<std::mutex> lock(decoder_mutex_);
  if (!complete_emitted_ && decoder_ && decoder_->eof() &&
      ring_->Size() == 0 && real_frames_fed_ > 0 &&
      played_frames >= real_frames_fed_.load()) {
    complete_emitted_ = true;
    flutter::EncodableMap c;
    c[flutter::EncodableValue("event")] = flutter::EncodableValue("complete");
    Emit(std::move(c));
  }
}

void FfmpegEngine::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& name = call.method_name();
  const flutter::EncodableValue* args = call.arguments();

  if (name == "setSource") {
    SetSource(GetStr(args, "url"), false);
    result->Success();
  } else if (name == "play") {
    SetSource(GetStr(args, "url"), true);
    result->Success();
  } else if (name == "resume") {
    {
      std::lock_guard<std::mutex> lock(decoder_mutex_);
      if (decoder_) {
        decoder_->Resume();
      }
    }
    if (output_) {
      output_->Resume();
    }
    EmitState(true);
    result->Success();
  } else if (name == "pause") {
    {
      std::lock_guard<std::mutex> lock(decoder_mutex_);
      if (decoder_) {
        decoder_->Pause();
      }
    }
    if (output_) {
      output_->Pause();
    }
    EmitState(false);
    result->Success();
  } else if (name == "seek") {
    int64_t ms = GetInt(args, "positionMs", 0);
    {
      std::lock_guard<std::mutex> lock(decoder_mutex_);
      if (decoder_) {
        decoder_->Seek(ms);
      }
    }
    result->Success();
  } else if (name == "setVolume") {
    double v = GetDouble(args, "volume", 1.0);
    if (output_) {
      output_->SetVolume(static_cast<float>(v));
    }
    result->Success();
  } else if (name == "dispose") {
    {
      std::lock_guard<std::mutex> lock(decoder_mutex_);
      if (decoder_) {
        decoder_->Close();
        decoder_.reset();
      }
    }
    if (output_) {
      output_->Pause();
    }
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace yunshu
