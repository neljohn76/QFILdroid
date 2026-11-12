import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qfildroid/services/firmware/hash_service.dart';

void main() {
  group('SHA-256', () {
    test('known vector: empty input', () {
      expect(
        HashService.sha256Bytes([]),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('known vector: abc', () {
      expect(
        HashService.sha256Text('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('file hashing matches in-memory hashing', () async {
      final dir = await Directory.systemTemp.createTemp('qfildroid_test');
      final file = File('${dir.path}/sample.bin');
      final bytes = List<int>.generate(100000, (i) => i % 251);
      await file.writeAsBytes(bytes);

      final fileHash = await HashService.sha256File(file.path);
      final memoryHash = HashService.sha256Bytes(bytes);
      expect(fileHash, memoryHash);

      await dir.delete(recursive: true);
    });

    test('verify compares digests', () {
      const a = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
      expect(HashService.verify(a, a), isTrue);
      expect(HashService.verify(a, a.substring(1)), isFalse);
      expect(HashService.verify(a, a.toUpperCase()), isFalse);
    });

    test('sha256File throws for missing file', () async {
      expect(
        () => HashService.sha256File('/nonexistent/file.bin'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
