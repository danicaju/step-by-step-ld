import 'package:flutter/material.dart';

import '../lcd/lcd_palette.dart';
import 'triangle_marks.dart';
import 'triangle_slot_layout.dart';

/// Triangulo del editor: trazo nitido en tinta LCD, arcos en los angulos editables, escuadra
/// en el vertice recto y los vertices rotulados A, B y C. Las casillas se colocan encima.
class TriangleDiagramPainter extends CustomPainter {
  final TriangleSlotLayout layout;
  final bool right;
  final LcdPalette palette;

  const TriangleDiagramPainter({required this.layout, required this.right, required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final v = layout.v;
    final path = Path()
      ..moveTo(v[0].dx, v[0].dy)
      ..lineTo(v[1].dx, v[1].dy)
      ..lineTo(v[2].dx, v[2].dy)
      ..close();
    canvas.drawPath(path, Paint()..color = palette.inset.withValues(alpha: 0.55));
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.formula
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    final mark = Paint()
      ..color = palette.formula
      ..strokeWidth = 1.6;
    for (var i = 0; i < 3; i++) {
      final isRight = right && i == 2;
      TriangleMarks.angle(canvas, v[i], v[(i + 1) % 3], v[(i + 2) % 3], mark, radius: 16, right: isRight);
    }
    final c = Offset((v[0].dx + v[1].dx + v[2].dx) / 3, (v[0].dy + v[1].dy + v[2].dy) / 3);
    const names = ['A', 'B', 'C'];
    for (var i = 0; i < 3; i++) {
      TriangleMarks.label(canvas, names[i], TriangleMarks.outward(v[i], c, 13), palette.formula, size: 13, weight: FontWeight.w900);
    }
    if (right) {
      TriangleMarks.label(canvas, '90°', v[2] + const Offset(26, -13), palette.formula, size: 11);
    }
  }

  @override
  bool shouldRepaint(covariant TriangleDiagramPainter old) =>
      old.right != right || old.palette != palette || old.layout != layout;
}
