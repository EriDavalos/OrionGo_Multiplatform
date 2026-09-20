// Parámetros como RA, DEC, LST siguen el nombre de drawRectangleAt/draw3DStar.
// ignore_for_file: non_constant_identifier_names

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/astronomy.dart';
import '../core/theme.dart';
import '../models/mount_device.dart';
import '../models/stars.dart';
import 'projection3d.dart';

/// Datos que necesita el cielo para dibujarse. Equivale al estado que la app
/// móvil lee directamente del MainService dentro de draw3DScene().
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
    required this.isViewAll,
    required this.lstHours,
    required this.latitude,
    required this.touchedAZ,
    required this.touchedALT,
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

  /// Equivale a `isViewAll`: mostrar también bajo el horizonte.
  final bool isViewAll;

  /// Hora sideral local en horas (`getLocalSiderealTime`).
  final double lstHours;
  final double latitude;

  /// Punto del cielo señalado (toque en pantalla u objeto seleccionado);
  /// lo usa draw3DPointer, igual que en la app móvil.
  final double touchedAZ;
  final double touchedALT;

  /// Posición de la montura en el marco LST = 0.
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

/// Dibuja la esfera celeste completa: portado de `draw3DScene()` de la app
/// móvil, con los mismos nombres de funciones y las mismas conversiones:
///
/// - Estrellas: `equatorialToHorizontalLST(RA, DEC, LST*15)` + espejo
///   `az = 360 - az` (aquí es donde se ve girar el cielo con la Tierra).
/// - Retícula de AR: `equatorialToHorizontalLST(ra, dec, -LST*15)` sin espejo.
/// - Rectángulos y retícula de DEC: `equatorialToHorizontal` con latitud y
///   DEC negados, sin hora sideral (marco LST = 0): por eso el rectángulo
///   propio queda anclado al centro de la vista.
class SkyPainter extends CustomPainter {
  SkyPainter(this.scene);

  final SkyScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scale = math.min(centerX, centerY) * scene.zoom;

