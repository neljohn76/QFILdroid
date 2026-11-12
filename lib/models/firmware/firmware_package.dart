/// Programmer (firehose loader) file metadata collected during inspection.
class ProgrammerInfo {
  const ProgrammerInfo({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.format,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final String sha256;

  /// One of: elf, mbn, bin, unknown.
  final String format;

  bool get isElf => format == 'elf';
}

/// A rawprogram or patch XML file discovered in a firmware package.
class XmlFileInfo {
  const XmlFileInfo({
    required this.path,
    required this.fileName,
    required this.kind,
    required this.sizeBytes,
    required this.sha256,
    required this.entryCount,
  });

  /// 'rawprogram' or 'patch'.
  final String kind;
  final String path;
  final String fileName;
  final int sizeBytes;
  final String sha256;
  final int entryCount;
}

/// Result of inspecting a firmware package directory or ZIP.
class FirmwarePackage {
  const FirmwarePackage({
    required this.rootPath,
    required this.programmers,
    required this.rawprogramFiles,
    required this.patchFiles,
    required this.otherFiles,
    required this.errors,
    required this.warnings,
  });

  final String rootPath;
  final List<ProgrammerInfo> programmers;
  final List<XmlFileInfo> rawprogramFiles;
  final List<XmlFileInfo> patchFiles;
  final List<String> otherFiles;
  final List<String> errors;
  final List<String> warnings;

  bool get isValid => errors.isEmpty;

  bool get hasProgrammer => programmers.isNotEmpty;

  bool get hasRawprogram => rawprogramFiles.isNotEmpty;

  /// Total number of planned write operations across all rawprogram files.
  int get totalOperations =>
      rawprogramFiles.fold(0, (sum, f) => sum + f.entryCount);
}
