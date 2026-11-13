#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include "usb_transport.h"

namespace qfildroid {
namespace sahara {

// Sahara command identifiers (Qualcomm Sahara/Firehose protocol, v1/v2/v3).
enum Command : uint32_t {
  kHello = 1,
  kHelloResponse = 2,
  kReadData = 3,
  kEndImageTx = 4,
  kDone = 5,
  kDoneResponse = 6,
  kReset = 7,
  kResetResponse = 8,
  kMemoryDebug = 9,
  kMemoryRead = 10,
  kCmdReady = 11,
  kCmdSwitch = 12,
  kExecCmd = 13,
  kExecResponse = 14,
  kExecData = 15,
};

constexpr uint32_t kMaxPacketLength = 8192;
constexpr uint32_t kHeaderSize = 8;

/** A raw Sahara packet: 8 byte header (cmd, length LE) + payload. */
struct Packet {
  uint32_t command = 0;
  uint32_t length = 0;
  std::vector<uint8_t> payload;

  std::vector<uint8_t> Serialize() const;
};

/** Parsed fields of a SAHARA_HELLO packet sent by the device. */
struct HelloInfo {
  uint32_t version = 0;
  uint32_t version_supported = 0;
  uint32_t max_command_len = 0;
};

/** Result of the Sahara handshake. */
struct HandshakeResult {
  bool ok = false;
  HelloInfo device_hello;
  std::string error;
};

/** Result of a programmer image transfer. */
struct WriteResult {
  bool ok = false;
  uint32_t end_image_tx_status = 0;
  uint64_t bytes_sent = 0;
  std::string error;
};

/** Result of a DONE exchange. */
struct DoneResult {
  bool ok = false;
  uint32_t status = 0;  // 0 = success, 1 = pending (device resets)
  std::string error;
};

using ProgressCallback = std::function<void(uint64_t bytes_sent, uint64_t total)>;

/**
 * Sahara protocol engine. Owns packet framing, command parsing and the
 * image-transfer state machine. Transport-agnostic.
 */
class SaharaEngine {
 public:
  explicit SaharaEngine(IUsbTransport& transport) : transport_(transport) {}

  /**
   * Waits for the device's SAHARA_HELLO packet and replies with a
   * SAHARA_HELLO_RESPONSE accepting the device's protocol version.
   */
  bool Handshake(HandshakeResult& result, int timeout_ms);

  /**
   * Executes the READ_DATA / END_IMAGE_TX cycle to transfer a
   * programmer image to the device.
   */
  bool WriteImage(uint32_t image_id, const uint8_t* data, size_t len,
                  const ProgressCallback& progress, int timeout_ms,
                  WriteResult& result);

  /** Sends SAHARA_DONE and reads the response. */
  bool Done(int timeout_ms, DoneResult& result);

  /** Sends SAHARA_RESET and reads the response. */
  bool Reset(int timeout_ms, std::string& error);

  /** Serializes a HELLO_RESPONSE packet accepting the given parameters. */
  static Packet MakeHelloResponse(uint32_t version, uint32_t version_supported,
                                  uint32_t max_command_len, uint32_t mode);

  /** Reads one framed packet from the transport. */
  bool ReadPacket(Packet& packet, int timeout_ms, std::string& error);

  /** Writes a full packet to the transport. */
  bool WritePacket(const Packet& packet, int timeout_ms, std::string& error);

 private:
  bool ReadExactly(uint8_t* buffer, size_t len, int timeout_ms,
                   std::string& error);

  IUsbTransport& transport_;
  uint32_t max_command_len_ = 1024;
};

}  // namespace sahara
}  // namespace qfildroid
