import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/usb_device_info.dart';
import '../providers/device_provider.dart';
import '../services/edl_identifier.dart';
import '../widgets/info_row.dart';

/// USB device enumeration, selection, permission management and full
/// interface/endpoint diagnostics.
class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({super.key});

  @override
  State<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().refreshDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();

    return RefreshIndicator(
      onRefresh: provider.refreshDevices,
      child: provider.devices.isEmpty
          ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No USB devices attached.\nPull to refresh.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              itemCount: provider.devices.length,
              itemBuilder: (context, index) {
                final device = provider.devices[index];
                final selected =
                    provider.selectedDevice?.deviceName == device.deviceName;
                return _DeviceCard(
                  device: device,
                  selected: selected,
                  onSelect: () => provider.selectDevice(device.deviceName),
                  onRequestPermission: () {
                    provider.selectDevice(device.deviceName);
                    provider.requestPermission();
                  },
                );
              },
            ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.selected,
    required this.onSelect,
    required this.onRequestPermission,
  });

  final UsbDeviceInfo device;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRequestPermission;

  @override
  Widget build(BuildContext context) {
    final candidate = EdlIdentifier.isEdlCandidate(device);
    return Card(
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    candidate ? Icons.warning_amber_outlined : Icons.usb,
                    color: candidate
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      device.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        size: 18, color: Colors.green),
                ],
              ),
              const SizedBox(height: 8),
              InfoRow(label: 'USB ID', value: device.idString),
              InfoRow(label: 'Path', value: device.deviceName),
              InfoRow(
                label: 'Permission',
                value: device.hasPermission ? 'granted' : 'not granted',
                mono: false,
              ),
              if (candidate)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Qualcomm EDL candidate (handshake required to confirm)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (!device.hasPermission)
                FilledButton.icon(
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text('Request permission'),
                  onPressed: onRequestPermission,
                )
              else
                _InterfaceList(device: device),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterfaceList extends StatelessWidget {
  const _InterfaceList({required this.device});

  final UsbDeviceInfo device;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final iface in device.interfaces)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interface ${iface.id} '
                  '(class 0x${iface.interfaceClass.toRadixString(16).padLeft(2, '0')}, '
                  'subclass 0x${iface.interfaceSubclass.toRadixString(16).padLeft(2, '0')}, '
                  'protocol 0x${iface.interfaceProtocol.toRadixString(16).padLeft(2, '0')})',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                for (final endpoint in iface.endpoints)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2),
                    child: Text(
                      'EP${endpoint.endpointNumber} ${endpoint.direction} '
                      '${endpoint.type} maxPacket=${endpoint.maxPacketSize}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
