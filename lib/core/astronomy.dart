import 'dart:math' as math;

import '../models/grade_components.dart';

/// Utilidades de ángulos y formato (equivalente a GradeComponents + helpers
/// que en Ionic vivían dentro de home.page.ts).
class Astro {
  static const double toRad = math.pi / 180;
  static const double toDeg = 180 / math.pi;

  static double normalizeAngle(double angle) =>
      (angle % 360 + 360) % 360;

  static double shortestAngleDiff(double a, double b) =>
      ((a - b + 540) % 360) - 180;

  static double clamp(double value, double min, double max) =>
      value < min ? min : (value > max ? max : value);

  /// 12.582 -> 12h 34m 55.20s
  static String decimalToHms(double decimalHours) {
    final g = GradeComponents.DecimalToGrades(decimalHours);
    final sign = decimalHours < 0 ? '-' : '';
    return '$sign${g.Grades.abs().toInt().toString().padLeft(2, '0')}h '
        '${g.Minutes.toInt().toString().padLeft(2, '0')}m '
        '${g.Seconds.toStringAsFixed(2).padLeft(5, '0')}s';
  }

  /// -41.68 -> -41° 40' 48.00"
  static String decimalToDms(double decimalDegrees) {
    final g = GradeComponents.DecimalToGrades(decimalDegrees);
    final sign = decimalDegrees < 0 ? '-' : '';
    return '$sign${g.Grades.abs().toInt().toString().padLeft(3, '0')}° '
        '${g.Minutes.toInt().toString().padLeft(2, '0')}\' '
        '${g.Seconds.toStringAsFixed(2).padLeft(5, '0')}"';
  }

  /// Segundos del día -> 13:45:02
  static String secondsOfDayToHms(int seconds) {
    final s = seconds % 86400;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${sec.toString().padLeft(2, '0')}';
  }

  /// Trunca a 2 decimales sin notación científica (para los inputs del cielo).
  static String fixed(double value, [int decimals = 2]) =>
      value.toStringAsFixed(decimals);

  /// Conversión inversa: (azimut, altitud) -> AR/DEC. La app móvil la usaba al
  /// arrastrar o tocar el cielo.
  static ({double ra, double dec}) horizontalToEquatorial(
    double azDeg,
    double altDeg,
    double lstDeg,
    double latitudeDeg,
  ) {
    final az = azDeg * toRad;
    final alt = altDeg * toRad;
    final lat = -latitudeDeg * toRad;
    final lst = lstDeg * toRad;

    final xHor = math.cos(alt) * math.cos(az);
    final yHor = math.cos(alt) * math.sin(az);
    final zHor = math.sin(alt);

    final x = xHor * math.sin(lat) + zHor * math.cos(lat);
    final y = yHor;
    final z = xHor * math.cos(lat) - zHor * math.sin(lat);

    final dec = math.asin(z.clamp(-1.0, 1.0));
    final ha = math.atan2(y, x);
    final ra = (lst - ha + 2 * math.pi) % (2 * math.pi);

    return (
      ra: ((ra * toDeg) % 360 + 360) % 360,
      dec: dec * toDeg,
    );
  }

  /// Conversión AR/DEC -> (azimut, altitud) de los rectángulos y la retícula
  /// de declinación: la versión con latitud y DEC negados de la app móvil
  /// (`equatorialToHorizontal` en home.page.ts). No usa hora sideral: vive en
  /// el marco LST = 0, el mismo del centro de la cámara.
  static ({double az, double alt}) equatorialToHorizontal(
    double raDeg,
    double decDeg,
    double latitudeDeg,
  ) {
    final latDeg = -latitudeDeg;

    final ra = raDeg * toRad;
    final dec = (-decDeg) * toRad;
    final lat = latDeg * toRad;

    // Coordenadas ecuatoriales a cartesianas
    final x = math.cos(dec) * math.cos(ra);
    final y = math.cos(dec) * math.sin(ra);
    final z = math.sin(dec);

    // Rotación por la latitud del observador (a coordenadas horizontales)
    final xHor = x * math.sin(lat) - z * math.cos(lat);
    final yHor = y;
    final zHor = x * math.cos(lat) + z * math.sin(lat);

    // Coordenadas horizontales
    var azDeg = math.atan2(yHor, xHor) * toDeg;
    if (azDeg < 0) azDeg += 360;

    final alt = math.asin(zHor.clamp(-1.0, 1.0)) * toDeg;
    return (az: azDeg, alt: alt);
  }

  /// Conversión AR/DEC -> (azimut, altitud) usando la hora sideral local en
  /// grados. Es la que usa el cielo de la app móvil
  /// (`equatorialToHorizontalLST`).
  static ({double az, double alt}) equatorialToHorizontalLST(
    double raDeg,
    double decDeg,
    double lstDeg,
    double latitudeDeg,
  ) {
    final ha = (lstDeg - raDeg + 360) % 360;

    final lat = latitudeDeg * toRad;
    final dec = decDeg * toRad;
    final haRad = ha * toRad;

    final sinAlt =
        math.sin(dec) * math.sin(lat) + math.cos(dec) * math.cos(lat) * math.cos(haRad);
    final alt = math.asin(sinAlt.clamp(-1.0, 1.0));

    final cosAz =
        (math.sin(dec) - math.sin(alt) * math.sin(lat)) / (math.cos(alt) * math.cos(lat));

    var az = math.acos(cosAz.clamp(-1.0, 1.0));
    if (math.sin(haRad) > 0) az = 2 * math.pi - az;

    return (az: az * toDeg, alt: alt * toDeg);
  }
}

/// Catálogo de tipos usado por el buscador de objetos celestes.
class StarTypes {
  static const Map<int, String> names = {
    0: 'Todos',
    1: 'Estrellas',
    2: 'Lunas',
    3: 'Galaxias',
    4: 'Constelaciones',
    5: 'Nebulosas',
    6: 'Cúmulos',
    7: 'Planetas',
  };

  static const Map<int, String> iconNames = {
    1: 'star_icon',
    2: 'moon_icon',
    3: 'galaxy_icon',
    4: 'constellation_icon',
    5: 'nebula_icon',
  };

  static String label(int type) => names[type] ?? 'Objeto';
}
