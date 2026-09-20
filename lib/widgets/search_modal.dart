import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/astronomy.dart';
import '../core/theme.dart';
import '../models/mount_device.dart';
import '../models/stars.dart';
import '../services/app_state.dart';
import '../services/star_catalog.dart';
import 'adaptive_panel.dart';
import 'dialogs.dart';

/// Abre el buscador como modal: hoja inferior en teléfono, diálogo centrado
/// en escritorio. En la app móvil era un `ModalController`.
Future<void> showSearchModal(BuildContext context) {
  return showAdaptivePanel(
    context,
    title: 'Buscar objeto celeste',
    maxWidth: 780,
    scrollable: false,
    child: const SearchModalBody(),
  );
}

/// Contenido del modal: conexión con la montura + buscador de objetos.
class SearchModalBody extends StatefulWidget {
  const SearchModalBody({super.key});

  @override
  State<SearchModalBody> createState() => _SearchModalBodyState();
}

class _SearchModalBodyState extends State<SearchModalBody> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;

  int _type = 0;
  List<Star> _results = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () => _search(value));
  }

  Future<void> _search(String value) async {
    if (!mounted) return;
    setState(() => _loading = true);
    final results = await StarCatalog.getStars(value, _type);
    if (!mounted) return;
    setState(() {
      _results = results.take(300).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _MountConnectionCard(),
        const SizedBox(height: 12),
        TextField(
          controller: _query,
          onChanged: _onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Buscar objeto celeste...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: StarTypes.names.entries
                .map(
                  (entry) => ChoiceChip(
                    label: Text(entry.value),
                    selected: _type == entry.key,
                    onSelected: (_) {
                      setState(() => _type = entry.key);
                      _search(_query.text);
                    },
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontraron cuerpos celestes disponibles.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) =>
                          _ResultTile(star: _results[index]),
                    ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Conexión con la montura (Bluetooth en Android, puerto serie en escritorio)
// ---------------------------------------------------------------------------

class _MountConnectionCard extends StatefulWidget {
  const _MountConnectionCard();

  @override
  State<_MountConnectionCard> createState() => _MountConnectionCardState();
}

class _MountConnectionCardState extends State<_MountConnectionCard> {
  bool _expanded = false;
  bool _loadingDevices = false;
  List<MountDevice> _devices = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final link = context.read<AppState>().link;
    if (link == null) {
      if (mounted) {
        setState(() => _error =
            'Esta plataforma no admite conexión directa con la montura.');
      }
      return;
    }

    setState(() {
      _loadingDevices = true;
      _error = null;
    });

    try {
      await link.sendPermission();
      final known = await link.listPairedDevices();
      final discovered = await link.discoverUnpairedDevices();
      if (!mounted) return;

      final merged = <String, MountDevice>{
        for (final device in [...known, ...discovered]) device.address: device,
      };

      setState(() {
        _devices = merged.values.toList();
        _loadingDevices = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loadingDevices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final link = state.link;
    final connected = state.deviceConnected;
    final isConnected = link?.isConnected == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected ? AppColors.success : AppColors.borderSoft,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: isConnected ? AppColors.success : AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected
                              ? (connected?.name ?? 'Conectado')
                              : 'Montura desconectada',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${link?.platformLabel ?? 'No disponible'} · '
                          'conéctate para enviar el objeto a la montura',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _loadingDevices ? null : _loadDevices,
                    icon: _loadingDevices
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isConnected)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      icon: const Icon(Icons.link_off_rounded, size: 18),
                      label: const Text('Desconectar montura'),
                      onPressed: () async {
                        await context.read<AppState>().disconnect();
                        if (context.mounted) setState(() {});
                      },
                    ),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_devices.isEmpty && !isConnected)
                    Text(
                      'No se encontraron dispositivos. Empareja la montura con '
                      'el Bluetooth del sistema e intenta de nuevo.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final isCurrent =
                              device.address == connected?.address;

                          return _DeviceRow(
                            device: device,
                            isConnected: isCurrent,
                            onConnect: isConnected
                                ? null
                                : () async {
                                    await context
                                        .read<AppState>()
                                        .connect(device);
                                    if (context.mounted) setState(() {});
                                  },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.isConnected,
    required this.onConnect,
  });

  final MountDevice device;
  final bool isConnected;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? AppColors.success : AppColors.borderSoft,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: AppColors.bg,
          backgroundImage: const AssetImage('assets/img/bluetooth_icon.png'),
        ),
        title: Text(
          device.name.isEmpty ? 'Sin nombre' : device.name,
          style: const TextStyle(fontSize: 13.5),
        ),
        subtitle: Text(
          device.address,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        trailing: isConnected
            ? const Icon(Icons.check_circle_rounded,
                size: 20, color: AppColors.success)
            : const Icon(Icons.link_rounded, size: 20),
        onTap: onConnect,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resultados
// ---------------------------------------------------------------------------

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.star});

  final Star star;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surface,
          child: Icon(_iconFor(star.type), size: 18),
        ),
        title: Text(
          star.name.isEmpty ? 'Sin nombre' : star.name,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          '${StarTypes.label(star.type)} · RA ${Astro.decimalToHms(star.RA)} · '
          'DEC ${Astro.decimalToDms(star.DEC)} · mag ${star.mag.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 11.5),
        ),
        trailing: const Icon(Icons.check_circle_outline_rounded, size: 20),
        onTap: () {
          state.setStarSelected(star);

          // Igual que openSearch() de la app móvil: coloca el puntero sobre
          // el objeto, con el mismo espejo 360 - az que usan las estrellas.
          final lstDegrees = state.localSiderealHours * 15;
          final altaz = Astro.equatorialToHorizontalLST(
            star.RA * 15,
            star.DEC,
            lstDegrees,
            state.latitude,
          );
          state.setTouchedFromAzAlt(360 - altaz.az, altaz.alt);

          Dialogs.toast('${star.name} seleccionado.');
          Navigator.of(context).maybePop();
        },
      ),
    );
  }

  IconData _iconFor(int type) => switch (type) {
        2 => Icons.nightlight_round,
        3 => Icons.blur_circular_rounded,
        4 => Icons.polyline_rounded,
        5 => Icons.cloud_rounded,
        6 => Icons.scatter_plot_rounded,
        7 => Icons.public_rounded,
        _ => Icons.star_rounded,
      };
}
