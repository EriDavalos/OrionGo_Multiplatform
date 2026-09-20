import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/app_state.dart';
import '../services/remote_service.dart';
import '../widgets/console_view.dart';
import '../widgets/dialogs.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/panels.dart';

class RemotePage extends StatefulWidget {
  const RemotePage({super.key, this.onMenu});

  final VoidCallback? onMenu;

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return PageScaffold(
      title: 'Remoto',
      subtitle:
          'Comparte tu montura como administrador o únete a una sesión como usuario.',
      onMenu: widget.onMenu,
      scrollable: false,
      maxWidth: 980,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSoft),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              tabs: const [
                Tab(text: 'Administrador'),
                Tab(text: 'Usuario'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AdminTab(state: state),
                _UserTab(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Servidor',
      trailing: Row(
        children: [
          StatusDot(
            color: state.isServerConnected
                ? AppColors.success
                : AppColors.danger,
          ),
          const SizedBox(width: 8),
          Text(
            state.isServerConnected ? 'Conectado' : 'Desconectado',
            style: const TextStyle(fontSize: 12.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoRow(
            label: 'Servidor',
            value: '${RemoteService.server}:${RemoteService.port}',
            icon: Icons.dns_rounded,
          ),
          InfoRow(
            label: 'Sala',
            value: state.isAdminConnected
                ? 'Administrador dentro de la sala'
                : 'Sin administrador',
            icon: Icons.group_rounded,
          ),
        ],
      ),
    );
  }
}

class _AdminTab extends StatelessWidget {
  const _AdminTab({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _ServerCard(state: state),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Modo remoto',
          subtitle: 'Permite que otros usuarios observen tu montura.',
          trailing: Switch(
            value: state.isRemote,
            onChanged: state.isInitServer
                ? (value) {
                    state.isRemote = value;
                    state.refresh();
                    state.sendLogServer(
                      value
                          ? 'El modo remoto ha sido activado'
                          : 'El modo remoto ha sido desactivado',
                    );
                    if (value && !state.isServerConnected) {
                      state.codeDeviceC = '';
                      state.isRemote = false;
                      state.refresh();
                    }
                  }
                : null,
          ),
          child: Column(
            children: [
              _CopyField(
                label: 'Id de dispositivo',
                value: state.idDeviceC,
                icon: Icons.rocket_launch_rounded,
              ),
              const SizedBox(height: 10),
              _CopyField(
                label: 'Código de acceso',
                value: state.codeDeviceC,
                icon: Icons.lock_rounded,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(
                        state.isInitServer
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        state.isInitServer ? 'Detener servidor' : 'Iniciar servidor',
                      ),
                      onPressed: () => _toggleServer(context, state),
                    ),
                  ),
                  if (state.isInitServer) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reconectar'),
                      onPressed: () {
                        state.remote.connect(
                          state,
                          state.idDeviceC,
                          username: state.username,
                          isAdmin: true,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Usuarios conectados (${state.usersData.length})',
          child: state.usersData.isEmpty
              ? const Text(
                  'Todavía no hay usuarios en la sala.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                )
              : Column(
                  children: state.usersData
                      .map(
                        (user) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${user.username}#${user.userId}${user.admin ? ' (Admin)' : ''}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              StatusDot(color: Color(_color(user.color))),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Consola del servidor',
          child: ConsoleView(lines: state.logServerList, height: 220),
        ),
      ],
    );
  }

  static int _color(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return int.tryParse(value, radix: 16) ?? 0xFFFFFFFF;
  }

  Future<void> _toggleServer(BuildContext context, AppState state) async {
    if (state.idDeviceC == 'NoDevice') {
      await Dialogs.message(
        '¡Error!',
        'No puedes ser administrador porque no tienes una montura predeterminada registrada.',
      );
      return;
    }

    if (!state.isInitServer) {
      final accept = await Dialogs.confirm(
        '¿Iniciar los servicios de servidor?',
        'Una vez iniciado no podrás acceder a la sección de usuarios y recibirás solicitudes.',
      );
      if (!accept) return;

      state.isInitServer = true;
      state.refresh();
      await state.remote.connect(
        state,
        state.idDeviceC,
        username: state.username,
        isAdmin: true,
      );
    } else {
      final accept = await Dialogs.confirm(
        '¿Detener los servicios de servidor?',
        'Los valores se restablecerán.',
      );
      if (!accept) return;

      state.isInitServer = false;
      state.isRemote = false;
      state.refresh();
      await state.remote.disconnect();
    }
  }
}

class _UserTab extends StatefulWidget {
  const _UserTab({required this.state});

  final AppState state;

  @override
  State<_UserTab> createState() => _UserTabState();
}

class _UserTabState extends State<_UserTab> {
  bool _connecting = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return ListView(
      children: [
        _ServerCard(state: state),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Unirse a un dispositivo',
          subtitle:
              'Pide el id y el código al administrador para solicitar acceso.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Id de dispositivo',
                  prefixIcon: Icon(Icons.rocket_launch_rounded),
                ),
                onChanged: (value) => state.idDevice = value,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Código de dispositivo',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
                onChanged: (value) => state.codeDevice = value,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                icon: _connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: const Text('Solicitar acceso'),
                onPressed: _connecting ? null : () => _request(state),
              ),
              if (state.remote.notMode != 0) ...[
                const SizedBox(height: 14),
                _StatusMessage(state: state),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Consola',
          child: ConsoleView(lines: state.logServerList, height: 180),
        ),
      ],
    );
  }

  Future<void> _request(AppState state) async {
    final idDevice = state.idDevice.trim();
    final codeDevice = state.codeDevice.trim();

    if (idDevice.isEmpty || codeDevice.isEmpty) {
      state.remote.notMode = 5;
      state.refresh();
      return;
    }

    setState(() => _connecting = true);
    try {
      if (idDevice != state.remote.firstId) {
        await state.remote.connect(
          state,
          idDevice,
          username: state.username,
        );
      }

      state.remote.notMode = state.isAdminConnected ? 4 : 1;
      state.remote.send({
        'action': 'remoteControl',
        'user': state.username,
        'codeDevice': codeDevice,
      });
    } catch (_) {
      state.remote.notMode = 1;
    } finally {
      if (mounted) setState(() => _connecting = false);
      state.refresh();
    }
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final mode = state.remote.notMode;

    final text = switch (mode) {
      0 => '',
      1 => 'El dispositivo no está disponible.',
      2 => '${state.idDevice} ha rechazado su solicitud.',
      3 => '${state.idDevice} ha permitido su solicitud.',
      4 => 'Esperando respuesta...',
      _ => 'Debes ingresar ambos campos.',
    };

    final color = mode > 2 ? AppColors.warning : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12.5)),
    );
  }
}

class _CopyField extends StatelessWidget {
  const _CopyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            readOnly: true,
            controller: TextEditingController(text: value.isEmpty ? '—' : value),
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Copiar',
          onPressed: value.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  Dialogs.toast('Se ha copiado al portapapeles exitosamente.');
                },
          icon: const Icon(Icons.copy_rounded, size: 20),
        ),
      ],
    );
  }
}
