import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/device_provider.dart';
import '../widgets/info_row.dart';
import '../widgets/status_badge.dart';

/// EDL mode screen: candidate identification, Sahara handshake and
/// diagnostics.
class EdlModeScreen extends StatelessWidget {
  const EdlModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final handshake = provider.handshake;
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
                Row(
                  children: [
                    const Text(
                      'EDL Mode',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    StatusBadge(stage: provider.stage, compact: true),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  provider.edlStatusText,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.cable, size: 18),
                  label: const Text('Connect (Sahara handshake)'),
                  onPressed: provider.busy ||
                          provider.selectedDevice == null ||
                          !provider.selectedDevice!.hasPermission
                      ? null
                      : () => provider.connectEdl(),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text('Disconnect'),
                  onPressed: provider.busy ? null : provider.disconnect,
                ),
                if (provider.selectedDevice != null &&
                    !provider.selectedDevice!.hasPermission)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('Grant USB permission first'),
                      onPressed: provider.requestPermission,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Handshake Diagnostics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                if (handshake == null)
                  Text(
                    'No handshake performed yet. Connect to the device to '
                    'verify EDL mode.',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 13),
                  )
                else ...[
                  InfoRow(
                    label: 'Result',
                    value: handshake['ok'] == true ? 'OK' : 'FAILED',
                    mono: false,
                  ),
                  InfoRow(
                    label: 'Protocol version',
                    value: '${handshake['version'] ?? '-'}',
                  ),
                  InfoRow(
                    label: 'Supported version',
                    value: '${handshake['versionSupported'] ?? '-'}',
                  ),
                  InfoRow(
                    label: 'Max command len',
                    value: '${handshake['maxCommandLen'] ?? '-'}',
                  ),
                  if (handshake['error'] != null &&
                      (handshake['error'] as String).isNotEmpty)
                    InfoRow(
                      label: 'Error',
                      value: handshake['error'] as String,
                      mono: false,
                    ),
                ],
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Safety Notes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                Text(
                  '• VID/PID match alone never proves EDL mode; only a '
                  'successful Sahara handshake does.\n'
                  '• Programmers are never uploaded automatically. Use the '
                  'Firmware Flasher with an authorized programmer.\n'
                  '• QFILdroid does not bypass secure boot or OEM '
                  'authentication.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
