import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/firmware/storage_info.dart';
import '../providers/device_provider.dart';
import '../services/firehose_commands.dart';
import '../widgets/info_row.dart';

/// Partition Manager: read-only storage diagnostics via the connected
/// programmer. No write operations are exposed in this screen.
class PartitionManagerScreen extends StatefulWidget {
  const PartitionManagerScreen({super.key});

  @override
  State<PartitionManagerScreen> createState() => _PartitionManagerScreenState();
}

class _PartitionManagerScreenState extends State<PartitionManagerScreen> {
  StorageInfo? _storage;
  String? _error;
  bool _loading = false;

  Future<void> _queryStorageInfo() async {
    final provider = context.read<DeviceProvider>();
    setState(() {
      _loading = true;
      _error = null;
      _storage = null;
    });
    try {
      final result = await provider.sendFirehoseCommand(
        FirehoseCommands.getStorageInfo(),
      );
      if (result == null) {
        setState(() => _error = 'Storage query blocked: connect in EDL Mode '
            'and validate a programmer first.');
        return;
      }
      final response = result['response'] as String? ?? '';
      final info = FirehoseCommands.parseStorageInfo(response);
      if (info == null) {
        setState(() => _error = 'Device did not report usable storage info.');
        return;
      }
      setState(() => _storage = info);
    } catch (e) {
      setState(() => _error = 'Storage query failed: $e');
    } finally {
      setState(() => _loading = false);
    }
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
                Row(
                  children: [
                    const Text(
                      'Storage Information',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_loading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  'Read-only diagnostics. Partition writes are not enabled '
                  'until the compatibility and safety validation layers are '
                  'complete.',
                  style: TextStyle(color: QfildroidTheme.warning, fontSize: 12),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.query_stats, size: 18),
                  label: const Text('Query storage info'),
                  onPressed: _loading ? null : _queryStorageInfo,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(color: QfildroidTheme.danger, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_storage != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Geometry',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 24),
                  InfoRow(label: 'Memory type', value: _storage!.memoryName),
                  InfoRow(label: 'Sector size', value: '${_storage!.sectorSize} bytes'),
                  InfoRow(label: 'Total sectors', value: '${_storage!.totalBlocks}'),
                  InfoRow(
                      label: 'Total size',
                      value:
                          '${(_storage!.totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
