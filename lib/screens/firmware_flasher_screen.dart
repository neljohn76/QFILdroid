import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/theme.dart';
import '../models/firmware/flash_plan.dart';
import '../models/firmware/storage_info.dart';
import '../models/log_entry.dart';
import '../providers/device_provider.dart';
import '../services/firmware/xml_parser.dart';
import '../services/flash_planner.dart';
import '../services/log_service.dart';

/// Staged firmware flashing workflow.
///
/// Safety: dry-run is the default. Actual write commands are only sent when
/// dry-run is disabled AND the device has a verified protocol connection.
/// This screen plans and validates operations; storage writes require a
/// validated programmer and explicit user confirmation.
class FirmwareFlasherScreen extends StatefulWidget {
  const FirmwareFlasherScreen({super.key});

  @override
  State<FirmwareFlasherScreen> createState() => _FirmwareFlasherScreenState();
}

class _FirmwareFlasherScreenState extends State<FirmwareFlasherScreen> {
  final TextEditingController _rawprogramController = TextEditingController();
  bool _dryRun = true;
  FlashPlan? _plan;
  String? _planError;

  @override
  void dispose() {
    _rawprogramController.dispose();
    super.dispose();
  }

  /// Opens the system document picker (Storage Access Framework) so no
  /// storage permission is required.
  Future<void> _pickRawprogram() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select rawprogram XML',
      type: FileType.any,
    );
    if (!mounted) return;
    final path = result?.files.single.path;
    if (path != null) {
      setState(() => _rawprogramController.text = path);
    }
  }

  Future<void> _buildPlan() async {
    final provider = context.read<DeviceProvider>();
    final log = context.read<LogService>();
    final path = _rawprogramController.text.trim();
    if (path.isEmpty) {
      setState(() => _planError = 'Pick a rawprogram XML file first');
      return;
    }

    String content;
    try {
      content = await File(path).readAsString();
    } on FileSystemException catch (e) {
      setState(() {
        _plan = null;
        _planError = 'Cannot read file: ${e.message}';
      });
      return;
    }
    final parser = const FirmwareXmlParser().parseRawprogram(
      content,
      sourceFile: path.split('/').last,
    );
    if (!parser.isValid) {
      setState(() {
        _plan = null;
        _planError = parser.errors.join('\n');
      });
      log.error(
        LogCategory.firmware,
        'rawprogram validation failed: ${parser.errors.join('; ')}',
      );
      return;
    }

    if (provider.handshake?['ok'] != true) {
      setState(() {
        _plan = null;
        _planError =
            'No verified protocol connection. Connect in EDL Mode first.';
      });
      return;
    }

    // Storage geometry must come from the device; without a validated
    // programmer we cannot query it, so planning uses unknown geometry and
    // will refuse writes.
    const storage = StorageInfo(
      memoryName: 'unknown',
      sectorSize: 0,
      totalBlocks: 0,
      blockSize: 0,
    );
    final plan = const FlashPlanner().plan(
      operations: parser.entries,
      storage: storage,
      fileAvailability: const {},
      dryRun: _dryRun,
    );
    log.info(
      LogCategory.flash,
      'Flash plan built: ${parser.entries.length} operations, '
      'dry-run=$_dryRun, ${plan.errorCount} rejected',
    );
    setState(() {
      _plan = plan;
      _planError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
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
                  'Firmware Flasher',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                Text(
                  'Stage: ${provider.stage.label}',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rawprogramController,
                  decoration: InputDecoration(
                    labelText: 'rawprogram XML file',
                    hintText: 'Pick rawprogram0.xml from device storage',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      tooltip: 'Browse files (SAF)',
                      onPressed: _pickRawprogram,
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dry-run mode'),
                  subtitle: const Text(
                    'Validate and plan only; no data is written',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _dryRun,
                  onChanged: (v) => setState(() => _dryRun = v),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.rule, size: 18),
                  label: const Text('Validate & build plan'),
                  onPressed: provider.busy ? null : _buildPlan,
                ),
                if (_planError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _planError!,
                    style: const TextStyle(
                        color: QfildroidTheme.danger, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_plan != null) _PlanCard(plan: _plan!),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final FlashPlan plan;

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
                Text(
                  plan.dryRun
                      ? 'Plan (dry run)'
                      : 'Plan (REAL WRITE MODE)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: plan.dryRun
                        ? QfildroidTheme.warning
                        : QfildroidTheme.danger,
                  ),
                ),
                const Spacer(),
                Text(
                  '${plan.validCount} valid / ${plan.entries.length} total',
                  style: TextStyle(color: scheme.outline, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 24),
            ...plan.warnings.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '⚠ $w',
                  style: const TextStyle(
                    color: QfildroidTheme.warning,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            ...plan.errors.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '✖ $e',
                  style: const TextStyle(
                      color: QfildroidTheme.danger, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in plan.entries.take(50))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${entry.isValid ? "✔" : "✖"} ${entry.operation}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: entry.isValid
                        ? scheme.onSurfaceVariant
                        : QfildroidTheme.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
