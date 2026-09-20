import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/app_state.dart';
import 'services/mount_link_factory.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService();
  final state = AppState(settings);
  await state.init();

  // Android -> Bluetooth serial; escritorio -> puerto serie (Bluetooth SPP).
  final link = createMountLink(baudRate: await state.baudRate);
  state.attachLink(link);
  state.sendLogDevice(
    'Conexión disponible: ${link?.platformLabel ?? 'ninguna en esta plataforma'}',
  );

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const OrionApp(),
    ),
  );
}
