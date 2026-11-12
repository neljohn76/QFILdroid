#include <deque>
#include <vector>

#include "test_main.h"
#include "sahara.h"

using namespace qfildroid::sahara;
using qfildroid::LoopbackTransport;

namespace {

void PutU32(std::vector<uint8_t>& out, uint32_t value) {
  out.push_back(static_cast<uint8_t>(value & 0xFF));
  out.push_back(static_cast<uint8_t>((value >> 8) & 0xFF));
  out.push_back(static_cast<uint8_t>((value >> 16) & 0xFF));
  out.push_back(static_cast<uint8_t>((value >> 24) & 0xFF));
}

std::vector<uint8_t> MakePacket(uint32_t command,
                                const std::vector<uint8_t>& payload) {
  std::vector<uint8_t> out;
  PutU32(out, command);
  PutU32(out, static_cast<uint32_t>(payload.size()) + 8);
  out.insert(out.end(), payload.begin(), payload.end());
  return out;
}

std::vector<uint8_t> MakeHello() {
  std::vector<uint8_t> payload(40, 0);
  payload[0] = 1;   // version = 1
  payload[4] = 1;   // version_supported = 1
  payload[8] = 48;  // max_command_len = 48
  return MakePacket(kHello, payload);
}

}  // namespace

QFIL_TEST(PacketSerializeMatchesQualcommFraming) {
  Packet packet;
  packet.command = kDone;
  packet.length = 8;
  auto bytes = packet.Serialize();
  QFIL_ASSERT(bytes.size() == 8);
  QFIL_ASSERT(bytes[0] == 0x05 && bytes[1] == 0x00);
  QFIL_ASSERT(bytes[4] == 0x08 && bytes[5] == 0x00);
}

QFIL_TEST(ReadPacketParsesHelloFields) {
  LoopbackTransport transport({MakeHello()});
  SaharaEngine engine(transport);
  std::string error;
  Packet packet;
  QFIL_ASSERT(engine.ReadPacket(packet, 1000, error));
  QFIL_ASSERT(packet.command == kHello);
  QFIL_ASSERT(packet.length == 48);
  QFIL_ASSERT(packet.payload.size() == 40);
  QFIL_ASSERT(packet.payload[0] == 1);
}

QFIL_TEST(ReadPacketRejectsInvalidLength) {
  std::vector<uint8_t> bad;
  PutU32(bad, kHello);
  PutU32(bad, 4);  // length below header size
  LoopbackTransport transport({bad});
  SaharaEngine engine(transport);
  std::string error;
  Packet packet;
  QFIL_ASSERT(!engine.ReadPacket(packet, 1000, error));
  QFIL_ASSERT(error.find("invalid packet length") != std::string::npos);
}

QFIL_TEST(HandshakeAcceptsDeviceHelloAndResponds) {
  LoopbackTransport transport({MakeHello()});
  SaharaEngine engine(transport);
  HandshakeResult result;
  QFIL_ASSERT(engine.Handshake(result, 1000));
  QFIL_ASSERT(result.ok);
  QFIL_ASSERT(result.device_hello.version == 1);
  QFIL_ASSERT(result.device_hello.version_supported == 1);
  QFIL_ASSERT(result.device_hello.max_command_len == 48);

  QFIL_ASSERT(transport.Writes().size() == 1);
  const auto& response = transport.Writes()[0];
  QFIL_ASSERT(response.size() == 48);
  QFIL_ASSERT(response[0] == 0x02);   // HELLO_RESPONSE
  QFIL_ASSERT(response[8] == 0x01);   // accepted version
  QFIL_ASSERT(response[20] == 0x00);  // mode = image transfer
}

QFIL_TEST(HandshakeFailsOnUnexpectedCommand) {
  std::vector<uint8_t> payload(4, 0);
  LoopbackTransport transport({MakePacket(kDone, payload)});
  SaharaEngine engine(transport);
  HandshakeResult result;
  QFIL_ASSERT(!engine.Handshake(result, 1000));
  QFIL_ASSERT(!result.ok);
  QFIL_ASSERT(result.error.find("expected SAHARA_HELLO") != std::string::npos);
}

