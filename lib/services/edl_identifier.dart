import '../models/usb_device_info.dart';

/// Qualcomm EDL USB identification.
///
/// VID/PID matching is only ever a *candidate* signal: it cannot prove that a
/// device is actually in Emergency Download mode. A real protocol handshake
/// (Sahara HELLO) is required before any protocol connection is claimed.
class EdlIdentifier {
  const EdlIdentifier._();

  /// Qualcomm Technologies vendor ID.
  static const int qualcommVid = 0x05C6;

  /// Product IDs commonly reported by Qualcomm SoCs in EDL/9008 mode.
  static const Set<int> edlPids = {
    0x9008, // QDLoader HS-USB Diagnostics 9008 (most common EDL PID)
    0x900E, // HS-USB Diagnostics 900E (older EDL variants)
    0x901D, // EDL on some platforms
  };

  /// Returns true when the USB IDs match known Qualcomm EDL identifiers.
  /// This is a preliminary candidate signal only.
  static bool isEdlCandidate(UsbDeviceInfo device) =>
      device.vendorId == qualcommVid && edlPids.contains(device.productId);

  /// Human-readable explanation of the identification result, for logs.
  static String describe(UsbDeviceInfo device) {
    if (device.vendorId != qualcommVid) {
      return 'VID ${device.vendorIdHex} is not a Qualcomm EDL vendor ID '
          '(expected 05C6)';
    }
    if (!edlPids.contains(device.productId)) {
      return 'Qualcomm VID detected, but PID ${device.productIdHex} is not a '
          'known EDL product ID';
    }
    return 'Qualcomm EDL candidate detected (${device.idString}). '
        'A Sahara handshake is required to confirm EDL mode';
  }
}
