import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/theme.dart';
import '../models/firmware/firmware_package.dart';
import '../models/log_entry.dart';
import '../services/firmware/firmware_inspector.dart';
import '../services/log_service.dart';
import '../widgets/info_row.dart';

/// Firmware Manager: package inspection screen (directory or ZIP).
///
/// Shows programmers, rawprogram/patch XML files and SHA-256 digests before
/// any operation is allowed.
class FirmwareManagerScreen extends StatefulWidget {
  const FirmwareManagerScreen({super.key});

  @override
  State<FirmwareManagerScreen> createState() => _FirmwareManagerScreenState();
}

class _FirmwareManagerScreenState extends State<FirmwareManagerScreen> {
  FirmwarePackage? _package;
  bool _loading = false;

  Future<void> _pickAndInspect() async {
    final log = context.read<LogService>();
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select firmware directory',
      );
      if (result == null) return;
      log.info(LogCategory.firmware, 'Inspecting firmware package: $result');
      final package = await FirmwareInspector().inspectDirectory(result);
      log.info(
        LogCategory.firmware,
        'Inspection complete: ${package.programmers.length} programmer(s), '
        '${package.rawprogramFiles.length} rawprogram, '
        '${package.patchFiles.length} patch, '
        '${package.errors.length} error(s)',
      );
      setState(() => _package = package);
    } catch (e) {
      log.error(LogCategory.firmware, 'Inspection failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final package = _package;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Firmware Package Inspection',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                Text(
                  'Select an extracted firmware directory. QFILdroid lists '
                  'programmers, rawprogram/patch XML files and computes '
                  'SHA-256 digests. Nothing is uploaded or executed from '
                  'this screen.',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(_loading ? 'Inspecting...' : 'Select directory'),
                  onPressed: _loading ? null : _pickAndInspect,
                ),
              ],
            ),
          ),
        ),
        if (package != null) _PackageCard(package: package),
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package});

  final FirmwarePackage package;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    package.rootPath,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  package.isValid ? Icons.verified_outlined : Icons.error_outline,
                  color: package.isValid
                      ? QfildroidTheme.success
                      : QfildroidTheme.danger,
                  size: 20,
                ),
              ],
            ),
            const Divider(height: 24),
            if (package.errors.isNotEmpty)
              ...package.errors.map(
                (e) => Text('✖ $e',
                    style: const TextStyle(
                        color: QfildroidTheme.danger, fontSize: 12)),
              ),
            if (package.warnings.isNotEmpty)
              ...package.warnings.map(
                (w) => Text('⚠ $w',
                    style: const TextStyle(
                        color: QfildroidTheme.warning, fontSize: 12)),
              ),
            const SizedBox(height: 8),
            for (final prog in package.programmers) ...[
              const Text(
                'Programmer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              InfoRow(label: 'File', value: prog.fileName),
              InfoRow(label: 'Size', value: '${prog.sizeBytes} bytes'),
              InfoRow(label: 'Format', value: prog.format),
              InfoRow(label: 'SHA-256', value: prog.sha256),
            ],
            for (final xml in package.rawprogramFiles) ...[
              const SizedBox(height: 8),
              const Text(
                'Rawprogram XML',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              InfoRow(label: 'File', value: xml.fileName),
              InfoRow(label: 'Operations', value: '${xml.entryCount}'),
              InfoRow(label: 'SHA-256', value: xml.sha256),
            ],
            for (final xml in package.patchFiles) ...[
              const SizedBox(height: 8),
              const Text(
                'Patch XML',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              InfoRow(label: 'File', value: xml.fileName),
              InfoRow(label: 'Patches', value: '${xml.entryCount}'),
              InfoRow(label: 'SHA-256', value: xml.sha256),
            ],
          ],
        ),
      ),
    );
  }
}
