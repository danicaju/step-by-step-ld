import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/math_engine/calculus/function_numeric.dart';
import '../../domain/math_engine/calculus/limit_models.dart';

/// Ventana matematica visible del visor.
class GraphWindow {
  final double xMin, xMax, yMin, yMax;
  const GraphWindow(this.xMin, this.xMax, this.yMin, this.yMax);
}

/// Pinta cualquier f(x) con sus asintotas, cortando las ramas en las discontinuidades
/// para no unir nunca +infinito con -infinito con una linea vertical falsa.
class UniversalFunctionPainter extends CustomPainter {
  static const Color ink = Color(0xFF1A2530);
  static const Color vColor = Color(0xFFE05D5D); // ALPHA
  static const Color hColor = Color(0xFFE5A93C); // SHIFT
  static const Color oColor = Color(0xFF3F4F48);
  static const Color gridColor = Color(0xFF9DB0A3);

  final FunctionModel model;
  final AsymptoteSet asymptotes;
  final GraphWindow window;

  const UniversalFunctionPainter({
    required this.model,
    required this.asymptotes,
    required this.window,
  });

  /// Ventana automatica: x en [-halfX, halfX]; y por percentiles de los valores finitos.
  static GraphWindow autoWindow(FunctionModel f, AsymptoteSet a, {double halfX = 10}) {
    if (a.vertical.length == 1 && a.horizontal.length == 1 && a.oblique.isEmpty) {
      return _hyperbolaWindow(f, a.vertical.first.x, a.horizontal.first.n);
    }
    final ys = <double>[];
    for (var i = 0; i <= 400; i++) {
      final y = f.at(-halfX + 2 * halfX * i / 400);
      if (y != null) ys.add(y);
    }
    for (final h in a.horizontal) {
      ys.add(h.n);
    }
    if (ys.isEmpty) return GraphWindow(-halfX, halfX, -5, 5);
    ys.sort();
    var lo = ys[(ys.length * 0.04).floor()];
    var hi = ys[math.min(ys.length - 1, (ys.length * 0.96).ceil())];
    if (hi - lo < 4) {
      final mid = (hi + lo) / 2;
      lo = mid - 2;
      hi = mid + 2;
    }
    final pad = (hi - lo) * 0.15;
    return GraphWindow(-halfX, halfX, lo - pad, hi + pad);
  }

  /// Hiperbola: ventana centrada en (AV, AH) que deja ver ambos cortes con los ejes.
  static GraphWindow _hyperbolaWindow(FunctionModel f, double cx, double cy) {
    var hx = math.max(5.0, cx.abs() + 2);
    for (final r in roots(f, cx - 60, cx + 60)) {
      hx = math.max(hx, (r - cx).abs() * 1.3 + 1);
    }
    var hy = math.max(3.0, cy.abs() * 1.2 + 1);
    final y0 = f.at(0);
    if (y0 != null) hy = math.max(hy, (y0 - cy).abs() * 1.3 + 1);
    return GraphWindow(cx - hx, cx + hx, cy - hy, cy + hy);
  }

  /// Ceros de f (cambios de signo refinados por biseccion), sin contar las asintotas verticales.
  static List<double> roots(FunctionModel f, double a, double b, {int n = 800}) {
    final out = <double>[];
    double? px, py;
    for (var i = 0; i <= n; i++) {
      final x = a + (b - a) * i / n;
      final y = f.at(x);
      if (y != null && py != null && px != null && py.sign != y.sign && py != 0) {
        var lo = px, hi = x, flo = py;
        for (var k = 0; k < 50; k++) {
          final mid = (lo + hi) / 2;
          final fm = f.at(mid);
          if (fm == null) break;
          if (fm.sign == flo.sign) {
            lo = mid;
            flo = fm;
          } else {
            hi = mid;
          }
        }
        final r = (lo + hi) / 2;
        final fr = f.at(r);
        if (fr != null && fr.abs() < 1e-6) out.add(r);
      } else if (y != null && y == 0) {
        out.add(x);
      }
      px = x;
      py = y;
    }
    return out;
  }

  /// Ramas continuas de la curva en la ventana (probado sin dibujar).
  static List<List<CurvePoint>> branchesFor(FunctionModel f, AsymptoteSet a, GraphWindow w, {int samples = 600}) =>
      FunctionSampler.branches(
        f.at,
        w.xMin,
        w.xMax,
        n: samples,
        cuts: a.verticalXs,
        jump: (w.yMax - w.yMin) * 0.75,
      );

