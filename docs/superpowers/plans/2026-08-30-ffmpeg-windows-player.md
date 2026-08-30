# Windows FFmpeg 播放引擎实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `music_channel_windows` 内自研 FFmpeg + WASAPI 播放引擎，替换 audioplayers，并清理 vendored 依赖。

**Architecture:** C++ 插件内实现三线程播放引擎（platform 线程收发通道 / decode 线程跑 FFmpeg 解复用解码重采样 / WASAPI 事件回调线程渲染），中间用有界环形缓冲背压。Dart 侧 `FfmpegPlayer` 薄封装经 MethodChannel/EventChannel 与引擎通信，业务代码只替换播放器对象与事件流订阅。

**Tech Stack:** Flutter Windows 插件（C++17/MSVC）、FFmpeg 7.1 LGPL shared（BtbN 构建，仅 avutil/avformat/avcodec/swresample）、WASAPI 共享模式、flutter_test。

**Spec:** `docs/superpowers/specs/2026-08-30-ffmpeg-windows-player-design.md`

## Global Constraints

- FFmpeg 只用 BtbN `win64-lgpl-shared` 变体，只链 `avutil/avformat/avcodec/swresample` 四库（LGPL 动态链接，与 Apache 2.0 兼容；禁止 GPL 构建）
- 通道名固定：MethodChannel `music_channel_windows/audio`，EventChannel `music_channel_windows/audio/events`
- 事件 schema（与 spec §5 一致）：`prepared`(含 `durationMs:int?`)、`state`(`playing:bool`)、`position`(`positionMs:int`)、`seekComplete`、`complete`、`error`(`code:String`,`message:String`)
- 所有 EventSink 调用必须发生在 platform 线程（经 `PlatformTaskQueue` 投递）
- `MusicPlatform` 接口不变；SMTC/托盘/任务栏进度/播放列表逻辑不动；iOS/macOS/web 包不动
- 播放源仅 HTTP(S) URL；单实例引擎
- C++/Dart 代码不加注释（仓库规范；CMake 保留原有英文注释行）
- 构建命令在 `yunshu_music/` 目录执行；Dart 单测在 `music_channel_windows/` 执行
- 提交信息用中文 conventional 风格（对齐 `git log` 现有风格）

---

### Task 1: FFmpeg 构建依赖接入（CMake 下载/链接/打包）

**Files:**
- Modify: `music_channel_windows/windows/CMakeLists.txt`

**Interfaces:**
- Consumes: BtbN GitHub Release 资产
- Produces: CMake 变量 `FFMPEG_ROOT`（解压根目录，含 `include/`、`lib/*.lib`、`bin/*.dll`），插件目标链接四库，DLL 进入 `music_channel_windows_bundled_libraries`

- [ ] **Step 1: 手动下载 FFmpeg 包并计算 SHA256（供 CMake 锁定）**

PowerShell（任意目录）:

```powershell
$ver = "n7.1-latest-win64-lgpl-shared-7.1"
$dir = "$env:TEMP\yunshu_music_ffmpeg"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-$ver.zip"
Invoke-WebRequest -Uri $url -OutFile "$dir\ffmpeg-$ver.zip"
(Get-FileHash "$dir\ffmpeg-$ver.zip" -Algorithm SHA256).Hash.ToLower()
tar -xzf "$dir\ffmpeg-$ver.zip" -C $dir
```

记下哈希值（Step 3 填入）。若 404，用下面命令找 `*-win64-lgpl-shared-*.zip` 实际资产名并替换 `$ver`:

```powershell
Invoke-RestMethod https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/tags/latest | ForEach-Object { $_.assets.name }
```

预期: `$dir\ffmpeg-n7.1-latest-win64-lgpl-shared-7.1\include\libavcodec\avcodec.h` 存在。

- [ ] **Step 2: 确认 MSVC 可链接的导入库存在**

```powershell
Get-ChildItem "$env:TEMP\yunshu_music_ffmpeg\ffmpeg-n7.1-latest-win64-lgpl-shared-7.1\lib"
```

预期: 存在 `avcodec.lib avformat.lib avutil.lib swresample.lib`（其余 .def/.dll.a 无视）。

- [ ] **Step 3: 重写插件 CMakeLists（FILL_SHA256 换成 Step 1 哈希）**

```cmake
cmake_minimum_required(VERSION 3.18)
set(PROJECT_NAME "music_channel_windows")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "music_channel_windows_plugin")

set(FFMPEG_VERSION "n7.1-latest-win64-lgpl-shared-7.1")
set(FFMPEG_URL "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-${FFMPEG_VERSION}.zip")
set(FFMPEG_SHA256 "FILL_SHA256")
set(FFMPEG_CACHE_DIR "$ENV{TEMP}/yunshu_music_ffmpeg")
set(FFMPEG_ROOT "${FFMPEG_CACHE_DIR}/ffmpeg-${FFMPEG_VERSION}")

if(NOT EXISTS "${FFMPEG_ROOT}/include/libavformat/avformat.h")
  set(FFMPEG_ZIP "${FFMPEG_CACHE_DIR}/ffmpeg-${FFMPEG_VERSION}.zip")
  file(DOWNLOAD "${FFMPEG_URL}" "${FFMPEG_ZIP}" SHOW_PROGRESS
       EXPECTED_HASH SHA256=${FFMPEG_SHA256})
  file(ARCHIVE_EXTRACT INPUT ${FFMPEG_ZIP} DESTINATION ${FFMPEG_CACHE_DIR})
endif()

file(GLOB FFMPEG_DLLS
  "${FFMPEG_ROOT}/bin/avcodec-*.dll"
  "${FFMPEG_ROOT}/bin/avformat-*.dll"
  "${FFMPEG_ROOT}/bin/avutil-*.dll"
  "${FFMPEG_ROOT}/bin/swresample-*.dll"
)

add_library(${PLUGIN_NAME} SHARED
  "music_channel_windows_plugin.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE "${FFMPEG_ROOT}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
  "${FFMPEG_ROOT}/lib/avcodec.lib"
  "${FFMPEG_ROOT}/lib/avformat.lib"
  "${FFMPEG_ROOT}/lib/avutil.lib"
  "${FFMPEG_ROOT}/lib/swresample.lib"
)

# List of absolute paths to libraries that should be bundled with the plugin
set(music_channel_windows_bundled_libraries
  ${FFMPEG_DLLS}
  PARENT_SCOPE
)
```

