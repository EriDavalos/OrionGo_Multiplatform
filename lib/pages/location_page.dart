import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../services/app_state.dart';
import '../widgets/dialogs.dart';
import '../widgets/page_scaffold.dart';

/// Elección de la ubicación del observador (equivale a location.page.ts).
class LocationPage extends StatefulWidget {
  const LocationPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  late LatLng _selected;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _selected = LatLng(state.latitude, state.longitude);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('El servicio de ubicación está desactivado.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Sin permisos de ubicación.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _selected = LatLng(position.latitude, position.longitude);
        _locating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _locating = false);
      await Dialogs.error('No se pudo obtener la ubicación: $error');
    }
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final accept = await Dialogs.confirm(
      '¿Desea cambiar la ubicación?',
      'El cielo y los movimientos se recalcularán con las coordenadas nuevas.',
    );
    if (!accept) return;

    state.latitude = _selected.latitude;
    state.longitude = _selected.longitude;
    state.refresh();
    Dialogs.toast('Ubicación actualizada.');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final desktop = context.isDesktop;

    return PageScaffold(
      title: 'Ubicación',
      subtitle: 'Toca el mapa para fijar la posición del observador.',
      onBack: widget.onBack,
      scrollable: false,
      maxWidth: 1200,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      actions: [
        if (!desktop)
          IconButton(
            tooltip: 'Usar mi ubicación',
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
      ],
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _selected,
                      initialZoom: 5,
                      onTap: (_, point) => setState(() => _selected = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.oriongo.platform',
                        tileBuilder: (context, tileWidget, tile) => ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            -0.85, 0, 0, 0, 255, //
                            0, -0.85, 0, 0, 255, //
                            0, 0, -0.85, 0, 255, //
                            0, 0, 0, 1, 0, //
                          ]),
                          child: tileWidget,
                        ),
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selected,
                            width: 46,
                            height: 46,
                            child: const Icon(
                              Icons.location_on_rounded,
                              size: 42,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Text(
                        '${_selected.latitude.toStringAsFixed(5)}, '
                        '${_selected.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: const Text('Usar mi ubicación'),
                  onPressed: _locating ? null : _useCurrentLocation,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Guardar'),
                  onPressed: _save,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Actual: ${state.latitude.toStringAsFixed(5)}, '
            '${state.longitude.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
