import 'package:xml/xml.dart';

import '../../models/firmware/rawprogram_operation.dart';

/// Parses rawprogram*.xml and patch*.xml files.
///
/// Parsing is strict: malformed attributes or non-numeric values are
/// collected as errors and the affected entries are dropped. Unknown XML
/// content never reaches the protocol layer.
class FirmwareXmlParser {
  const FirmwareXmlParser();

  /// Parses a rawprogram XML document into validated operations.
  XmlParseResult<RawprogramOperation> parseRawprogram(
    String content, {
    String sourceFile = 'rawprogram.xml',
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final entries = <RawprogramOperation>[];

    XmlDocument document;
    try {
      document = XmlDocument.parse(content);
    } on XmlException catch (e) {
      errors.add('$sourceFile: XML parse error: ${e.message}');
      return XmlParseResult(
        entries: entries,
        errors: errors,
        warnings: warnings,
      );
    }

    final programs = document.findAllElements('program').toList();
    if (programs.isEmpty) {
      errors.add('$sourceFile: no <program> elements found');
    }

    for (final element in programs) {
      final filename = element.getAttribute('filename');
      if (filename == null || filename.isEmpty) {
        errors.add('$sourceFile: <program> entry missing filename attribute');
        continue;
      }

      final sectorSize = _getInt(element, 'SECTOR_SIZE_IN_BYTES');
      final startSector = _getInt(element, 'start_sector');
      final numSectors = _getInt(element, 'num_partition_sectors');
      final partition = _getInt(element, 'physical_partition_number');

      for (final name in const [
        'SECTOR_SIZE_IN_BYTES',
        'start_sector',
        'num_partition_sectors',
        'physical_partition_number',
      ]) {
        if (_getInt(element, name) == null) {
          errors.add('$sourceFile [$filename]: missing or invalid $name');
        }
      }
      if (sectorSize == null ||
          startSector == null ||
          numSectors == null ||
          partition == null) {
        continue;
      }

      if (sectorSize == 0) {
        errors.add('$sourceFile [$filename]: SECTOR_SIZE_IN_BYTES is zero');
        continue;
      }
      if (numSectors == 0) {
        warnings.add('$sourceFile [$filename]: zero-length operation skipped');
        continue;
      }
      if (startSector < 0 || partition < 0) {
        errors.add(
            '$sourceFile [$filename]: negative start_sector or partition number');
        continue;
      }

      entries.add(
        RawprogramOperation(
          sourceFile: sourceFile,
          filename: filename,
          sectorSize: sectorSize,
          startSector: startSector,
          numSectors: numSectors,
          physicalPartition: partition,
          label: element.getAttribute('label'),
        ),
      );
    }

    return XmlParseResult(
      entries: entries,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Parses a patch XML document into validated patch operations.
  XmlParseResult<PatchOperation> parsePatch(
    String content, {
    String sourceFile = 'patch0.xml',
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final entries = <PatchOperation>[];

    XmlDocument document;
    try {
      document = XmlDocument.parse(content);
    } on XmlException catch (e) {
      errors.add('$sourceFile: XML parse error: ${e.message}');
      return XmlParseResult(
        entries: entries,
        errors: errors,
        warnings: warnings,
      );
    }

    final patches = document.findAllElements('patch').toList();
    if (patches.isEmpty) {
      warnings.add('$sourceFile: no <patch> elements found');
    }

    for (final element in patches) {
      final sectorSize = _getInt(element, 'SECTOR_SIZE_IN_BYTES');
      final startSector = _getInt(element, 'start_sector');
      final numSectors = _getInt(element, 'num_patch_sectors');
      final partition = _getInt(element, 'physical_partition_number');
      final byteOffset = _getInt(element, 'byte_offset') ?? 0;
      final patchBytes = _decodePatchValue(element.getAttribute('value'));

      if (sectorSize == null ||
          startSector == null ||
          numSectors == null ||
          partition == null) {
        errors.add('$sourceFile: patch entry missing geometry attributes');
        continue;
      }
      if (patchBytes == null) {
        errors.add('$sourceFile: patch entry has invalid value attribute');
        continue;
      }
      if (byteOffset < 0 ||
          byteOffset + patchBytes.length > numSectors * sectorSize) {
        errors.add('$sourceFile: patch payload exceeds patch region');
        continue;
      }

      entries.add(
        PatchOperation(
          sourceFile: sourceFile,
          sectorSize: sectorSize,
          startSector: startSector,
          numSectors: numSectors,
          physicalPartition: partition,
          patchBytes: [...List<int>.filled(byteOffset, 0), ...patchBytes],
          filename: element.getAttribute('filename'),
        ),
      );
    }

    return XmlParseResult(
      entries: entries,
      errors: errors,
      warnings: warnings,
    );
  }

  int? _getInt(XmlElement element, String attribute) {
    final raw = element.getAttribute(attribute);
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }

  /// Patch values are hex strings ("0x..." or bare hex).
  List<int>? _decodePatchValue(String? value) {
    if (value == null) return null;
    var hex = value.trim();
    if (hex.startsWith('0x') || hex.startsWith('0X')) hex = hex.substring(2);
    if (hex.isEmpty || hex.length.isOdd) return null;
    if (hex.contains(RegExp(r'[^0-9a-fA-F]'))) return null;
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