- [ ] **Step 4: 构建验证**

Run（workdir `yunshu_music/`）: `flutter build windows --debug`
Expected: BUILD SUCCEEDED

```powershell
Get-ChildItem build\windows\x64\runner\Debug\*.dll | Select-Object -ExpandProperty Name
```

预期包含 `avcodec-61.dll avformat-61.dll avutil-59.dll swresample-5.dll`（7.1 系版本号 61/61/59/5，以实际为准）。

- [ ] **Step 5: 运行冒烟**

Run: `flutter run -d windows`，app 正常启动（播放仍走旧 audioplayers），无新增报错后停止。

- [ ] **Step 6: Commit**

```bash
git add music_channel_windows/windows/CMakeLists.txt
git commit -m "feat(windows): 接入 FFmpeg LGPL 构建依赖"
```

---

### Task 2: C++ 基础件（平台线程任务队列 + 环形缓冲）

**Files:**
- Create: `music_channel_windows/windows/platform_task_queue.h`
- Create: `music_channel_windows/windows/ring_buffer.h`

**Interfaces:**
- Consumes: 无
- Produces:

```cpp
namespace yunshu {
class PlatformTaskQueue {
 public:
  static PlatformTaskQueue& Instance();
  bool Start();                           // platform 线程调用
  void Shutdown();                        // platform 线程调用
  void Post(std::function<void()> task);  // 任意线程调用，任务在 platform 线程执行
};

class RingBuffer {
 public:
  explicit RingBuffer(size_t capacity_bytes);
  size_t Read(uint8_t* dst, size_t n);        // 非阻塞，返回实际读取字节数
  size_t Write(const uint8_t* src, size_t n); // 缓冲满时阻塞，abort 后返回已写字节数
  void Clear();
  void AbortWrite();
  void ResetAbort();
  size_t Size() const;
  bool IsAborted() const;
};
}  // namespace yunshu
```

- [ ] **Step 1: 写 platform_task_queue.h**

```cpp
#pragma once

#include <windows.h>

#include <deque>
#include <functional>
#include <mutex>

namespace yunshu {

class PlatformTaskQueue {
 public:
  static PlatformTaskQueue& Instance() {
    static PlatformTaskQueue instance;
    return instance;
  }

  bool Start() {
    if (hwnd_ != nullptr) {
      return true;
    }
    WNDCLASS wc = {};
    wc.lpfnWndProc = &PlatformTaskQueue::WndProc;
    wc.hInstance = GetModuleHandle(nullptr);
    wc.lpszClassName = L"yunshu_platform_task_queue";
    RegisterClass(&wc);
    hwnd_ = CreateWindowEx(0, wc.lpszClassName, L"", 0, 0, 0, 0, 0,
                           HWND_MESSAGE, nullptr, wc.hInstance, nullptr);
    return hwnd_ != nullptr;
  }

  void Shutdown() {
    if (hwnd_ != nullptr) {
      DestroyWindow(hwnd_);
      hwnd_ = nullptr;
    }
    Drain();
  }

  void Post(std::function<void()> task) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      tasks_.push_back(std::move(task));
    }
    if (hwnd_ != nullptr) {
      PostMessage(hwnd_, kDrainMsg, 0, 0);
    }
  }

 private:
  static constexpr UINT kDrainMsg = WM_APP + 0x1F;

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == kDrainMsg) {
      Instance().Drain();
      return 0;
    }
    return DefWindowProc(hwnd, msg, wp, lp);
  }

  void Drain() {
    std::deque<std::function<void()>> local;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      local.swap(tasks_);
    }
    for (auto& task : local) {
      task();
    }
  }

  std::mutex mutex_;
  std::deque<std::function<void()>> tasks_;
  HWND hwnd_ = nullptr;
};

}  // namespace yunshu
```

- [ ] **Step 2: 写 ring_buffer.h**

