#include "sahara.h"

#include <cstring>

namespace qfildroid {
namespace sahara {

namespace {

void PutU32(std::vector<uint8_t>& out, uint32_t value) {
  out.push_back(static_cast<uint8_t>(value & 0xFF));
  out.push_back(static_cast<uint8_t>((value >> 8) & 0xFF));
  out.push_back(static_cast<uint8_t>((value >> 16) & 0xFF));
  out.push_back(static_cast<uint8_t>((value >> 24) & 0xFF));
}

uint32_t GetU32(const uint8_t* data, size_t offset) {
  return static_cast<uint32_t>(data[offset]) |
         (static_cast<uint32_t>(data[offset + 1]) << 8) |
         (static_cast<uint32_t>(data[offset + 2]) << 16) |
         (static_cast<uint32_t>(data[offset + 3]) << 24);
}

}  // namespace

std::vector<uint8_t> Packet::Serialize() const {
  std::vector<uint8_t> out;
  out.reserve(kHeaderSize + payload.size());
  PutU32(out, command);
  PutU32(out, static_cast<uint32_t>(payload.size()) + kHeaderSize);
  out.insert(out.end(), payload.begin(), payload.end());
  return out;
}

Packet SaharaEngine::MakeHelloResponse(uint32_t version,
                                       uint32_t version_supported,
                                       uint32_t max_command_len, uint32_t mode) {
  Packet packet;
  packet.command = kHelloResponse;
  // v1 hello response: version, version_supported, max_cmd_len, mode + 28
  // reserved bytes = 40 bytes payload, 48 bytes total.
  packet.payload.clear();
  PutU32(packet.payload, version);
  PutU32(packet.payload, version_supported);
  PutU32(packet.payload, max_command_len);
  PutU32(packet.payload, mode);
  packet.payload.resize(40, 0);
  packet.length = 48;
  return packet;
}

bool SaharaEngine::ReadExactly(uint8_t* buffer, size_t len, int timeout_ms,
                               std::string& error) {
  size_t received = 0;
  while (received < len) {
    int n = transport_.Read(buffer + received, len - received, timeout_ms);
    if (n <= 0) {
      error = "USB read failed (" +
              (transport_.LastError().empty() ? std::string("timeout")
                                              : transport_.LastError()) +
              ")";
      return false;
    }
    received += static_cast<size_t>(n);
  }
  return true;
}

bool SaharaEngine::ReadPacket(Packet& packet, int timeout_ms,
                              std::string& error) {
  uint8_t header[kHeaderSize];
  if (!ReadExactly(header, sizeof(header), timeout_ms, error)) return false;

  uint32_t command = GetU32(header, 0);
  uint32_t length = GetU32(header, 4);

  if (length < kHeaderSize || length > kMaxPacketLength) {
    error = "invalid packet length " + std::to_string(length);
    return false;
  }

  packet.command = command;
  packet.length = length;
  size_t payload_len = length - kHeaderSize;
  packet.payload.resize(payload_len);
  if (payload_len > 0) {
    if (!ReadExactly(packet.payload.data(), payload_len, timeout_ms, error)) {
      return false;
    }
  }
  return true;
}

bool SaharaEngine::WritePacket(const Packet& packet, int timeout_ms,
                               std::string& error) {
  std::vector<uint8_t> bytes = packet.Serialize();
  int written = transport_.Write(bytes.data(), bytes.size(), timeout_ms);
  if (written < 0 || static_cast<size_t>(written) != bytes.size()) {
    error = "USB write failed (" + transport_.LastError() + ")";
    return false;
  }
  return true;
}

bool SaharaEngine::Handshake(HandshakeResult& result, int timeout_ms) {
  std::string error;
  Packet hello;
  if (!ReadPacket(hello, timeout_ms, error)) {
    result.error = "handshake: " + error;
    return false;
  }
  if (hello.command != kHello) {
    result.error = "handshake: expected SAHARA_HELLO (1), got command " +
                   std::to_string(hello.command);
    return false;
  }
  if (hello.payload.size() < 12) {
    result.error = "handshake: HELLO payload too short (" +
                   std::to_string(hello.payload.size()) + " bytes)";
    return false;
  }

  result.device_hello.version = GetU32(hello.payload.data(), 0);
  result.device_hello.version_supported = GetU32(hello.payload.data(), 4);
  result.device_hello.max_command_len = GetU32(hello.payload.data(), 8);
  if (result.device_hello.max_command_len >= kHeaderSize &&
      result.device_hello.max_command_len <= kMaxPacketLength) {
    max_command_len_ = result.device_hello.max_command_len;
  }

  Packet response = MakeHelloResponse(
      result.device_hello.version, result.device_hello.version_supported,
      result.device_hello.max_command_len, 0 /* image transfer mode */);
  if (!WritePacket(response, timeout_ms, error)) {
    result.error = "handshake: " + error;
    return false;
  }

  result.ok = true;
  return true;
}

bool SaharaEngine::WriteImage(uint32_t image_id, const uint8_t* data,
                              size_t len, const ProgressCallback& progress,
                              int timeout_ms, WriteResult& result) {
  std::string error;
  uint64_t total_sent = 0;

  while (true) {
    Packet packet;
    if (!ReadPacket(packet, timeout_ms, error)) {
      result.error = "image transfer: " + error;
      return false;
    }

    if (packet.command == kReadData && packet.payload.size() >= 12) {
      uint32_t req_image_id = GetU32(packet.payload.data(), 0);
      uint32_t offset = GetU32(packet.payload.data(), 4);
      uint32_t length = GetU32(packet.payload.data(), 8);

      if (req_image_id != image_id) {
        result.error = "image transfer: device requested image " +
                       std::to_string(req_image_id) + ", expected " +
                       std::to_string(image_id);
        return false;
      }
      if (offset > len || length > len - offset) {
        result.error = "image transfer: device requested range [" +
                       std::to_string(offset) + ", +" +
                       std::to_string(length) + ") exceeds image size " +
                       std::to_string(len);
        return false;
      }

      int written =
          transport_.Write(data + offset, length, timeout_ms);
      if (written < 0 || static_cast<size_t>(written) != length) {
        result.error = "image transfer: USB write failed";
        return false;
      }
      total_sent += length;
      if (progress) progress(total_sent, len);
      continue;
    }

    if (packet.command == kEndImageTx && packet.payload.size() >= 4) {
      uint32_t status = GetU32(packet.payload.data(), 0);
      result.end_image_tx_status = status;
      if (status != 0) {
        result.error = "image transfer: device reported failure status " +
                       std::to_string(status);
        return false;
      }
      result.ok = true;
      result.bytes_sent = total_sent;
      return true;
    }

    result.error = "image transfer: unexpected command " +
                   std::to_string(packet.command);
    return false;
  }
}

bool SaharaEngine::Done(int timeout_ms, DoneResult& result) {
  std::string error;
  Packet done;
  done.command = kDone;
  done.length = kHeaderSize;
  if (!WritePacket(done, timeout_ms, error)) {
    result.error = "done: " + error;
    return false;
  }
  Packet response;
  if (!ReadPacket(response, timeout_ms, error)) {
    result.error = "done: " + error;
    return false;
  }
  if (response.command != kDoneResponse || response.payload.size() < 4) {
    result.error = "done: unexpected response command " +
                   std::to_string(response.command);
    return false;
  }
  result.status = GetU32(response.payload.data(), 0);
  result.ok = true;
  return true;
}

bool SaharaEngine::Reset(int timeout_ms, std::string& error) {
  Packet reset;
  reset.command = kReset;
  reset.length = kHeaderSize;
  if (!WritePacket(reset, timeout_ms, error)) {
    error = "reset: " + error;
    return false;
  }
  Packet response;
  if (!ReadPacket(response, timeout_ms, error)) {
    error = "reset: " + error;
    return false;
  }
  if (response.command != kResetResponse) {
    error = "reset: unexpected response command " +
            std::to_string(response.command);
    return false;
  }
  return true;
}

}  // namespace sahara
}  // namespace qfildroid
