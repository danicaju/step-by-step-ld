import 'package:flutter/material.dart';

import '../../domain/math_engine/models/inequality_models.dart';
import 'number_line_layout.dart';
import 'number_line_palette.dart';

/// CustomPainter de la recta real de signos (estilo pizarra / LCD Casio).
///
/// Dibuja en tres bandas (ver [NumberLineBands]): carteles SI / NO arriba, la recta con sus
/// tramos y puntos (llenos o huecos) en el centro; las etiquetas LaTeX van debajo (widget).
class NumberLinePainter extends CustomPainter {
  final Inequality1DVisualData data;
  final NumberLinePalette palette;
  final NumberLineLayout layout;

  NumberLinePainter({required this.data, required this.palette, required this.layout});

  double get _y => NumberLineBands.lineY;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (data.isSystem) {
      _hatchSystem(canvas);
    } else if (data.signTestIntervals != null && data.signTestIntervals!.isNotEmpty) {
      _paintSignTest(canvas, data.signTestIntervals!);
    } else {
      _paintSingle(canvas, data.primaryIntervals);
    }
    _paintAxis(canvas, size);
    _paintPoints(canvas);
  }

  // ------------------------------------------------------------ sistemas 1D
  void _hatchSystem(Canvas canvas) {
    const bandH = 26.0;
    final top = _y - bandH / 2, bottom = _y + bandH / 2;
    final s1 = Paint()
      ..color = palette.accent.withValues(alpha: 0.6)
      ..strokeWidth = 1.6;
    for (final i in data.primaryIntervals) {
      _hatch(canvas, layout.x(i.start), layout.x(i.end), top, bottom, forward: true, paint: s1);
    }
    final s2 = Paint()
      ..color = palette.alpha.withValues(alpha: 0.65)
      ..strokeWidth = 1.6;
    for (final i in data.secondaryIntervals ?? const <InequalityInterval>[]) {
      _hatch(canvas, layout.x(i.start), layout.x(i.end), top, bottom, forward: false, paint: s2);
    }
    final fill = Paint()..color = palette.accent.withValues(alpha: 0.25);
    final edge = Paint()
      ..color = palette.accent
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    for (final i in data.intersectionIntervals ?? const <InequalityInterval>[]) {
      final rect = Rect.fromLTRB(layout.x(i.start), top - 2, layout.x(i.end), bottom + 2);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, edge);
    }
  }

  void _hatch(Canvas canvas, double x1, double x2, double top, double bottom,
      {required bool forward, required Paint paint}) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(x1, top, x2, bottom));
    const step = 7.0;
    final h = bottom - top;
    for (double x = x1 - h; x < x2 + h; x += step) {
      if (forward) {
        canvas.drawLine(Offset(x, bottom), Offset(x + h, top), paint);
      } else {
        canvas.drawLine(Offset(x, top), Offset(x + h, bottom), paint);
      }
    }
    canvas.restore();
  }

  // ------------------------------------------------------- solucion simple
  void _paintSingle(Canvas canvas, List<InequalityInterval> intervals) {
    final fill = Paint()..color = palette.accent.withValues(alpha: 0.28);
    final bar = Paint()
      ..color = palette.accent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    for (final i in intervals) {
      final x1 = layout.x(i.start), x2 = layout.x(i.end);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(x1, _y - 7, x2, _y + 7), const Radius.circular(3)),
        fill,
      );
      canvas.drawLine(Offset(x1, _y), Offset(x2, _y), bar);
    }
  }

  // ----------------------------------------------------- carteles SI / NO
  void _paintSignTest(Canvas canvas, List<InequalityInterval> intervals) {
    final fill = Paint()..color = palette.accent.withValues(alpha: 0.28);
    final bar = Paint()
      ..color = palette.accent
      ..strokeWidth = 3.5;
    for (final i in intervals) {
      final x1 = layout.x(i.start), x2 = layout.x(i.end);
      final midX = (x1 + x2) / 2;
      if (i.isSatisfied) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(x1, _y - 7, x2, _y + 7), const Radius.circular(3)),
          fill,
        );
        canvas.drawLine(Offset(x1, _y), Offset(x2, _y), bar);
        _badge(canvas, 'SÍ', Offset(midX, NumberLineBands.top / 2), palette.yesBg, palette.yesFg);
      } else {
        _badge(canvas, 'NO', Offset(midX, NumberLineBands.top / 2), palette.noBg, palette.noFg);
      }
    }
  }

  void _badge(Canvas canvas, String text, Offset center, Color bg, Color fg) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(center: center, width: tp.width + 14, height: tp.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), Paint()..color = bg);
    tp.paint(canvas, Offset(rect.left + 7, rect.top + 3));
  }

  // ------------------------------------------------------ recta y flechas
  void _paintAxis(Canvas canvas, Size size) {
    final line = Paint()
      ..color = palette.axis
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final left = layout.paddingX - 12, right = layout.contentWidth - layout.paddingX + 12;
    canvas.drawLine(Offset(left, _y), Offset(right, _y), line);
    _arrow(canvas, Offset(left, _y), isLeft: true, paint: line);
    _arrow(canvas, Offset(right, _y), isLeft: false, paint: line);
    final style = TextStyle(color: palette.axis, fontSize: 13, fontWeight: FontWeight.bold);
    _text(canvas, '-∞', Offset(layout.paddingX - 38, _y - 8), style);
    _text(canvas, '+∞', Offset(right + 8, _y - 8), style);
  }

  void _paintPoints(Canvas canvas) {
    final tick = Paint()
      ..color = palette.axis
      ..strokeWidth = 1.3;
    final ring = Paint()
      ..color = palette.ink
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    for (final cp in data.criticalPoints) {
      final sx = layout.x(cp.value);
      canvas.drawLine(Offset(sx, _y - 8), Offset(sx, _y + 8), tick);
      final dot = Paint()..color = cp.isClosed ? palette.accent : palette.panel;
      canvas.drawCircle(Offset(sx, _y), 6, dot);
      canvas.drawCircle(Offset(sx, _y), 6, ring);
    }
  }

  void _arrow(Canvas canvas, Offset p, {required bool isLeft, required Paint paint}) {
    const a = 6.0;
    final d = isLeft ? a : -a;
    canvas.drawPath(
      Path()
        ..moveTo(p.dx + d, p.dy - a)
        ..lineTo(p.dx, p.dy)
        ..lineTo(p.dx + d, p.dy + a),
      paint,
    );
  }

  void _text(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant NumberLinePainter old) =>
      old.data != data || old.palette != palette || old.layout != layout;
}
