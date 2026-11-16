import 'package:flutter/material.dart';

class MatrixBracket extends StatelessWidget {
  final bool isLeft;
  final bool isDeterminant;
  final Color color;
  final double height;

  const MatrixBracket({
    super.key,
    required this.isLeft,
    required this.isDeterminant,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (isDeterminant) {
      return Container(
        width: 2.2,
        height: height,
        color: color,
        margin: const EdgeInsets.symmetric(horizontal: 2),
      );
    }
    return CustomPaint(
      size: Size(6, height),
      painter: BracketPainter(isLeft: isLeft, color: color),
    );
  }
}

class BracketPainter extends CustomPainter {
  final bool isLeft;
  final Color color;

  BracketPainter({required this.isLeft, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isLeft) {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BracketPainter oldDelegate) {
    return oldDelegate.isLeft != isLeft || oldDelegate.color != color;
  }
}
