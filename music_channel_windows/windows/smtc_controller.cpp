#include "smtc_controller.h"

// ABI interface declarations, required by the interop header below.
#include <windows.media.h>

#include <SystemMediaTransportControlsInterop.h>

#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Storage.Streams.h>

#include <chrono>
#include <thread>

#include "platform_task_queue.h"

namespace yunshu {

namespace {

using winrt::Windows::Foundation::TimeSpan;
using winrt::Windows::Media::MediaPlaybackStatus;
using winrt::Windows::Media::MediaPlaybackType;
using winrt::Windows::Media::SystemMediaTransportControls;
using winrt::Windows::Media::SystemMediaTransportControlsButton;
using winrt::Windows::Media::SystemMediaTransportControlsButtonPressedEventArgs;
using winrt::Windows::Media::SystemMediaTransportControlsTimelineProperties;
using winrt::Windows::Storage::Streams::DataWriter;
using winrt::Windows::Storage::Streams::InMemoryRandomAccessStream;
using winrt::Windows::Storage::Streams::RandomAccessStreamReference;

using ABI::Windows::Media::ISystemMediaTransportControls;

TimeSpan ToTimeSpan(int64_t milliseconds) {
  if (milliseconds < 0) {
    milliseconds = 0;
  }
  return std::chrono::duration_cast<TimeSpan>(
      std::chrono::milliseconds(milliseconds));
}

MediaPlaybackStatus StatusFromString(const std::string& status) {
  if (status == "playing") {
    return MediaPlaybackStatus::Playing;
  }
  if (status == "paused") {
    return MediaPlaybackStatus::Paused;
  }
  return MediaPlaybackStatus::Stopped;
}

SmtcButton ButtonFromNative(SystemMediaTransportControlsButton button) {
  switch (button) {
    case SystemMediaTransportControlsButton::Play:
      return SmtcButton::kPlay;
    case SystemMediaTransportControlsButton::Pause:
      return SmtcButton::kPause;
    case SystemMediaTransportControlsButton::Next:
      return SmtcButton::kNext;
    case SystemMediaTransportControlsButton::Previous:
      return SmtcButton::kPrevious;
    case SystemMediaTransportControlsButton::Stop:
      return SmtcButton::kStop;
    default:
      return SmtcButton::kPlay;
  }
}

}  // namespace

struct SmtcController::Impl {
  SystemMediaTransportControls controls{nullptr};
  ButtonCallback on_button;
  winrt::event_token button_token{};
  bool button_registered = false;

  winrt::hstring title;
  winrt::hstring artist;
  RandomAccessStreamReference cover{nullptr};

  void ApplyMetadata() {
    if (!controls) {
      return;
    }
    auto display = controls.DisplayUpdater();
    display.Type(MediaPlaybackType::Music);
    auto music = display.MusicProperties();
    music.Title(title);
    music.Artist(artist);
    if (cover) {
      display.Thumbnail(cover);
    }
    display.Update();
  }
};

SmtcController::SmtcController() : impl_(std::make_unique<Impl>()) {}

SmtcController::~SmtcController() { Shutdown(); }

void SmtcController::Initialize(HWND hwnd, ButtonCallback on_button) {
  if (hwnd == nullptr) {
    return;
  }
  impl_->on_button = std::move(on_button);

  auto interop = winrt::get_activation_factory<
      SystemMediaTransportControls, ISystemMediaTransportControlsInterop>();
  winrt::com_ptr<ISystemMediaTransportControls> interop_controls;
  winrt::check_hresult(interop->GetForWindow(
      hwnd, winrt::guid_of<ISystemMediaTransportControls>(),
      interop_controls.put_void()));
  impl_->controls = SystemMediaTransportControls{
      interop_controls.detach(), winrt::take_ownership_from_abi};

  auto controls = impl_->controls;
  controls.IsEnabled(true);
  controls.IsPlayEnabled(true);
  controls.IsPauseEnabled(true);
  controls.IsStopEnabled(true);
  controls.IsNextEnabled(true);
  controls.IsPreviousEnabled(true);
  controls.IsFastForwardEnabled(false);
  controls.IsRewindEnabled(false);

  impl_->button_token = controls.ButtonPressed(
      [this](SystemMediaTransportControls const&,
             SystemMediaTransportControlsButtonPressedEventArgs const& args) {
        if (impl_->on_button) {
          impl_->on_button(ButtonFromNative(args.Button()));
        }
      });
  impl_->button_registered = true;
}

void SmtcController::SetEnabled(bool enabled) {
  if (impl_->controls) {
    impl_->controls.IsEnabled(enabled);
  }
}

void SmtcController::SetMetadata(const std::wstring& title,
                                 const std::wstring& artist) {
  impl_->title = winrt::hstring(title);
  impl_->artist = winrt::hstring(artist);
  impl_->ApplyMetadata();
}

void SmtcController::SetCover(const std::vector<uint8_t>& bytes) {
  if (bytes.empty()) {
    impl_->cover = nullptr;
    return;
  }
  // Building the stream uses WinRT async operations, which deadlock when
  // blocked on the STA platform thread. Do the work on a worker thread and
  // hand the finished reference back to the platform thread.
  std::thread([this, bytes]() {
    try {
      winrt::init_apartment(winrt::apartment_type::multi_threaded);
      InMemoryRandomAccessStream stream;
      DataWriter writer{stream};
      writer.WriteBytes(winrt::array_view<uint8_t const>(
          bytes.data(), bytes.data() + bytes.size()));
      writer.StoreAsync().get();
      writer.DetachStream();
      stream.Seek(0);
      RandomAccessStreamReference reference =
          RandomAccessStreamReference::CreateFromStream(stream);
      PlatformTaskQueue::Instance().Post([this, reference]() {
        impl_->cover = reference;
        impl_->ApplyMetadata();
      });
      winrt::uninit_apartment();
    } catch (...) {
      // Ignore: a missing thumbnail is non-fatal.
    }
  }).detach();
}

void SmtcController::SetPlaybackStatus(const std::string& status) {
  if (impl_->controls) {
    impl_->controls.PlaybackStatus(StatusFromString(status));
  }
}

void SmtcController::SetTimeline(int64_t position_ms, int64_t end_ms) {
  if (!impl_->controls) {
    return;
  }
  SystemMediaTransportControlsTimelineProperties properties;
  properties.StartTime(ToTimeSpan(0));
  properties.EndTime(ToTimeSpan(end_ms));
  properties.MinSeekTime(ToTimeSpan(0));
  properties.MaxSeekTime(ToTimeSpan(end_ms));
  properties.Position(ToTimeSpan(position_ms));
  impl_->controls.UpdateTimelineProperties(properties);
}

void SmtcController::Shutdown() {
  if (!impl_ || !impl_->controls) {
    return;
  }
  if (impl_->button_registered) {
    impl_->controls.ButtonPressed(impl_->button_token);
    impl_->button_registered = false;
  }
  impl_->controls.IsEnabled(false);
  impl_->controls = nullptr;
}

}  // namespace yunshu
