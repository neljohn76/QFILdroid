import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// SHA-256 verification helpers for firmware files and packages.
class HashService {
  const HashService._();

  /// Computes SHA-256 over a file by streaming it in chunks.
  static Future<String> sha256File(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File not found', path);
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      builder.add(chunk);
    }
    return sha256.convert(builder.takeBytes()).toString();
  }

  /// Computes SHA-256 over an in-memory byte sequence.
  static String sha256Bytes(List<int> bytes) => sha256.convert(bytes).toString();

  /// Computes SHA-256 over UTF-8 text.
  static String sha256Text(String text) =>
      sha256.convert(utf8.encode(text)).toString();

  /// Compares two hex digests.
  static bool verify(String expected, String actual) {
    if (expected.length != actual.length) return false;
    var mismatch = 0;
    for (var i = 0; i < expected.length; i++) {
      mismatch |= expected.codeUnitAt(i) ^ actual.codeUnitAt(i);
    }
    return mismatch == 0;
  }
}