QFIL_TEST(HandshakeTimesOutWithoutDevice) {
  LoopbackTransport transport({});
  SaharaEngine engine(transport);
  HandshakeResult result;
  QFIL_ASSERT(!engine.Handshake(result, 10));
  QFIL_ASSERT(result.error.find("USB read failed") != std::string::npos);
}

QFIL_TEST(WriteImageServesReadDataAndFinishes) {
  std::vector<uint8_t> image = {0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02, 0x03, 0x04};

  std::vector<uint8_t> read_payload(12, 0);
  read_payload[0] = 13;  // image_id = 13 (EDL programmer)
  read_payload[4] = 0;   // offset = 0
  read_payload[8] = 8;   // length = 8
  std::vector<uint8_t> end_payload(4, 0);  // status = 0

  LoopbackTransport transport(
      {MakePacket(kReadData, read_payload),
       MakePacket(kEndImageTx, end_payload)});
  SaharaEngine engine(transport);

  uint64_t observed_total = 0;
  WriteResult result;
  QFIL_ASSERT(engine.WriteImage(
      13, image.data(), image.size(),
      [&](uint64_t sent, uint64_t total) {
        observed_total = sent;
        QFIL_ASSERT(total == image.size());
      },
      1000, result));
  QFIL_ASSERT(result.ok);
  QFIL_ASSERT(result.bytes_sent == 8);
  QFIL_ASSERT(observed_total == 8);

  QFIL_ASSERT(transport.Writes().size() == 1);
  QFIL_ASSERT(transport.Writes()[0] == image);  // raw image bytes, no header
}

QFIL_TEST(WriteImageRejectsOutOfRangeRequest) {
  std::vector<uint8_t> image = {0x01, 0x02, 0x03, 0x04};
  std::vector<uint8_t> read_payload(12, 0);
  read_payload[0] = 13;  // image_id = 13 (EDL programmer)
  read_payload[8] = 100;  // length beyond image size
  LoopbackTransport transport({MakePacket(kReadData, read_payload)});
  SaharaEngine engine(transport);
  WriteResult result;
  QFIL_ASSERT(!engine.WriteImage(13, image.data(), image.size(), {}, 1000,
                                 result));
  QFIL_ASSERT(result.error.find("exceeds image size") != std::string::npos);
}

QFIL_TEST(WriteImageReportsDeviceFailureStatus) {
  std::vector<uint8_t> image = {0x01, 0x02};
  std::vector<uint8_t> end_payload = {0x05, 0x00, 0x00, 0x00};  // status 5
  LoopbackTransport transport({MakePacket(kEndImageTx, end_payload)});
  SaharaEngine engine(transport);
  WriteResult result;
  QFIL_ASSERT(!engine.WriteImage(13, image.data(), image.size(), {}, 1000,
                                 result));
  QFIL_ASSERT(result.error.find("failure status 5") != std::string::npos);
}

QFIL_TEST(DoneRoundTrip) {
  std::vector<uint8_t> done_resp_payload = {0x00, 0x00, 0x00, 0x00};
  LoopbackTransport transport({MakePacket(kDoneResponse, done_resp_payload)});
  SaharaEngine engine(transport);
  DoneResult result;
  QFIL_ASSERT(engine.Done(1000, result));
  QFIL_ASSERT(result.ok);
  QFIL_ASSERT(result.status == 0);
  QFIL_ASSERT(transport.Writes().size() == 1);
  QFIL_ASSERT(transport.Writes()[0][0] == 0x05);  // SAHARA_DONE
}

QFIL_TEST(ResetRoundTrip) {
  std::vector<uint8_t> payload(4, 0);
  LoopbackTransport transport({MakePacket(kResetResponse, payload)});
  SaharaEngine engine(transport);
  std::string error;
  QFIL_ASSERT(engine.Reset(1000, error));
  QFIL_ASSERT(transport.Writes()[0][0] == 0x07);  // SAHARA_RESET
}