```cpp
#pragma once

#include <algorithm>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <vector>

namespace yunshu {

class RingBuffer {
 public:
  explicit RingBuffer(size_t capacity_bytes) : storage_(capacity_bytes) {}

  size_t Read(uint8_t* dst, size_t n) {
    std::unique_lock<std::mutex> lock(mutex_);
    size_t to_read = std::min(n, filled_);
    if (to_read == 0) {
      return 0;
    }
    size_t first = std::min(to_read, storage_.size() - head_);
    std::memcpy(dst, storage_.data() + head_, first);
    if (to_read > first) {
      std::memcpy(dst + first, storage_.data(), to_read - first);
    }
    head_ = (head_ + to_read) % storage_.size();
    filled_ -= to_read;
    lock.unlock();
    can_write_.notify_all();
    return to_read;
  }

  size_t Write(const uint8_t* src, size_t n) {
    size_t written = 0;
    std::unique_lock<std::mutex> lock(mutex_);
    while (written < n) {
      if (aborted_) {
        return written;
      }
      size_t space = storage_.size() - filled_;
      if (space == 0) {
        can_write_.wait(lock);
        continue;
      }
      size_t to_write = std::min(n - written, space);
      size_t tail = (head_ + filled_) % storage_.size();
      size_t first = std::min(to_write, storage_.size() - tail);
      std::memcpy(storage_.data() + tail, src + written, first);
      if (to_write > first) {
        std::memcpy(storage_.data(), src + written + first, to_write - first);
      }
      filled_ += to_write;
      written += to_write;
    }
    return written;
  }

  void Clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    head_ = 0;
    filled_ = 0;
    can_write_.notify_all();
  }

  void AbortWrite() {
    std::lock_guard<std::mutex> lock(mutex_);
    aborted_ = true;
    can_write_.notify_all();
  }

  void ResetAbort() {
    std::lock_guard<std::mutex> lock(mutex_);
    aborted_ = false;
  }

  size_t Size() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return filled_;
  }

  bool IsAborted() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return aborted_;
  }

 private:
  mutable std::mutex mutex_;
  std::condition_variable can_write_;
  std::vector<uint8_t> storage_;
  size_t head_ = 0;
  size_t filled_ = 0;
  bool aborted_ = false;
};

}  // namespace yunshu
```

- [ ] **Step 3: 构建验证（头文件暂未被引用，验证仓库可构建）**

Run（workdir `yunshu_music/`）: `flutter build windows --debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add music_channel_windows/windows/platform_task_queue.h music_channel_windows/windows/ring_buffer.h
git commit -m "feat(windows): 平台线程任务队列与环形缓冲"
```

---

### Task 3: WASAPI 音频输出

**Files:**
- Create: `music_channel_windows/windows/wasapi_output.h`
- Create: `music_channel_windows/windows/wasapi_output.cpp`
- Modify: `music_channel_windows/windows/CMakeLists.txt`（加源文件与 ole32）

**Interfaces:**
- Consumes: 无（Filler 由引擎注入，间接读环形缓冲）
- Produces:

```cpp
namespace yunshu {
class WasapiOutput {
 public:
  using Filler = std::function<size_t(uint8_t* dst, size_t bytes)>;
  using ProgressCb = std::function<void(uint32_t position_ms, uint64_t played_frames)>;

  bool Start(Filler filler, ProgressCb on_progress);
  void Stop();
  void Pause();
  void Resume();
  void Flush(uint32_t new_position_ms);
  bool SetVolume(float volume);
  int sample_rate() const;
  int channels() const;
};
}  // namespace yunshu
```

- [ ] **Step 1: 写 wasapi_output.h**

```cpp
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
```

- [ ] **Step 2: 写 wasapi_output.cpp**

```cpp
#include "wasapi_output.h"

#include <objbase.h>

namespace yunshu {

namespace {
constexpr REFERENCE_TIME kBufferDuration =
    static_cast<REFERENCE_TIME>(200 * 10000);
}  // namespace

bool WasapiOutput::Start(Filler filler, ProgressCb on_progress) {
  filler_ = std::move(filler);
  on_progress_ = std::move(on_progress);
  event_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  running_ = true;
  paused_ = true;
  thread_ = std::thread(&WasapiOutput::RenderLoop, this);
  return true;
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
  if (FAILED(hr)) {
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
```

- [ ] **Step 3: CMakeLists 加源文件与 ole32**

`add_library` 改为:

```cmake
add_library(${PLUGIN_NAME} SHARED
  "music_channel_windows_plugin.cpp"
  "wasapi_output.cpp"
)
```

`target_link_libraries` 行改为:

```cmake
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin ole32
```

- [ ] **Step 4: 构建验证**

Run（workdir `yunshu_music/`）: `flutter build windows --debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add music_channel_windows/windows/wasapi_output.h music_channel_windows/windows/wasapi_output.cpp music_channel_windows/windows/CMakeLists.txt
git commit -m "feat(windows): WASAPI 共享模式音频输出"
```

---

### Task 4: FFmpeg 解码器（解复用/解码/重采样循环）

**Files:**
- Create: `music_channel_windows/windows/ffmpeg_decoder.h`
- Create: `music_channel_windows/windows/ffmpeg_decoder.cpp`
- Modify: `music_channel_windows/windows/CMakeLists.txt`（加源文件）

**Interfaces:**
- Consumes: `RingBuffer`（Task 2）、FFmpeg 四库（Task 1）
- Produces:

```cpp
namespace yunshu {
struct AudioTargetFormat { int sample_rate; int channels; };

class FfmpegDecoder {
 public:
  struct Callbacks {
    std::function<void(int64_t duration_ms)> on_prepared;  // duration_ms<0 表示未知
    std::function<void(std::string code, std::string message)> on_error;
    std::function<void()> on_seek_done;
    std::function<void(uint32_t target_ms)> on_flush_output;  // decode 线程同步调用
  };

  FfmpegDecoder(RingBuffer* ring, AudioTargetFormat target, Callbacks callbacks);
  ~FfmpegDecoder();
  void Open(const std::string& url, bool start_paused);
  void Resume();
  void Pause();
  void Seek(int64_t target_ms);
  void Close();
  bool eof() const;
};
}  // namespace yunshu
```

- [ ] **Step 1: 写 ffmpeg_decoder.h**

```cpp
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
```

- [ ] **Step 2: 写 ffmpeg_decoder.cpp**

