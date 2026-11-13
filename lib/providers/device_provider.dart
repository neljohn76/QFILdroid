import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/connection_stage.dart';
import '../models/log_entry.dart';
import '../models/usb_device_info.dart';
import '../services/edl_identifier.dart';
import '../services/log_service.dart';
import '../services/protocol_service.dart';
import '../services/usb_service.dart';

/// Central device/protocol state: USB enumeration, permissions, EDL
/// candidate detection, Sahara handshake and programmer validation.
///
/// The stage never advances past a condition that has not actually been
/// verified on the device.
class DeviceProvider extends ChangeNotifier {
  DeviceProvider({
    required UsbService usbService,
    required ProtocolService protocolService,
    required LogService logService,
  })  : _usb = usbService,
        _protocol = protocolService,
        _log = logService {
    _usbSubscription = _usb.events.listen(_onUsbEvent);
  }

  final UsbService _usb;
  final ProtocolService _protocol;
  final LogService _log;

  StreamSubscription<Map<Object?, Object?>>? _usbSubscription;

  ConnectionStage _stage = ConnectionStage.disconnected;
  List<UsbDeviceInfo> _devices = <UsbDeviceInfo>[];
  UsbDeviceInfo? _selectedDevice;
  bool _opened = false;
  Map<Object?, Object?>? _handshake;
  Map<Object?, Object?>? _programmerResult;
  bool _busy = false;

  ConnectionStage get stage => _stage;
  List<UsbDeviceInfo> get devices => List.unmodifiable(_devices);
  UsbDeviceInfo? get selectedDevice => _selectedDevice;
  bool get isOpen => _opened;
  Map<Object?, Object?>? get handshake => _handshake;
  Map<Object?, Object?>? get programmerResult => _programmerResult;
  bool get busy => _busy;

  bool get isEdlCandidate =>
      _selectedDevice != null && EdlIdentifier.isEdlCandidate(_selectedDevice!);

  String get edlStatusText => _selectedDevice == null
      ? 'No device selected'
      : EdlIdentifier.describe(_selectedDevice!);

  /// Native protocol engine version ('engine not loaded' when absent).
  Future<String> engineVersion() => _protocol.engineVersion();

  /// Writes a diagnostic report via the platform layer.
  Future<Map<Object?, Object?>> exportReport(String content) =>
      _usb.exportLogs(content);

  Future<void> refreshDevices() async {
    try {
      _devices = await _usb.listDevices();
      _log.info(
        LogCategory.usb,
        'Enumerated ${_devices.length} USB device(s)',
      );
      if (_devices.isEmpty) {
        _selectedDevice = null;
        _resetProtocolState();
        _opened = false;
        _stage = ConnectionStage.disconnected;
      } else {
        _selectedDevice ??= _devices.first;
        if (_stage == ConnectionStage.disconnected) {
          _stage = _selectedDevice!.hasPermission
              ? ConnectionStage.usbConnected
              : ConnectionStage.permissionRequired;
        }
        if (isEdlCandidate &&
            _stage.index <= ConnectionStage.usbConnected.index) {
          _stage = ConnectionStage.edlCandidateDetected;
        }
      }
      notifyListeners();
    } catch (e) {
      _log.error(LogCategory.usb, 'Device enumeration failed: $e');
    }
  }

  Future<void> selectDevice(String deviceName) async {
    final device = _devices.firstWhere(
      (d) => d.deviceName == deviceName,
      orElse: () => _devices.first,
    );
    _selectedDevice = device;
    _resetProtocolState();
    _opened = false;
    _stage = device.hasPermission
        ? ConnectionStage.usbConnected
        : ConnectionStage.permissionRequired;
    if (isEdlCandidate) {
      _stage = ConnectionStage.edlCandidateDetected;
    }
    notifyListeners();
  }

  Future<void> requestPermission() async {
    final device = _selectedDevice;
    if (device == null) return;
    _log.info(
      LogCategory.usb,
      'Requesting USB permission for ${device.displayName} (${device.idString})',
    );
    await _usb.requestPermission(device.deviceName);
  }

