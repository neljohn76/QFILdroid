import 'dart:io';

import '../models/firmware/storage_info.dart';

/// Dart-side Firehose XML command builders.
///
/// These mirror the C++ engine builders and are used for planning,
/// display and unit tests. Actual wire transmission always goes through
/// the native engine (ProtocolService.firehoseCommand).
class FirehoseCommands {
  const FirehoseCommands._();

  static String _header() => '<?xml version="1.0" encoding="UTF-8" ?>\n<data>\n';

  static String configure({
    String memoryName = 'ufs',
    int sectorSize = 4096,
    int maxPayloadBytes = 1048576,
  }) =>
      '${_header()}<configure MemoryName="$memoryName" '
      'ValidatePayloadBuffer="true" SkipStorageInit="false" '
      'SkipWrite="false" SectorSizeInBytes="$sectorSize" '
      'MaxPayloadSizeToTargetInBytes="$maxPayloadBytes" />\n</data>';

  static String program({
    required int sectorSize,
    required int startSector,
    required int numSectors,
    required int physicalPartition,
    required String filename,
  }) =>
      '${_header()}<program SECTOR_SIZE_IN_BYTES="$sectorSize" '
      'num_partition_sectors="$numSectors" start_sector="$startSector" '
      'physical_partition_number="$physicalPartition" '
      'filename="${_escape(filename)}" />\n</data>';

  static String readback({
    required int sectorSize,
    required int startSector,
    required int numSectors,
    required int physicalPartition,
    required String filename,
  }) =>
      '${_header()}<readback SECTOR_SIZE_IN_BYTES="$sectorSize" '
      'num_partition_sectors="$numSectors" start_sector="$startSector" '
      'physical_partition_number="$physicalPartition" '
      'filename="${_escape(filename)}" />\n</data>';

  static String getStorageInfo() =>
      '${_header()}<getstorageinfo rawstring="true" />\n</data>';

  static String nop() => '${_header()}<nop value="ping" />\n</data>';

  static String _escape(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// Parses a <storage_info> response from raw getstorageinfo output.
  /// Returns null when the response carries no usable geometry.
  static StorageInfo? parseStorageInfo(String xml) {
    final tag = xml.indexOf('<storage_info');
    if (tag < 0) return null;
    var end = xml.indexOf('</storage_info>', tag);
    final block = end < 0 ? xml.substring(tag) : xml.substring(tag, end);

    final memoryName = _attrAny(block, ['MemoryName', 'memory_name']);
    final sectorSize = int.tryParse(
        _attrAny(block, ['SectorSizeInBytes', 'sector_size', 'BlockSize']));
    final totalBlocks = int.tryParse(
        _attrAny(block, ['TotalBlocks', 'total_blocks']));
    final blockSize =
        int.tryParse(_attrAny(block, ['BlockSize', 'block_size'])) ?? 0;

    if (sectorSize == null || totalBlocks == null) return null;
    if (sectorSize <= 0 || totalBlocks <= 0) return null;
    return StorageInfo(
      memoryName: memoryName,
      sectorSize: sectorSize,
      totalBlocks: totalBlocks,
      blockSize: blockSize,
    );
  }

  static String _attrAny(String block, List<String> names) {
    final lower = block.toLowerCase();
    for (final name in names) {
      final needle = '${name.toLowerCase()}="';
      final pos = lower.indexOf(needle);
      if (pos < 0) continue;
      final start = pos + needle.length;
      final end = block.indexOf('"', start);
      if (end < 0) continue;
      return block.substring(start, end);
    }
    return '';
  }
}

/// Small file bridge so screens can read firmware files without importing
/// dart:io directly in widget code paths that tests exercise.
class FirmwareFileReader {
  const FirmwareFileReader._();

  static Future<String> readText(String path) => File(path).readAsString();

  static Future<List<int>> readBytes(String path) => File(path).readAsBytes();
}
