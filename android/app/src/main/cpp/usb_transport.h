#pragma once

#include <cstddef>
#include <cstdint>
#include <deque>
#include <string>
#include <vector>

namespace qfildroid {

/**
 * Bulk endpoint transport abstraction. The protocol engines (Sahara,
 * Firehose) depend only on this interface, never on Android or JNI types.
 *
 * On Android the concrete implementation forwards bulk transfers to the
 * Kotlin USB Host layer through JNI. In host tests, LoopbackTransport is
 * used instead.
 */
class IUsbTransport {
 public:
  virtual ~IUsbTransport() = default;

  /** Returns bytes written, or negative value on error. */
  virtual int Write(const uint8_t* data, size_t len, int timeout_ms) = 0;

  /** Returns number of bytes read into buffer, or negative on error/timeout. */
  virtual int Read(uint8_t* buffer, size_t max_len, int timeout_ms) = 0;

  virtual const std::string& LastError() const = 0;
};

/**
 * Scripted transport used by host unit tests. Replays queued responses and
 * records everything written, so packet framing can be verified offline.
 */
class LoopbackTransport : public IUsbTransport {
 public:
  explicit LoopbackTransport(std::deque<std::vector<uint8_t>> responses)
      : responses_(std::move(responses)) {}

  int Write(const uint8_t* data, size_t len, int timeout_ms) override;
  int Read(uint8_t* buffer, size_t max_len, int timeout_ms) override;
  const std::string& LastError() const override { return last_error_; }

  const std::vector<std::vector<uint8_t>>& Writes() const { return writes_; }
  void QueueResponse(std::vector<uint8_t> response) {
    responses_.push_back(std::move(response));
  }

 private:
  std::deque<std::vector<uint8_t>> responses_;
  size_t current_offset_ = 0;
  std::vector<std::vector<uint8_t>> writes_;
  std::string last_error_;
};

}  // namespace qfildroid