```cpp
#include "ffmpeg_decoder.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>

namespace yunshu {

namespace {

std::string AvErr(int err) {
  char buf[AV_ERROR_MAX_STRING_SIZE] = {0};
  av_strerror(err, buf, sizeof(buf));
  return std::string(buf);
}

}  // namespace

FfmpegDecoder::~FfmpegDecoder() {
  Close();
}

int FfmpegDecoder::InterruptCb(void* opaque) {
  auto* self = static_cast<FfmpegDecoder*>(opaque);
  return self->abort_.load() ? 1 : 0;
}

void FfmpegDecoder::Open(const std::string& url, bool start_paused) {
  abort_ = false;
  eof_ = false;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    state_ = start_paused ? State::kPaused : State::kPlaying;
  }
  thread_ = std::thread([this, url, start_paused] { Run(url, start_paused); });
}

bool FfmpegDecoder::Prepare(const std::string& url) {
  fmt_ = avformat_alloc_context();
  if (fmt_ == nullptr) {
    callbacks_.on_error("ALLOC_FAILED", "avformat_alloc_context");
    return false;
  }
  fmt_->interrupt_callback.callback = &FfmpegDecoder::InterruptCb;
  fmt_->interrupt_callback.opaque = this;

  AVDictionary* opts = nullptr;
  av_dict_set(&opts, "reconnect", "1", 0);
  av_dict_set(&opts, "reconnect_streamed", "1", 0);
  av_dict_set(&opts, "reconnect_delay_max", "5", 0);
  int ret = avformat_open_input(&fmt_, url.c_str(), nullptr, &opts);
  av_dict_free(&opts);
  if (ret < 0) {
    callbacks_.on_error("OPEN_FAILED", AvErr(ret));
    return false;
  }
  ret = avformat_find_stream_info(fmt_, nullptr);
  if (ret < 0) {
    callbacks_.on_error("PROBE_FAILED", AvErr(ret));
    return false;
  }
  stream_index_ =
      av_find_best_stream(fmt_, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
  if (stream_index_ < 0) {
    callbacks_.on_error("NO_AUDIO_STREAM", "no audio stream");
    return false;
  }
  const AVCodec* codec =
      avcodec_find_decoder(fmt_->streams[stream_index_]->codecpar->codec_id);
  if (codec == nullptr) {
    callbacks_.on_error("NO_DECODER", "decoder not found");
    return false;
  }
  codec_ = avcodec_alloc_context3(codec);
  if (codec_ == nullptr) {
    callbacks_.on_error("ALLOC_FAILED", "avcodec_alloc_context3");
    return false;
  }
  ret = avcodec_parameters_to_context(codec_,
                                      fmt_->streams[stream_index_]->codecpar);
  if (ret < 0) {
    callbacks_.on_error("PARAMS_FAILED", AvErr(ret));
    return false;
  }
  ret = avcodec_open2(codec_, codec, nullptr);
  if (ret < 0) {
    callbacks_.on_error("DECODER_OPEN_FAILED", AvErr(ret));
    return false;
  }

  AVChannelLayout out_layout = AV_CHANNEL_LAYOUT_STEREO;
  if (target_.channels == 1) {
    out_layout = AV_CHANNEL_LAYOUT_MONO;
  }
  ret = swr_alloc_set_opts2(&swr_, &out_layout, AV_SAMPLE_FMT_FLT,
                            target_.sample_rate, &codec_->ch_layout,
                            codec_->sample_fmt, codec_->sample_rate, 0,
                            nullptr);
  if (ret < 0 || swr_ == nullptr) {
    callbacks_.on_error("SWR_INIT_FAILED", AvErr(ret));
    return false;
  }
  ret = swr_init(swr_);
  if (ret < 0) {
    callbacks_.on_error("SWR_INIT_FAILED", AvErr(ret));
    return false;
  }

  int64_t duration_ms = -1;
  if (fmt_->duration != AV_NOPTS_VALUE && fmt_->duration > 0) {
    duration_ms = fmt_->duration / 1000;
  }
  callbacks_.on_prepared(duration_ms);
  return true;
}

void FfmpegDecoder::Run(std::string url, bool start_paused) {
  if (Prepare(url)) {
    DecodeLoop();
  }
  if (fmt_ != nullptr) {
    avformat_close_input(&fmt_);
  }
  if (codec_ != nullptr) {
    avcodec_free_context(&codec_);
  }
  if (swr_ != nullptr) {
    swr_free(&swr_);
  }
  if (swr_buffer_ != nullptr) {
    av_free(swr_buffer_);
    swr_buffer_ = nullptr;
  }
}

void FfmpegDecoder::DecodeLoop() {
  AVPacket* packet = av_packet_alloc();
  AVFrame* frame = av_frame_alloc();
  const size_t bytes_per_frame =
      static_cast<size_t>(target_.channels) * sizeof(float);
  const size_t frames_per_convert = 8192;
  swr_buffer_size_ = frames_per_convert * bytes_per_frame;
  swr_buffer_ = static_cast<uint8_t*>(av_malloc(swr_buffer_size_));

  bool draining = false;
  while (true) {
    State st;
    {
      std::unique_lock<std::mutex> lock(mutex_);
      cv_.wait(lock, [this] {
        return abort_.load() || state_ == State::kPlaying ||
               state_ == State::kSeeking || state_ == State::kStopped;
      });
      st = state_;
    }
    if (abort_.load() || st == State::kStopped) {
      break;
    }
    if (st == State::kSeeking) {
      int64_t target;
      {
        std::lock_guard<std::mutex> lock(mutex_);
        target = pending_seek_ms_;
      }
      DoSeek(target);
      continue;
    }

    if (draining) {
      while (true) {
        int ret = avcodec_receive_frame(codec_, frame);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
          break;
        }
        if (ret < 0) {
          callbacks_.on_error("DECODE_FAILED", AvErr(ret));
          break;
        }
        int converted = swr_convert(
            swr_, &swr_buffer_, static_cast<int>(frames_per_convert),
            (const uint8_t**)frame->data, frame->nb_samples);
        av_frame_unref(frame);
        if (converted > 0) {
          ring_->Write(swr_buffer_,
                       static_cast<size_t>(converted) * bytes_per_frame);
        }
      }
      eof_ = true;
      {
        std::lock_guard<std::mutex> lock(mutex_);
        if (state_ == State::kPlaying) {
          state_ = State::kIdle;
        }
      }
      continue;
    }

    int ret = av_read_frame(fmt_, packet);
    if (ret == AVERROR_EOF || ret == AVERROR_EXIT) {
      avcodec_send_packet(codec_, nullptr);
      draining = true;
      continue;
    }
    if (ret < 0) {
      callbacks_.on_error("READ_FAILED", AvErr(ret));
      break;
    }
    if (packet->stream_index != stream_index_) {
      av_packet_unref(packet);
      continue;
    }
    avcodec_send_packet(codec_, packet);
    av_packet_unref(packet);
    while (true) {
      ret = avcodec_receive_frame(codec_, frame);
      if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
        break;
      }
      if (ret < 0) {
        callbacks_.on_error("DECODE_FAILED", AvErr(ret));
        break;
      }
      int converted = swr_convert(
          swr_, &swr_buffer_, static_cast<int>(frames_per_convert),
          (const uint8_t**)frame->data, frame->nb_samples);
      av_frame_unref(frame);
      if (converted > 0) {
        ring_->Write(swr_buffer_,
                     static_cast<size_t>(converted) * bytes_per_frame);
      }
      {
        std::lock_guard<std::mutex> lock(mutex_);
        if (state_ == State::kSeeking || state_ == State::kStopped) {
          break;
        }
      }
    }
  }
  av_frame_free(&frame);
  av_packet_free(&packet);
}

void FfmpegDecoder::Resume() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (state_ == State::kPaused || state_ == State::kIdle) {
      state_ = State::kPlaying;
    }
  }
  cv_.notify_all();
}

void FfmpegDecoder::Pause() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (state_ == State::kPlaying) {
      state_ = State::kPaused;
    }
  }
}

void FfmpegDecoder::Seek(int64_t target_ms) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    resume_after_seek_ = state_ == State::kPlaying || state_ == State::kIdle;
    pending_seek_ms_ = target_ms;
    state_ = State::kSeeking;
  }
  cv_.notify_all();
  ring_->Clear();
}

void FfmpegDecoder::DoSeek(int64_t target_ms) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    state_ = State::kIdle;
  }
  ring_->Clear();
  if (fmt_ != nullptr && codec_ != nullptr) {
    av_seek_frame(fmt_, -1, target_ms * 1000, AVSEEK_FLAG_BACKWARD);
    avcodec_flush_buffers(codec_);
  }
  eof_ = false;
  if (callbacks_.on_flush_output) {
    callbacks_.on_flush_output(static_cast<uint32_t>(target_ms));
  }
  {
    std::lock_guard<std::mutex> lock(mutex_);
    state_ = resume_after_seek_ ? State::kPlaying : State::kPaused;
  }
  cv_.notify_all();
  if (callbacks_.on_seek_done) {
    callbacks_.on_seek_done();
  }
}

void FfmpegDecoder::Close() {
  abort_ = true;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    state_ = State::kStopped;
  }
  cv_.notify_all();
  ring_->AbortWrite();
  if (thread_.joinable()) {
    thread_.join();
  }
}

}  // namespace yunshu
```

