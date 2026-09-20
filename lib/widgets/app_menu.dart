import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/app_state.dart';

/// Secciones de la app: las mismas vistas que OrionGo_Mobile.
enum AppSection {
  home,
  devices,
  remote,
  motor,
  settings,
  pair,
  search,
  location,
  logs,
}

class Destination {
  const Destination(this.section, this.label, this.icon);

  final AppSection section;
  final String label;
  final IconData icon;
}

const List<Destination> mainDestinations = [
  Destination(AppSection.home, 'Inicio', Icons.blur_on_rounded),
  Destination(AppSection.devices, 'Monturas', Icons.rocket_launch_rounded),
  Destination(AppSection.remote, 'Remoto', Icons.sports_esports_rounded),
  Destination(AppSection.motor, 'Ajustes de motor', Icons.settings_input_component),
  Destination(AppSection.settings, 'Configuraciones', Icons.tune_rounded),
];

const List<Destination> toolDestinations = [
  Destination(AppSection.pair, 'Emparejar montura', Icons.bluetooth_rounded),
  Destination(AppSection.search, 'Buscar objeto', Icons.search_rounded),
  Destination(AppSection.location, 'Ubicación', Icons.map_rounded),
  Destination(AppSection.logs, 'Consolas', Icons.terminal_rounded),
];

String sectionTitle(AppSection section) {
  for (final destination in [...mainDestinations, ...toolDestinations]) {
    if (destination.section == section) return destination.label;
  }
  return 'OrionGo';
}

/// Barra lateral fija para escritorio. Se puede colapsar a una barra de
/// iconos para aprovechar mejor el lienzo del cielo.
class OrionSidebar extends StatelessWidget {
  const OrionSidebar({
    super.key,
    required this.current,
    required this.onSelect,
    this.activeTool,
    this.collapsed = false,
    this.onToggle,
  });

  final AppSection current;
  final ValueChanged<AppSection> onSelect;
  final AppSection? activeTool;
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      width: collapsed ? 76 : 264,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: collapsed
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          _BrandHeader(collapsed: collapsed, onToggle: onToggle),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              children: [
                ...mainDestinations.map(
                  (destination) => collapsed
                      ? _RailTile(
                          destination: destination,
                          selected: current == destination.section &&
                              activeTool == null,
                          onTap: () => onSelect(destination.section),
                        )
                      : _SidebarTile(
                          destination: destination,
                          selected: current == destination.section &&
                              activeTool == null,
                          onTap: () => onSelect(destination.section),
                        ),
                ),
                if (!collapsed) const _SidebarLabel('Herramientas'),
                ...toolDestinations.map(
                  (destination) => collapsed
                      ? _RailTile(
                          destination: destination,
                          selected: activeTool == destination.section,
                          onTap: () => onSelect(destination.section),
                        )
                      : _SidebarTile(
                          destination: destination,
                          selected: activeTool == destination.section,
                          onTap: () => onSelect(destination.section),
                        ),
                ),
              ],
            ),
          ),
          collapsed ? _RailFooter(state: state) : _SidebarFooter(state: state),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.collapsed, this.onToggle});

  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      tooltip: collapsed ? 'Mostrar menú' : 'Ocultar menú',
      onPressed: onToggle,
      icon: Icon(
        collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
        size: 20,
      ),
    );

    final brandIcon = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(Icons.public_rounded, size: 20),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
      ),
      child: collapsed
          ? Column(
              children: [
                brandIcon,
                const SizedBox(height: 6),
                toggle,
              ],
            )
          : Row(
              children: [
                brandIcon,
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OrionGo',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Platform',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textFaint),
                      ),
                    ],
                  ),
                ),
                toggle,
              ],
            ),
    );
  }
}

/// Ítem de la barra colapsada: solo icono, con tooltip.
class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: destination.label,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            hoverColor: Colors.white.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Icon(
                destination.icon,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pie de la barra colapsada: solo el indicador de conexión.
class _RailFooter extends StatelessWidget {
  const _RailFooter({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final connected = state.link?.isConnected ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Tooltip(
        message: connected
            ? (state.deviceConnected?.name ?? 'Conectado')
            : 'Desconectado',
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: connected ? AppColors.success : AppColors.danger,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          color: AppColors.textFaint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  size: 19,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.circle, size: 6, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final connected = state.link?.isConnected ?? false;
    final name = state.deviceConnected?.name ?? 'Sin montura';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: connected ? AppColors.success : AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? name : 'Desconectado',
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'v${AppState.appVersion} · ${state.fps} fps',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Menú lateral deslizable para teléfono.
class OrionDrawer extends StatelessWidget {
  const OrionDrawer({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final AppSection current;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  const Icon(Icons.public_rounded, size: 26),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OrionGo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Hecho por Eri Davalos',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  ...mainDestinations.map(
                    (destination) => ListTile(
                      leading: Icon(destination.icon, size: 20),
                      title: Text(destination.label),
                      selected: current == destination.section,
                      selectedTileColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(destination.section);
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 6),
                    child: Text(
                      'HERRAMIENTAS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: AppColors.textFaint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...toolDestinations.map(
                    (destination) => ListTile(
                      leading: Icon(destination.icon, size: 20),
                      title: Text(destination.label),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(destination.section);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    state.link?.isConnected == true
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_disabled_rounded,
                    size: 18,
                    color: state.link?.isConnected == true
                        ? AppColors.success
                        : AppColors.textFaint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.deviceConnected?.name ?? 'Montura desconectada',
                      style: const TextStyle(fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
