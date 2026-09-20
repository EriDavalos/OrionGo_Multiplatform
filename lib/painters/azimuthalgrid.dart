import 'package:flutter/material.dart';
import 'dart:math';

//////////////////// PAINTER ////////////////////

class AzimuthalGridPainter extends CustomPainter {

  @override
  void paint(Canvas canvas, Size size) {

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final maxRadius = min(centerX, centerY) - 20;

    final gridPaint = Paint()
      ..color = const Color.fromRGBO(80, 80, 80, 1)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // RADIALES (cada 15°)
    for (int i = 0; i < 360; i += 15) {

      final angle = (i - 90) * pi / 180;

      final x = centerX + maxRadius * cos(angle);
      final y = centerY + maxRadius * sin(angle);

      canvas.drawLine(
        Offset(centerX, centerY),
        Offset(x, y),
        gridPaint,
      );

      // Etiquetas cada 30°
      if (i % 30 == 0) {

        final lx = centerX + (maxRadius + 20) * cos(angle);
        final ly = centerY + (maxRadius + 20) * sin(angle);

        textPainter.text = TextSpan(
          text: "$i°",
          style: const TextStyle(color: Colors.white, fontSize: 14),
        );

        textPainter.layout();

        textPainter.paint(
          canvas,
          Offset(lx - textPainter.width / 2,
                 ly - textPainter.height / 2),
        );
      }
    }

    // CÍRCULOS ALTITUD (cada 10°)
    for (int j = 0; j <= 90; j += 10) {

      final radius = (j / 90) * maxRadius;

      canvas.drawCircle(
        Offset(centerX, centerY),
        radius,
        gridPaint,
      );

      if (j > 0) {

        textPainter.text = TextSpan(
          text: "${90 - j}°",
          style: const TextStyle(color: Colors.white, fontSize: 12),
        );

        textPainter.layout();

        textPainter.paint(
          canvas,
          Offset(centerX + radius + 10, centerY - 10),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}