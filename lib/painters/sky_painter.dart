import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/astronomy.dart';
import '../core/theme.dart';
import '../models/mount_device.dart';
import '../models/stars.dart';
import 'projection3d.dart';

/// Datos que necesita el cielo para dibujarse.
class SkyScene {
  const SkyScene({
    required this.stars,
    required this.rotationAz,
    required this.rotationAlt,
    required this.rotationRoll,
    required this.zoom,
    required this.radiusAdjust,
    required this.showAzimuthalGrid,
    required this.showEquatorialGrid,
    required this.showBelowHorizon,
    required this.equatorialToHorizontal,
    required this.selectedStar,
    required this.mountRA,
    required this.mountDec,
    required this.mountColor,
    required this.mountLabel,
    required this.ownRA,
    required this.ownDEC,
    required this.ownColor,
    required this.ownLabel,
    required this.users,
  });

  final List<Star> stars;
  final double rotationAz;
  final double rotationAlt;
  final double rotationRoll;
  final double zoom;
  final double radiusAdjust;
  final bool showAzimuthalGrid;
  final bool showEquatorialGrid;
  final bool showBelowHorizon;

  /// Conversión AR (grados) / DEC (grados) -> azimut / altitud, usando la hora
  /// sideral local del observador.
  final ({double az, double alt}) Function(double raDeg, double decDeg)
      equatorialToHorizontal;

  final Star selectedStar;

  /// Posición de la montura expresada en coordenadas ecuatoriales.
  final double mountRA;
  final double mountDec;
  final Color mountColor;
  final String mountLabel;

  final double ownRA;
  final double ownDEC;
  final Color ownColor;
  final String ownLabel;
  final List<RemoteUser> users;
}

/// Dibuja la esfera celeste completa: equivalente a `draw3DScene()` de la app
/// móvil, con la misma cámara y proyección.
class SkyPainter extends CustomPainter {
  SkyPainter(this.scene);

