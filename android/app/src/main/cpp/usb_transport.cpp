#include "usb_transport.h"

#include <algorithm>

namespace qfildroid {

int LoopbackTransport::Write(const uint8_t* data, size_t len, int timeout_ms) {
  (void)timeout_ms;
  writes_.emplace_back(data, data + len);
  return static_cast<int>(len);
}

int LoopbackTransport::Read(uint8_t* buffer, size_t max_len, int timeout_ms) {
  (void)timeout_ms;
  if (responses_.empty()) {
    last_error_ = "no scripted response available";
    return -1;
  }
  const std::vector<uint8_t>& current = responses_.front();
  size_t remaining = current.size() - current_offset_;
  size_t n = remaining < max_len ? remaining : max_len;
  std::copy(current.begin() + static_cast<long>(current_offset_),
            current.begin() + static_cast<long>(current_offset_ + n), buffer);
  current_offset_ += n;
  if (current_offset_ >= current.size()) {
    responses_.pop_front();
    current_offset_ = 0;
  }
  return static_cast<int>(n);
}

}  // namespace qfildroid
