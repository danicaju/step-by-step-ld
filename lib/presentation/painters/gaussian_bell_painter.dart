import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/math_engine/statistics/probability_distribution_solver.dart';

/// Campana de Gauss N(mu, sigma) con el area de la probabilidad sombreada.
class GaussianBellPainter extends CustomPainter {
  static const Color ink = Color(0xFF1A2530);
  static const Color shade = Color(0xFFE5A93C); // SHIFT
  static const Color gridColor = Color(0xFF7A8A7E);

  final double mu;
  final double sigma;

  /// Limites del area sombreada; `null` = hasta el extremo visible (±infinito).
  final double? lower;
  final double? upper;
  final double probability;

  const GaussianBellPainter({
    required this.mu,
    required this.sigma,
    this.lower,
    this.upper,
    required this.probability,
  });

  /// Semiancho visible en unidades de sigma (>= 4, ampliado si un limite queda lejos).
  static double halfRange(double mu, double sigma, double? lower, double? upper) {
    var k = 4.0;
    for (final b in [lower, upper]) {
      if (b != null) k = math.max(k, (b - mu).abs() / sigma + 0.8);
    }
    return k;
  }

  /// Intervalo realmente sombreado, recortado a la ventana visible.
  static (double, double) shadedRange(double mu, double sigma, double? lower, double? upper) {
    final k = halfRange(mu, sigma, lower, upper);
    final lo = math.max(lower ?? (mu - k * sigma), mu - k * sigma);
    final hi = math.min(upper ?? (mu + k * sigma), mu + k * sigma);
    return (lo, hi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    const padX = 14.0, padTop = 22.0, padBottom = 22.0;
    final k = halfRange(mu, sigma, lower, upper);
    final xMin = mu - k * sigma, xMax = mu + k * sigma;
    final peak = ProbabilityDistributionSolver.pdf(mu, mu, sigma);
    final w = math.max(1.0, size.width - 2 * padX);
    final h = math.max(1.0, size.height - padTop - padBottom);
    double px(double x) => padX + (x - xMin) / (xMax - xMin) * w;
    double py(double y) => padTop + h - y / (peak * 1.08) * h;
    final base = padTop + h;

    // Eje y marcas en mu y mu +- sigma.
    final axis = Paint()
      ..color = ink
      ..strokeWidth = 1.3;
    canvas.drawLine(Offset(padX, base), Offset(size.width - padX, base), axis);
    final tick = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8;
    for (var i = -3; i <= 3; i++) {
      final x = mu + i * sigma;
      if (x < xMin || x > xMax) continue;
      canvas.drawLine(Offset(px(x), base), Offset(px(x), base + (i == 0 ? 6 : 4)), axis);
      if (i == 0) canvas.drawLine(Offset(px(x), py(peak)), Offset(px(x), base), tick);
      _text(canvas, _short(x), Offset(px(x), base + 6), center: true, bold: i == 0);
    }

    // Area sombreada.
    final (lo, hi) = shadedRange(mu, sigma, lower, upper);
    if (hi > lo) {
      final area = Path()..moveTo(px(lo), base);
      const steps = 120;
      for (var i = 0; i <= steps; i++) {
        final x = lo + (hi - lo) * i / steps;
        area.lineTo(px(x), py(ProbabilityDistributionSolver.pdf(x, mu, sigma)));
      }
      area.lineTo(px(hi), base);
      area.close();
      canvas.drawPath(area, Paint()..color = shade.withValues(alpha: 0.55));
      for (final b in [lower, upper]) {
        if (b == null) continue;
        canvas.drawLine(
          Offset(px(b), base),
          Offset(px(b), py(ProbabilityDistributionSolver.pdf(b, mu, sigma))),
          Paint()
            ..color = ink
            ..strokeWidth = 1.2,
        );
      }
    }

    // Curva.
    final curve = Path();
    const n = 240;
    for (var i = 0; i <= n; i++) {
      final x = xMin + (xMax - xMin) * i / n;
      final p = Offset(px(x), py(ProbabilityDistributionSolver.pdf(x, mu, sigma)));
      i == 0 ? curve.moveTo(p.dx, p.dy) : curve.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );

    _text(canvas, 'N(${_short(mu)}, ${_short(sigma)})   P = ${ProbabilityDistributionSolver.fmt(probability, 4).replaceAll(r'{,}', ',')}',
        const Offset(8, 4),
        bold: true);
  }

  static String _short(double v) {
    final s = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
    return s.replaceAll('.', ',');
  }

  void _text(Canvas canvas, String text, Offset at, {bool center = false, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: ink, fontSize: 10, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? Offset(at.dx - tp.width / 2, at.dy) : at);
  }

  @override
  bool shouldRepaint(covariant GaussianBellPainter old) =>
      old.mu != mu || old.sigma != sigma || old.lower != lower || old.upper != upper || old.probability != probability;
}

/// Campana dentro de un `ClipRRect` estricto con el fondo LCD.
class GaussianBellView extends StatelessWidget {
  final NormalResult result;

  const GaussianBellView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const Key('gaussian_bell_clip'),
      borderRadius: BorderRadius.circular(8.5),
      child: Container(
        color: const Color(0xFFC8D6CD),
        child: LayoutBuilder(
          builder: (context, c) => CustomPaint(
            key: const Key('gaussian_bell_paint'),
            size: Size(c.maxWidth.isFinite ? c.maxWidth : 300, c.maxHeight.isFinite ? c.maxHeight : 160),
            painter: GaussianBellPainter(
              mu: result.mu,
              sigma: result.sigma,
              lower: result.lower,
              upper: result.upper,
              probability: result.probability,
            ),
          ),
        ),
      ),
    );
  }
}
