/// A single <program> entry parsed from a rawprogram XML file.
class RawprogramOperation {
  const RawprogramOperation({
    required this.sourceFile,
    required this.filename,
    required this.sectorSize,
    required this.startSector,
    required this.numSectors,
    required this.physicalPartition,
    this.label,
  });

  final String sourceFile;
  final String filename;
  final int sectorSize;
  final int startSector;
  final int numSectors;
  final int physicalPartition;
  final String? label;

  int get byteLength => numSectors * sectorSize;

  Map<String, Object?> toMap() => {
        'sourceFile': sourceFile,
        'filename': filename,
        'sectorSize': sectorSize,
        'startSector': startSector,
        'numSectors': numSectors,
        'physicalPartition': physicalPartition,
        'label': label,
      };

  @override
  String toString() =>
      '$filename: start=$startSector sectors=$numSectors sectorSize=$sectorSize lun=$physicalPartition';
}

/// A single <patch> entry parsed from a patch XML file.
class PatchOperation {
  const PatchOperation({
    required this.sourceFile,
    required this.sectorSize,
    required this.startSector,
    required this.numSectors,
    required this.physicalPartition,
    required this.patchBytes,
    this.filename,
  });

  final String sourceFile;
  final int sectorSize;
  final int startSector;
  final int numSectors;
  final int physicalPartition;
  final List<int> patchBytes;
  final String? filename;

  Map<String, Object?> toMap() => {
        'sourceFile': sourceFile,
        'sectorSize': sectorSize,
        'startSector': startSector,
        'numSectors': numSectors,
        'physicalPartition': physicalPartition,
        'patchBytes': patchBytes,
        'filename': filename,
      };
}

/// Result of parsing an XML file; separates hard errors from warnings.
class XmlParseResult<T> {
  const XmlParseResult({
    required this.entries,
    required this.errors,
    required this.warnings,
  });

  final List<T> entries;
  final List<String> errors;
  final List<String> warnings;

  bool get isValid => errors.isEmpty;
}
