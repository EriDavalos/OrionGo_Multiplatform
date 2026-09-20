import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart' as vm;

/// Cámara del cielo. Usa la misma matemática que la app móvil (rotación de
/// azimut, altitud y roll sobre la esfera celeste) pero resuelta con
/// `vector_math`: las tres rotaciones se componen una vez en una única matriz
/// que se reutiliza para proyectar cada punto.
class SkyProjection {
  SkyProjection({
    required this.rotationAz,
    required this.rotationAlt,
    required this.rotationRoll,
    required this.scale,
    required this.center,
  }) {
    _matrix = vm.Matrix4.rotationY(_rad(rotationRoll))
      ..multiply(vm.Matrix4.rotationX(_rad(rotationAlt)))
      ..multiply(vm.Matrix4.rotationZ(_rad(rotationAz)));
  }

  final double rotationAz;
  final double rotationAlt;
  final double rotationRoll;
  final double scale;
  final Offset center;

  /// Distancia de la cámara al centro de la esfera.
  static const double cameraDistance = 1.0;

  late final vm.Matrix4 _matrix;
  vm.Matrix4? _inverse;

  static double _rad(double degrees) => degrees * math.pi / 180;

  /// Proyecta (azimut, altitud) en grados al plano de la pantalla.
  /// Devuelve `null` si el punto queda detrás del observador.
  Offset? project(double azimuth, double altitude) {
    final az = _rad(azimuth);
    final alt = _rad(altitude);

    final point = vm.Vector3(
      math.cos(alt) * math.cos(az),
      math.cos(alt) * math.sin(az),
      math.sin(alt),
    );

    final rotated = _matrix.transformed3(point);

    // z > 0 significa que el punto está detrás de la cámara.
    if (rotated.z > 0) return null;

    final depth = cameraDistance - rotated.z;
    if (depth.abs() < 0.0001) return null;

    return Offset(
      center.dx + (rotated.x / depth) * scale,
      center.dy - (rotated.y / depth) * scale,
    );
  }

  /// Inversa de [project]: convierte un punto de pantalla en (az, alt).
  ({double az, double alt})? screenToSpherical(Offset screen) {
    final dx = (screen.dx - center.dx) / scale;
    final dy = (center.dy - screen.dy) / scale;

    const d = cameraDistance;

    final a = dx * dx + dy * dy + 1;
    final b = -2 * dx * dx * d - 2 * dy * dy * d;
    final c = dx * dx * d * d + dy * dy * d * d - 1;

    final discriminant = b * b - 4 * a * c;
    if (discriminant < 0) return null;

    final z3 = (-b - math.sqrt(discriminant)) / (2 * a);
    final x3 = dx * (d - z3);
    final y3 = dy * (d - z3);

    _inverse ??= vm.Matrix4.inverted(_matrix);
    final point = _inverse!.transformed3(vm.Vector3(x3, y3, z3));

    final alt = math.asin(point.z.clamp(-1.0, 1.0)) * 180 / math.pi;
    var az = math.atan2(point.y, point.x) * 180 / math.pi;
    az = (az + 360) % 360;

    return (az: az, alt: alt);
  }

  /// Factor de sensibilidad del arrastre: gira más despacio cerca del cenit.
  static double sensitivityFactor(double angleDegrees) {
    var angle = angleDegrees % 360;
    if (angle < 0) angle += 360;

    final distance = (angle - 270).abs();
    final factor = math.max(0.0, 1 - (distance / 90));
    return 1 - factor;
  }
}
