import 'dart:math' as math;

import 'triangle_exact.dart';
import 'triangle_models.dart';
import 'triangle_tex.dart';

/// Triangulo rectangulo: Pitagoras y razones trigonometricas, "como en clase".
abstract final class TriangleStepsRight {
  static String _ang(double v) => triAng(v);
  static double _deg(double r) => r * 180 / math.pi;

  /// [r] = vertice del angulo recto (la hipotenusa es el lado opuesto, `kTriSides[r]`).
  static TriangleSolution solve(TriCtx ctx, List<double?> s, List<double?> a, int r) {
    final i = (r + 1) % 3, j = (r + 2) % 3;
    final sd = <Val?>[for (final v in s) v == null ? null : Val.of(v)];
    final ad = <double?>[...a];
    ad[r] = 90;
    final h = kTriSides[r];

    // 1. Pitagoras si faltan lados y hay dos conocidos.
    final hypGiven = sd[r] != null;
    final legsGiven = sd[i] != null && sd[j] != null;
    if (sd.where((v) => v != null).length == 2) {
      if (sd[r] == null) {
        final x = sd[i]!, y = sd[j]!;
        final res = (x.sq() + y.sq()).sqrt();
        sd[r] = res;
        ctx.card('Teorema de Pitágoras', [
          '$h^{2} = ${kTriSides[i]}^{2} + ${kTriSides[j]}^{2}',
          '$h = \\sqrt{${x.paren}^{2} + ${y.paren}^{2}} ${res.eqRoot(x.sq() + y.sq())}',
        ], 'La hipotenusa es la raíz de la suma de los cuadrados de los catetos.');
      } else {
        final known = sd[i] != null ? i : j, miss = known == i ? j : i;
        final x = sd[r]!, y = sd[known]!;
        final res = (x.sq() - y.sq()).sqrt();
        sd[miss] = res;
        ctx.card('Teorema de Pitágoras', [
          '${kTriSides[miss]}^{2} = $h^{2} - ${kTriSides[known]}^{2}',
          '${kTriSides[miss]} = \\sqrt{${x.paren}^{2} - ${y.paren}^{2}} ${res.eqRoot(x.sq() - y.sq())}',
        ], 'Despejamos el cateto: cateto² = hipotenusa² - cateto².');
      }
    }

    if (sd.every((v) => v != null)) {
      _anglesFromSides(ctx, sd, ad, r, i, j, hypGiven && !legsGiven);
    } else {
      _fromAngleAndSide(ctx, sd, ad, r, i, j);
    }
    return TriangleSolution([for (final v in sd) v!.v], [for (final v in ad) v!], vals: [for (final v in sd) v!]);
  }

  /// Los tres lados ya se conocen: angulos agudos con tan (dos catetos) o sen (hipotenusa y cateto).
  static void _anglesFromSides(TriCtx ctx, List<Val?> sd, List<double?> ad, int r, int i, int j, bool useSin) {
    final h = kTriSides[r];
    final op = ad[i] == null ? i : j; // angulo agudo a calcular primero
    final other = op == i ? j : i;
    final o = sd[op]!, c = sd[other]!, hyp = sd[r]!;
    final double deg;
    if (useSin) {
      deg = _deg(math.asin((o.v / hyp.v).clamp(-1.0, 1.0)));
      ctx.card('Razón seno', [
        '\\sin ${kTriAngles[op]} = \\frac{${kTriSides[op]}}{$h}',
        '\\sin ${kTriAngles[op]} = \\frac{${o.tex}}{${hyp.tex}} \\Rightarrow ${kTriAngles[op]} = \\arcsin\\left(\\frac{${o.tex}}{${hyp.tex}}\\right) \\approx ${_ang(deg)}',
      ], 'sen = cateto opuesto / hipotenusa.');
    } else {
      deg = _deg(math.atan2(o.v, c.v));
      ctx.card('Razón tangente', [
        '\\tan ${kTriAngles[op]} = \\frac{${kTriSides[op]}}{${kTriSides[other]}}',
        '\\tan ${kTriAngles[op]} = \\frac{${o.tex}}{${c.tex}} \\Rightarrow ${kTriAngles[op]} = \\arctan\\left(\\frac{${o.tex}}{${c.tex}}\\right) \\approx ${_ang(deg)}',
      ], 'tan = cateto opuesto / cateto contiguo.');
    }
    ad[op] = deg;
    ad[other] = 90 - deg;
    ctx.card('Suma de ángulos', [
      '${kTriAngles[0]} + ${kTriAngles[1]} + ${kTriAngles[2]} = 180^{\\circ}',
      '${kTriAngles[other]} = 180^{\\circ} - 90^{\\circ} - ${_ang(deg)} = ${_ang(ad[other]!)}',
    ], 'Los ángulos de un triángulo suman 180°; el recto vale 90°.');
  }

