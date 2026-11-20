import 'package:flutter/material.dart';

enum Guide {
  none('No guide'),
  thirds('Rule of thirds'),
  golden('Golden ratio'),
  diagonals('Diagonals'),
  center('Centre cross');

  const Guide(this.label);
  final String label;
}

/// Composition guides drawn over the image. Everything is computed from the
/// paint size, so it lines up at any zoom or window size.
class GuidePainter extends CustomPainter {
  GuidePainter(this.guide);
  final Guide guide;

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    void v(double f) => canvas.drawLine(Offset(s.width * f, 0), Offset(s.width * f, s.height), paint);
    void h(double f) => canvas.drawLine(Offset(0, s.height * f), Offset(s.width, s.height * f), paint);

    switch (guide) {
      case Guide.none:
        break;
      case Guide.thirds:
        for (final f in [1 / 3, 2 / 3]) {
          v(f);
          h(f);
        }
      case Guide.golden:
        for (final f in [0.382, 0.618]) {
          v(f);
          h(f);
        }
      case Guide.diagonals:
        canvas.drawLine(Offset.zero, Offset(s.width, s.height), paint);
        canvas.drawLine(Offset(s.width, 0), Offset(0, s.height), paint);
      case Guide.center:
        v(0.5);
        h(0.5);
    }
  }

  @override
  bool shouldRepaint(GuidePainter old) => old.guide != guide;
}