    final camera = SkyProjection(
      rotationAz: scene.rotationAz,
      rotationAlt: scene.rotationAlt,
      rotationRoll: scene.rotationRoll,
      scale: scale,
      center: Offset(centerX, centerY),
    );

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg);

    /* Líneas azimutales */
    if (scene.showAzimuthalGrid) {
      draw3DAzimuthalLines(canvas, camera, 15);
      draw3DAltitudeCircles(canvas, camera, 10);
    }

    /* Líneas ecuatoriales */
    if (scene.showEquatorialGrid) {
      draw3DRightAscensionLines(canvas, camera, 15);
      draw3DDeclinationCircles(canvas, camera, 10);
    }

    /* Debajo del horizonte */
    if (!scene.isViewAll) {
      draw3DUnderHorizonBackground(canvas, camera);
    }

    draw3DHorizonCircle(canvas, camera);

    _drawStars(canvas, camera, size);

    // Coordenadas cardinales
    draw3DAZCP(canvas, camera, 0, 0, AppColors.danger, 'N');
    draw3DAZCP(canvas, camera, 90, 0, AppColors.danger, 'E');
    draw3DAZCP(canvas, camera, 180, 0, AppColors.danger, 'S');
    draw3DAZCP(canvas, camera, 270, 0, AppColors.danger, 'O');

    // Estrella seleccionada / punto señalado
    draw3DPointer(
      canvas,
      camera,
      scene.touchedAZ,
      scene.touchedALT,
      Colors.white,
    );

    // Montura, observador y usuarios remotos (drawRectangleAt, como en móvil)
    drawRectangleAt(
      canvas,
      camera,
      scene.mountRA,
      scene.mountDec,
      scene.mountColor,
      scene.mountLabel,
    );

    drawRectangleAt(
      canvas,
      camera,
      scene.ownRA,
      scene.ownDEC,
      scene.ownColor,
      scene.ownLabel,
    );

    for (final user in scene.users) {
      drawRectangleAt(
        canvas,
        camera,
        user.posRA,
        user.posDEC,
        _parseColor(user.color),
        '-- ${user.username}${user.admin ? ' (Admin)' : ''} --',
      );
    }
  }

  // ------------------------------------------------------------ retícula 3D
  void draw3DAzimuthalLines(Canvas canvas, SkyProjection camera, int step) {
    final paint = Paint()
      ..color = AppColors.gridAzimuthal
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final maxHorizon = scene.isViewAll ? -90.0 : 0.0;

    for (double az = 0; az < 360; az += step) {
      final path = Path();
      var started = false;

      for (double alt = 90; alt >= maxHorizon; alt -= 3) {
        final point = camera.project3DPoint(az, alt);
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

  void draw3DAltitudeCircles(Canvas canvas, SkyProjection camera, int step) {
    final paint = Paint()
      ..color = const Color(0x66007BCE)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final maxHorizon = scene.isViewAll ? -90.0 : 0.0;

    for (double alt = maxHorizon; alt < 90; alt += step) {
      final path = Path();
      var started = false;

      for (double az = 0; az <= 360; az += 5) {
        final point = camera.project3DPoint(az, alt);
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

  void draw3DHorizonCircle(Canvas canvas, SkyProjection camera) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    var started = false;

    for (double az = 0; az <= 360; az += 5) {
      final point = camera.project3DPoint(az, 0);
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

  void draw3DDeclinationCircles(
    Canvas canvas,
    SkyProjection camera, [
    int step = 10,
  ]) {
    final maxHorizon = scene.isViewAll ? -90.0 : -5.0;

    for (double dec = -90; dec <= 90; dec += step) {
      final paint = Paint()
        ..color = dec == 0 ? const Color(0x59FD6500) : const Color(0x33FD6500)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      final path = Path();
      var started = false;

      for (double ra = 0; ra <= 360; ra += 5) {
        final altaz = Astro.equatorialToHorizontal(ra, dec, scene.latitude);
        final point = camera.project3DPoint(altaz.az, altaz.alt);

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

  void draw3DRightAscensionLines(
    Canvas canvas,
    SkyProjection camera, [
    int step = 15,
  ]) {
    final paint = Paint()
      ..color = AppColors.gridEquatorial
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final maxHorizon = scene.isViewAll ? -90.0 : -5.0;

    // La app móvil usa LST * -15 aquí: equivale al espejo 360 - az de las
    // estrellas, sin aplicar el volteo explícito.
    for (double ra = 0; ra < 360; ra += step) {
      final path = Path();
      var started = false;

      for (double dec = -90; dec <= 90; dec += 3) {
        final altaz = Astro.equatorialToHorizontalLST(
          ra,
          dec,
          -scene.lstHours * 15,
          scene.latitude,
        );
        final point = camera.project3DPoint(altaz.az, altaz.alt);

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

  void draw3DUnderHorizonBackground(
    Canvas canvas,
    SkyProjection camera, [
    int step = 10,
  ]) {
    final paint = Paint()..color = AppColors.ground;

    for (double alt = 0; alt > -90; alt -= step) {
      final altNext = alt - step;

      for (double az = 0; az <= 360; az += step) {
        final p1 = camera.project3DPoint(az, alt);
        final p2 = camera.project3DPoint(az, altNext);
        final p3 = camera.project3DPoint(az + step, altNext);
        final p4 = camera.project3DPoint(az + step, alt);

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

  // ------------------------------------------------------------------ cielo
  void _drawStars(Canvas canvas, SkyProjection camera, Size size) {
    final white = Paint()..color = AppColors.starDefault;
    final cyan = Paint()..color = AppColors.starCyan;
    final violet = Paint()..color = AppColors.starViolet;

    for (final star in scene.stars) {
      final altaz = Astro.equatorialToHorizontalLST(
        star.RA * 15,
        star.DEC,
        scene.lstHours * 15,
        scene.latitude,
      );
      final alt = altaz.alt;
      if (!scene.isViewAll && alt < 0) continue;

      final az = 360 - altaz.az;
      final point = camera.project3DPoint(az, alt);
      if (point == null) continue;
      if (point.dx < 0 ||
          point.dx > size.width ||
          point.dy < 0 ||
          point.dy > size.height) {
        continue;
      }

      final paint = switch (star.type) {
        1 => white,
        3 => cyan,
        _ => violet,
      };

      draw3DStar(
        canvas,
        camera,
        star.RA * 15,
        star.DEC,
        scene.lstHours,
        paint.color,
        '',
        mag: magToRadius(star.mag) + scene.radiusAdjust,
      );
    }
  }

  /// Portado de draw3DStar(): proyección con LST + espejo de azimut.
  void draw3DStar(
    Canvas canvas,
    SkyProjection camera,
    double RA,
    double DEC,
    double LST,
    Color color,
    String label, {
    double lx = -10,
    double ly = -10,
    double mag = 1,
  }) {
    final altaz = Astro.equatorialToHorizontalLST(
      RA,
      DEC,
      LST * 15,
      scene.latitude,
    );

    final az = 360 - altaz.az;
    final alt = altaz.alt;

    final p = camera.project3DPoint(az, alt);
    if (p == null) return;

    canvas.drawCircle(p, math.max(0.4, mag), Paint()..color = color);

    if (label.isNotEmpty) {
      _label(
        canvas,
        label,
        p + Offset(lx, ly),
        color: Colors.white,
        fontSize: 14,
      );
    }
  }

  /// Portado de magToRadius(): brillo -> radio en píxeles.
  double magToRadius(double mag) {
    const minMag = -1.5;
    const maxMag = 6.0;
    const minR = 1.0;
    const maxR = 0.25;

    final clampedMag = mag.clamp(minMag, maxMag);
    final t = (clampedMag - minMag) / (maxMag - minMag);
    return minR + (maxR - minR) * t;
  }

  /// Portado de draw3DAZCP(): punto cardinal con espejo `az = 360 - AZ`.
  void draw3DAZCP(
    Canvas canvas,
    SkyProjection camera,
    double AZ,
    double ALT,
    Color color,
    String label, {
    double lx = -10,
    double ly = -20,
  }) {
    final az = 360 - AZ;
    final p = camera.project3DPoint(az, ALT);
    if (p == null) return;

    canvas.drawCircle(p, 3, Paint()..color = color);
    _label(
      canvas,
      label,
      p + Offset(lx, ly),
      color: color,
      fontSize: 16,
      bold: true,
    );
  }

  /// Portado de draw3DPointer(): cruz de localización sobre el punto
  /// señalado (toque en pantalla u objeto seleccionado).
  void draw3DPointer(
    Canvas canvas,
    SkyProjection camera,
    double az,
    double alt,
    Color color, {
    double mag = 35,
  }) {
    final p = camera.project3DPoint(az, alt);
    if (p == null) return;

    final distS = 35 * 0.3;
    final distF = 35 * 0.8;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(p.dx - mag - distS, p.dy),
      Offset(p.dx - distF, p.dy),
      paint,
    );
    canvas.drawLine(
      Offset(p.dx + distF, p.dy),
      Offset(p.dx + mag + distS, p.dy),
      paint,
    );
    canvas.drawLine(
      Offset(p.dx, p.dy - mag - distS),
      Offset(p.dx, p.dy - distF),
      paint,
    );
    canvas.drawLine(
      Offset(p.dx, p.dy + distF),
      Offset(p.dx, p.dy + mag + distS),
      paint,
    );
  }

  // ----------------------------------------------------- rectángulos (marco)
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
  /// Usa la conversión con latitud y DEC negados y SIN hora sideral (marco
  /// LST = 0), igual que allá: el marcador del observador (touchedRA/touchedDEC
  /// sincronizado con la cámara) se mantiene en el centro de la pantalla,
  /// relativo a donde se mira.
  ///
  /// El marcador rota para seguir la línea de rotación del cielo: se proyecta
  /// el punto principal y un segundo punto desplazado 0.1° en DEC, y el
  /// rectángulo se orienta con el ángulo entre ambos. Su tamaño crece con el
  /// zoom según el modelo del sensor (4160x6240 con focal 400).
  void drawRectangleAt(
    Canvas canvas,
    SkyProjection camera,
    double ra,
    double dec,
    Color color,
    String label,
  ) {
    // Proyección del punto principal.
    final altaz = Astro.equatorialToHorizontal(ra, dec, scene.latitude);
    final p = camera.project3DPoint(altaz.az, altaz.alt);
    if (p == null) return;

    // Proyección de un punto muy cercano (para calcular la orientación).
    final altaz2 = Astro.equatorialToHorizontal(ra, dec + 0.1, scene.latitude);
    final p2 = camera.project3DPoint(altaz2.az, altaz2.alt);
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
      ..strokeWidth = 1
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
    canvas.drawLine(const Offset(-5, 0), const Offset(5, 0), paint);
    canvas.drawLine(const Offset(0, -5), const Offset(0, 5), paint);

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

  // ----------------------------------------------------------------- ayuda
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
