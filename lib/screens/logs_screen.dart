import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/log_entry.dart';
import '../providers/device_provider.dart';
import '../services/log_service.dart';

/// Diagnostic log viewer with category filter and export.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final Set<LogCategory> _categories = {...LogCategory.values};
  LogLevel _minLevel = LogLevel.debug;

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<LogService>();
    final provider = context.read<DeviceProvider>();
    final entries = logs.filtered(
      categories: _categories,
      minLevel: _minLevel,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final category in LogCategory.values)
                      FilterChip(
                        label: Text(
                          category.name.toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: _categories.contains(category),
                        onSelected: (selected) => setState(() {
                          selected
                              ? _categories.add(category)
                              : _categories.remove(category);
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Text('Level:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              DropdownButton<LogLevel>(
                value: _minLevel,
                underline: const SizedBox.shrink(),
                items: [
                  for (final level in LogLevel.values)
                    DropdownMenuItem(
                      value: level,
                      child: Text(level.name, style: const TextStyle(fontSize: 12)),
                    ),
                ],
                onChanged: (v) => setState(() => _minLevel = v ?? LogLevel.debug),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: logs.exportText()),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report copied to clipboard')),
                  );
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.save_alt, size: 16),
                label: const Text('Export'),
                onPressed: () async {
                  final usb = provider;
                  final result = await usb.exportReport(logs.exportText());
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result['ok'] == true
                            ? 'Report saved to ${result['path']}'
                            : 'Export failed: ${result['error']}',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Text('No log entries',
                      style: TextStyle(color: Colors.white38)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[entries.length - 1 - index];
                    return _LogTile(entry: entry);
                  },
                ),
        ),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final LogEntry entry;

  Color get _color {
    switch (entry.level) {
      case LogLevel.error:
        return const Color(0xFFF85149);
      case LogLevel.warning:
        return const Color(0xFFD29922);
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
