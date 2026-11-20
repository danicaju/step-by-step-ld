import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/math_engine/geometry/line_equations_solver.dart';
import '../lcd/lcd_palette.dart';

/// Mini-grafica cartesiana de la recta: cuadricula suave, ejes, recta, puntos A/B o P
/// y flecha del vector director. Los colores salen de [LcdPalette] (clasico, papel, noche).
class LineGraphPainter extends CustomPainter {
  final LineEquationsResult result;
  final LcdPalette palette;
  final bool night;

  const LineGraphPainter(this.result, this.palette, {this.night = false});

  /// Acento del vector director: rojo ALPHA oscuro en LCD clara, ambar SHIFT en la oscura.
  Color get accent => night ? const Color(0xFFE5A93C) : const Color(0xFF9A3B3B);

  /// Ventana (en coordenadas de la recta) que contiene puntos, vector, origen y cortes con los ejes.
  static Rect viewport(LineEquationsResult r, Size size) {
    final xs = <double>[0], ys = <double>[0];
    void add(double x, double y) {
      xs.add(x);
      ys.add(y);
    }

    for (final p in r.points) {
      add(p.x.toDouble(), p.y.toDouble());
    }
    final px = r.x0.toDouble(), py = r.y0.toDouble();
    add(px + r.v1.toDouble(), py + r.v2.toDouble());
    if (r.b != 0) add(0, -r.c / r.b);
    if (r.a != 0) add(-r.c / r.a, 0);
    var minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    var minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final span = math.max(math.max(maxX - minX, maxY - minY), 4.0);
    final pad = span * 0.22;
    minX -= pad;
    maxX += pad;
    minY -= pad;
    maxY += pad;
    // Misma escala en ambos ejes para que la pendiente se vea fiel.
    final w = math.max(size.width, 1), h = math.max(size.height, 1);
    final k = math.max((maxX - minX) / w, (maxY - minY) / h);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    return Rect.fromCenter(center: Offset(cx, cy), width: k * w, height: k * h);
  }

  static double niceStep(double span) {
    final raw = span / 6;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final m in [1.0, 2.0, 5.0, 10.0]) {
      if (raw <= m * mag) return m * mag;
    }
    return 10 * mag;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final vp = viewport(result, size);
    final k = size.width / vp.width;
    Offset toPx(double x, double y) => Offset((x - vp.left) * k, size.height - (y - vp.top) * k);

    final grid = Paint()
      ..color = palette.border.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = palette.original
      ..strokeWidth = 1.4;
    final step = niceStep(vp.width);
    for (var x = (vp.left / step).ceil() * step; x <= vp.right; x += step) {
      canvas.drawLine(toPx(x, vp.top), toPx(x, vp.bottom), grid);
    }
    for (var y = (vp.top / step).ceil() * step; y <= vp.bottom; y += step) {
      canvas.drawLine(toPx(vp.left, y), toPx(vp.right, y), grid);
    }
    final o = toPx(0, 0);
    if (o.dx >= 0 && o.dx <= size.width) canvas.drawLine(Offset(o.dx, 0), Offset(o.dx, size.height), axis);
    if (o.dy >= 0 && o.dy <= size.height) canvas.drawLine(Offset(0, o.dy), Offset(size.width, o.dy), axis);
    _ticks(canvas, size, vp, step, toPx);

    // La recta A x + B y + C = 0 de borde a borde.
    final line = Paint()
      ..color = palette.formula
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final a = result.a.toDouble(), b = result.b.toDouble(), c = result.c.toDouble();
    if (b != 0) {
      canvas.drawLine(toPx(vp.left, (-a * vp.left - c) / b), toPx(vp.right, (-a * vp.right - c) / b), line);
    } else if (a != 0) {
      canvas.drawLine(toPx(-c / a, vp.top), toPx(-c / a, vp.bottom), line);
    }

    _vector(canvas, toPx);
    final dot = Paint()..color = palette.formula;
    for (final p in result.points) {
      final at = toPx(p.x.toDouble(), p.y.toDouble());
      canvas.drawCircle(at, 4.2, dot);
      canvas.drawCircle(at, 4.2, Paint()
        ..color = palette.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
      _text(canvas, '${p.label}(${_n(p.x.toDouble())}, ${_n(p.y.toDouble())})', at + const Offset(7, -15),
          bold: true, bg: true);
    }
  }

  void _vector(Canvas canvas, Offset Function(double, double) toPx) {
    if (result.points.isEmpty) return;
    final p0 = result.points.first;
    final from = toPx(p0.x.toDouble(), p0.y.toDouble());
    final to = toPx(p0.x.toDouble() + result.v1.toDouble(), p0.y.toDouble() + result.v2.toDouble());
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    final d = to - from;
    if (d.distance < 1) return;
    final u = d / d.distance;
    final n = Offset(-u.dy, u.dx);
    canvas.drawLine(to, to - u * 9 + n * 4.5, paint);
    canvas.drawLine(to, to - u * 9 - n * 4.5, paint);
    _text(canvas, 'v', (from + to) / 2 + n * 11, bold: true, color: accent);
  }

  void _ticks(Canvas canvas, Size size, Rect vp, double step, Offset Function(double, double) toPx) {
    final o = toPx(0, 0);
    final yAxis = o.dx.clamp(10.0, size.width - 10);
    final xAxis = o.dy.clamp(8.0, size.height - 10);
    for (var x = (vp.left / step).ceil() * step; x <= vp.right; x += step) {
      if (x.abs() < step / 2) continue;
      _text(canvas, _n(x), Offset(toPx(x, 0).dx, xAxis + 7), size9: true);
    }
    for (var y = (vp.top / step).ceil() * step; y <= vp.bottom; y += step) {
      if (y.abs() < step / 2) continue;
      _text(canvas, _n(y), Offset(yAxis - 9, toPx(0, y).dy), size9: true);
    }
  }

  static String _n(double v) {
    final r = (v * 100).round() / 100;
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }

  void _text(Canvas canvas, String text, Offset at,
      {bool bold = false, bool size9 = false, bool bg = false, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? (size9 ? palette.original : palette.formula),
          fontSize: size9 ? 8.5 : 10.5,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final topLeft = at - Offset(tp.width / 2, tp.height / 2);
    if (bg) {
      canvas.drawRect(
        (topLeft & tp.size).inflate(1.5),
        Paint()..color = palette.background.withValues(alpha: 0.78),
      );
    }
    tp.paint(canvas, topLeft);
  }

  @override
  bool shouldRepaint(covariant LineGraphPainter old) =>
      old.result != result || old.palette != palette || old.night != night;
}

/// Grafica de la recta con el fondo de la LCD (recorte estricto, sin desbordes).
class LineGraphView extends StatelessWidget {
  final LineEquationsResult result;
  final LcdTheme theme;

  const LineGraphView({super.key, required this.result, required this.theme});

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    return ClipRRect(
      key: const Key('line_graph_clip'),
      borderRadius: BorderRadius.circular(8.5),
      child: Container(
        color: pal.background,
        child: LayoutBuilder(
          builder: (context, c) => RepaintBoundary(
            child: CustomPaint(
              key: const Key('line_graph_paint'),
              size: Size(c.maxWidth.isFinite ? c.maxWidth : 260, c.maxHeight.isFinite ? c.maxHeight : 150),
              painter: LineGraphPainter(result, pal, night: theme == LcdTheme.night),
            ),
          ),
        ),
      ),
    );
  }
}
