#include "ffmpeg_decoder.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>
}

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
