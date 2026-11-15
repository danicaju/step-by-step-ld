import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/math_engine/models/inequality_models.dart';

/// Widget visual para la recta real de inecuaciones (1.º grado, 2.º grado, valor absoluto y sistemas 1D).
class NumberLineWidget extends StatelessWidget {
  final Inequality1DVisualData data;
  final bool isOledDark;
  final double height;

  const NumberLineWidget({
    super.key,
    required this.data,
    this.isOledDark = false,
    this.height = 130,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isOledDark ? const Color(0xFF14181B) : const Color(0xFFE8EFEA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOledDark ? const Color(0xFF263238) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      child: CustomPaint(
        painter: NumberLinePainter(
          data: data,
          isOledDark: isOledDark,
        ),
      ),
    );
  }
}

/// CustomPainter que dibuja la recta real técnica estilo pizarra/LCD.
class NumberLinePainter extends CustomPainter {
  final Inequality1DVisualData data;
  final bool isOledDark;

  NumberLinePainter({
    required this.data,
    required this.isOledDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final centerY = size.height * 0.52;
    final paddingX = 36.0;
    final drawWidth = size.width - 2 * paddingX;

    // Colores según tema LCD / OLED
    final axisColor = isOledDark ? const Color(0xFF64748B) : const Color(0xFF475569);
    final labelColor = isOledDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final primaryColor = const Color(0xFF0D9488); // Teal

    // 1. Determinar rango visible [minX, maxX]
    final pts = data.criticalPoints.map((p) => p.value).toList();
    double minVal = -5.0;
    double maxVal = 5.0;

    if (pts.isNotEmpty) {
      final pMin = pts.reduce(math.min);
      final pMax = pts.reduce(math.max);
      final span = math.max(pMax - pMin, 2.0);
      final margin = math.max(span * 0.45, 1.5);
      minVal = (pMin - margin).floorToDouble();
      maxVal = (pMax + margin).ceilToDouble();
    }

    if ((maxVal - minVal).abs() < 1e-4) {
      minVal -= 3;
      maxVal += 3;
    }

    double toScreenX(double val) {
      if (val.isInfinite) {
        return val.isNegative ? paddingX : size.width - paddingX;
      }
      final t = (val - minVal) / (maxVal - minVal);
      return paddingX + t * drawWidth;
    }

    // 2. Dibujar zonas sombreadas / rayados
    if (data.isSystem) {
      _paintSystemHatching(
        canvas: canvas,
        size: size,
        centerY: centerY,
        toScreenX: toScreenX,
        primaryIntervals: data.primaryIntervals,
        secondaryIntervals: data.secondaryIntervals ?? const [],
        intersectionIntervals: data.intersectionIntervals ?? const [],
      );
    } else if (data.signTestIntervals != null && data.signTestIntervals!.isNotEmpty) {
      _paintSignTestIntervals(
        canvas: canvas,
        size: size,
        centerY: centerY,
        toScreenX: toScreenX,
        intervals: data.signTestIntervals!,
        labelColor: labelColor,
      );
    } else {
      _paintSingleSolution(
        canvas: canvas,
        size: size,
        centerY: centerY,
        toScreenX: toScreenX,
        intervals: data.primaryIntervals,
        fillColor: primaryColor,
      );
    }

    // 3. Dibujar la recta real principal con flechas a los extremos
    final linePaint = Paint()
      ..color = axisColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(paddingX - 12, centerY),
      Offset(size.width - paddingX + 12, centerY),
      linePaint,
    );

    // Flechas en los extremos
    _drawArrow(canvas, Offset(paddingX - 12, centerY), isLeft: true, paint: linePaint);
    _drawArrow(canvas, Offset(size.width - paddingX + 12, centerY), isLeft: false, paint: linePaint);

    // Leyendas -∞ y +∞
    _drawText(
      canvas,
      r'-\infty',
      Offset(paddingX - 28, centerY - 8),
      TextStyle(color: axisColor, fontSize: 11, fontWeight: FontWeight.bold),
    );
    _drawText(
      canvas,
      r'+\infty',
      Offset(size.width - paddingX + 16, centerY - 8),
      TextStyle(color: axisColor, fontSize: 11, fontWeight: FontWeight.bold),
    );

    // 4. Dibujar puntos críticos (abiertos ○ o cerrados ●) y sus etiquetas
    for (final cp in data.criticalPoints) {
      final sx = toScreenX(cp.value);

      // Marca vertical de referencia
      canvas.drawLine(
        Offset(sx, centerY - 5),
        Offset(sx, centerY + 5),
        Paint()
          ..color = axisColor
          ..strokeWidth = 1.2,
      );

      // Círculo del punto crítico
      final dotPaint = Paint()..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = isOledDark ? Colors.white : const Color(0xFF0F172A)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;

      if (cp.isClosed) {
        // Punto relleno [●]
        dotPaint.color = isOledDark ? const Color(0xFF38BDF8) : const Color(0xFF0F766E);
        canvas.drawCircle(Offset(sx, centerY), 5.5, dotPaint);
        canvas.drawCircle(Offset(sx, centerY), 5.5, strokePaint);
      } else {
        // Punto hueco (○)
        dotPaint.color = isOledDark ? const Color(0xFF14181B) : const Color(0xFFE8EFEA);
        canvas.drawCircle(Offset(sx, centerY), 5.5, dotPaint);
        canvas.drawCircle(Offset(sx, centerY), 5.5, strokePaint);
      }

      // Etiqueta del valor debajo del punto
      _drawCenteredText(
        canvas,
        cp.label,
        Offset(sx, centerY + 12),
        TextStyle(
          color: labelColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    // 5. Título o leyenda inferior (solución final)
    if (data.solutionLatex.isNotEmpty) {
      final summaryText = data.solutionLatex
          .replaceAll(r'\text{', '')
          .replaceAll('}', '')
          .replaceAll(r'\cup', '∪')
          .replaceAll(r'\cap', '∩')
          .replaceAll(r'\emptyset', '∅')
          .replaceAll(r'\mathbb{R}', 'ℝ')
          .replaceAll(r'-\infty', '-∞')
          .replaceAll(r'+\infty', '+∞')
          .replaceAll(r'\quad', '  ');

      _drawCenteredText(
        canvas,
        'Solución: $summaryText',
        Offset(size.width / 2, size.height - 10),
        TextStyle(
          color: isOledDark ? const Color(0xFF38BDF8) : const Color(0xFF0F766E),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Rayados para Sistemas 1D (S1 = ///, S2 = \\\, Intersección = XXX)
  // ---------------------------------------------------------------------------
  void _paintSystemHatching({
    required Canvas canvas,
    required Size size,
    required double centerY,
    required double Function(double) toScreenX,
    required List<InequalityInterval> primaryIntervals,
    required List<InequalityInterval> secondaryIntervals,
    required List<InequalityInterval> intersectionIntervals,
  }) {
    final bandH = 26.0;
    final topY = centerY - bandH / 2;
    final bottomY = centerY + bandH / 2;

    // Rayado S1: +45° (///) color Cyan / Azul
    final s1Paint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.55)
      ..strokeWidth = 1.6;

    for (final inter in primaryIntervals) {
      final x1 = toScreenX(inter.start);
      final x2 = toScreenX(inter.end);
      _drawHatch(canvas, x1, x2, topY, bottomY, isForward: true, paint: s1Paint);
    }

    // Rayado S2: -45° (\\\) color Rosa / Naranja
    final s2Paint = Paint()
      ..color = const Color(0xFFFB7185).withValues(alpha: 0.55)
      ..strokeWidth = 1.6;

    for (final inter in secondaryIntervals) {
      final x1 = toScreenX(inter.start);
      final x2 = toScreenX(inter.end);
      _drawHatch(canvas, x1, x2, topY, bottomY, isForward: false, paint: s2Paint);
    }

    // Intersección S1 ∩ S2: Malla cruzada XXX + relleno esmeralda translúcido
    final meshFill = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    final meshBorder = Paint()
      ..color = const Color(0xFF059669)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    for (final inter in intersectionIntervals) {
      final x1 = toScreenX(inter.start);
      final x2 = toScreenX(inter.end);
      final rect = Rect.fromLTRB(x1, topY - 2, x2, bottomY + 2);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), meshFill);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), meshBorder);
    }
  }

  void _drawHatch(
    Canvas canvas,
    double x1,
    double x2,
    double topY,
    double bottomY, {
    required bool isForward,
    required Paint paint,
  }) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(x1, topY, x2, bottomY));
    const step = 7.0;
    final h = bottomY - topY;

    if (isForward) {
      for (double x = x1 - h; x < x2 + h; x += step) {
        canvas.drawLine(Offset(x, bottomY), Offset(x + h, topY), paint);
      }
    } else {
      for (double x = x1 - h; x < x2 + h; x += step) {
        canvas.drawLine(Offset(x, topY), Offset(x + h, bottomY), paint);
      }
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Inecuación individual (1.º Grado y Valor Absoluto)
  // ---------------------------------------------------------------------------
  void _paintSingleSolution({
    required Canvas canvas,
    required Size size,
    required double centerY,
    required double Function(double) toScreenX,
    required List<InequalityInterval> intervals,
    required Color fillColor,
  }) {
    const bandH = 14.0;
    final topY = centerY - bandH / 2;
    final bottomY = centerY + bandH / 2;

    final fillPaint = Paint()
      ..color = fillColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final barPaint = Paint()
      ..color = fillColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    for (final inter in intervals) {
      final x1 = toScreenX(inter.start);
      final x2 = toScreenX(inter.end);
      final rect = Rect.fromLTRB(x1, topY, x2, bottomY);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), fillPaint);
      canvas.drawLine(Offset(x1, centerY), Offset(x2, centerY), barPaint);
    }
  }

  // ---------------------------------------------------------------------------
  // Inecuaciones de 2.º Grado con carteles SÍ / NO sobre la recta
  // ---------------------------------------------------------------------------
  void _paintSignTestIntervals({
    required Canvas canvas,
    required Size size,
    required double centerY,
    required double Function(double) toScreenX,
    required List<InequalityInterval> intervals,
    required Color labelColor,
  }) {
    const bandH = 14.0;
    final topY = centerY - bandH / 2;
    final bottomY = centerY + bandH / 2;

    final greenFill = Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.35);
    final greenBar = Paint()
      ..color = const Color(0xFF059669)
      ..strokeWidth = 3.5;

    for (final inter in intervals) {
      final x1 = toScreenX(inter.start);
      final x2 = toScreenX(inter.end);
      final midX = (x1 + x2) / 2;

      if (inter.isSatisfied) {
        final rect = Rect.fromLTRB(x1, topY, x2, bottomY);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), greenFill);
        canvas.drawLine(Offset(x1, centerY), Offset(x2, centerY), greenBar);

        // Cartel "SÍ" en verde brillante encima de la recta
        _drawBadge(
          canvas,
          'SÍ',
          Offset(midX, centerY - 18),
          const Color(0xFF16A34A),
          Colors.white,
        );
      } else {
        // Cartel "NO" en rojo/tenue encima de la recta
        _drawBadge(
          canvas,
          'NO',
          Offset(midX, centerY - 18),
          const Color(0xFFDC2626),
          Colors.white,
        );
      }
    }
  }

  void _drawBadge(
    Canvas canvas,
    String text,
    Offset center,
    Color bg,
    Color textColor,
  ) {
    const padH = 6.0;
    const padV = 2.0;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + padH * 2,
      height: tp.height + padV * 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = bg,
    );
    tp.paint(canvas, Offset(rect.left + padH, rect.top + padV));
  }

  void _drawArrow(
    Canvas canvas,
    Offset point, {
    required bool isLeft,
    required Paint paint,
  }) {
    const arrowSize = 6.0;
    final path = Path();
    if (isLeft) {
      path.moveTo(point.dx + arrowSize, point.dy - arrowSize);
      path.lineTo(point.dx, point.dy);
      path.lineTo(point.dx + arrowSize, point.dy + arrowSize);
    } else {
      path.moveTo(point.dx - arrowSize, point.dy - arrowSize);
      path.lineTo(point.dx, point.dy);
      path.lineTo(point.dx - arrowSize, point.dy + arrowSize);
    }
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  void _drawCenteredText(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant NumberLinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.isOledDark != isOledDark;
  }
}
