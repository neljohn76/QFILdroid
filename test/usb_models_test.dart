import 'package:flutter_test/flutter_test.dart';
import 'package:qfildroid/models/usb_device_info.dart';
import 'package:qfildroid/services/edl_identifier.dart';

UsbDeviceInfo deviceFromMap(Map<Object?, Object?> map) =>
    UsbDeviceInfo.fromMap(map);

Map<Object?, Object?> edlMap() => {
      'deviceName': 'usb1',
      'vendorId': 0x05C6,
      'productId': 0x9008,
      'hasPermission': false,
      'manufacturerName': 'Qualcomm',
      'productName': 'QDLoader 9008',
      'interfaces': [
        {
          'id': 0,
          'class': 0xFF,
          'subclass': 0xFF,
          'protocol': 0xFF,
          'endpoints': [
            {
              'endpointNumber': 1,
              'direction': 'in',
              'type': 'bulk',
              'maxPacketSize': 512,
            },
            {
              'endpointNumber': 2,
              'direction': 'out',
              'type': 'bulk',
              'maxPacketSize': 512,
            },
          ],
        },
      ],
    };

void main() {
  group('UsbDeviceInfo parsing', () {
    test('parses full native map', () {
      final device = deviceFromMap(edlMap());
      expect(device.deviceName, 'usb1');
      expect(device.vendorId, 0x05C6);
      expect(device.productId, 0x9008);
      expect(device.idString, '05C6:9008');
      expect(device.interfaces, hasLength(1));
      expect(device.interfaces.first.endpoints, hasLength(2));
      expect(device.hasBulkPair, isTrue);
    });

    test('parses map with missing optional fields', () {
      final device = deviceFromMap({
        'deviceName': 'usb2',
        'vendorId': 0x1D6B,
        'productId': 0x0102,
        'hasPermission': true,
        'interfaces': [],
      });
      expect(device.productName, isNull);
      expect(device.interfaces, isEmpty);
      expect(device.hasBulkPair, isFalse);
      expect(device.idString, '1D6B:0102');
    });

    test('endpoint direction and bulk classification', () {
      final device = deviceFromMap(edlMap());
      final endpoints = device.interfaces.first.endpoints;
      expect(endpoints[0].isBulk, isTrue);
      expect(endpoints[0].isIn, isTrue);
      expect(endpoints[1].isOut, isTrue);
      expect(endpoints[1].isBulk, isTrue);
    });
  });

  group('EDL identification', () {
    test('05C6:9008 is an EDL candidate', () {
      final device = deviceFromMap(edlMap());
      expect(EdlIdentifier.isEdlCandidate(device), isTrue);
    });

    test('other Qualcomm PID is not an EDL candidate', () {
      final device = deviceFromMap({
        ...edlMap(),
        'productId': 0x6000, // diagnostic mode, not EDL
      });
      expect(EdlIdentifier.isEdlCandidate(device), isFalse);
    });

    test('non-Qualcomm VID is never an EDL candidate', () {
      final device = deviceFromMap({
        ...edlMap(),
        'vendorId': 0x18D1,
        'productId': 0x9008,
      });
      expect(EdlIdentifier.isEdlCandidate(device), isFalse);
    });

    test('describe explains mismatch reasons', () {
      final wrongPid = deviceFromMap({...edlMap(), 'productId': 0x6000});
      expect(EdlIdentifier.describe(wrongPid), contains('not a known EDL'));
      final wrongVid = deviceFromMap({...edlMap(), 'vendorId': 0x1234});
      expect(EdlIdentifier.describe(wrongVid), contains('not a Qualcomm'));
    });
  });
}
