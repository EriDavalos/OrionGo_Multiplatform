import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../models/mount_device.dart';
import '../services/app_state.dart';
import '../widgets/dialogs.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/panels.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key, this.onMenu});

  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return PageScaffold(
      title: 'Monturas',
      subtitle: 'Dispositivos registrados y su estado de conexión.',
      onMenu: onMenu,
      child: state.devicesRegistered.isEmpty
          ? const _EmptyState()
          : AdaptiveGrid(
              minItemWidth: 300,
              maxColumns: 4,
              children: state.devicesRegistered
                  .map((device) => _DeviceCard(device: device))
                  .toList(),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 70),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: const Column(
        children: [
          Icon(Icons.rocket_launch_rounded, size: 40, color: AppColors.textFaint),
          SizedBox(height: 14),
          Text('No existe ninguna montura registrada'),
          SizedBox(height: 6),
          Text(
            'Conecta una montura desde "Emparejar montura" para registrarla.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final MountDevice device;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final status = state.statusByDevice[device.address] ?? MountStatus.available;
    final connected = state.deviceConnected?.address == device.address &&
        state.link?.isConnected == true;

    final borderColor = device.isDefault
        ? (connected ? AppColors.success : AppColors.danger)
        : AppColors.borderSoft;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: device.isDefault ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rocket_launch_rounded, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      device.idDevice ?? device.address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (device.isDefault)
                const Icon(Icons.star_rounded,
                    color: AppColors.warning, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Image.asset(
              'assets/img/OrionDeviceV1.png',
              height: 120,
              errorBuilder: (context, error, stack) => const SizedBox(
                height: 120,
                child: Icon(Icons.image_not_supported_rounded,
                    color: AppColors.textFaint),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              StatusDot(
                color: connected ? AppColors.success : AppColors.textFaint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connected ? 'Conectada' : status.label,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              IconButton(
                tooltip: 'Marcar como predeterminada',
                onPressed: device.isDefault
                    ? null
                    : () => state.setDefaultDevice(device),
                icon: const Icon(Icons.star_border_rounded, size: 20),
              ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: () async {
                  final accept = await Dialogs.confirm(
                    '¿Eliminar la montura?',
                    'Se quitará "${device.name}" del catálogo de dispositivos.',
                  );
                  if (accept) await state.deleteDevice(device);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
          if (device.model != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Modelo: ${device.model}',
                style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
              ),
            ),
        ],
      ),
    );
  }
}