  /// Opens the device and performs the Sahara handshake.
  Future<void> connectEdl({int timeoutMs = 5000}) async {
    final device = _selectedDevice;
    if (device == null || _busy) return;
    _busy = true;
    notifyListeners();

    try {
      if (!await _usb.hasPermission(device.deviceName)) {
        _stage = ConnectionStage.permissionRequired;
        _log.warning(LogCategory.usb, 'USB permission not granted yet');
        return;
      }

      final open = await _usb.openDevice(device.deviceName);
      if (open['ok'] != true) {
        _stage = ConnectionStage.edlCandidateDetected;
        _log.error(LogCategory.usb, 'Failed to open device: ${open['error']}');
        return;
      }
      _opened = true;
      _log.info(
        LogCategory.usb,
        'Device opened: interface ${open['interfaceId']}, '
        'bulk in EP${open['bulkInEndpoint']}, bulk out EP${open['bulkOutEndpoint']}',
      );

      final handshake = await _protocol.saharaHandshake(
        device.deviceName,
        timeoutMs: timeoutMs,
      );
      _handshake = handshake;
      if (handshake['ok'] == true) {
        _stage = ConnectionStage.protocolConnected;
        _log.info(
          LogCategory.sahara,
          'Handshake succeeded: protocol version ${handshake['version']}, '
          'EDL mode confirmed',
        );
      } else {
        _stage = ConnectionStage.edlCandidateDetected;
        _log.error(
            LogCategory.sahara, 'Handshake failed: ${handshake['error']}');
      }
    } catch (e) {
      _stage = ConnectionStage.operationFailed;
      _log.error(LogCategory.sahara, 'EDL connect error: $e');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Transfers the selected programmer over Sahara (image ID 13).
  Future<bool> sendProgrammer(Uint8List programmerBytes) async {
    final device = _selectedDevice;
    if (device == null || !_opened || _busy) return false;
    if (_stage != ConnectionStage.protocolConnected) {
      _log.warning(
        LogCategory.sahara,
        'Programmer transfer blocked: no verified protocol connection',
      );
      return false;
    }
    _busy = true;
    _stage = ConnectionStage.operationInProgress;
    notifyListeners();

    try {
      _log.info(
        LogCategory.sahara,
        'Transferring programmer (${programmerBytes.length} bytes, image ID 13)',
      );
      final result = await _protocol.saharaWriteImage(
        device.deviceName,
        13,
        programmerBytes,
      );
      _programmerResult = result;
      if (result['ok'] == true) {
        _stage = ConnectionStage.programmerValidated;
        _log.info(
          LogCategory.sahara,
          'Programmer transferred: ${result['bytesSent']} bytes, '
          'END_IMAGE_TX status 0',
        );
        return true;
      }
      _stage = ConnectionStage.operationFailed;
      _log.error(
        LogCategory.sahara,
        'Programmer transfer failed: ${result['error']}',
      );
      return false;
    } catch (e) {
      _stage = ConnectionStage.operationFailed;
      _log.error(LogCategory.sahara, 'Programmer transfer error: $e');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Sends a Firehose XML command (programmer must be validated first).
  Future<Map<Object?, Object?>?> sendFirehoseCommand(
    String xml, {
    int timeoutMs = 30000,
  }) async {
    final device = _selectedDevice;
    if (device == null || !_opened) return null;
    if (_stage != ConnectionStage.programmerValidated &&
        _stage != ConnectionStage.readyForAuthorizedOperation &&
        _stage != ConnectionStage.protocolConnected) {
      _log.warning(
        LogCategory.firehose,
        'Firehose command blocked: programmer not validated',
      );
      return null;
    }
    _log.debug(LogCategory.firehose, 'TX: $xml');
    final result = await _protocol.firehoseCommand(
      device.deviceName,
      xml,
      timeoutMs: timeoutMs,
    );
    final logs = (result['logs'] as List<Object?>?) ?? const [];
    for (final line in logs) {
      _log.info(LogCategory.firehose, 'Device: $line');
    }
    if (result['ok'] == true) {
      _log.info(LogCategory.firehose, 'Command acknowledged (ACK)');
    } else {
      _log.error(
        LogCategory.firehose,
        'Command not acknowledged: ${result['error']}',
      );
    }
    return result;
  }

  Future<void> disconnect() async {
    final device = _selectedDevice;
    if (device != null && _opened) {
      try {
        await _usb.closeDevice(device.deviceName);
      } catch (_) {}
    }
    _opened = false;
    _resetProtocolState();
    _stage = _selectedDevice == null
        ? ConnectionStage.disconnected
        : (isEdlCandidate
            ? ConnectionStage.edlCandidateDetected
            : ConnectionStage.usbConnected);
    _log.info(LogCategory.usb, 'Device closed');
    notifyListeners();
  }

  void _onUsbEvent(Map<Object?, Object?> event) {
    final type = event['type'] as String?;
    final deviceName = event['deviceName'] as String?;
    switch (type) {
      case 'attached':
        _log.info(LogCategory.usb, 'USB device attached: $deviceName');
        refreshDevices();
        break;
      case 'detached':
        _log.warning(LogCategory.usb, 'USB device detached: $deviceName');
        if (_selectedDevice?.deviceName == deviceName) {
          _opened = false;
          _resetProtocolState();
          _stage = ConnectionStage.disconnected;
        }
        refreshDevices();
        break;
      case 'permission':
        final granted = event['granted'] as bool? ?? false;
        if (granted) {
          _log.info(LogCategory.usb, 'USB permission granted: $deviceName');
          refreshDevices();
        } else {
          _log.warning(LogCategory.usb, 'USB permission denied: $deviceName');
          if (_selectedDevice?.deviceName == deviceName) {
            _stage = ConnectionStage.permissionRequired;
          }
          notifyListeners();
        }
        break;
      default:
        break;
    }
  }

  void _resetProtocolState() {
    _handshake = null;
    _programmerResult = null;
  }

  @override
  void dispose() {
    _usbSubscription?.cancel();
    super.dispose();
  }
}
