# QFILdroid

No-PC required, QFIL implementation for Android.

QFILdroid is an Android-based Qualcomm firmware servicing workstation: a
Flutter (Material 3) frontend on top of a Kotlin USB Host layer and a C++
(NDK) protocol engine implementing the Qualcomm Sahara and Firehose
protocols over USB OTG / USB-C host connectivity.

## Status

This is an early foundation release. See
[docs/FEATURE_STATUS.md](docs/FEATURE_STATUS.md) for a precise, honest
breakdown of what is implemented, unit tested, hardware tested, and not
implemented.

**Nothing in this README claims hardware-verified flashing.** USB, Sahara
and Firehose logic are implemented and covered by automated host tests;
on-device behavior must be validated on real Qualcomm EDL hardware before
trusting any operation.

## Feature Overview

- USB device enumeration with full interface/endpoint diagnostics
- USB permission management and attach/detach monitoring
- Qualcomm EDL candidate detection (VID 05C6, PIDs 9008/900E/901D) —
  treated as a *candidate only*, confirmed exclusively by a successful
  Sahara handshake
- Sahara protocol engine in C++: packet framing, handshake, programmer
  image transfer (READ_DATA / END_IMAGE_TX), DONE/RESET handling
- Firehose protocol engine in C++: XML command generation, response
  parsing, storage info queries
- Firmware package inspection (directory or ZIP): programmers,
  rawprogram XML, patch XML, SHA-256 digests
- Strict rawprogram/patch XML parsing with per-entry validation
- Flash planning with storage-boundary validation, sector-size checks,
  overlap detection and **dry-run by default**
- Timestamped, categorized, exportable diagnostic logs

## Safety Policy

- Never flashes an unknown device: a verified Sahara handshake is required
  before any protocol connection is shown as established.
- Never uploads a programmer automatically; transfer is explicit.
- Never writes with unknown storage geometry; plans without device geometry
  are refused.
- Dry-run is the default for new firmware packages.
- No secure boot, authentication, or OEM authorization bypass. Only
  compatible devices and authorized programmers are supported.

## Building

Requires Flutter (stable, 3.22+), the Android SDK, and Android NDK r26+.
See [docs/BUILDING.md](docs/BUILDING.md).

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Project Layout

```
lib/            Flutter UI, services, providers, models
android/.../kotlin/   USB Host layer, protocol bridge, MainActivity
android/.../cpp/      C++ protocol engine (Sahara, Firehose, transport)
android/.../cpp/tests/ Host unit tests for the C++ engine
test/           Dart unit tests
docs/           Architecture, feature status, build instructions
firmware/       Working directory for firmware packages (not committed)
```

## License

Apache License 2.0. See [LICENSE](LICENSE).