  /// Un lado y un angulo agudo: se completa el angulo y se calculan los lados con sen, cos o tan.
  static void _fromAngleAndSide(TriCtx ctx, List<Val?> sd, List<double?> ad, int r, int i, int j) {
    final k = ad[i] != null ? i : j; // vertice del angulo agudo dado
    final m = k == i ? j : i;
    final x = ad[k]!;
    ad[m] = 90 - x;
    ctx.card('Suma de ángulos', [
      '${kTriAngles[0]} + ${kTriAngles[1]} + ${kTriAngles[2]} = 180^{\\circ}',
      '${kTriAngles[m]} = 180^{\\circ} - 90^{\\circ} - ${_ang(x)} = ${_ang(ad[m]!)}',
    ], 'Los ángulos de un triángulo suman 180°; el recto vale 90°.');
    final h = kTriSides[r], opp = kTriSides[k], adj = kTriSides[m], ax = kTriAngles[k];
    final sin = Val.sinD(x), cos = Val.cosD(x), tan = Val.tanD(x);
    final sinTex = '\\sin ${_ang(x)}', cosTex = '\\cos ${_ang(x)}', tanTex = '\\tan ${_ang(x)}';
    if (sd[r] != null) {
      final c = sd[r]!;
      sd[k] = c * sin;
      sd[m] = c * cos;
      ctx.card('Razones seno y coseno', [
        '$opp = $h \\sin $ax,\\qquad $adj = $h \\cos $ax',
        '$opp = ${c.tex} \\cdot $sinTex ${sd[k]!.eq}',
        '$adj = ${c.tex} \\cdot $cosTex ${sd[m]!.eq}',
      ], 'Con la hipotenusa: cateto opuesto = hipotenusa · sen y cateto contiguo = hipotenusa · cos.');
    } else if (sd[k] != null) {
      final o = sd[k]!;
      sd[r] = o / sin;
      sd[m] = o / tan;
      ctx.card('Razones seno y tangente', [
        '$h = \\frac{$opp}{\\sin $ax},\\qquad $adj = \\frac{$opp}{\\tan $ax}',
        '$h = \\frac{${o.tex}}{$sinTex} ${sd[r]!.eq}',
        '$adj = \\frac{${o.tex}}{$tanTex} ${sd[m]!.eq}',
      ], 'Con el cateto opuesto: hipotenusa = cateto / sen y el otro cateto = cateto / tan.');
    } else {
      final a2 = sd[m]!;
      sd[r] = a2 / cos;
      sd[k] = a2 * tan;
      ctx.card('Razones coseno y tangente', [
        '$h = \\frac{$adj}{\\cos $ax},\\qquad $opp = $adj \\tan $ax',
        '$h = \\frac{${a2.tex}}{$cosTex} ${sd[r]!.eq}',
        '$opp = ${a2.tex} \\cdot $tanTex ${sd[k]!.eq}',
      ], 'Con el cateto contiguo: hipotenusa = cateto / cos y cateto opuesto = cateto · tan.');
    }
  }
}
