#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "usb_transport.h"

namespace qfildroid {
namespace firehose {

/** Parsed Firehose XML response. */
struct Response {
  bool ack = false;
  bool parsed = false;
  std::string raw;
  std::vector<std::string> logs;
  std::string error;
  std::string value;  // raw "value" attribute of <response>
};

/** Parsed fields of a Firehose <storage_info> response. */
struct StorageInfo {
  bool ok = false;
  uint32_t sector_size = 0;
  uint64_t total_blocks = 0;
  uint64_t block_size = 0;
  std::string memory_name;
  std::string error;
};

/**
 * Firehose protocol engine: XML command generation and response parsing.
 * Transport-agnostic; one XML command is written per exchange and the
 * response is read back until a <response> element is seen.
 */
class FirehoseEngine {
 public:
  explicit FirehoseEngine(IUsbTransport& transport) : transport_(transport) {}

  /** Builds a <configure> command. */
  static std::string BuildConfigure(const std::string& memory_name,
                                    uint32_t sector_size,
                                    uint32_t max_payload_bytes);

  /** Builds a <program> command for a sector range. */
  static std::string BuildProgram(uint32_t sector_size,
                                  uint64_t start_sector,
                                  uint64_t num_sectors,
                                  uint32_t physical_partition,
                                  const std::string& filename);

  /** Builds an <erase> command for a sector range. */
  static std::string BuildErase(uint32_t sector_size, uint64_t start_sector,
                                uint64_t num_sectors,
                                uint32_t physical_partition);

  /** Builds a <readback> command (partition backup). */
  static std::string BuildReadback(uint32_t sector_size, uint64_t start_sector,
                                   uint64_t num_sectors,
                                   uint32_t physical_partition,
                                   const std::string& filename);

  /** Builds a <getstorageinfo> command. */
  static std::string BuildGetStorageInfo();

  /** Builds a <nop> ping command. */
  static std::string BuildNop();

  /**
   * Sends one XML command and reads the response. Reads until a
   * <response .../> element is parsed or the timeout budget is exhausted.
   */
  bool SendCommand(const std::string& xml, int timeout_ms, Response& response);

  /** Parses a Firehose XML response chunk. */
  static Response ParseResponse(const std::string& xml);

  /** Extracts storage info fields from a getstorageinfo response. */
  static StorageInfo ParseStorageInfo(const std::string& xml);

 private:
  bool ReadResponse(int timeout_ms, Response& response);

  IUsbTransport& transport_;
  static constexpr uint32_t kMaxResponseBytes = 1024 * 1024;
};

}  // namespace firehose
}  // namespace qfildroid
