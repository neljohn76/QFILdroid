import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../models/firmware/firmware_package.dart';
import 'hash_service.dart';
import 'xml_parser.dart';

/// Inspects firmware packages: extracted directories or ZIP archives.
///
/// Produces a [FirmwarePackage] describing programmers, rawprogram XML
/// files, patch XML files and integrity problems. Inspection never uploads
/// or executes anything.
class FirmwareInspector {
  FirmwareInspector({FirmwareXmlParser? parser})
      : _parser = parser ?? FirmwareXmlParser();

  final FirmwareXmlParser _parser;

  static const Set<String> _programmerExtensions = {
    '.mbn',
    '.elf',
    '.bin',
    '.hex',
  };

  /// Inspects a firmware directory on disk.
  Future<FirmwarePackage> inspectDirectory(String rootPath) async {
    final dir = Directory(rootPath);
    if (!await dir.exists()) {
      return FirmwarePackage(
        rootPath: rootPath,
        programmers: const [],
        rawprogramFiles: const [],
        patchFiles: const [],
        otherFiles: const [],
        errors: ['Directory not found: $rootPath'],
        warnings: const [],
      );
    }

    final programmers = <ProgrammerInfo>[];
    final rawprograms = <XmlFileInfo>[];
    final patches = <XmlFileInfo>[];
    final other = <String>[];
    final errors = <String>[];
    final warnings = <String>[];

    final entities =
        await dir.list(recursive: true, followLinks: false).toList();
    for (final entity in entities.whereType<File>()) {
      final name = p.basename(entity.path).toLowerCase();
      final ext = p.extension(name);

      if (name.startsWith('rawprogram') && name.endsWith('.xml')) {
        final info = await _inspectXml(entity, 'rawprogram');
        if (info != null) {
          rawprograms.add(info);
        } else {
          errors.add('Failed to parse ${entity.path}');
        }
      } else if (name.startsWith('patch') && name.endsWith('.xml')) {
        final info = await _inspectXml(entity, 'patch');
        if (info != null) {
          patches.add(info);
        } else {
          errors.add('Failed to parse ${entity.path}');
        }
      } else if (_programmerExtensions.contains(ext) &&
          _looksLikeProgrammer(name)) {
        try {
          final bytes = await entity.readAsBytes();
          programmers.add(
            ProgrammerInfo(
              path: entity.path,
              fileName: p.basename(entity.path),
              sizeBytes: bytes.length,
              sha256: HashService.sha256Bytes(bytes),
              format: _programmerFormat(bytes),
            ),
          );
        } on FileSystemException catch (e) {
          errors.add('Cannot read ${entity.path}: ${e.message}');
        }
      } else {
        other.add(p.relative(entity.path, from: rootPath));
      }
    }

    if (programmers.isEmpty) {
      warnings.add('No programmer (firehose loader) file found in package');
    }
    if (rawprograms.isEmpty) {
      warnings.add('No rawprogram XML found in package');
    }

    return FirmwarePackage(
      rootPath: rootPath,
      programmers: programmers,
      rawprogramFiles: rawprograms,
      patchFiles: patches,
      otherFiles: other,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Extracts a ZIP firmware package to a working directory and inspects it.
  Future<FirmwarePackage> inspectZip(String zipPath, String extractTo) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      extractArchiveToDisk(archive, extractTo);
      return inspectDirectory(extractTo);
    } on ArchiveException {
      return FirmwarePackage(
        rootPath: zipPath,
        programmers: const [],
        rawprogramFiles: const [],
        patchFiles: const [],
        otherFiles: const [],
        errors: ['Invalid ZIP archive: $zipPath'],
        warnings: const [],
      );
    } on FileSystemException catch (e) {
      return FirmwarePackage(
        rootPath: zipPath,
        programmers: const [],
        rawprogramFiles: const [],
        patchFiles: const [],
        otherFiles: const [],
        errors: ['Cannot read ZIP: ${e.message}'],
        warnings: const [],
      );
    }
  }

  Future<XmlFileInfo?> _inspectXml(File file, String kind) async {
    try {
      final content = await file.readAsString();
      final result = kind == 'rawprogram'
          ? _parser.parseRawprogram(content, sourceFile: p.basename(file.path))
          : _parser.parsePatch(content, sourceFile: p.basename(file.path));
      if (!result.isValid) return null;
      final bytes = await file.readAsBytes();
      return XmlFileInfo(
        path: file.path,
        fileName: p.basename(file.path),
        kind: kind,
        sizeBytes: bytes.length,
        sha256: HashService.sha256Bytes(bytes),
        entryCount: result.entries.length,
      );
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeProgrammer(String lowerName) {
    return lowerName.contains('prog') ||
        lowerName.contains('firehose') ||
        lowerName.contains('loader') ||
        lowerName.contains('edl');
  }

  String _programmerFormat(List<int> bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x7F &&
        bytes[1] == 0x45 &&
        bytes[2] == 0x4C &&
        bytes[3] == 0x46) {
      return 'elf';
    }
    return 'mbn';
  }
}
