#include <deque>
#include <string>
#include <vector>

#include "firehose.h"
#include "test_main.h"
#include "usb_transport.h"

using namespace qfildroid::firehose;
using qfildroid::LoopbackTransport;

namespace {

std::string AckResponse() {
  return "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
         "<data>\n<response value=\"ACK\" rawstatus=\"true\" />\n</data>";
}

std::string NakResponse() {
  return "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
         "<data>\n<response value=\"NAK\" />\n</data>";
}

}  // namespace

QFIL_TEST(BuildConfigureContainsRequiredAttributes) {
  std::string xml = FirehoseEngine::BuildConfigure("ufs", 4096, 1048576);
  QFIL_ASSERT(xml.find("MemoryName=\"ufs\"") != std::string::npos);
  QFIL_ASSERT(xml.find("SectorSizeInBytes=\"4096\"") != std::string::npos);
  QFIL_ASSERT(xml.find("MaxPayloadSizeToTargetInBytes=\"1048576\"") !=
              std::string::npos);
  QFIL_ASSERT(xml.find("<configure") != std::string::npos);
}

QFIL_TEST(BuildProgramContainsSectorGeometry) {
  std::string xml =
      FirehoseEngine::BuildProgram(4096, 12345, 678, 1, "boot_a.img");
  QFIL_ASSERT(xml.find("SECTOR_SIZE_IN_BYTES=\"4096\"") != std::string::npos);
  QFIL_ASSERT(xml.find("num_partition_sectors=\"678\"") != std::string::npos);
  QFIL_ASSERT(xml.find("start_sector=\"12345\"") != std::string::npos);
  QFIL_ASSERT(xml.find("physical_partition_number=\"1\"") != std::string::npos);
  QFIL_ASSERT(xml.find("filename=\"boot_a.img\"") != std::string::npos);
}

QFIL_TEST(BuildReadbackAndEraseCarryGeometry) {
  std::string rb =
      FirehoseEngine::BuildReadback(512, 100, 50, 0, "backup.bin");
  QFIL_ASSERT(rb.find("<readback") != std::string::npos);
  QFIL_ASSERT(rb.find("start_sector=\"100\"") != std::string::npos);
  std::string erase = FirehoseEngine::BuildErase(512, 100, 50, 0);
  QFIL_ASSERT(erase.find("<erase") != std::string::npos);
}

QFIL_TEST(XmlEscapingPreventsInjection) {
  std::string xml = FirehoseEngine::BuildProgram(
      512, 0, 1, 0, "evil\"/><erase/>\".img");
  QFIL_ASSERT(xml.find("<erase/>") == std::string::npos);
  QFIL_ASSERT(xml.find("&quot;") != std::string::npos);
}

QFIL_TEST(ParseResponseDetectsAck) {
  Response response = FirehoseEngine::ParseResponse(AckResponse());
  QFIL_ASSERT(response.parsed);
  QFIL_ASSERT(response.ack);
  QFIL_ASSERT(response.value == "ACK");
}

QFIL_TEST(ParseResponseDetectsNak) {
  Response response = FirehoseEngine::ParseResponse(NakResponse());
  QFIL_ASSERT(response.parsed);
  QFIL_ASSERT(!response.ack);
  QFIL_ASSERT(response.value == "NAK");
}

QFIL_TEST(ParseResponseCollectsLogEntries) {
  std::string xml =
      "<?xml version=\"1.0\" ?><data>"
      "<log value=\"INFO\" />"
      "<log value=\"Starting erase\" />"
      "<response value=\"ACK\" /></data>";
  Response response = FirehoseEngine::ParseResponse(xml);
  QFIL_ASSERT(response.ack);
  QFIL_ASSERT(response.logs.size() == 2);
  QFIL_ASSERT(response.logs[1] == "Starting erase");
}

QFIL_TEST(ParseResponseRejectsGarbage) {
  Response response = FirehoseEngine::ParseResponse("not xml at all");
  QFIL_ASSERT(!response.parsed);
  QFIL_ASSERT(!response.error.empty());
}

QFIL_TEST(SendCommandWritesXmlAndReadsAck) {
  LoopbackTransport transport(
      {std::vector<uint8_t>(AckResponse().begin(), AckResponse().end())});
  FirehoseEngine engine(transport);
  Response response;
  QFIL_ASSERT(engine.SendCommand(FirehoseEngine::BuildNop(), 1000, response));
  QFIL_ASSERT(response.ack);
  QFIL_ASSERT(transport.Writes().size() == 1);
  std::string written(transport.Writes()[0].begin(), transport.Writes()[0].end());
  QFIL_ASSERT(written.find("<nop value=\"ping\" />") != std::string::npos);
}

QFIL_TEST(SendCommandAccumulatesChunkedResponses) {
  std::string full = AckResponse();
  std::vector<uint8_t> first(full.begin(), full.begin() + 20);
  std::vector<uint8_t> second(full.begin() + 20, full.end());
  LoopbackTransport transport({first, second});
  FirehoseEngine engine(transport);
  Response response;
  QFIL_ASSERT(engine.SendCommand(FirehoseEngine::BuildNop(), 1000, response));
  QFIL_ASSERT(response.ack);
}

QFIL_TEST(SendCommandTimesOutCleanly) {
  LoopbackTransport transport({});
  FirehoseEngine engine(transport);
  Response response;
  QFIL_ASSERT(!engine.SendCommand(FirehoseEngine::BuildNop(), 10, response));
  QFIL_ASSERT(!response.ack);
  QFIL_ASSERT(response.error.find("no response from device") !=
              std::string::npos);
}

QFIL_TEST(ParseStorageInfoExtractsGeometry) {
  std::string xml =
      "<?xml version=\"1.0\" ?><data>"
      "<storage_info block_size=\"4096\" MemoryName=\"UFS\" "
      "prod_name=\"KLUDG4UHDE\" total_blocks=\"122880\" "
      "SectorSizeInBytes=\"4096\" />"
      "<response value=\"ACK\" /></data>";
  StorageInfo info = FirehoseEngine::ParseStorageInfo(xml);
  QFIL_ASSERT(info.ok);
  QFIL_ASSERT(info.sector_size == 4096);
  QFIL_ASSERT(info.total_blocks == 122880);
  QFIL_ASSERT(info.memory_name == "UFS");
}
