# QFILdroid Architecture

## Layering

```
+----------------------------------------------------------+
| Flutter UI (lib/screens, lib/widgets)                    |
|   Material 3, dark technician theme                      |
+----------------------------------------------------------+
| State (lib/providers)                                    |
|   DeviceProvider: connection stage state machine         |
+----------------------------------------------------------+
| Services (lib/services)                                  |
|   UsbService        ProtocolService      LogService      |
|        |                  |                  |           |
|  MethodChannel      MethodChannel       in-memory ring   |
|  "com.qfildroid/usb" "com.qfildroid/protocol"  buffer    |
|  EventChannel                                           |
|  "com.qfildroid/events"                                 |
+----------------------------------------------------------+
| Kotlin (android/.../kotlin)                              |
|   MainActivity      UsbHostManager     ProtocolBridge    |
|   channel wiring    UsbManager,        JNI declarations  |
|                     permissions,                         |
|                     bulk endpoints                       |
+----------------------------------------------------------+
| C++ engine (android/.../cpp)                             |
|   qfildroid_jni.cpp   JNI glue, JniUsbTransport          |
|   sahara.{h,cpp}      packet framing + state machine     |
|   firehose.{h,cpp}    XML build/parse + response loop    |
|   usb_transport.{h,cpp} IUsbTransport abstraction        |
+----------------------------------------------------------+
| Android USB Host API (bulk endpoint transfers)           |
+----------------------------------------------------------+
```

## Key Decisions

### USB transport is separated from protocol logic

The C++ engines depend only on `IUsbTransport` (write/read with timeout).
On Android, `JniUsbTransport` forwards bulk transfers through JNI to
Kotlin (`NativeUsbBridge` -> `UsbHostManager` -> `UsbManager.bulkTransfer`).
The engines never touch file descriptors. In host tests,
`LoopbackTransport` scripts device responses, which is why the protocol
engines are unit-testable off-device.

### VID/PID is a candidate signal, never proof

`EdlIdentifier` (Dart) matches VID 05C6 against known EDL PIDs
(9008/900E/901D). Matching only sets the `edlCandidateDetected` stage. The
`protocolConnected` stage is reached exclusively after the C++ Sahara
engine receives a valid SAHARA_HELLO packet and answers it — i.e. the
device actually spoke the protocol.

### Connection stage is an explicit state machine

`ConnectionStage` mirrors the QFIL-style states (Disconnected ... Operation
Completed) and the provider only advances states on verified conditions:
permission grants arrive from the Android permission broadcast, handshake
results from the native engine, programmer validation from END_IMAGE_TX
status 0.

### Strict firmware parsing

`FirmwareXmlParser` collects per-entry errors instead of throwing; entries
with missing/invalid geometry are dropped, and a plan built from a package
with errors cannot execute. `FlashPlanner` enforces storage boundaries,
sector-size match, and file availability, and flags overlapping writes.

### Dry-run by default

`FlashPlanner.plan(dryRun:)` defaults to true in the UI. Non-dry-run
execution additionally requires a verified protocol connection; storage
writes are only ever issued as explicit Firehose <program> commands after
the staged workflow completes.

## Native engine testability

`android/app/src/main/cpp/tests/` builds the engine on the host with CMake
and runs scripted-transport tests for packet framing, handshake, image
transfer, DONE/RESET, XML building/response parsing and storage info
parsing. These tests run anywhere with a C++17 compiler:

```bash
cd android/app/src/main/cpp/tests
cmake -S . -B build && cmake --build build && ./build/engine_tests
```
