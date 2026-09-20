import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../models/stars.dart';
import '../painters/projection3d.dart';
import '../painters/sky_painter.dart';
import '../services/app_state.dart';
import '../services/star_catalog.dart';

/// Superficie interactiva del cielo estelar.
///
/// Mantiene el bucle de dibujo (equivalente a `loop()` en la app móvil),
/// gestiona la cámara con arrastre, pinza y rueda del ratón, y carga el
/// catálogo de estrellas según la magnitud límite.
class SkyView extends StatefulWidget {
  const SkyView({super.key});

  @override
  State<SkyView> createState() => _SkyViewState();
}

class _SkyViewState extends State<SkyView>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;

  List<Star> _stars = const [];
  double _loadedMagnitude = double.nan;

  int _frames = 0;
  DateTime _framesSince = DateTime.now();
  DateTime _countersSince = DateTime.now();

  Offset _lastFocal = Offset.zero;
  double _lastScale = 1;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      state.resetCamera();
      _reloadStars();
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    final state = context.read<AppState>();

    state.tickTime();

    if (state.magMax != _loadedMagnitude) {
      _reloadStars();
    }

    final now = DateTime.now();
    if (now.difference(_countersSince).inMilliseconds >= 1000) {
      _countersSince = now;
      state.tickCounters();

      final elapsed = now.difference(_framesSince).inMilliseconds;
      if (elapsed > 0) {
        state.setFps((_frames * 1000 / elapsed).round());
      }
      _frames = 0;
      _framesSince = now;
    }
    _frames++;

    setState(() {});
  }

  Future<void> _reloadStars() async {
    final target = context.read<AppState>().magMax;
    _loadedMagnitude = target;

    final stars = await StarCatalog.upToMagnitude(target);
    if (!mounted) return;
    setState(() => _stars = stars);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocal = details.localFocalPoint;
    _lastScale = 1;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final state = context.read<AppState>();

    if (details.pointerCount >= 2) {
      final ratio = details.scale / (_lastScale == 0 ? 1 : _lastScale);
      _lastScale = details.scale;
      if (ratio > 0 && ratio.isFinite) state.zoomBy(ratio);
      return;
    }

    final delta = details.localFocalPoint - _lastFocal;
    _lastFocal = details.localFocalPoint;

    // Con ratón el arrastre es más suave que con el dedo (0.4 vs 0.6).
    final gain = MediaQuery.sizeOf(context).width >= Breakpoints.desktop
        ? 0.4
        : 0.6;
    if (delta.dx.abs() > 0.01 || delta.dy.abs() > 0.01) {
      state.rotateBy(delta.dx, delta.dy, gain: gain);
    }
  }

  void _handleTap(TapUpDetails details) {
    if (_size == Size.zero) return;
    final state = context.read<AppState>();

    final camera = SkyProjection(
      rotationAz: state.rotationAz,
      rotationAlt: state.rotationAlt,
      rotationRoll: state.rotationRoll,
      scale: math.min(_size.width, _size.height) / 2 * state.zoom3D,
      center: Offset(_size.width / 2, _size.height / 2),
    );

    final spherical = camera.screenToSpherical(details.localPosition);
    if (spherical == null) return;
    state.setTouchedFromAzAlt(spherical.az, spherical.alt);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final mountConnected = state.isOnline
        ? state.deviceConnectedAdmin
        : state.deviceConnected != null;
    final mountName = state.isOnline
        ? state.nameDeviceConnectedAdmin
        : (state.deviceConnected?.name ?? 'No conectado');

    final scene = SkyScene(
      stars: _stars,
      rotationAz: state.rotationAz,
      rotationAlt: state.rotationAlt,
      rotationRoll: state.rotationRoll,
      zoom: state.zoom3D,
      radiusAdjust: state.rAdjust,
      showAzimuthalGrid: state.isAzimuthalGrid,
      showEquatorialGrid: state.isEquatorialGrid,
      showBelowHorizon: state.showBelowHorizon,
      equatorialToHorizontal: state.equatorialToHorizontal,
      selectedStar: state.starSelected,
      mountRA: state.angleC2,
      mountDec: 90 + state.angleC1,
      mountColor: mountConnected ? const Color(0xFF7CFC00) : AppColors.danger,
      mountLabel: 'Montura: $mountName',
      ownRA: state.touchedRA,
      ownDEC: state.touchedDEC,
      ownColor: state.color,
      ownLabel: '-- ${state.username} --',
      users: state.usersData,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);

        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
              state.zoomBy(factor);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            onTapUp: _handleTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: CustomPaint(
                painter: SkyPainter(scene),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ),
          ),
        );
      },
    );
  }
}
