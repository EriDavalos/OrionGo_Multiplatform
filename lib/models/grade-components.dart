class GradeComponents {
  double grades;
  double minutes;
  double seconds;

  GradeComponents(this.grades, this.minutes, this.seconds);

  /// Convierte grados/minutos/segundos a formato decimal
  static double gradesToDecimal(
      double grades, double minutes, double seconds) {
    final sign = grades < 0 ? -1 : 1;
    grades = grades.abs();
    final decimal =
        (grades + (minutes / 60.0) + (seconds / 3600.0)) * sign;
    return decimal;
  }

  /// Convierte formato decimal a grados/minutos/segundos
  static GradeComponents decimalToGrades(double decimalN) {
    final sign = decimalN < 0 ? -1 : 1;
    decimalN *= sign;

    final grades = decimalN.floorToDouble();
    final minutesRaw = (decimalN - grades) * 100 * 0.6;
    final intMinutes = minutesRaw.floorToDouble();
    final seconds = (minutesRaw - intMinutes) * 100 * 0.6;

    return GradeComponents(grades * sign, intMinutes, seconds);
  }
}