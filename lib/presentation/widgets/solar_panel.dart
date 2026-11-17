import 'package:flutter/material.dart';

/// Panel fotovoltaico decorativo de la ClassWiz: 4 celdas oscuras en una
/// franja con marco gris y rejilla fina. Sin tonos azules (anti-slop).
class SolarPanel extends StatelessWidget {
  final double width;
  final double height;

  const SolarPanel({super.key, this.width = 54, this.height = 16});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const Key('solar_panel'),
      size: Size(width, height),
      painter: _SolarPainter(),
    );
  }
}

class _SolarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2.5));
    canvas.drawRRect(frame, Paint()..color = const Color(0xFF3A3D44));
    const pad = 1.5;
    const gap = 1.2;
    final cellW = (size.width - pad * 2 - gap * 3) / 4;
    final cellH = size.height - pad * 2;
    for (int i = 0; i < 4; i++) {
      final x = pad + i * (cellW + gap);
      final rect = Rect.fromLTWH(x, pad, cellW, cellH);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A2420), Color(0xFF14110F)],
          ).createShader(rect),
      );
      final grid = Paint()
        ..color = const Color(0xFF5A4F47).withValues(alpha: 0.45)
        ..strokeWidth = 0.4;
      for (int g = 1; g < 3; g++) {
        canvas.drawLine(Offset(x + cellW * g / 3, pad), Offset(x + cellW * g / 3, pad + cellH), grid);
      }
      canvas.drawLine(Offset(x, pad + cellH / 2), Offset(x + cellW, pad + cellH / 2), grid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
