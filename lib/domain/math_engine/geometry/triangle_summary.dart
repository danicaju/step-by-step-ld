import 'dart:math' as math;

import 'triangle_exact.dart';
import 'triangle_models.dart';
import 'triangle_tex.dart';

/// Clasificacion, perimetro y area de un triangulo resuelto.
class TriangleSummary {
  final String bySides; // equilatero | isosceles | escaleno
  final String byAngles; // acutangulo | rectangulo | obtusangulo
  final double perimeter;
  final double area;
  final bool isRight;

  const TriangleSummary(this.bySides, this.byAngles, this.perimeter, this.area, this.isRight);

  static const double _tol = 1e-6;

  factory TriangleSummary.of(TriangleSolution t) {
    final s = t.sides, a = t.angles;
    final tol = _tol * s.reduce(math.max);
    bool eq(double x, double y) => (x - y).abs() <= tol;
    final equal = (eq(s[0], s[1]) ? 1 : 0) + (eq(s[1], s[2]) ? 1 : 0) + (eq(s[0], s[2]) ? 1 : 0);
    final bySides = equal >= 3 ? 'equilátero' : (equal >= 1 ? 'isósceles' : 'escaleno');
    final maxA = a.reduce(math.max);
    final isRight = (maxA - 90).abs() < 1e-6;
    final byAngles = isRight ? 'rectángulo' : (maxA > 90 ? 'obtusángulo' : 'acutángulo');
    final p = s[0] + s[1] + s[2];
    final h = p / 2;
    final area = isRight
        ? _legs(t).fold<double>(1, (x, v) => x * v) / 2
        : math.sqrt(math.max(0, h * (h - s[0]) * (h - s[1]) * (h - s[2])));
    return TriangleSummary(bySides, byAngles, p, area, isRight);
  }

  /// Los dos catetos (lados que no son la hipotenusa) de un triangulo rectangulo.
  static List<double> _legs(TriangleSolution t) {
    final r = t.angles.indexWhere((v) => (v - 90).abs() < 1e-6);
    return [for (var i = 0; i < 3; i++) if (i != r) t.sides[i]];
  }

  String get caption =>
      '${_cap(bySides)} · ${_cap(byAngles)}  |  P = ${_plain(perimeter)}  |  Área = ${_plain(area)}';

  static String _plain(double v) => Val(v).dec(2).replaceAll('{,}', ',');

  String get sentence => 'Es un triángulo $bySides y $byAngles.';

  static String _cap(String s) => s[0].toUpperCase() + s.substring(1);

  /// Paso final: clasificacion, perimetro y area (Heron o base · altura / 2).
  static void addStep(TriCtx ctx, List<TriangleSolution> sols) {
    final rows = <String>[];
    final notes = <String>[];
    for (var k = 0; k < sols.length; k++) {
      final t = sols[k];
      final sum = TriangleSummary.of(t);
      final tag = sols.length > 1 ? 'S_{${k + 1}}:\\; ' : '';
      final x = t.vals ?? [for (final v in t.sides) Val.of(v)];
      final p = x[0] + x[1] + x[2];
      rows.add('${tag}P = a + b + c = ${x[0].tex} + ${x[1].tex} + ${x[2].tex} ${p.eq}');
      if (sum.isRight) {
        final legs = [for (var i = 0; i < 3; i++) if ((t.angles[i] - 90).abs() > 1e-6) x[i]];
        final s2 = legs[0] * legs[1] / Val.of(2);
        rows.add('S = \\frac{b \\cdot h}{2} = \\frac{${legs[0].tex} \\cdot ${legs[1].tex}}{2} ${s2.eq}');
      } else {
        final h = p / Val.of(2);
        final prod = h * (h - x[0]) * (h - x[1]) * (h - x[2]);
        rows.add('s = \\frac{a + b + c}{2} = ${h.tex}');
        rows.add(
            'S = \\sqrt{s(s-a)(s-b)(s-c)} = \\sqrt{${h.tex}\\cdot ${(h - x[0]).tex}\\cdot ${(h - x[1]).tex}\\cdot ${(h - x[2]).tex}} ${prod.sqrt().eq}');
      }
      notes.add('${sols.length > 1 ? 'Solución ${k + 1}: ' : ''}${sum.sentence}');
    }
    ctx.card('Clasificación, perímetro y área', rows,
        '${notes.join(' ')} El área se calcula con base · altura / 2 (rectángulo) o con la fórmula de Herón.');
  }
}
