import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../providers/device_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/info_row.dart';

/// Settings: appearance (brightness mode + accent color), connection
/// defaults and engine information.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _engineVersion = 'checking...';
  int _timeoutSeconds = 5;

  @override
  void initState() {
    super.initState();
    _loadEngineVersion();
  }

  Future<void> _loadEngineVersion() async {
    final provider = context.read<DeviceProvider>();
    final version = await provider.engineVersion();
    if (mounted) {
      setState(() => _engineVersion = version);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const _AppearanceCard(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Protocol Engine',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                InfoRow(label: 'Engine version', value: _engineVersion),
                InfoRow(label: 'Sahara', value: 'implemented (v1/v2/v3 framing)'),
                InfoRow(label: 'Firehose', value: 'implemented (XML command set)'),
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
                  'Connection',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                DropdownButtonFormField<int>(
                  value: _timeoutSeconds,
                  decoration: const InputDecoration(
                    labelText: 'Sahara handshake timeout (seconds)',
                  ),
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('2 s')),
                    DropdownMenuItem(value: 5, child: Text('5 s')),
                    DropdownMenuItem(value: 10, child: Text('10 s')),
                    DropdownMenuItem(value: 30, child: Text('30 s')),
                  ],
                  onChanged: (v) => setState(() => _timeoutSeconds = v ?? 5),
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
                  'Safety Policy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                Text(
                  '• Dry-run is the default for new firmware packages.\n'
                  '• Programmers are never uploaded automatically.\n'
                  '• Destructive operations require explicit confirmation.\n'
                  '• Secure boot, authentication and OEM authorization are '
                  'never bypassed.\n'
                  '• Every operation is logged.',
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

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appearance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
              ],
              selected: {theme.themeMode},
              onSelectionChanged: (selection) =>
                  theme.setThemeMode(selection.first),
            ),
            const SizedBox(height: 16),
            Text(
              'Accent color',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < QfildroidTheme.accents.length; i++)
                  _AccentSwatch(
                    accent: QfildroidTheme.accents[i],
                    selected: theme.accentIndex == i,
                    onTap: () => theme.setAccent(i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final QfildroidAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: accent.name,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : scheme.outline,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, size: 20, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