注意: seek 采用 `AVSEEK_FLAG_BACKWARDS`，解出的首帧可能略早于目标位置，位置计数以 `WasapiOutput::Flush` 的 target 为准，误差在关键帧粒度内，可接受。

- [ ] **Step 3: CMakeLists 加源文件**

`add_library` 列表追加一行 `"ffmpeg_decoder.cpp"`。

- [ ] **Step 4: 构建验证**

Run（workdir `yunshu_music/`）: `flutter build windows --debug`
Expected: BUILD SUCCEEDED（FFmpeg 头文件与导入库链接通过）

- [ ] **Step 5: Commit**

```bash
git add music_channel_windows/windows/ffmpeg_decoder.h music_channel_windows/windows/ffmpeg_decoder.cpp music_channel_windows/windows/CMakeLists.txt
git commit -m "feat(windows): FFmpeg 解复用解码重采样循环"
```

---

### Task 5: 播放引擎接线（通道注册/命令/事件/complete 检测）

**Files:**
- Create: `music_channel_windows/windows/ffmpeg_engine.h`
- Create: `music_channel_windows/windows/ffmpeg_engine.cpp`
- Modify: `music_channel_windows/windows/music_channel_windows_plugin.cpp`
- Modify: `music_channel_windows/windows/CMakeLists.txt`（加源文件）

**Interfaces:**
- Consumes: Task 2 `PlatformTaskQueue`/`RingBuffer`、Task 3 `WasapiOutput`、Task 4 `FfmpegDecoder`
- Produces: 原生侧完整实现 spec §5 协议（方法 `setSource/play/resume/pause/seek/setVolume/dispose`；事件 `prepared/state/position/seekComplete/complete/error`）