  /// `x = \frac{1}{2}` -> `x = 1/2` para las etiquetas del visor.
  static String plainLabel(String latex) {
    var s = latex;
    final frac = RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}');
    while (frac.hasMatch(s)) {
      s = s.replaceAllMapped(frac, (m) => '${m[1]}/${m[2]}');
    }
    return s
        .replaceAll(r'\sqrt', '√')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\,', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll(r'\', '');
  }

  Offset _px(Size s, double x, double y) => Offset(
        (x - window.xMin) / (window.xMax - window.xMin) * s.width,
        s.height - (y - window.yMin) / (window.yMax - window.yMin) * s.height,
      );

  static double _niceStep(double span) {
    final raw = span / 8;
    final p = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / p;
    return (f < 1.5 ? 1 : (f < 3.5 ? 2 : (f < 7.5 ? 5 : 10))) * p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    _grid(canvas, size);
    for (final v in asymptotes.vertical) {
      _dashed(canvas, _px(size, v.x, window.yMin), _px(size, v.x, window.yMax), vColor, const [10, 5]);
      _label(canvas, size, plainLabel(v.latex), _px(size, v.x, window.yMax) + const Offset(4, 4), vColor);
    }
    for (final h in asymptotes.horizontal) {
      _dashed(canvas, _px(size, window.xMin, h.n), _px(size, window.xMax, h.n), hColor, const [5, 4]);
      _label(canvas, size, plainLabel(h.latex), _px(size, window.xMin, h.n) + const Offset(4, -14), hColor);
    }
    for (final o in asymptotes.oblique) {
      final a = _px(size, window.xMin, o.m * window.xMin + o.n);
      final b = _px(size, window.xMax, o.m * window.xMax + o.n);
      _dashed(canvas, a, b, oColor, const [9, 3, 2, 3]);
      _label(canvas, size, plainLabel(o.latex), Offset(size.width * 0.52, size.height * 0.06), oColor);
    }
    _intercepts(canvas, size);
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    for (final br in branchesFor(model, asymptotes, window, samples: math.max(300, size.width.round()))) {
      final path = Path();
      var first = true;
      for (final (x, y) in br) {
        final p = _px(size, x, y);
        if (p.dy < -size.height * 2 || p.dy > size.height * 3) {
          first = true; // fuera de la ventana: corta la rama
          continue;
        }
        if (first) {
          path.moveTo(p.dx, p.dy);
          first = false;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  /// Puntos de corte con OX y OY (marcados y rotulados).
  void _intercepts(Canvas canvas, Size size) {
    final dot = Paint()..color = const Color(0xFFE05D5D);
    final ring = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    void mark(double x, double y, String text) {
      if (x < window.xMin || x > window.xMax || y < window.yMin || y > window.yMax) return;
      final c = _px(size, x, y);
      canvas.drawCircle(c, 4, dot);
      canvas.drawCircle(c, 4, ring);
      _label(canvas, size, text, c + const Offset(6, 4), ink);
    }

    String fmt(double v) => (v - v.roundToDouble()).abs() < 1e-9 ? v.round().toString() : v.toStringAsFixed(2);
    for (final r in roots(model, window.xMin, window.xMax)) {
      mark(r, 0, '(${fmt(r)}, 0)');
    }
    final y0 = model.at(0);
    if (y0 != null) mark(0, y0, '(0, ${fmt(y0)})');
  }

  void _grid(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 0.6;
    final axis = Paint()
      ..color = ink
      ..strokeWidth = 1.3;
    final sx = _niceStep(window.xMax - window.xMin);
    final sy = _niceStep(window.yMax - window.yMin);
    for (var x = (window.xMin / sx).ceil() * sx; x <= window.xMax; x += sx) {
      canvas.drawLine(_px(size, x, window.yMin), _px(size, x, window.yMax), x.abs() < 1e-9 ? axis : grid);
    }
    for (var y = (window.yMin / sy).ceil() * sy; y <= window.yMax; y += sy) {
      canvas.drawLine(_px(size, window.xMin, y), _px(size, window.xMax, y), y.abs() < 1e-9 ? axis : grid);
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Color color, List<double> pattern) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6;
    final total = (b - a).distance;
    if (total == 0 || total.isNaN) return;
    final dir = (b - a) / total;
    var d = 0.0;
    var i = 0;
    while (d < total) {
      final len = pattern[i % pattern.length];
      if (i.isEven) {
        canvas.drawLine(a + dir * d, a + dir * math.min(total, d + len), paint);
      }
      d += len;
      i++;
    }
  }

  void _label(Canvas canvas, Size size, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.6);
    final x = at.dx.clamp(2.0, math.max(2.0, size.width - tp.width - 2)).toDouble();
    final y = at.dy.clamp(2.0, math.max(2.0, size.height - tp.height - 2)).toDouble();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant UniversalFunctionPainter old) =>
      old.model.raw != model.raw || old.asymptotes != asymptotes || old.window != window;
}

/// Visor con `ClipRRect` estricto: nada se dibuja fuera del marco LCD.
class UniversalGraphView extends StatelessWidget {
  final FunctionModel model;
  final AsymptoteSet asymptotes;

  const UniversalGraphView({super.key, required this.model, required this.asymptotes});

  @override
  Widget build(BuildContext context) {
    final w = UniversalFunctionPainter.autoWindow(model, asymptotes);
    return ClipRRect(
      key: const Key('universal_graph_clip'),
      borderRadius: BorderRadius.circular(8.5),
      child: Container(
        color: const Color(0xFFC8D6CD),
        child: LayoutBuilder(
          builder: (context, c) => CustomPaint(
            key: const Key('universal_graph_paint'),
            size: Size(c.maxWidth.isFinite ? c.maxWidth : 300, c.maxHeight.isFinite ? c.maxHeight : 200),
            painter: UniversalFunctionPainter(model: model, asymptotes: asymptotes, window: w),
          ),
        ),
      ),
    );
  }
}
