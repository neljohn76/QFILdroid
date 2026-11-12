#include "firehose.h"

#include <algorithm>
#include <cctype>

namespace qfildroid {
namespace firehose {

namespace {

std::string XmlEscape(const std::string& in) {
  std::string out;
  out.reserve(in.size());
  for (char c : in) {
    switch (c) {
      case '&': out += "&amp;"; break;
      case '<': out += "&lt;"; break;
      case '>': out += "&gt;"; break;
      case '"': out += "&quot;"; break;
      case '\'': out += "&apos;"; break;
      default: out += c;
    }
  }
  return out;
}

std::string ToLower(const std::string& in) {
  std::string out = in;
  std::transform(out.begin(), out.end(), out.begin(),
                 [](unsigned char c) { return std::tolower(c); });
  return out;
}

std::string GetAttribute(const std::string& element, const std::string& name) {
  std::string needle = name + "=\"";
  size_t pos = element.find(needle);
  if (pos == std::string::npos) return "";
  size_t start = pos + needle.size();
  size_t end = element.find('"', start);
  if (end == std::string::npos) return "";
  return element.substr(start, end - start);
}

/** Case-insensitive attribute lookup with fallback names. */
std::string GetAttributeAny(const std::string& block,
                            const std::vector<std::string>& names) {
  std::string lower = ToLower(block);
  for (const std::string& name : names) {
    std::string needle = ToLower(name) + "=\"";
    size_t pos = lower.find(needle);
    if (pos == std::string::npos) continue;
    size_t start = pos + needle.size();
    size_t end = block.find('"', start);
    if (end == std::string::npos) continue;
    return block.substr(start, end - start);
  }
  return "";
}

}  // namespace

std::string FirehoseEngine::BuildConfigure(const std::string& memory_name,
                                           uint32_t sector_size,
                                           uint32_t max_payload_bytes) {
  std::string xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
  xml += "<data>\n<configure MemoryName=\"" + XmlEscape(memory_name) +
         "\" ValidatePayloadBuffer=\"true\" SkipStorageInit=\"false\" "
         "SkipWrite=\"false\" SectorSizeInBytes=\"" +
         std::to_string(sector_size) + "\" MaxPayloadSizeToTargetInBytes=\"" +
         std::to_string(max_payload_bytes) + "\" />\n</data>";
  return xml;
}

std::string FirehoseEngine::BuildProgram(uint32_t sector_size,
                                         uint64_t start_sector,
                                         uint64_t num_sectors,
                                         uint32_t physical_partition,
                                         const std::string& filename) {
  std::string xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
  xml += "<data>\n<program SECTOR_SIZE_IN_BYTES=\"" +
         std::to_string(sector_size) + "\" num_partition_sectors=\"" +
         std::to_string(num_sectors) + "\" start_sector=\"" +
         std::to_string(start_sector) + "\" physical_partition_number=\"" +
         std::to_string(physical_partition) + "\" filename=\"" +
         XmlEscape(filename) + "\" />\n</data>";
  return xml;
}

std::string FirehoseEngine::BuildErase(uint32_t sector_size,
                                       uint64_t start_sector,
                                       uint64_t num_sectors,
                                       uint32_t physical_partition) {
  std::string xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
  xml += "<data>\n<erase SECTOR_SIZE_IN_BYTES=\"" +
         std::to_string(sector_size) + "\" num_partition_sectors=\"" +
         std::to_string(num_sectors) + "\" start_sector=\"" +
         std::to_string(start_sector) + "\" physical_partition_number=\"" +
         std::to_string(physical_partition) + "\" />\n</data>";
  return xml;
}

std::string FirehoseEngine::BuildReadback(uint32_t sector_size,
                                          uint64_t start_sector,
                                          uint64_t num_sectors,
                                          uint32_t physical_partition,
                                          const std::string& filename) {
  std::string xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
  xml += "<data>\n<readback SECTOR_SIZE_IN_BYTES=\"" +
         std::to_string(sector_size) + "\" num_partition_sectors=\"" +
         std::to_string(num_sectors) + "\" start_sector=\"" +
         std::to_string(start_sector) + "\" physical_partition_number=\"" +
         std::to_string(physical_partition) + "\" filename=\"" +
         XmlEscape(filename) + "\" />\n</data>";
  return xml;
}

std::string FirehoseEngine::BuildGetStorageInfo() {
  return "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
         "<data>\n<getstorageinfo rawstring=\"true\" />\n</data>";
}

std::string FirehoseEngine::BuildNop() {
  return "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
         "<data>\n<nop value=\"ping\" />\n</data>";
}

Response FirehoseEngine::ParseResponse(const std::string& xml) {
  Response response;
  response.raw = xml;

  size_t response_tag = xml.find("<response");
  if (response_tag == std::string::npos) {
    // Some responses only carry <log> entries.
    if (xml.find("<log") != std::string::npos) {
      response.parsed = true;
    } else {
      response.error = "no <response> element found";
    }
  } else {
    response.parsed = true;
    size_t tag_end = xml.find('>', response_tag);
    std::string element = tag_end == std::string::npos
                              ? xml.substr(response_tag)
                              : xml.substr(response_tag, tag_end - response_tag + 1);
    std::string value = GetAttribute(element, "value");
    response.value = value;
    response.ack = ToLower(value) == "ack";
    if (!response.ack && value.empty()) {
      response.error = "response element missing value attribute";
    }
  }

  size_t pos = 0;
  while (true) {
    size_t log_tag = xml.find("<log", pos);
    if (log_tag == std::string::npos) break;
    size_t open_end = xml.find('>', log_tag);
    if (open_end == std::string::npos) break;
    std::string element = xml.substr(log_tag, open_end - log_tag + 1);
    bool self_closing = !element.empty() && element[element.size() - 2] == '/';
    if (self_closing) {
      std::string value = GetAttribute(element, "value");
      if (!value.empty()) response.logs.push_back(value);
      pos = open_end + 1;
    } else {
      size_t close = xml.find("</log>", open_end);
      if (close == std::string::npos) break;
      response.logs.push_back(xml.substr(open_end + 1, close - open_end - 1));
      pos = close + 6;
    }
  }

  return response;
}

StorageInfo FirehoseEngine::ParseStorageInfo(const std::string& xml) {
  StorageInfo info;
  size_t tag = xml.find("<storage_info");
  if (tag == std::string::npos) {
    info.error = "no <storage_info> element found";
    return info;
  }
  size_t end = xml.find("</storage_info>", tag);
  std::string block = end == std::string::npos ? xml.substr(tag)
                                               : xml.substr(tag, end - tag);
  info.memory_name = GetAttributeAny(block, {"MemoryName", "memory_name"});
  info.sector_size = static_cast<uint32_t>(strtoull(
      GetAttributeAny(block, {"SectorSizeInBytes", "sector_size"}).c_str(),
      nullptr, 10));
  info.total_blocks = strtoull(
      GetAttributeAny(block, {"TotalBlocks", "total_blocks"}).c_str(),
      nullptr, 10);
  info.block_size =
      strtoull(GetAttributeAny(block, {"BlockSize", "block_size"}).c_str(),
               nullptr, 10);
  info.ok = info.sector_size > 0 && info.total_blocks > 0;
  if (!info.ok) {
    info.error = "storage info missing sector/block counts";
  }
  return info;
}

bool FirehoseEngine::ReadResponse(int timeout_ms, Response& response) {
  std::string accumulated;
  uint8_t buffer[4096];
  uint32_t budget = kMaxResponseBytes;

  while (budget > 0) {
    int n = transport_.Read(buffer, sizeof(buffer), timeout_ms);
    if (n <= 0) break;
    size_t take = static_cast<size_t>(n) < budget ? static_cast<size_t>(n) : budget;
    accumulated.append(reinterpret_cast<const char*>(buffer), take);
    budget -= static_cast<uint32_t>(take);

    Response parsed = ParseResponse(accumulated);
    if (parsed.parsed) {
      response = parsed;
      return true;
    }
  }

  response = ParseResponse(accumulated);
  if (!response.parsed) {
    response.error = accumulated.empty()
                         ? "no response from device (timeout)"
                         : "unterminated response: " + accumulated;
    return false;
  }
  return true;
}

bool FirehoseEngine::SendCommand(const std::string& xml, int timeout_ms,
                                 Response& response) {
  int written = transport_.Write(reinterpret_cast<const uint8_t*>(xml.data()),
                                 xml.size(), timeout_ms);
  if (written < 0 || static_cast<size_t>(written) != xml.size()) {
    response.error = "USB write failed (" + transport_.LastError() + ")";
    return false;
  }
  return ReadResponse(timeout_ms, response);
}

}  // namespace firehose
}  // namespace qfildroid
