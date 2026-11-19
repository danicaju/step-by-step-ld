import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../domain/math_engine/calculus/function_numeric.dart';
import '../../domain/math_engine/calculus/limit_models.dart';
import 'graph_axis_ticks.dart';
import 'graph_label_layout.dart';
import 'graph_key_points.dart';
import 'graph_viewport_calculator.dart';

export '../widgets/universal_graph_view.dart';
export 'graph_key_points.dart' show KeyPoint;
export 'graph_viewport_calculator.dart' show GraphWindow;

/// Pinta cualquier f(x) con sus asintotas, cortando las ramas en las discontinuidades
/// para no unir nunca +infinito con -infinito con una linea vertical falsa.
class UniversalFunctionPainter extends CustomPainter {
  static const Color ink = Color(0xFF1A2530);
  static const Color vColor = Color(0xFFE05D5D); // ALPHA
  static const Color hColor = Color(0xFFE5A93C); // SHIFT
  static const Color oColor = Color(0xFF3F4F48);

  final FunctionModel model;
  final AsymptoteSet asymptotes;
  final GraphWindow window;
  final List<KeyPoint> keyPoints;
  final bool degrees;
  final bool trig;

  /// Fondo de la LCD del tema activo (pastillas de las etiquetas) .
  final Color background;

  UniversalFunctionPainter({
    required this.model,
    required this.asymptotes,
    required this.window,
    this.keyPoints = const [],
    this.degrees = false,
    this.trig = false,
    this.background = const Color(0xFFC8D6CD),
  });

  /// Ventana automatica generica: x en [-halfX, halfX]; y por percentiles.
  static GraphWindow autoWindow(FunctionModel f, AsymptoteSet a, {double halfX = 10}) =>
      GraphViewportCalculator.generic(f, a, halfX: halfX);

  /// Ceros de f (cambios de signo refinados por biseccion).
  static List<double> roots(FunctionModel f, double a, double b, {int n = 800}) =>
      GraphKeyPoints.roots(f, a, b, n: n);

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

  List<Rect> _tickRects = const [];

  Offset _px(Size s, double x, double y) => Offset(
        (x - window.xMin) / (window.xMax - window.xMin) * s.width,
        s.height - (y - window.yMin) / (window.yMax - window.yMin) * s.height,
      );

  bool _inX(double x) => x >= window.xMin && x <= window.xMax;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    _tickRects = GraphAxisTicks.paint(canvas, size, window, trig: trig, degrees: degrees);
    for (final v in asymptotes.vertical.where((v) => _inX(v.x))) {
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
    _curve(canvas, size);
    _points(canvas, size);
  }

  void _curve(Canvas canvas, Size size) {
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

  /// Cortes, vertices y puntos clave: marcador + etiqueta sin colisiones con ejes ni entre si.
  void _points(Canvas canvas, Size size) {
    final dot = Paint()..color = vColor;
    final ring = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final layout = GraphLabelLayout(size, occupied: _tickRects);
    final y0 = _px(size, window.xMin, 0).dy, x0 = _px(size, 0, window.yMin).dx;
    if (y0 >= 0 && y0 <= size.height) layout.reserve(Rect.fromLTWH(0, y0 - 2, size.width, 4));
    if (x0 >= 0 && x0 <= size.width) layout.reserve(Rect.fromLTWH(x0 - 2, 0, 4, size.height));
    for (final k in keyPoints) {
      layout.reserve(Rect.fromCircle(center: _px(size, k.x, k.y), radius: 5));
    }
    final pill = Paint()..color = background.withValues(alpha: 0.88);
    final pillBorder = Paint()
      ..color = ink.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final k in keyPoints) {
      final c = _px(size, k.x, k.y);
      canvas.drawCircle(c, 4, dot);
      canvas.drawCircle(c, 4, ring);
      if (!k.labeled) continue;
      final tp = TextPainter(
        text: TextSpan(text: k.label, style: const TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.6);
      final box = layout.place(c, Size(tp.width + 6, tp.height + 3));
      final rr = RRect.fromRectAndRadius(box, const Radius.circular(3));
      canvas.drawRRect(rr, pill);
      canvas.drawRRect(rr, pillBorder);
      tp.paint(canvas, box.topLeft + const Offset(3, 1.5));
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
      old.model.raw != model.raw ||
      old.asymptotes != asymptotes ||
      old.window != window ||
      old.degrees != degrees ||
      old.trig != trig ||
      old.background != background ||
      !listEquals(old.keyPoints, keyPoints);
}
