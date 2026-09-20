import 'dart:math';

class Star {
  double RAJ2000;
  double DECJ2000;
  String name;
  int type;
  double RA = 0;
  double DEC = 0;
  double HA = 0;
  double LST = 0;
  double AZ = 0;
  double ALT = 0;
  double mag = 0;

  Star(
    this.RAJ2000,
    this.DECJ2000, {
    this.name = '',
    this.type = 0,
    this.mag = 1,
  }) {
    RA = RAJ2000;
    DEC = DECJ2000;
  }

  /// Alternativa al método estático coordinates
  factory Star.coordinates(
    double RAHJ2000,
    double RAMJ2000,
    double RASJ2000,
    double DECGJ2000,
    double DECMJ2000,
    double DECSJ2000,
    String name,
    int type,
    double mag,
  ) {
    final RA = gradesToDecimal(RAHJ2000, RAMJ2000, RASJ2000);
    final DEC = gradesToDecimal(DECGJ2000, DECMJ2000, DECSJ2000);
    return Star(RA, DEC, name: name, type: type, mag: mag);
  }

  static double gradesToDecimal(double g, double m, double s) {
    final sign = g < 0 ? -1 : 1;
    return sign * (g.abs() + m / 60.0 + s / 3600.0);
  }

  void calculatePositionWithDate(double lat, double lon, DateTime date) {
    equatorialToHorizontal(lat, lon, date);
  }

  void equatorialToHorizontal(double lat, double lon, DateTime localDate) {
    final LST = getLocalSiderealTime(lon, localDate);

    final RA = RAJ2000;
    final DEC = DECJ2000;

    double HA = LST - RA;
    if (HA > 12) HA -= 24;
    if (HA < -12) HA += 24;

    final haRad = degToRad(HA * 15);
    final latRad = degToRad(lat);
    final decRad = degToRad(DEC);

    final sinALT = sin(decRad) * sin(latRad) +
        cos(decRad) * cos(latRad) * cos(haRad);
    final altRad = asin(sinALT);
    final ALT = radToDeg(altRad);

    final sinAZ = -cos(decRad) * sin(haRad) / cos(altRad);
    final cosAZ = (sin(decRad) - sin(altRad) * sin(latRad)) /
        (cos(altRad) * cos(latRad));
    final azRad = atan2(sinAZ, cosAZ);
    double AZ = radToDeg(azRad);
    if (AZ < 0) AZ += 360;

    this.AZ = AZ;
    this.ALT = ALT;
    this.HA = HA;
    this.LST = LST;
  }

  double getLocalSiderealTime(double lon, DateTime date) {
    final JD = getJulianDate(date);
    final GST = getGreenwichSiderealTime(JD);
    double LST = GST + lon / 15.0;
    if (LST < 0) LST += 24;
    return LST;
  }

  double getJulianDate(DateTime date) {
    final dt1 = DateTime.utc(2000, 1, 1, 12, 0, 0);
    final diffMs = date.toUtc().millisecondsSinceEpoch -
        dt1.millisecondsSinceEpoch;
    final diffDays = diffMs / 86400000.0;
    return 2451545.0 + diffDays;
  }

  double getGreenwichSiderealTime(double JD) {
    final GST =
        18.697374558 + 24.06570982441908 * (JD - 2451545.0);
    return GST % 24;
  }

  double degToRad(double deg) {
    return deg * pi / 180.0;
  }

  double radToDeg(double rad) {
    return rad * 180.0 / pi;
  }

  void precess(DateTime date) {
    final alpha0 = RAJ2000 * (pi * 2.0 / 24.0);
    final delta0 = DECJ2000 * (pi / 180.0);

    final JD1 = 2451545.0;
    final JD2 = getJulianDate(date);

    final T = (JD1 - 2451545.0) / 36525.0;
    final t = (JD2 - JD1) / 36525.0;

    double zetaA = ((2306.2181 + 1.39656 * T - 0.000139 * T * T) * t +
        (0.30188 - 0.000344 * T) * t * t +
        0.017998 * t * t * t);

    double zA = ((2306.2181 + 1.39656 * T - 0.000139 * T * T) * t +
        (1.09468 + 0.000066 * T) * t * t +
        0.018203 * t * t * t);

    double thetaA = ((2004.3109 - 0.85330 * T - 0.000217 * T * T) * t -
        (0.42665 + 0.000217 * T) * t * t -
        0.041833 * t * t * t);

    final sec2rad = pi / (180.0 * 3600.0);
    zetaA *= sec2rad;
    zA *= sec2rad;
    thetaA *= sec2rad;

    final A = cos(delta0) * sin(alpha0 + zetaA);
    final B = cos(thetaA) * cos(delta0) * cos(alpha0 + zetaA) -
        sin(thetaA) * sin(delta0);
    final C = sin(thetaA) * cos(delta0) * cos(alpha0 + zetaA) +
        cos(thetaA) * sin(delta0);

    double alpha = atan2(A, B) + zA;
    double delta = asin(C);

    if (alpha < 0) alpha += 2 * pi;
    if (alpha >= 2 * pi) alpha -= 2 * pi;

    RA = alpha * (24.0 / (2.0 * pi));
    final sign = delta < 0 ? -1 : 1;
    DEC = delta.abs() * (180.0 / pi) * sign;
  }
}