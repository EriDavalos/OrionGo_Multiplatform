
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/astronomy.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../models/grade_components.dart';
import '../models/stars.dart';
import '../services/app_state.dart';
import '../services/star_catalog.dart';
import '../widgets/adaptive_panel.dart';
import '../widgets/app_menu.dart';
import '../widgets/panels.dart';
import '../widgets/sky_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenTool,
    this.onOpenDrawer,
  });

  final ValueChanged<AppSection> onOpenTool;
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final desktop = context.isDesktop;

    return Stack(
      children: [
        Positioned.fill(child: const SkyView()),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: state.noticed
                      ? AppColors.danger.withValues(alpha: 0.7)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _TopOverlay(
            onOpenTool: onOpenTool,
            onOpenDrawer: onOpenDrawer,
            desktop: desktop,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomControls(desktop: desktop),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- barra
class _TopOverlay extends StatelessWidget {
  const _TopOverlay({
    required this.onOpenTool,
    required this.desktop,
    this.onOpenDrawer,
  });

  final ValueChanged<AppSection> onOpenTool;
  final bool desktop;
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final connected = state.deviceConnected;
    final mountText = state.isOnline
        ? (state.deviceConnectedAdmin
            ? 'Conectado con ${state.nameDeviceConnectedAdmin}'
            : 'No conectado')
        : (connected == null ? 'No conectado' : 'Conectado con ${connected.name}');

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(desktop ? 24 : 8, 8, desktop ? 24 : 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (onOpenDrawer != null)
                  IconButton(
                    onPressed: onOpenDrawer,
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'Menú',
                  ),
                const Spacer(),
                if (!state.isOnline)
                  _ToolIcon(
                    icon: Icons.terminal_rounded,
                    tooltip: 'Consolas',
                    onTap: () => onOpenTool(AppSection.logs),
                  ),
                if (!state.isOnline)
                  _ToolIcon(
                    icon: Icons.map_rounded,
                    tooltip: 'Ubicación',
                    onTap: () => onOpenTool(AppSection.location),
                  ),
                if (!state.isOnline && state.hasLink)
                  _ToolIcon(
                    icon: Icons.bluetooth_rounded,
                    tooltip: 'Emparejar montura',
                    onTap: () => onOpenTool(AppSection.pair),
                  ),
                _ToolIcon(
                  icon: Icons.search_rounded,
                  tooltip: 'Buscar objeto',
                  onTap: () => onOpenTool(AppSection.search),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${state.fps} fps',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _StatusLine(text: mountText),
            _StatusLine(
              text:
                  'α: ${state.rotationAz.toStringAsFixed(1)}°  '
                  'β: ${state.rotationAlt.toStringAsFixed(1)}°  '
                  'γ: ${state.rotationRoll.toStringAsFixed(1)}°',
            ),
            _StatusLine(
              text: 'R.A.: ${Astro.decimalToHms(state.touchedRA / 15)}   '
                  'DEC: ${Astro.decimalToDms(state.touchedDEC)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textMuted,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface.withValues(alpha: 0.7),
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- controles
class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(desktop ? 28 : 16),
        child: Row(
          children: [
            _RoundButton(
              tooltip: 'Hora del cielo',
              onTap: () => _openTimePanel(context),
              child: const Icon(Icons.schedule_rounded, size: 20),
            ),
            const Spacer(),
            _RoundButton(
              tooltip: 'Modos de visibilidad',
              onTap: () => _openViewPanel(context),
              child: const Icon(Icons.tune_rounded, size: 20),
            ),
            const SizedBox(width: 10),
            _RoundButton(
              tooltip: 'Posición inicial',
              onTap: () => state.goHome(),
              child: const Icon(Icons.home_rounded, size: 20),
            ),
            const SizedBox(width: 10),
            _RoundButton(
              tooltip: state.isTracking ? 'Detener seguimiento' : 'Seguir',
              active: state.isTracking,
              onTap: () => state.toggleTracking(),
              badge: state.isTracking ? state.trackingTimeStr : null,
              child: Icon(
                state.isTracking
                    ? Icons.close_rounded
                    : Icons.motion_photos_on_rounded,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            _RoundButton(
              tooltip: 'Ir al objeto centrado',
              active: state.isGoTo,
              onTap: () => state.goTo(),
              badge: state.isGoTo ? state.goToTimeStr : null,
              child: Icon(
                state.isGoTo ? Icons.close_rounded : Icons.gps_fixed_rounded,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            _RoundButton(
              tooltip: 'Objeto celeste',
              onTap: () => _openStarPanel(context),
              child: const Icon(Icons.star_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTimePanel(BuildContext context) async {
    final state = context.read<AppState>();
    await showAdaptivePanel(
      context,
      title: 'Hora del cielo',
      maxWidth: 620,
      child: _TimePanel(state: state),
    );
  }

  Future<void> _openViewPanel(BuildContext context) async {
    final state = context.read<AppState>();
    await showAdaptivePanel(
      context,
      title: 'Modos de visibilidad',
      maxWidth: 560,
      child: _ViewPanel(state: state),
    );
  }

  Future<void> _openStarPanel(BuildContext context) async {
    final state = context.read<AppState>();
    await showAdaptivePanel(
      context,
      title: 'Coordenadas del objeto',
      maxWidth: 620,
      child: _StarPanel(state: state),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.child,
    required this.onTap,
    required this.tooltip,
    this.active = false,
    this.badge,
  });

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: active ? AppColors.danger : AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? AppColors.danger : AppColors.border,
                ),
              ),
              child: IconTheme(
                data: const IconThemeData(color: Colors.white),
                child: Center(child: child),
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -10,
            right: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------- panel: hora
class _TimePanel extends StatefulWidget {
  const _TimePanel({required this.state});

  final AppState state;

  @override
  State<_TimePanel> createState() => _TimePanelState();
}

class _TimePanelState extends State<_TimePanel> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      '${state.dtNow.day.toString().padLeft(2, '0')}/'
                      '${state.dtNow.month.toString().padLeft(2, '0')}/'
                      '${state.dtNow.year}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: state.dtNow,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null) return;
                      state.setCustomTime(
                        DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          state.dtNow.hour,
                          state.dtNow.minute,
                          state.dtNow.second,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${state.dtNow.hour.toString().padLeft(2, '0')}:'
                  '${state.dtNow.minute.toString().padLeft(2, '0')}:'
                  '${state.dtNow.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 86399,
                    value: state.secondsOfDay.toDouble().clamp(0, 86399),
                    onChanged: state.isHourEditing
                        ? (value) => state.setSecondsOfDay(value.round())
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Editar'),
                  selected: state.isHourEditing,
                  onSelected: (value) {
                    state.isHourEditing = value;
                    state.refresh();
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  onPressed: () =>
                      state.setCustomTime(state.dtNow.subtract(const Duration(days: 1))),
                  icon: const Icon(Icons.skip_previous_rounded),
                  tooltip: 'Día anterior',
                ),
                IconButton.filledTonal(
                  onPressed: () =>
                      state.setCustomTime(state.dtNow.add(const Duration(days: 1))),
                  icon: const Icon(Icons.skip_next_rounded),
                  tooltip: 'Día siguiente',
                ),
                IconButton.filled(
                  onPressed: state.resetTimeToNow,
                  icon: const Icon(Icons.watch_later_rounded),
                  tooltip: 'Usar la hora actual',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------- panel: visibilidad
class _ViewPanel extends StatefulWidget {
  const _ViewPanel({required this.state});

  final AppState state;

  @override
  State<_ViewPanel> createState() => _ViewPanelState();
}

class _ViewPanelState extends State<_ViewPanel> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Retículas', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Acimutal'),
                  selected: state.isAzimuthalGrid,
                  onSelected: (value) => state.setGrids(azimuthal: value),
                ),
                FilterChip(
                  label: const Text('Ecuatorial'),
                  selected: state.isEquatorialGrid,
                  onSelected: (value) => state.setGrids(equatorial: value),
                ),
                FilterChip(
                  label: const Text('Ver bajo el horizonte'),
                  selected: state.showBelowHorizon,
                  onSelected: (_) => state.toggleBelowHorizon(),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Cantidad de estrellas visibles · magnitud ${state.magMax.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13),
            ),
            Slider(
              min: -1.5,
              max: 7,
              divisions: 850,
              value: state.magMax.clamp(-1.5, 7),
              onChanged: state.setMagnitudeLimit,
            ),
            Text(
              'Zoom actual: ${state.zoom3D.toStringAsFixed(1)}x',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------- panel: objeto
class _StarPanel extends StatefulWidget {
  const _StarPanel({required this.state});

  final AppState state;

  @override
  State<_StarPanel> createState() => _StarPanelState();
}

class _StarPanelState extends State<_StarPanel> {
  late final TextEditingController _rah;
  late final TextEditingController _ram;
  late final TextEditingController _ras;
  late final TextEditingController _decg;
  late final TextEditingController _decm;
  late final TextEditingController _decs;

  Star? _searchResult;

  @override
  void initState() {
    super.initState();
    final star = widget.state.starSelected;
    final ra = GradeComponents.decimalToGrades(star.RA);
    final dec = GradeComponents.decimalToGrades(star.DEC);

    _rah = TextEditingController(text: ra.grades.toInt().toString());
    _ram = TextEditingController(text: ra.minutes.toInt().toString());
    _ras = TextEditingController(text: ra.seconds.toStringAsFixed(2));
    _decg = TextEditingController(text: dec.grades.toInt().toString());
    _decm = TextEditingController(text: dec.minutes.toInt().toString());
    _decs = TextEditingController(text: dec.seconds.toStringAsFixed(2));
  }

  @override
  void dispose() {
    for (final controller in [_rah, _ram, _ras, _decg, _decm, _decs]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final ha = Astro.decimalToHms(state.starSelected.HA);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Objeto seleccionado',
              subtitle: state.starSelected.name.isEmpty
                  ? 'Sin objeto seleccionado'
                  : state.starSelected.name,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Buscar'),
                      onPressed: () {
                        Navigator.pop(context);
                        _openSearch(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.gps_fixed_rounded, size: 16),
                      label: const Text('Ir a'),
                      onPressed: () => state.goTo(
                        ra: state.starSelected.AZ,
                        dec: state.starSelected.ALT,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Ángulo horario',
              subtitle: 'HA: $ha',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: Astro.decimalToHms(state.starSelected.HA),
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Ángulo horario',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: Astro.decimalToDms(
                          state.starSelected.getLocalSiderealTime(
                                state.longitude,
                                state.dtNow,
                              ) *
                              15,
                        ),
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Hora sideral local',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Coordenadas del objeto celeste',
              subtitle: 'Ascensión recta y declinación (J2000).',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: NumberField(
                            label: 'h',
                            controller: _rah,
                            onChanged: _applyCoordinates),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: NumberField(
                            label: 'm',
                            controller: _ram,
                            onChanged: _applyCoordinates),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: NumberField(
                            label: 's',
                            controller: _ras,
                            onChanged: _applyCoordinates),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: NumberField(
                            label: '°',
                            controller: _decg,
                            onChanged: _applyCoordinates),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: NumberField(
                            label: "'",
                            controller: _decm,
                            onChanged: _applyCoordinates),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: NumberField(
                            label: '"',
                            controller: _decs,
                            onChanged: _applyCoordinates),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(child: Text('Seguir objeto')),
                      Switch(
                        value: state.isTracking,
                        onChanged: (_) => state.toggleTracking(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_searchResult != null) ...[
              const SizedBox(height: 12),
              _SearchPreview(star: _searchResult!),
            ],
          ],
        );
      },
    );
  }

  void _applyCoordinates(String _) {
    final ra = GradeComponents.gradesToDecimal(
      double.tryParse(_rah.text) ?? 0,
      double.tryParse(_ram.text) ?? 0,
      double.tryParse(_ras.text) ?? 0,
    );
    final dec = GradeComponents.gradesToDecimal(
      double.tryParse(_decg.text) ?? 0,
      double.tryParse(_decm.text) ?? 0,
      double.tryParse(_decs.text) ?? 0,
    );

    final star = Star(ra, dec, name: 'Objeto manual', type: 0, mag: 2);
    star.precess(widget.state.dtNow);
    star.calculatePositionWithDate(
      widget.state.latitude,
      widget.state.longitude,
      widget.state.dtNow,
    );
    widget.state.starSelected = star;
    widget.state.refresh();
  }

  Future<void> _openSearch(BuildContext context) async {
    final state = widget.state;
    final star = await showDialog<Star>(
      context: context,
      builder: (_) => const _SearchDialog(),
    );
    if (star == null) return;
    state.selectStar(star);
    state.setTouchedFromAzAlt(star.AZ, star.ALT);
    setState(() => _searchResult = star);
  }
}

class _SearchPreview extends StatelessWidget {
  const _SearchPreview({required this.star});

  final Star star;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: star.name,
      subtitle:
          '${Astro.decimalToHms(star.RA)}  ·  ${Astro.decimalToDms(star.DEC)}',
      child: Text(
        'Azimut ${star.AZ.toStringAsFixed(2)}°  ·  Altitud ${star.ALT.toStringAsFixed(2)}°',
        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
      ),
    );
  }
}

/// Selector rápido de objeto celeste dentro del panel de coordenadas.
class _SearchDialog extends StatefulWidget {
  const _SearchDialog();

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final TextEditingController _query = TextEditingController();
  int _type = 0;
  List<Star> _results = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String value) async {
    setState(() => _loading = true);
    final results = await StarCatalog.search(value, _type);
    if (!mounted) return;
    setState(() {
      _results = results.take(120).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 620),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _query,
                    onChanged: _search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar objeto celeste...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: starTypeNames.entries
                        .map(
                          (entry) => ChoiceChip(
                            label: Text(entry.value),
                            selected: _type == entry.key,
                            onSelected: (_) {
                              _type = entry.key;
                              _search(_query.text);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final star = _results[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.star_border_rounded),
                          title: Text(star.name.isEmpty ? 'Sin nombre' : star.name),
                          subtitle: Text(
                            'RA ${Astro.decimalToHms(star.RA)} · DEC ${Astro.decimalToDms(star.DEC)} · mag ${star.mag.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onTap: () => Navigator.pop(context, star),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

const starTypeNames = {
  0: 'Todos',
  1: 'Estrellas',
  2: 'Lunas',
  3: 'Galaxias',
  4: 'Constelaciones',
  5: 'Nebulosas',
  6: 'Cúmulos',
  7: 'Planetas',
};
