import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/qfildroid_app.dart';
import 'providers/device_provider.dart';
import 'services/log_service.dart';
import 'services/protocol_service.dart';
import 'services/usb_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QfildroidRoot());
}

class QfildroidRoot extends StatelessWidget {
  const QfildroidRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<UsbService>(create: (_) => UsbService()),
        Provider<ProtocolService>(create: (_) => ProtocolService()),
        Provider<LogService>(create: (_) => LogService()),
        ChangeNotifierProvider<DeviceProvider>(
          create: (context) => DeviceProvider(
            usbService: context.read<UsbService>(),
            protocolService: context.read<ProtocolService>(),
            logService: context.read<LogService>(),
          ),
        ),
      ],
      child: const QfildroidApp(),
    );
  }
}
