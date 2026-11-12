import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/theme.dart';
import '../models/connection_stage.dart';
import '../models/log_entry.dart';
import '../providers/device_provider.dart';
import '../services/log_service.dart';
import '../widgets/info_row.dart';
import '../widgets/status_badge.dart';


/// Technician dashboard: connection state, device info, EDL detection and
/// recent diagnostics.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final logs = context.watch<LogService>();

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
                      'Connection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (device.busy)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 8),
                    StatusBadge(stage: device.stage),
                  ],
                ),
                const Divider(height: 24),
                if (device.selectedDevice == null)
                  const Text(
                    'No USB device connected. Attach a device via OTG or '
                    'USB-C host mode.',
                    style: TextStyle(color: Colors.white54),
                  )
                else ...[
                  InfoRow(
                    label: 'Device',
                    value: device.selectedDevice!.displayName,
                    mono: false,
                  ),
                  InfoRow(
                    label: 'USB ID',
                    value: device.selectedDevice!.idString,
                  ),
                  InfoRow(
                    label: 'Product',
                    value: device.selectedDevice!.productName ?? 'unknown',
                    mono: false,
                  ),
                  InfoRow(
                    label: 'Serial',
                    value: device.selectedDevice!.serialNumber ?? 'n/a',
                  ),
                  InfoRow(
                    label: 'Permission',
                    value: device.selectedDevice!.hasPermission
                        ? 'granted'
                        : 'not granted',
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
                  'Qualcomm EDL Detection',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                Text(
                  device.edlStatusText,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  device.handshake == null
                      ? 'Protocol: not connected'
                      : device.handshake!['ok'] == true
                          ? 'Sahara connected (protocol v${device.handshake!['version']})'
                          : 'Sahara handshake failed',
                  style: TextStyle(
                    color: device.handshake?['ok'] == true
                        ? QfildroidTheme.success
                        : Colors.white54,
                    fontSize: 13,
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
                Row(
                  children: [
                    const Text(
                      'Recent Diagnostics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${logs.entries.length} entries',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (logs.entries.isEmpty)
                  const Text(
                    'No events recorded yet.',
                    style: TextStyle(color: Colors.white54),
                  )
                else
                  ...logs.entries.reversed.take(6).map(
                        (e) => _LogLine(entry: e),
                      ),
              ],
            ),
          ),
        ),
        if (device.stage == ConnectionStage.permissionRequired)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton.icon(
              icon: const Icon(Icons.lock_open),
              label: const Text('Grant USB permission'),
              onPressed: device.busy ? null : device.requestPermission,
            ),
          ),
      ],
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry});

  final LogEntry entry;

  Color get _color {
    switch (entry.level) {
      case LogLevel.error:
        return QfildroidTheme.danger;
      case LogLevel.warning:
        return QfildroidTheme.warning;
      case LogLevel.info:
        return Colors.white70;
      case LogLevel.debug:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        entry.format(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: _color,
        ),
      ),
    );
  }
}
