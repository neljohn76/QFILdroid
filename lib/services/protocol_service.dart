import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Dart facade for the C++ protocol engine.
///
/// Wraps MethodChannel "com.qfildroid/protocol". All protocol framing and
/// state machines live in the native engine; this class only marshals calls.
class ProtocolService {
  static const MethodChannel _channel = MethodChannel('com.qfildroid/protocol');

  bool _isEngineMissing(PlatformException e) => e.code == 'ENGINE_MISSING';

  /// Version string of the loaded native engine.
  Future<String> engineVersion() async {
    try {
      return await _channel.invokeMethod<String>('engineVersion') ?? 'unknown';
    } on PlatformException catch (e) {
      if (_isEngineMissing(e)) return 'engine not loaded';
      rethrow;
    }
  }

  /// Performs the Sahara handshake. Returns {ok, version, versionSupported,
  /// maxCommandLen, error}.
  Future<Map<Object?, Object?>> saharaHandshake(
    String deviceName, {
    int timeoutMs = 5000,
  }) async {
    try {
      return (await _channel.invokeMethod<Map<Object?, Object?>>(
            'saharaHandshake',
            {'deviceName': deviceName, 'timeoutMs': timeoutMs},
          )) ??
          {'ok': false, 'error': 'null result from native layer'};
    } on PlatformException catch (e) {
      if (_isEngineMissing(e)) {
        return {'ok': false, 'error': 'native engine not loaded'};
      }
      rethrow;
    }
  }

  /// Transfers the programmer image over Sahara READ_DATA cycles.
  Future<Map<Object?, Object?>> saharaWriteImage(
    String deviceName,
    int imageId,
    Uint8List data, {
    int timeoutMs = 10000,
  }) async {
    try {
      return (await _channel.invokeMethod<Map<Object?, Object?>>(
            'saharaWriteImage',
            {
              'deviceName': deviceName,
              'imageId': imageId,
              'data': data,
              'timeoutMs': timeoutMs,
            },
          )) ??
          {'ok': false, 'error': 'null result from native layer'};
    } on PlatformException catch (e) {
      if (_isEngineMissing(e)) {
        return {'ok': false, 'error': 'native engine not loaded'};
      }
      rethrow;
    }
  }

  Future<Map<Object?, Object?>> saharaDone(
    String deviceName, {
    int timeoutMs = 5000,
  }) async {
    try {
      return (await _channel.invokeMethod<Map<Object?, Object?>>(
            'saharaDone',
            {'deviceName': deviceName, 'timeoutMs': timeoutMs},
          )) ??
          {'ok': false, 'error': 'null result from native layer'};
    } on PlatformException catch (e) {
      if (_isEngineMissing(e)) {
        return {'ok': false, 'error': 'native engine not loaded'};
      }
      rethrow;
    }
  }

  Future<Map<Object?, Object?>> saharaReset(
    String deviceName, {
    int timeoutMs = 5000,
  }) async {
    try {
      return (await _channel.invokeMethod<Map<Object?, Object?>>(
            'saharaReset',
            {'deviceName': deviceName, 'timeoutMs': timeoutMs},
          )) ??
          {'ok': false, 'error': 'null result from native layer'};
    } on PlatformException catch (e) {
      if (_isEngineMissing(e)) {
        return {'ok': false, 'error': 'native engine not loaded'};
      }
      rethrow;
    }
  }

  /// Sends a raw Firehose XML command. Returns {ok, parsed, response, logs,
  /// error}.
  Future<Map<Object?, Object?>> firehoseCommand(
    String deviceName,
    String xml, {
    int timeoutMs = 30000,
  }) async {
    try {
      return (await _channel.invokeMethod<Map<Object?, Object?>>(
            'firehoseCommand',
            {'deviceName': deviceName, 'xml': xml, 'timeoutMs': timeoutMs},
          )) ??
          {'ok': false, 'error': 'null result from native layer'};
    } on PlatformException catch (e) {
      if (_isEngineMissing(e)) {
        return {'ok': false, 'error': 'native engine not loaded'};
      }
      rethrow;
    }
  }
}
