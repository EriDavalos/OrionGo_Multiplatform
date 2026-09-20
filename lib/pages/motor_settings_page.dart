import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../services/app_state.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/panels.dart';

class MotorSettingsPage extends StatelessWidget {
  const MotorSettingsPage({super.key, this.onMenu});

  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return PageScaffold(
      title: 'Ajustes de motor',
      subtitle:
          'Telemetría en vivo de los dos drivers. Los valores se actualizan con cada trama de la montura.',
      onMenu: onMenu,
      child: Column(
        children: [
          _DriverCard(
            title: 'Eje de declinación (driver 1)',
            icon: Icons.swap_vert_rounded,
            enabled: state.isEnableDEC,
            microsteps: state.microsteps1,
            position: state.position1,
            angle: state.angleC1,
            speed: state.speed1,
            accel: state.accel1,
            uart: state.uart1,
            ratio: state.drv1r,
          ),
          const SizedBox(height: 16),
          _DriverCard(
            title: 'Eje de ascensión recta (driver 2)',
            icon: Icons.swap_horiz_rounded,
            enabled: state.isEnableRA,
            microsteps: state.microsteps2,
            position: state.position2,
            angle: state.angleC2,
            speed: state.speed2,
            accel: state.accel2,
            uart: state.uart2,
            ratio: state.drv2r,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Movimiento',
            subtitle: 'Estado actual del seguimiento y del GoTo.',
            trailing: StatusDot(
              color: state.isTracking ? AppColors.success : AppColors.textFaint,
            ),
            child: Column(
              children: [
                InfoRow(
                  label: 'Seguimiento sideral',
                  value: state.isTracking ? 'Activo' : 'Detenido',
                  icon: Icons.motion_photos_on_rounded,
                ),
                InfoRow(
                  label: 'Velocidad de rotación terrestre',
                  value: '${state.earthSpeed.toStringAsFixed(2)} pasos/s',
                  icon: Icons.speed_rounded,
                ),
                InfoRow(
                  label: 'Microstep para seguimiento',
                  value: '${state.microstepForFollow}',
                  icon: Icons.linear_scale_rounded,
                ),
                InfoRow(
                  label: 'GoTo en curso',
                  value: state.isGoTo ? state.goToTimeStr : 'No',
                  icon: Icons.gps_fixed_rounded,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: Icon(
                          state.isTracking
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          state.isTracking
                              ? 'Detener seguimiento'
                              : 'Iniciar seguimiento',
                        ),
                        onPressed: state.toggleTracking,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.home_rounded),
                        label: const Text('Posición inicial'),
                        onPressed: state.goHome,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.title,
    required this.icon,
    required this.enabled,
    required this.microsteps,
    required this.position,
    required this.angle,
    required this.speed,
    required this.accel,
    required this.uart,
    required this.ratio,
  });

  final String title;
  final IconData icon;
  final bool enabled;
  final int microsteps;
  final double position;
  final double angle;
  final double speed;
  final double accel;
  final int uart;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      trailing: Row(
        children: [
          StatusDot(color: enabled ? AppColors.success : AppColors.textFaint),
          const SizedBox(width: 8),
          Text(
            enabled ? 'Habilitado' : 'Deshabilitado',
            style: const TextStyle(fontSize: 12.5),
          ),
        ],
      ),
      child: AdaptiveGrid(
        minItemWidth: 150,
        spacing: 12,
        maxColumns: 6,
        children: [
          ValueTile(
            label: 'PASOS',
            value: position.toStringAsFixed(0),
            icon: icon,
          ),
          ValueTile(
            label: 'ÁNGULO',
            value: '${angle.toStringAsFixed(2)}°',
          ),
          ValueTile(label: 'MICROPASOS', value: '$microsteps'),
          ValueTile(
            label: 'VELOCIDAD',
            value: speed.toStringAsFixed(0),
            icon: Icons.speed_rounded,
          ),
          ValueTile(
            label: 'ACELERACIÓN',
            value: accel.toStringAsFixed(0),
            icon: Icons.trending_up_rounded,
          ),
          ValueTile(
            label: 'UART · REDUCCIÓN',
            value: '$uart · ${ratio.toStringAsFixed(1)}:1',
            icon: Icons.settings_input_component,
          ),
        ],
      ),
    );
  }
}
