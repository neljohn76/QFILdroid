import 'package:flutter_test/flutter_test.dart';
import 'package:qfildroid/services/firmware/xml_parser.dart';

const validRawprogram = '''
<?xml version="1.0" encoding="UTF-8" ?>
<data>
  <program SECTOR_SIZE_IN_BYTES="4096" file_sector_offset="0"
      filename="boot_a.img" label="boot_a"
      num_partition_sectors="2048" partofsingleimage="false"
      physical_partition_number="4" start_sector="131072" />
  <program SECTOR_SIZE_IN_BYTES="4096"
      filename="persist.img"
      num_partition_sectors="8192"
      physical_partition_number="0" start_sector="8" />
</data>
''';

const validPatch = '''
<?xml version="1.0" ?>
<patches>
  <patch byte_offset="112" filename="DISK" SECTOR_SIZE_IN_BYTES="4096"
      physical_partition_number="0" start_sector="1"
      num_patch_sectors="1" value="0x0000000000000001" />
</patches>
''';

void main() {
  const parser = FirmwareXmlParser();

  group('rawprogram parsing', () {
    test('parses valid entries', () {
      final result = parser.parseRawprogram(validRawprogram);
      expect(result.isValid, isTrue);
      expect(result.entries, hasLength(2));

      final boot = result.entries.first;
      expect(boot.filename, 'boot_a.img');
      expect(boot.sectorSize, 4096);
      expect(boot.startSector, 131072);
      expect(boot.numSectors, 2048);
      expect(boot.physicalPartition, 4);
      expect(boot.label, 'boot_a');
      expect(boot.byteLength, 2048 * 4096);
    });

    test('rejects missing geometry attributes', () {
      final result = parser.parseRawprogram(
        '<data><program filename="x.img" start_sector="1"/></data>',
      );
      expect(result.isValid, isFalse);
      expect(result.entries, isEmpty);
      expect(result.errors.join(' '), contains('SECTOR_SIZE_IN_BYTES'));
    });

    test('rejects non-numeric values', () {
      final result = parser.parseRawprogram(
        '<data><program filename="x.img" SECTOR_SIZE_IN_BYTES="abc" '
        'start_sector="1" num_partition_sectors="1" '
        'physical_partition_number="0"/></data>',
      );
      expect(result.isValid, isFalse);
      expect(result.entries, isEmpty);
    });

    test('rejects zero sector size', () {
      final result = parser.parseRawprogram(
        '<data><program filename="x.img" SECTOR_SIZE_IN_BYTES="0" '
        'start_sector="1" num_partition_sectors="1" '
        'physical_partition_number="0"/></data>',
      );
      expect(result.isValid, isFalse);
      expect(result.errors.join(' '), contains('zero'));
    });

    test('reports malformed XML as error', () {
      final result = parser.parseRawprogram('<data><program');
      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('no program elements is an error', () {
      final result = parser.parseRawprogram('<data></data>');
      expect(result.isValid, isFalse);
      expect(result.errors.join(' '), contains('no <program>'));
    });
  });

  group('patch parsing', () {
    test('parses valid patch with byte offset padding', () {
      final result = parser.parsePatch(validPatch);
      expect(result.isValid, isTrue);
      expect(result.entries, hasLength(1));
      final patch = result.entries.first;
      // byte_offset 112 pads the 8-byte value to 120 bytes
      expect(patch.patchBytes, hasLength(120));
      expect(patch.patchBytes.sublist(112), [0, 0, 0, 0, 0, 0, 0, 1]);
    });

    test('rejects odd-length hex values', () {
      final result = parser.parsePatch(
        '<patches><patch byte_offset="0" SECTOR_SIZE_IN_BYTES="4096" '
        'physical_partition_number="0" start_sector="1" '
        'num_patch_sectors="1" value="0xABC"/></patches>',
      );
      expect(result.isValid, isFalse);
    });

    test('rejects payload larger than patch region', () {
      final result = parser.parsePatch(
        '<patches><patch byte_offset="0" SECTOR_SIZE_IN_BYTES="512" '
        'physical_partition_number="0" start_sector="1" '
        'num_patch_sectors="1" value="0x" '
        'filename="DISK"/></patches>'.replaceFirst('value="0x" ',
            'value="${'AA' * 600}" '),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.join(' '), contains('exceeds patch region'));
    });
  });
}