- [ ] **Step 1: 写 ffmpeg_engine.h**

```cpp
#pragma once

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
};

}  // namespace yunshu
```

- [ ] **Step 2: 写 ffmpeg_engine.cpp**

```cpp
#include "ffmpeg_engine.h"

#include <flutter/standard_method_codec.h>

#include <libavformat/avformat.h>

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
  target_ = {output_->sample_rate(), output_->channels()};
  block_align_ = static_cast<size_t>(target_.channels) * sizeof(float);
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
```

- [ ] **Step 3: 修改 music_channel_windows_plugin.cpp 注册引擎**

文件头 `#include <sstream>` 之后加:

```cpp
#include "ffmpeg_engine.h"
```

`RegisterWithRegistrar` 内 `registrar->AddPlugin(std::move(plugin));` 之前加:

```cpp
  yunshu::FfmpegEngine::Instance()->Init(registrar);
```

析构函数改为:

```cpp
MusicChannelWindowsPlugin::~MusicChannelWindowsPlugin() {
  yunshu::FfmpegEngine::Instance()->Shutdown();
}
```

- [ ] **Step 4: CMakeLists 加源文件**

`add_library` 列表追加一行 `"ffmpeg_engine.cpp"`。

- [ ] **Step 5: 构建 + 运行验证**

Run（workdir `yunshu_music/`）: `flutter build windows --debug`
Expected: BUILD SUCCEEDED

Run: `flutter run -d windows`
Expected: app 正常启动（播放仍走旧 audioplayers，新引擎空闲、无崩溃、无异常日志），停止运行。

- [ ] **Step 6: Commit**

```bash
git add music_channel_windows/windows/ffmpeg_engine.h music_channel_windows/windows/ffmpeg_engine.cpp music_channel_windows/windows/music_channel_windows_plugin.cpp music_channel_windows/windows/CMakeLists.txt
git commit -m "feat(windows): 播放引擎通道接线"
```

---

### Task 6: Dart FfmpegPlayer 封装（TDD）

**Files:**
- Create: `music_channel_windows/lib/ffmpeg_player.dart`
- Test: `music_channel_windows/test/ffmpeg_player_test.dart`（目录不存在则新建）

**Interfaces:**
- Consumes: Task 5 通道协议
- Produces（Task 7 依赖）:

```dart
class FfmpegPlayer {
  FfmpegPlayer();
  Stream<Duration> get onPositionChanged;
  Stream<bool> get onPlayerStateChanged;
  Stream<Duration?> get onPrepared;
  Stream<void> get onSeekComplete;
  Stream<void> get onComplete;
  Stream<String> get onError;
  double get volume;
  Future<void> setSourceUrl(String url);
  Future<void> play(String url);
  Future<void> resume();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double value);
  Future<void> dispose();
}
```

- [ ] **Step 1: 写失败测试 `music_channel_windows/test/ffmpeg_player_test.dart`**

```dart
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_channel_windows/ffmpeg_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('music_channel_windows/audio');
  const eventChannelName = 'music_channel_windows/audio/events';

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  Future<void> emitEvent(Map<Object?, Object?> event) async {
    final bytes = const StandardMethodCodec().encodeSuccessEnvelope(event);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(eventChannelName, ByteData.view(bytes.buffer), (_) {});
    await pumpEventQueue();
  }

  test('play sends url on method channel', () async {
    final player = FfmpegPlayer();
    await player.play('https://example.com/a.flac');
    expect(calls, hasLength(1));
    expect(calls.first.method, 'play');
    expect(calls.first.arguments, {'url': 'https://example.com/a.flac'});
    await player.dispose();
  });

  test('setSourceUrl/seek/setVolume map to method calls', () async {
    final player = FfmpegPlayer();
    await player.setSourceUrl('https://example.com/b.mp3');
    await player.seek(const Duration(seconds: 30));
    await player.setVolume(0.5);
    expect(calls.map((c) => c.method).toList(),
        ['setSource', 'seek', 'setVolume']);
    expect(calls[1].arguments, {'positionMs': 30000});
    expect(calls[2].arguments, {'volume': 0.5});
    expect(player.volume, 0.5);
    await player.dispose();
  });

  test('prepared event carries duration or null', () async {
    final player = FfmpegPlayer();
    final durations = <Duration?>[];
    player.onPrepared.listen(durations.add);
    await emitEvent({'event': 'prepared', 'durationMs': 123456});
    await emitEvent({'event': 'prepared', 'durationMs': null});
    expect(durations, [const Duration(milliseconds: 123456), null]);
    await player.dispose();
  });

  test('state/position/seekComplete/complete events map', () async {
    final player = FfmpegPlayer();
    final states = <bool>[];
    final positions = <Duration>[];
    var seekDone = 0;
    var complete = 0;
    player.onPlayerStateChanged.listen(states.add);
    player.onPositionChanged.listen(positions.add);
    player.onSeekComplete.listen((_) => seekDone++);
    player.onComplete.listen((_) => complete++);
    await emitEvent({'event': 'state', 'playing': true});
    await emitEvent({'event': 'state', 'playing': false});
    await emitEvent({'event': 'position', 'positionMs': 4242});
    await emitEvent({'event': 'seekComplete'});
    await emitEvent({'event': 'complete'});
    expect(states, [true, false]);
    expect(positions, [const Duration(milliseconds: 4242)]);
    expect(seekDone, 1);
    expect(complete, 1);
    await player.dispose();
  });

  test('error event carries message', () async {
    final player = FfmpegPlayer();
    final errors = <String>[];
    player.onError.listen(errors.add);
    await emitEvent({
      'event': 'error',
      'code': 'OPEN_FAILED',
      'message': 'Server returned 404',
    });
    expect(errors, ['Server returned 404']);
    await player.dispose();
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run（workdir `music_channel_windows/`）: `flutter test test/ffmpeg_player_test.dart`
Expected: FAIL，报 `Error: Couldn't resolve the package 'music_channel_windows' ... ffmpeg_player.dart`（Target of URI doesn't exist）

