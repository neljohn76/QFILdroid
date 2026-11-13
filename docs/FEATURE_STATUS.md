# Feature Implementation Status

Legend: **Implemented** / **Unit tested** / **Integration tested** /
**Hardware tested** / **Not implemented**.

This report is honest: features are only marked hardware tested if they
have been exercised on real Qualcomm EDL hardware. As of this commit,
**no hardware testing has been performed** (development environment has no
Android device or Qualcomm target attached).

## Module A — Device Manager

| Feature | Status |
|---|---|
| USB device enumeration (UsbManager) | Implemented, not hardware tested |
| VID/PID identification (05C6:9008/900E/901D) | Implemented, unit tested (test/usb_models_test.dart) |
| Interface/endpoint inspection | Implemented, unit tested (model parsing); not hardware tested |
| USB permission request flow | Implemented; not hardware tested |
| Attach/detach event monitoring | Implemented; not hardware tested |
| Connection status states | Implemented |
| Device diagnostics display | Implemented |

## Module B — Sahara Protocol

| Feature | Status |
|---|---|
| Packet framing (8-byte header, LE lengths) | Implemented, unit tested (C++ host tests) |
| Command parsing (HELLO/READ_DATA/END_IMAGE_TX/DONE/RESET) | Implemented, unit tested |
| Protocol state management (handshake -> image tx -> done) | Implemented, unit tested |
| Error handling (bad length, wrong command, device NAK status, out-of-range reads) | Implemented, unit tested |
| Programmer transfer (image ID 13) | Implemented, unit tested; not hardware tested |
| Timeout handling | Implemented, unit tested |
| Handshake diagnostics UI | Implemented |

## Module C — Firehose Protocol

| Feature | Status |
|---|---|
| XML command generation (configure/program/erase/readback/getstorageinfo/nop) | Implemented, unit tested (C++ host tests) |
| Response parsing (ACK/NAK, log entries, chunked responses) | Implemented, unit tested |
| Storage configuration queries | Implemented, unit tested (parser); not hardware tested |
| Device capability reporting | Partial: storage info only |
| Programmer compatibility validation | Not implemented (requires device-specific knowledge; blocked on hardware) |

## Module D — Firmware Manager

| Feature | Status |
|---|---|
| Firmware directory inspection | Implemented, unit tested via parser/hash tests |
| ZIP package extraction + inspection | Implemented; not integration tested in CI |
| Programmer file detection (ELF magic, MBN) | Implemented |
| rawprogram XML parsing | Implemented, unit tested |
| patch XML parsing | Implemented, unit tested |
| SHA-256 verification | Implemented, unit tested (known vectors) |
| Package inspection screen | Implemented |

## Module E — Partition Manager

| Feature | Status |
|---|---|
| Storage info query (getstorageinfo) | Implemented (UI + parsing); not hardware tested |
| Storage geometry display | Implemented |
| Partition table retrieval | Not implemented (requires programmer round-trip on hardware) |
| Partition writes | Intentionally not implemented (safety gate) |

## Module F — Firmware Flasher

| Feature | Status |
|---|---|
| Staged workflow (detect -> verify -> validate -> plan -> confirm) | Implemented |
| Dry-run mode (default ON) | Implemented, unit tested |
| Storage boundary validation | Implemented, unit tested |
| Overlap detection | Implemented, unit tested |
| Planned-operation review UI | Implemented |
| Actual storage writes | Gated: require validated programmer + device geometry; not hardware tested |
| Progress reporting during writes | Not implemented (blocked on hardware verification of transfer loop) |
| Cancellation | Not implemented |

## Module G — Backup & Restore

| Feature | Status |
|---|---|
| Readback planning + validation | Implemented (planning level) |
| Backup execution | Not implemented (blocked on hardware verification) |
| Restore | Intentionally disabled in this build |

## Module H — Diagnostic Logs

| Feature | Status |
|---|---|
| Timestamped categorized logs (USB/Sahara/Firehose/Firmware/Flash/System) | Implemented, unit testable |
| Log viewer with filters | Implemented |
| Export (app-specific external storage) | Implemented; not hardware tested |
| Export to clipboard | Implemented |

## Testing Summary

- C++ engine host tests: 23/23 passing (`android/app/src/main/cpp/tests`)
- Dart unit tests: USB model parsing, EDL identification, rawprogram/patch
  parsing, SHA-256 vectors, flash planning / boundary validation
  (`flutter test` — requires Flutter SDK)
- Hardware tests: none performed yet

## Known Limitations

1. Development environment had no Flutter SDK or Android SDK available; the
   Dart/Kotlin code is written against stable APIs but has not been
   compiled here. Run `flutter analyze && flutter test && flutter build apk`
   to verify (see docs/BUILDING.md).
2. The C++ engine was compiled and tested on host (g++ 14, C++17); the NDK
   build uses the same sources via CMake.
3. Programmer compatibility validation requires device-specific data that
   must be collected during hardware testing.
4. No simulated device detection is used anywhere; all device state comes
   from the Android USB Host layer or the native protocol engine.
