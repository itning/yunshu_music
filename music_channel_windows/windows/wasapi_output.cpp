#include "wasapi_output.h"

#include <mmreg.h>
#include <objbase.h>

extern "C" {
#include <libavutil/samplefmt.h>
}

namespace yunshu {

namespace {
constexpr REFERENCE_TIME kBufferDuration =
    static_cast<REFERENCE_TIME>(200 * 10000);

int DetectSampleFormat(const WAVEFORMATEX* mix) {
  WORD tag = mix->wFormatTag;
  const WORD bits = mix->wBitsPerSample;
  if (tag == WAVE_FORMAT_EXTENSIBLE) {
    const auto* ext = reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(mix);
    tag = static_cast<WORD>(ext->SubFormat.Data1);
  }
  if (tag == WAVE_FORMAT_IEEE_FLOAT) {
    return AV_SAMPLE_FMT_FLT;
  }
  if (tag == WAVE_FORMAT_PCM) {
    if (bits == 8) {
      return AV_SAMPLE_FMT_U8;
    }
    if (bits == 16) {
      return AV_SAMPLE_FMT_S16;
    }
    if (bits == 24 || bits == 32) {
      return AV_SAMPLE_FMT_S32;
    }
  }
  return AV_SAMPLE_FMT_FLT;
}
}  // namespace

bool WasapiOutput::Start(Filler filler, ProgressCb on_progress) {
  filler_ = std::move(filler);
  on_progress_ = std::move(on_progress);
  event_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  running_ = true;
  paused_ = true;
  {
    std::lock_guard<std::mutex> lock(init_mutex_);
    init_done_ = false;
    initialized_ = false;
  }
  thread_ = std::thread(&WasapiOutput::RenderLoop, this);
  std::unique_lock<std::mutex> lock(init_mutex_);
  init_cv_.wait(lock, [this] { return init_done_; });
  return initialized_;
}

void WasapiOutput::RenderLoop() {
  CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  IMMDeviceEnumerator* enumerator = nullptr;
  IMMDevice* device = nullptr;
  WAVEFORMATEX* mix = nullptr;
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
                                reinterpret_cast<void**>(&enumerator));
  if (SUCCEEDED(hr) && enumerator != nullptr) {
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
  }
  if (SUCCEEDED(hr) && device != nullptr) {
    hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                          reinterpret_cast<void**>(&client_));
  }
  if (SUCCEEDED(hr) && client_ != nullptr) {
    hr = client_->GetMixFormat(&mix);
  }
  if (SUCCEEDED(hr) && mix != nullptr) {
    hr = client_->Initialize(AUDCLNT_SHAREMODE_SHARED,
                             AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                             kBufferDuration, 0, mix, nullptr);
  }
  if (SUCCEEDED(hr)) {
    hr = client_->SetEventHandle(event_);
  }
  if (SUCCEEDED(hr)) {
    hr = client_->GetBufferSize(&buffer_frames_);
  }
  if (SUCCEEDED(hr)) {
    hr = client_->GetService(__uuidof(IAudioRenderClient),
                             reinterpret_cast<void**>(&render_));
  }
  if (SUCCEEDED(hr)) {
    hr = client_->GetService(__uuidof(ISimpleAudioVolume),
                             reinterpret_cast<void**>(&simple_volume_));
  }
  if (SUCCEEDED(hr) && mix != nullptr) {
    sample_rate_ = mix->nSamplesPerSec;
    channels_ = mix->nChannels;
    block_align_ = mix->nBlockAlign;
    sample_format_ = DetectSampleFormat(mix);
    BYTE* data = nullptr;
    if (SUCCEEDED(render_->GetBuffer(buffer_frames_, &data))) {
      ZeroMemory(data, static_cast<size_t>(buffer_frames_) * mix->nBlockAlign);
      render_->ReleaseBuffer(buffer_frames_, 0);
    }
  }
  if (mix != nullptr) {
    CoTaskMemFree(mix);
  }
  if (device != nullptr) {
    device->Release();
  }
  if (enumerator != nullptr) {
    enumerator->Release();
  }
  const bool initialized = SUCCEEDED(hr);
  {
    std::lock_guard<std::mutex> lock(init_mutex_);
    initialized_ = initialized;
    init_done_ = true;
  }
  init_cv_.notify_all();
  if (!initialized) {
    running_ = false;
    return;
  }
  client_->Start();

  auto next_emit = std::chrono::steady_clock::now();
  while (running_) {
    WaitForSingleObject(event_, 100);
    if (!running_) {
      break;
    }
    if (paused_) {
      continue;
    }
    UINT32 padding = 0;
    if (FAILED(client_->GetCurrentPadding(&padding))) {
      break;
    }
    UINT32 avail = buffer_frames_ - padding;
    if (avail > 0) {
      BYTE* dst = nullptr;
      if (FAILED(render_->GetBuffer(avail, &dst))) {
        break;
      }
      size_t want = static_cast<size_t>(avail) * block_align_.load();
      size_t got = filler_ ? filler_(dst, want) : 0;
      if (got < want) {
        ZeroMemory(dst + got, want - got);
      }
      render_->ReleaseBuffer(avail, 0);
      submitted_frames_ += avail;
    }
    auto now = std::chrono::steady_clock::now();
    if (on_progress_ && now >= next_emit) {
      next_emit = now + std::chrono::milliseconds(200);
      if (SUCCEEDED(client_->GetCurrentPadding(&padding))) {
        uint64_t submitted = submitted_frames_.load();
        uint64_t played = submitted > padding ? submitted - padding : 0;
        int rate = sample_rate_.load();
        uint32_t pos_ms =
            static_cast<uint32_t>(played * 1000 / (rate > 0 ? rate : 1));
        on_progress_(pos_ms, played);
      }
    }
  }
  client_->Stop();
}

void WasapiOutput::Stop() {
  running_ = false;
  if (event_ != nullptr) {
    SetEvent(event_);
  }
  if (thread_.joinable()) {
    thread_.join();
  }
}

void WasapiOutput::Pause() {
  paused_ = true;
  if (client_ != nullptr) {
    client_->Stop();
  }
}

void WasapiOutput::Resume() {
  if (client_ != nullptr) {
    client_->Start();
  }
  paused_ = false;
}

void WasapiOutput::Flush(uint32_t new_position_ms) {
  if (client_ != nullptr) {
    client_->Stop();
    client_->Reset();
  }
  int rate = sample_rate_.load();
  submitted_frames_ =
      static_cast<uint64_t>(new_position_ms) * (rate > 0 ? rate : 1) / 1000;
  if (!paused_.load() && client_ != nullptr) {
    client_->Start();
  }
}

bool WasapiOutput::SetVolume(float volume) {
  if (simple_volume_ == nullptr) {
    return false;
  }
  return SUCCEEDED(simple_volume_->SetMasterVolume(volume, nullptr));
}

}  // namespace yunshu
