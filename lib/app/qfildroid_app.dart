import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/device_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/backup_restore_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/device_manager_screen.dart';
import '../screens/edl_mode_screen.dart';
import '../screens/firmware_flasher_screen.dart';
import '../screens/firmware_manager_screen.dart';
import '../screens/logs_screen.dart';
import '../screens/partition_manager_screen.dart';
import '../screens/settings_screen.dart';
import 'theme.dart';

/// Root widget: Material 3 shell following the user's selected brightness
/// mode and accent color.
class QfildroidApp extends StatelessWidget {
  const QfildroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'QFILdroid',
      debugShowCheckedModeBanner: false,
      theme: QfildroidTheme.light(theme.seedColor),
      darkTheme: QfildroidTheme.dark(theme.seedColor),
      themeMode: theme.themeMode,
      home: const HomeShell(),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.screen);

  final String label;
  final IconData icon;
  final Widget screen;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<_Destination> _destinations = [
    _Destination('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
    _Destination('Device', Icons.usb, DeviceManagerScreen()),
    _Destination('EDL', Icons.cable, EdlModeScreen()),
    _Destination('Flasher', Icons.flash_on, FirmwareFlasherScreen()),
    _Destination('Partitions', Icons.storage, PartitionManagerScreen()),
    _Destination('Backup', Icons.backup_outlined, BackupRestoreScreen()),
    _Destination('Firmware', Icons.folder_zip_outlined, FirmwareManagerScreen()),
    _Destination('Logs', Icons.receipt_long, LogsScreen()),
    _Destination('Settings', Icons.settings_outlined, SettingsScreen()),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().refreshDevices();
    });
  }

  Future<void> _cycleThemeMode() async {
    final theme = context.read<ThemeProvider>();
    const order = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    final next = order[(order.indexOf(theme.themeMode) + 1) % order.length];
    await theme.setThemeMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;
    final destinations = _destinations;
    final modeIcon = switch (theme.themeMode) {
      ThemeMode.system => Icons.brightness_auto_outlined,
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
    };

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                'Q',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('QFILdroid'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch appearance mode',
            icon: Icon(modeIcon),
            onPressed: _cycleThemeMode,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: Text('v0.2.0', style: TextStyle(fontSize: 12))),
          ),
        ],
      ),
      body: destinations[_index].screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in destinations.take(5))
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
      endDrawer: Drawer(
        width: 260,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: scheme.primaryContainer),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'QFILdroid',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            for (var i = 5; i < destinations.length; i++)
              ListTile(
                leading: Icon(destinations[i].icon),
                title: Text(destinations[i].label),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _index = i);
                },
              ),
          ],
        ),
      ),
    );
  }
}
