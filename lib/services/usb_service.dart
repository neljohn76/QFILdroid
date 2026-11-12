import 'dart:async';

import 'package:flutter/services.dart';

import '../models/usb_device_info.dart';

/// Dart facade for the Android USB Host layer.
///
/// Wraps MethodChannel "com.qfildroid/usb" and EventChannel
/// "com.qfildroid/events". No protocol logic lives here.
class UsbService {
  static const MethodChannel _channel = MethodChannel('com.qfildroid/usb');
  static const EventChannel _eventChannel =
      EventChannel('com.qfildroid/events');

  Stream<Map<Object?, Object?>>? _events;

  /// Stream of USB events:
  /// {type: attached|detached|permission, deviceName, granted?}.
  Stream<Map<Object?, Object?>> get events {
    _events ??= _eventChannel.receiveBroadcastStream().map(
          (event) =>
              event is Map ? event.cast<Object?, Object?>() : <Object?, Object?>{},
        );
    return _events!;
  }

  /// Lists all attached USB devices with interface/endpoint details.
  Future<List<UsbDeviceInfo>> listDevices() async {
    final raw = await _channel.invokeMethod<List<Object?>>('listDevices');
    return (raw ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(UsbDeviceInfo.fromMap)
        .toList(growable: false);
  }

  Future<UsbDeviceInfo?> deviceInfo(String deviceName) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'deviceInfo',
      {'deviceName': deviceName},
    );
    return raw == null ? null : UsbDeviceInfo.fromMap(raw);
  }

  Future<bool> hasPermission(String deviceName) async {
    return (await _channel.invokeMethod<bool>(
          'hasPermission',
          {'deviceName': deviceName},
        )) ??
        false;
  }

  /// Triggers the Android USB permission dialog. The outcome arrives on the
  /// events stream as a "permission" event.
  Future<void> requestPermission(String deviceName) async {
    await _channel.invokeMethod<void>(
      'requestPermission',
      {'deviceName': deviceName},
    );
  }

  /// Opens the device and claims its bulk interface. Returns the native
  /// result map ({ok, error?, interfaceId?, bulkInEndpoint?, ...}).
  Future<Map<Object?, Object?>> openDevice(String deviceName) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'openDevice',
      {'deviceName': deviceName},
    );
    return raw ?? {'ok': false, 'error': 'null result from native layer'};
  }

  Future<void> closeDevice(String deviceName) async {
    await _channel.invokeMethod<void>(
      'closeDevice',
      {'deviceName': deviceName},
    );
  }

  /// Writes a diagnostic report to app-specific external storage.
  /// Returns {ok, path} or {ok: false, error}.
  Future<Map<Object?, Object?>> exportLogs(String content) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'exportLogs',
      {'content': content},
    );
    return raw ?? {'ok': false, 'error': 'null result from native layer'};
  }
}
