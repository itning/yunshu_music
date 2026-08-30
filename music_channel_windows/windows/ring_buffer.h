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
