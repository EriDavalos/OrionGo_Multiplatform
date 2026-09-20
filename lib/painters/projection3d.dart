import 'dart:math';
import 'dart:ui';
import '../globals.dart';

Offset? project3DPoint(double az, double alt, double scale, double cx, double cy) {
  const toRad = pi / 180;

  az *= toRad;
  alt *= toRad;

  double x = cos(alt) * cos(az);
  double y = cos(alt) * sin(az);
  double z = sin(alt);

  final azRot = rotationAZ3D * toRad;
  final altRot = rotationALT3D * toRad;
  final rollRot = rotationRoll3D * toRad;

  final x1 = x * cos(azRot) - y * sin(azRot);
  final y1 = x * sin(azRot) + y * cos(azRot);
  final z1 = z;

  final y2 = y1 * cos(altRot) - z1 * sin(altRot);
  final z2 = y1 * sin(altRot) + z1 * cos(altRot);
  final x2 = x1;

  final x3 = x2 * cos(rollRot) - y2 * sin(rollRot);
  final y3 = x2 * sin(rollRot) + y2 * cos(rollRot);
  final z3 = z2;

  if (z2 > 0) return null;

  const d = 1.0;

  final px = cx + (x3 / (d - z3)) * scale;
  final py = cy - (y3 / (d - z3)) * scale;

  return Offset(px, py);
}