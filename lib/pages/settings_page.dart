import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../services/app_state.dart';
import '../widgets/dialogs.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/panels.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onMenu});

  final VoidCallback? onMenu;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _username;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(
      text: context.read<AppState>().username,
    );
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return PageScaffold(
      title: 'Configuraciones',
      subtitle: 'Perfil, ubicación del observador y conexión.',
      onMenu: widget.onMenu,
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Perfil',
            subtitle:
                'El nombre se muestra a los demás usuarios en el modo remoto.',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () async {
                    await state.setUsername(_username.text);
                    Dialogs.toast('Perfil actualizado.');
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Ubicación del observador',
            subtitle: 'Se usa para calcular el cielo y los movimientos.',
            trailing: TextButton.icon(
              icon: const Icon(Icons.map_rounded, size: 16),
              label: const Text('Cambiar'),
              onPressed: () {},
            ),
            child: Column(
              children: [
                InfoRow(
                  label: 'Latitud',
                  value: state.latitude.toStringAsFixed(6),
                  icon: Icons.my_location_rounded,
                ),
                InfoRow(
                  label: 'Longitud',
                  value: state.longitude.toStringAsFixed(6),
                  icon: Icons.explore_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Conexión con la montura',
            child: Column(
              children: [
                InfoRow(
                  label: 'Medio',
                  value: state.link?.platformLabel ?? 'No disponible',
                  icon: Icons.settings_input_hdmi_rounded,
                ),
                InfoRow(
                  label: 'Montura registrada',
                  value: state.idDeviceC.isEmpty ? 'Ninguna' : state.idDeviceC,
                  icon: Icons.rocket_launch_rounded,
                ),
                if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                  InfoRow(
                    label: 'Velocidad del puerto',
                    value: '${state.baudRate} baudios',
                    icon: Icons.speed_rounded,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AdaptiveGrid(
            minItemWidth: 300,
            maxColumns: 2,
            children: [
              SectionCard(
                title: 'Identificador de usuario',
                subtitle: 'Se genera automáticamente la primera vez.',
                child: SelectableText(
                  state.userId,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              SectionCard(
                title: 'Datos de la app',
                subtitle: 'OrionGo Platform v${AppState.appVersion}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Misma interfaz que la app móvil, adaptada a escritorio: '
                      'barra lateral fija, paneles centrados y cielo estelar '
                      'con proyección 3D sobre vector_math.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Restablecer configuración'),
                      onPressed: () async {
                        final accept = await Dialogs.confirm(
                          '¿Restablecer la configuración?',
                          'Se borrarán el nombre de usuario y las monturas registradas.',
                        );
                        if (!accept) return;
                        await state.resetSettings();
                        if (context.mounted) {
                          _username.text = state.username;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
