import 'package:flutter/material.dart';

/// Icono de fracción vertical apilada (caja vacía / barra / caja llena) para la tecla a/b.
class FractionKeyIcon extends StatelessWidget {
  final Color color;
  final double size;

  const FractionKeyIcon({super.key, this.color = Colors.white, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const Key('fraction_key_icon'),
      size: Size(size, size),
      painter: _FractionPainter(color),
    );
  }
}

class _FractionPainter extends CustomPainter {
  final Color color;
  const _FractionPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final fill = Paint()..color = color;
    final box = size.width * 0.42;
    final cx = size.width / 2;
    final top = Rect.fromCenter(
      center: Offset(cx, size.height * 0.22 + box / 2 - box / 2 + 1),
      width: box,
      height: box * 0.8,
    );
    canvas.drawRect(top, stroke);
    final midY = size.height / 2;
    canvas.drawLine(Offset(size.width * 0.12, midY), Offset(size.width * 0.88, midY), stroke);
    final bottom = Rect.fromCenter(
      center: Offset(cx, size.height * 0.78),
      width: box,
      height: box * 0.8,
    );
    canvas.drawRect(bottom, fill);
  }

  @override
  bool shouldRepaint(covariant _FractionPainter old) => old.color != color;
}
