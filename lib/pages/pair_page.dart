import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/mount_device.dart';
import '../services/app_state.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/panels.dart';

/// Emparejamiento de la montura.
///
/// En Android lista dispositivos Bluetooth (emparejados y descubiertos);
/// en computadora lista los puertos serie, donde aparecen los dispositivos
/// Bluetooth que ya estén emparejados en el sistema operativo.
class PairPage extends StatefulWidget {
  const PairPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<PairPage> createState() => _PairPageState();
}

class _PairPageState extends State<PairPage> {
  List<MountDevice> _known = const [];
  List<MountDevice> _available = const [];
  bool _loadingKnown = true;
  bool _loadingAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    final link = state.link;

    if (link == null) {
      setState(() {
        _loadingKnown = false;
        _error = 'Esta plataforma no admite conexión directa con la montura.';
      });
      return;
    }

    setState(() {
      _loadingKnown = true;
      _error = null;
    });

    try {
      await link.requestPermissions();
      final known = await link.knownDevices();
      if (!mounted) return;
      setState(() {
        _known = known;
        _loadingKnown = false;
      });

      setState(() => _loadingAvailable = true);
      final available = await link.discoverDevices();
      if (!mounted) return;
      setState(() {
        _available = available
            .where((device) =>
                !known.any((known) => known.address == device.address))
            .toList();
        _loadingAvailable = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingKnown = false;
        _loadingAvailable = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final link = state.link;
    final connected = state.deviceConnected;

    return PageScaffold(
      title: 'Emparejar montura',
      subtitle: link?.hint ?? 'Conexión directa con el dispositivo.',
      onBack: widget.onBack,
      maxWidth: 820,
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Medio de conexión',
            trailing: Text(
              link?.platformLabel ?? 'No disponible',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            child: Column(
              children: [
                InfoRow(
                  label: 'Estado',
                  value: state.link?.isConnected == true
                      ? 'Conectado'
                      : 'Desconectado',
                  icon: Icons.link_rounded,
                ),
                if (connected != null) ...[
                  InfoRow(
                    label: 'Dispositivo',
                    value: connected.name,
                    icon: Icons.rocket_launch_rounded,
                  ),
                  InfoRow(
                    label: 'Dirección',
                    value: connected.address,
                    icon: Icons.tag_rounded,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBox(message: _error!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (connected != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Desemparejar'),
                onPressed: () => state.disconnectDevice(),
              ),
            ),
          _DeviceSection(
            title: state.link?.platformLabel == 'Bluetooth'
                ? 'Dispositivos emparejados'
                : 'Puertos disponibles',
            emptyText: state.link?.platformLabel == 'Bluetooth'
                ? 'No se encontró ningún dispositivo emparejado.'
                : 'No se encontró ningún puerto serie.',
            devices: _known,
            loading: _loadingKnown,
            connectedAddress: state.deviceConnected?.address,
            onConnect: (device) => _connect(state, device),
          ),
          const SizedBox(height: 16),
          _DeviceSection(
            title: state.link?.platformLabel == 'Bluetooth'
                ? 'Dispositivos disponibles'
                : 'Todos los puertos del sistema',
            emptyText: 'No se encontraron dispositivos nuevos.',
            devices: _available,
            loading: _loadingAvailable,
            connectedAddress: state.deviceConnected?.address,
            onConnect: (device) => _connect(state, device),
          ),
        ],
      ),
    );
  }

  Future<void> _connect(AppState state, MountDevice device) async {
    await state.connectDevice(device);
    if (!mounted) return;
    setState(() {});
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12.5, color: AppColors.danger),
      ),
    );
  }
}

class _DeviceSection extends StatelessWidget {
  const _DeviceSection({
    required this.title,
    required this.emptyText,
    required this.devices,
    required this.loading,
    required this.onConnect,
    this.connectedAddress,
  });

  final String title;
  final String emptyText;
  final List<MountDevice> devices;
  final bool loading;
  final ValueChanged<MountDevice> onConnect;
  final String? connectedAddress;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      trailing: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              '${devices.length}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
      child: devices.isEmpty
          ? Text(
              emptyText,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            )
          : Column(
              children: devices
                  .map(
                    (device) => _DeviceTile(
                      device: device,
                      isConnected: device.address == connectedAddress,
                      onConnect: () => onConnect(device),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onConnect,
    required this.isConnected,
  });

  final MountDevice device;
  final VoidCallback onConnect;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected ? AppColors.success : AppColors.borderSoft,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.bg,
          backgroundImage: const AssetImage('assets/img/bluetooth_icon.png'),
        ),
        title: Text(
          device.name.isEmpty ? 'Sin nombre' : device.name,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          device.address,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        trailing: isConnected
            ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
            : const Icon(Icons.link_rounded, size: 20),
        onTap: isConnected ? null : onConnect,
      ),
    );
  }
}
