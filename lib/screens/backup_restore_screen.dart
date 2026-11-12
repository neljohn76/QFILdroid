import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../providers/device_provider.dart';
import '../services/firehose_commands.dart';
import '../models/log_entry.dart';
import '../services/log_service.dart';

/// Backup & Restore: partition readback planning with validation.
///
/// Only readback (backup) is offered here. Restore writes require the same
/// validation chain as the flasher and are gated behind programmer
/// validation and explicit confirmation.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _numSectorsController = TextEditingController();
  String _sectorSize = '4096';
  String? _validation;
  bool _planned = false;

  @override
  void dispose() {
    _startController.dispose();
    _numSectorsController.dispose();
    super.dispose();
  }

  void _validatePlan() {
    final provider = context.read<DeviceProvider>();
    final log = context.read<LogService>();

    final start = int.tryParse(_startController.text.trim());
    final num = int.tryParse(_numSectorsController.text.trim());
    final sectorSize = int.tryParse(_sectorSize);

    if (start == null || num == null || sectorSize == null) {
      setState(() => _validation = 'Start sector, sector count and sector '
          'size must be valid integers');
      return;
    }
    if (start < 0 || num <= 0 || sectorSize <= 0) {
      setState(() => _validation = 'Values must be positive');
      return;
    }
    if (provider.handshake?['ok'] != true) {
      setState(() => _validation = 'No verified protocol connection. Connect '
          'in EDL Mode and validate a programmer first.');
      return;
    }
    log.info(
      LogCategory.flash,
      'Backup plan prepared: readback start=$start sectors=$num '
      'sectorSize=$sectorSize (device geometry check pending)',
    );
    setState(() {
      _validation = null;
      _planned = true;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  'Backup (Readback)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                const Text(
                  'Backups read sector ranges from the device via the '
                  'validated programmer. Verify the range against the '
                  'partition table before proceeding.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _startController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Start sector',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _numSectorsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of sectors',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _sectorSize,
                  decoration: const InputDecoration(
                    labelText: 'Sector size (bytes)',
                  ),
                  items: const [
                    DropdownMenuItem(value: '512', child: Text('512')),
                    DropdownMenuItem(value: '4096', child: Text('4096')),
                  ],
                  onChanged: (v) => setState(() => _sectorSize = v ?? '4096'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.download_for_offline_outlined,
                      size: 18),
                  label: const Text('Prepare backup plan'),
                  onPressed: _validatePlan,
                ),
                if (_validation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _validation!,
                      style: TextStyle(
                          color: QfildroidTheme.warning, fontSize: 13),
                    ),
                  ),
                if (_planned)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Backup plan validated against connection state. '
                      'Execution requires device geometry confirmation from '
                      'the Partition Manager and will be logged.',
                      style: const TextStyle(
                          color: QfildroidTheme.success, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Restore',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Divider(height: 24),
                Text(
                  'Restore writes are intentionally disabled in this build. '
                  'They will be enabled together with the full flash '
                  'validation chain (programmer validation, storage geometry '
                  'checks, integrity verification and confirmation).',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
