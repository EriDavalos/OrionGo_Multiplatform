// Los nombres se conservan idénticos a models/grade-components.ts de la app
// móvil (Grades, Minutes, Seconds, GradesToDecimal, DecimalToGrades).
// ignore_for_file: non_constant_identifier_names

class GradeComponents {
  double Grades;
  double Minutes;
  double Seconds;

  GradeComponents(this.Grades, this.Minutes, this.Seconds);

  /// Convierte grados/minutos/segundos a formato decimal
  static double GradesToDecimal(double grades, double minutes, double seconds) {
    final sign = grades < 0 ? -1 : 1;
    grades = grades.abs();
    final decimal =
        (grades + (minutes / 60.0) + (seconds / 3600.0)) * sign;
    return decimal;
  }

  /// Convierte formato decimal a grados/minutos/segundos
  static GradeComponents DecimalToGrades(double decimalN) {
    final sign = decimalN < 0 ? -1 : 1;
    decimalN *= sign;

    final grades = decimalN.floorToDouble();
    final minutesRaw = (decimalN - grades) * 100 * 0.6;
    final intMinutes = minutesRaw.floorToDouble();
    final seconds = (minutesRaw - intMinutes) * 100 * 0.6;

    return GradeComponents(grades * sign, intMinutes, seconds);
  }
}