- [ ] **Step 3: 写 `music_channel_windows/lib/ffmpeg_player.dart`**

```dart
import 'dart:async';

import 'package:flutter/services.dart';

class FfmpegPlayer {
  static const MethodChannel _methodChannel =
      MethodChannel('music_channel_windows/audio');
  static const EventChannel _eventChannel =
      EventChannel('music_channel_windows/audio/events');

  final StreamController<Map<Object?, Object?>> _eventsController =
      StreamController<Map<Object?, Object?>>.broadcast();
  late final StreamSubscription<dynamic> _subscription;

  double _volume = 1.0;

  FfmpegPlayer() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map<Object?, Object?>) {
          _eventsController.add(event);
        }
      },
      onError: Object,
    );
  }

  Stream<Map<Object?, Object?>> get events => _eventsController.stream;

  Stream<Duration> get onPositionChanged => events
      .where((e) => e['event'] == 'position')
      .map((e) => Duration(milliseconds: (e['positionMs'] as num).toInt()));

  Stream<bool> get onPlayerStateChanged =>
      events.where((e) => e['event'] == 'state').map((e) => e['playing'] == true);

  Stream<Duration?> get onPrepared => events
      .where((e) => e['event'] == 'prepared')
      .map((e) => e['durationMs'] == null
          ? null
          : Duration(milliseconds: (e['durationMs'] as num).toInt()));

  Stream<void> get onSeekComplete =>
      events.where((e) => e['event'] == 'seekComplete').map((_) {});

  Stream<void> get onComplete =>
      events.where((e) => e['event'] == 'complete').map((_) {});

  Stream<String> get onError => events
      .where((e) => e['event'] == 'error')
      .map((e) => e['message']?.toString() ?? 'unknown error');

  double get volume => _volume;

  Future<void> setSourceUrl(String url) =>
      _methodChannel.invokeMethod('setSource', {'url': url});

  Future<void> play(String url) =>
      _methodChannel.invokeMethod('play', {'url': url});

  Future<void> resume() => _methodChannel.invokeMethod('resume');

  Future<void> pause() => _methodChannel.invokeMethod('pause');

  Future<void> seek(Duration position) => _methodChannel
      .invokeMethod('seek', {'positionMs': position.inMilliseconds});

  Future<void> setVolume(double value) {
    _volume = value;
    return _methodChannel.invokeMethod('setVolume', {'volume': value});
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _eventsController.close();
    await _methodChannel.invokeMethod('dispose');
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run（workdir `music_channel_windows/`）: `flutter test test/ffmpeg_player_test.dart`
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add music_channel_windows/lib/ffmpeg_player.dart music_channel_windows/test/ffmpeg_player_test.dart
git commit -m "feat(windows): FfmpegPlayer Dart 封装与单测"
```

---

### Task 7: 业务切换到自研引擎

**Files:**
- Modify: `music_channel_windows/lib/music_channel_windows.dart`
- Modify: `music_channel_windows/pubspec.yaml`

**Interfaces:**
- Consumes: Task 6 `FfmpegPlayer`
- Produces: Windows 播放链路全部走自研引擎（audioplayers 从 Windows 业务中移除）

- [ ] **Step 1: 替换 import 与播放器字段**

`music_channel_windows/lib/music_channel_windows.dart`:

删除行:

```dart
import 'package:audioplayers/audioplayers.dart';
```

在 `import 'package:windows_taskbar/windows_taskbar.dart';` 之后加:

```dart
import 'ffmpeg_player.dart';
```

字段声明 `late AudioPlayer _player;` 改为:

```dart
late FfmpegPlayer _player;
```

- [ ] **Step 2: 替换初始化**

```dart
    _player = AudioPlayer(playerId: "69420");
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setPlayerMode(PlayerMode.mediaPlayer);
```

改为:

```dart
    _player = FfmpegPlayer();
```

- [ ] **Step 3: 替换 onPlayerStateChanged 订阅**

```dart
    _player.onPlayerStateChanged.listen((PlayerState event) {
      if (PlayerState.completed == event) {
        return;
      }
      bool playing = PlayerState.playing == event;
      _playbackState.state = playing ? MusicStatus.playing : MusicStatus.paused;
```

改为（后续行不变）:

```dart
    _player.onPlayerStateChanged.listen((bool playing) {
      _playbackState.state = playing ? MusicStatus.playing : MusicStatus.paused;
```

- [ ] **Step 4: 替换 eventStream 块**

删除整个 `_player.eventStream.listen((AudioEvent event) { ... });` 块（原 switch，含 duration/seekComplete/complete/prepared/log 分支），在原位置替换为:

```dart
    _player.onPrepared.listen((Duration? duration) {
      if (null != duration) {
        int ms = duration.inMilliseconds;
        _metaData.duration = ms;
        _metadataEventController.sink.add(_metaData.toMap());
        windowManager.isVisible().then((visible) {
          if (visible) {
            WindowsTaskbar.setProgress(_playbackState.position, ms);
          }
        });
        _smtc.setEndTime(duration);
      }
      _playbackState.state = MusicStatus.paused;
      _playbackStateController.sink.add(_playbackState.toMap());
    });

    _player.onComplete.listen((_) {
      _playbackState.state = MusicStatus.none;
      _playbackStateController.sink.add(_playbackState.toMap());
      windowManager.isVisible().then((visible) {
        if (visible) {
          WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
        }
      });
      _smtc.setPlaybackStatus(PlaybackStatus.stopped);
      next(false);
      initPlay(autoStart: true);
    });
```

- [ ] **Step 5: 替换播放调用**

`initPlay` 内:

```dart
    if (autoStart) {
      _player.play(UrlSource(url));
    } else {
      _player.setSourceUrl(url);
    }
```

改为:

```dart
    if (autoStart) {
      _player.play(url);
    } else {
      _player.setSourceUrl(url);
    }
```

`play()`/`pause()`/`seekTo()`/`setVolume()` 方法体不变（`_player.resume()`/`_player.pause()`/`_player.seek(position)`/`_player.setVolume(value)` 签名一致）。

- [ ] **Step 6: 移除 audioplayers 依赖**

`music_channel_windows/pubspec.yaml` 删除行:

```yaml
  audioplayers: ^6.5.1
```

Run（workdir `yunshu_music/`）: `flutter pub get`
Expected: 无错误（audioplayers 仍会经 music_channel_ios/macos 传递存在，但不再被 Windows 业务使用）。

- [ ] **Step 7: 静态检查**

Run（workdir `music_channel_windows/`）: `flutter analyze`
Expected: No issues found!

- [ ] **Step 8: 构建与完整手动验收**

Run（workdir `yunshu_music/`）: `flutter run -d windows`

按 spec §10 清单逐项验收:

1. 播放 / 暂停 / 继续 / seek（含 >4 分钟长音频的远端 seek）
2. 音量调节（含静音）
3. 自然播完自动切歌、手动上下曲、随机/顺序/单曲循环模式
4. 格式: mp3、flac、ogg、m4a(aac)、wav
5. 网络断开的表现（error 事件不崩溃、恢复后可重新播放）
6. SMTC 系统媒体控制、托盘菜单（播放/暂停文案切换）、任务栏进度条联动
7. 热重启后无残留音频、无崩溃

Expected: 全部通过。任何一项失败回到对应 C++ 任务修复后重验。

- [ ] **Step 9: Commit**

```bash
git add music_channel_windows/lib/music_channel_windows.dart music_channel_windows/pubspec.yaml yunshu_music/pubspec.lock
git commit -m "feat(windows): 播放业务切换到自研 FFmpeg 引擎"
```

---

### Task 8: 依赖清理与 LGPL 合规收尾

**Files:**
- Modify: `yunshu_music/pubspec.yaml`
- Delete: `audioplayers_windows/`（整个目录）
- Modify: `music_channel_windows/README.md`

**Interfaces:**
- Consumes: Task 7 完成（Windows 业务已不用 audioplayers）
- Produces: 仓库无 vendored audioplayers_windows；官方包仅作为 iOS/macOS 的传递依赖编译进 Windows 构建（运行时死代码，issue #1635 不触发）

- [ ] **Step 1: 移除 app 的 dependency_overrides（保留 flutter_rust_bridge 钉版）**

`yunshu_music/pubspec.yaml` 中删除:

```yaml
  # audioplayers_windows 在非平台线程发送 EventSink 消息（上游 issue #1635），
  # 本地 vendor 了修复 PR #1961（另修复了其 MSVC 编译错误），官方发布后可移除
  audioplayers_windows:
    path: ../audioplayers_windows
```

保留同段的 `flutter_rust_bridge: 2.11.1`（smtc_windows 仍需要）。

- [ ] **Step 2: 删除 vendored 目录**

```bash
git rm -r audioplayers_windows
```

- [ ] **Step 3: 依赖解析与构建验证**

Run（workdir `yunshu_music/`）:

```bash
flutter pub get
flutter pub deps
```

Expected: `flutter pub deps` 中 `audioplayers_windows` 来自 pub.dev（4.2.1，transitive），不再有 path 指向。

Run: `flutter build windows --debug`
Expected: BUILD SUCCEEDED（官方 audioplayers_windows 正常编译；此前已核实 vendored 与官方 4.2.1 的全部差异仅为 PR #1961，官方版本身可在 MSVC 下编译）

- [ ] **Step 4: README LGPL 合规声明**

`music_channel_windows/README.md` 末尾追加:

```markdown
## FFmpeg

Windows 实现动态链接 FFmpeg（LGPL v2.1+，BtbN `win64-lgpl-shared` 构建，
仅包含 avutil / avformat / avcodec / swresample）：

- 构建来源: https://github.com/BtbN/FFmpeg-Builds
- 锁定版本与 SHA256: 见 `windows/CMakeLists.txt`
- FFmpeg 源码: https://ffmpeg.org/download.html
```

- [ ] **Step 5: 最终回归验收**

Run（workdir `yunshu_music/`）: `flutter run -d windows`，重复 Task 7 Step 8 清单第 1/3/6 项快速回归。
再验证打包产物:

```powershell
Get-ChildItem build\windows\x64\runner\Debug\*.dll | Select-Object -ExpandProperty Name
```

Expected: 仍含 4 个 FFmpeg DLL；回归项全部通过。

- [ ] **Step 6: Commit**

```bash
git add yunshu_music/pubspec.yaml yunshu_music/pubspec.lock music_channel_windows/README.md
git commit -m "chore: 移除 vendored audioplayers_windows 依赖"
```
