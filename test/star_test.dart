import 'package:flutter_test/flutter_test.dart';
import 'package:oriongo_multiplatform/core/astronomy.dart';
import 'package:oriongo_multiplatform/models/grade_components.dart';
import 'package:oriongo_multiplatform/models/stars.dart';

void main() {
  group('GradeComponents', () {
    test('convierte grados/minutos/segundos a decimal y vuelve', () {
      final decimal = GradeComponents.GradesToDecimal(41, 16, 7.5);
      expect(decimal, closeTo(41.26875, 0.0001));

      final parts = GradeComponents.DecimalToGrades(decimal);
      expect(parts.Grades, 41);
      expect(parts.Minutes, 16);
      expect(parts.Seconds, closeTo(7.5, 0.01));
    });

    test('conserva el signo de las declinaciones negativas', () {
      expect(GradeComponents.GradesToDecimal(-41, 16, 0), lessThan(0));
      expect(GradeComponents.DecimalToGrades(-41.5).Grades, -41);
    });
  });

  group('Star', () {
    test('la hora sideral local se mantiene en el rango horario', () {
      final star = Star(0, 0);
      final lst = star.getLocalSiderealTime(-89.5727, DateTime.utc(2026, 1, 1));
      expect(lst, inInclusiveRange(0, 24));
    });

    test('la precesión desplaza la posición respecto a J2000', () {
      final star = Star.coordinates(
        0, 42, 44.33, 41, 16, 7.5, 'Andrómeda', 3, 3.4,
      );
      final raJ2000 = star.RAJ2000;

      star.precess(DateTime.utc(2050, 1, 1));

      // La precesión general mueve la AR unas 3.07 s por año: 50 años ≈ 0.04 h.
      expect((star.RA - raJ2000).abs(), greaterThan(0.01));
      expect(star.RA, inInclusiveRange(0, 24));
      expect(star.DEC, inInclusiveRange(-90, 90));
    });

    test('un objeto en la culminación alcanza 90 grados de altitud', () {
      // HA = 0 cuando la hora sideral coincide con la ascensión recta y la
      // declinación es igual a la latitud del observador.
      // Todas las coordenadas se expresan en grados (AR en horas × 15).
      final latitude = 21.094412;
      final result = Astro.equatorialToHorizontalLST(
        12 * 15,
        latitude,
        12 * 15,
        latitude,
      );

      expect(result.alt, closeTo(90, 0.01));
    });
  });

  group('Astro', () {
    test('formatea horas y grados en sexagesimal', () {
      expect(Astro.decimalToHms(12.5), '12h 30m 00.00s');
      expect(Astro.decimalToDms(-41.5), '-041° 30\' 00.00"');
      expect(Astro.secondsOfDayToHms(3661), '01:01:01');
    });

    test('normaliza ángulos y calcula la diferencia mínima', () {
      expect(Astro.normalizeAngle(-30), 330);
      expect(Astro.normalizeAngle(370), 10);
      expect(Astro.shortestAngleDiff(10, 350), 20);
      expect(Astro.shortestAngleDiff(350, 10), -20);
    });
  });
}