  final SkyScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final camera = SkyProjection(
      rotationAz: scene.rotationAz,
      rotationAlt: scene.rotationAlt,
      rotationRoll: scene.rotationRoll,
      scale: math.min(centerX, centerY) * scene.zoom,
      center: Offset(centerX, centerY),
    );

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg);

    if (scene.showAzimuthalGrid) {
      _drawAzimuthalLines(canvas, camera);
      _drawAltitudeCircles(canvas, camera);
    }
    if (scene.showEquatorialGrid) {
      _drawRightAscensionLines(canvas, camera);
      _drawDeclinationCircles(canvas, camera);
    }
    if (!scene.showBelowHorizon) {
      _drawGround(canvas, camera);
    }

    _drawHorizon(canvas, camera);
    _drawStars(canvas, camera, size);
    _drawCardinalPoints(canvas, camera);
    _drawSelectedStar(canvas, camera);
    _drawMount(canvas, camera);
    _drawObservers(canvas, camera);
  }

  // ------------------------------------------------------------------ retícula
  void _drawAzimuthalLines(Canvas canvas, SkyProjection camera) {
    final paint = Paint()
      ..color = AppColors.gridAzimuthal
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final maxHorizon = scene.showBelowHorizon ? -90.0 : 0.0;

    for (double az = 0; az < 360; az += 15) {
      final path = Path();
      var started = false;

      for (double alt = 90; alt >= maxHorizon; alt -= 3) {
        final point = camera.project(az, alt);
        if (point == null) {
          started = false;
          continue;
        }
        if (started) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          started = true;
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawAltitudeCircles(Canvas canvas, SkyProjection camera) {
    final paint = Paint()
      ..color = const Color(0x66007BCE)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final maxHorizon = scene.showBelowHorizon ? -90.0 : 0.0;

    for (double alt = maxHorizon; alt < 90; alt += 10) {
      final path = Path();
      var started = false;

      for (double az = 0; az <= 360; az += 5) {
        final point = camera.project(az, alt);
        if (point == null) {
          started = false;
          continue;
        }
        if (started) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          started = true;
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawRightAscensionLines(Canvas canvas, SkyProjection camera) {
    final paint = Paint()
      ..color = AppColors.gridEquatorial
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final maxHorizon = scene.showBelowHorizon ? -90.0 : -5.0;

    for (double ra = 0; ra < 360; ra += 15) {
      final path = Path();
      var started = false;

      for (double dec = -90; dec <= 90; dec += 3) {
        final altaz = scene.equatorialToHorizontal(ra, dec);
        final point = camera.project(altaz.az, altaz.alt);

        if (point == null || altaz.alt < maxHorizon) {
          started = false;
          continue;
        }
        if (started) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          started = true;
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawDeclinationCircles(Canvas canvas, SkyProjection camera) {
    final maxHorizon = scene.showBelowHorizon ? -90.0 : -5.0;

    for (double dec = -90; dec <= 90; dec += 10) {
      final paint = Paint()
        ..color = dec == 0 ? const Color(0x59FD6500) : const Color(0x33FD6500)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      final path = Path();
      var started = false;

      for (double ra = 0; ra <= 360; ra += 5) {
        final altaz = scene.equatorialToHorizontal(ra, dec);
        final point = camera.project(altaz.az, altaz.alt);

        if (point == null || altaz.alt < maxHorizon) {
          started = false;
          continue;
        }
        if (started) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          started = true;
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawGround(Canvas canvas, SkyProjection camera) {
    final paint = Paint()..color = AppColors.ground;

    for (double alt = 0; alt > -90; alt -= 10) {
      final altNext = alt - 10;

      for (double az = 0; az <= 360; az += 10) {
        final p1 = camera.project(az, alt);
        final p2 = camera.project(az, altNext);
        final p3 = camera.project(az + 10, altNext);
        final p4 = camera.project(az + 10, alt);

        if (p1 == null || p2 == null || p3 == null || p4 == null) continue;

        canvas.drawPath(
          Path()
            ..moveTo(p1.dx, p1.dy)
            ..lineTo(p2.dx, p2.dy)
            ..lineTo(p3.dx, p3.dy)
            ..lineTo(p4.dx, p4.dy)
            ..close(),
          paint,
        );
      }
    }
  }

  void _drawHorizon(Canvas canvas, SkyProjection camera) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    var started = false;

    for (double az = 0; az <= 360; az += 5) {
      final point = camera.project(az, 0);
      if (point == null) {
        started = false;
        continue;
      }
      if (started) {
        path.lineTo(point.dx, point.dy);
      } else {
        path.moveTo(point.dx, point.dy);
        started = true;
      }
    }
    canvas.drawPath(path, paint);
  }

  // -------------------------------------------------------------------- cielo
  void _drawStars(Canvas canvas, SkyProjection camera, Size size) {
    final white = Paint()..color = AppColors.starDefault;
    final cyan = Paint()..color = AppColors.starCyan;
    final violet = Paint()..color = AppColors.starViolet;

    for (final star in scene.stars) {
      final altaz = scene.equatorialToHorizontal(star.RA * 15, star.DEC);
      if (!scene.showBelowHorizon && altaz.alt < 0) continue;

      final point = camera.project(altaz.az, altaz.alt);
      if (point == null) continue;
      if (point.dx < 0 ||
          point.dx > size.width ||
          point.dy < 0 ||
          point.dy > size.height) {
        continue;
      }

      final radius = _magnitudeRadius(star.mag) + scene.radiusAdjust;
      final paint = switch (star.type) {
        1 => white,
        3 => cyan,
        _ => violet,
      };

      canvas.drawCircle(point, math.max(0.4, radius), paint);
    }
  }

  double _magnitudeRadius(double magnitude) {
    const minMag = -1.5;
    const maxMag = 6.0;
    const minR = 2.0;
    const maxR = 0.5;

    final clamped = magnitude.clamp(minMag, maxMag);
    final t = (clamped - minMag) / (maxMag - minMag);
    return minR + (maxR - minR) * t;
  }

  void _drawCardinalPoints(Canvas canvas, SkyProjection camera) {
    const cardinals = <(double, String)>[
      (0, 'N'),
      (90, 'E'),
      (180, 'S'),
      (270, 'O'),
    ];

    for (final (az, label) in cardinals) {
      final point = camera.project(az, 0);
      if (point == null) continue;
      _label(
        canvas,
        label,
        point + const Offset(-6, -24),
        color: const Color(0xFFEF4444),
        fontSize: 16,
        bold: true,
      );
    }
  }

  void _drawSelectedStar(Canvas canvas, SkyProjection camera) {
    final star = scene.selectedStar;
    if (star.name.isEmpty) return;

    final altaz = scene.equatorialToHorizontal(star.RA * 15, star.DEC);
    final point = camera.project(altaz.az, altaz.alt);
    if (point == null) return;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;

    canvas.drawLine(
        point - const Offset(16, 0), point + const Offset(16, 0), paint);
    canvas.drawLine(
        point - const Offset(0, 16), point + const Offset(0, 16), paint);
    canvas.drawCircle(
      point,
      9,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    _label(canvas, star.name, point + const Offset(20, -10),
        color: Colors.white, fontSize: 13, bold: true);
  }

  void _drawMount(Canvas canvas, SkyProjection camera) {
    _drawRectangleAt(
      canvas,
      camera,
      scene.mountRA,
      scene.mountDec,
      scene.mountColor,
      scene.mountLabel,
    );
  }

  void _drawObservers(Canvas canvas, SkyProjection camera) {
    _drawRectangleAt(
      canvas,
      camera,
      scene.ownRA,
      scene.ownDEC,
      scene.ownColor,
      scene.ownLabel,
    );

    for (final user in scene.users) {
      _drawRectangleAt(
        canvas,
        camera,
        user.posRA,
        user.posDEC,
        _parseColor(user.color),
        '-- ${user.username}${user.admin ? ' (Admin)' : ''} --',
      );
    }
  }

  static Color _parseColor(String hex) {
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return Colors.white;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? Colors.white : Color(parsed);
  }

  /// Rectángulo del campo visual: portado de `drawRectangleAt()` de la app
  /// móvil.
  ///
  /// Igual que allá, el marcador rota para seguir la línea de rotación del
  /// cielo: se proyecta el punto principal y un segundo punto desplazado
  /// 0.1° en DEC, y el rectángulo se orienta con el ángulo entre ambos. Su
  /// tamaño crece con el zoom siguiendo el modelo del sensor (4160x6240 con
  /// focal 400).
  void _drawRectangleAt(
    Canvas canvas,
    SkyProjection camera,
    double ra,
    double dec,
    Color color,
    String label,
  ) {
    // Proyección del punto principal.
    final altaz = scene.equatorialToHorizontal(ra, dec);
    final p = camera.project(altaz.az, altaz.alt);
    if (p == null) return;

    // Proyección de un punto muy cercano (para calcular la orientación).
    final altaz2 = scene.equatorialToHorizontal(ra, dec + 0.1);
    final p2 = camera.project(altaz2.az, altaz2.alt);
    if (p2 == null) return;

    final angle = math.atan2(p2.dy - p.dy, p2.dx - p.dx);

    // Tamaño del rectángulo (misma matemática que la app móvil).
    const focalLens = 400.0;
    const size = focalLens * 1.25 / 1000;
    const sensorWidthMM = 4160 * size;
    const sensorHeightMM = 6240 * size;
    const imageWidthPx = 4160.0;
    const imageHeightPx = 6240.0;
    const rectWidthMM = 4.160;
    const rectHeightMM = 6.240;

    // El zoom se aplica como reducción del campo visual.
    final mmPerPixelX = (sensorWidthMM / scene.zoom) / imageWidthPx;
    final mmPerPixelY = (sensorHeightMM / scene.zoom) / imageHeightPx;

    final rectWidthPx = rectWidthMM / mmPerPixelX;
    final rectHeightPx = rectHeightMM / mmPerPixelY;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);

    // Rectángulo.
    canvas.drawRect(
      Rect.fromLTWH(
        -rectWidthPx / 2,
        -rectHeightPx / 2,
        rectWidthPx,
        rectHeightPx,
      ),
      paint,
    );

    // Cruz en el centro.
    canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), paint);
    canvas.drawLine(const Offset(0, -8), const Offset(0, 8), paint);

    // Texto rotado ~-89.36° como en la app móvil (Math.atan(-90)).
    canvas.rotate(math.atan(-90.0));

    final fontSize = math.max(rectHeightPx * 0.03, 9.5);
    final raStr = Astro.decimalToHms(ra / 15);
    final decStr = Astro.decimalToDms(dec);

    _label(
      canvas,
      'RA: $raStr, DEC: $decStr',
      Offset(-rectWidthPx / 1.35, -rectHeightPx / 2.9),
      color: color,
      fontSize: fontSize,
    );
    _label(
      canvas,
      label,
      Offset(-rectWidthPx / 1.35, -rectHeightPx / 3.4),
      color: color,
      fontSize: fontSize,
    );

    canvas.restore();
  }

  void _label(
    Canvas canvas,
    String text,
    Offset position, {
    required Color color,
    double fontSize = 12,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant SkyPainter oldDelegate) => true;
}
