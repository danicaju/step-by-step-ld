import 'dart:math' as math;

import '../arithmetic/casio_iberia_arsenal.dart';
import 'triangle_exact.dart';
import 'triangle_models.dart';
import 'triangle_tex.dart';

/// Triangulos cualesquiera (LLL, LAL, ALA/AAL, LLA): teorema del coseno, del seno y suma de angulos.
abstract final class TriangleStepsOblique {
  static const double _eps = 1e-9;
  static String _ang(double v) => triAng(v);
  static double _deg(double r) => r * 180 / math.pi;
  static double _rad(double d) => d * math.pi / 180;

  static void _sumStep(TriCtx ctx, List<double?> ang, int miss) {
    final others = [for (var q = 0; q < 3; q++) if (q != miss) q];
    final v = 180 - ang[others[0]]! - ang[others[1]]!;
    ang[miss] = v;
    ctx.card('Suma de ángulos', [
      '${kTriAngles[0]} + ${kTriAngles[1]} + ${kTriAngles[2]} = 180^{\\circ}',
      '${kTriAngles[miss]} = 180^{\\circ} - ${_ang(ang[others[0]]!)} - ${_ang(ang[others[1]]!)} = ${_ang(v)}',
    ], 'Los ángulos de un triángulo suman 180°.');
  }

  /// Angulo del vertice [i] con el teorema del coseno, conocidos los tres lados.
  static double _cosAngle(TriCtx ctx, List<Val> x, int i) {
    final j = (i + 1) % 3, k = (i + 2) % 3;
    final n = i == 0 ? 'A' : (i == 1 ? 'B' : 'C');
    final num = x[j].sq() + x[k].sq() - x[i].sq();
    final den = x[j] * x[k] * Val.of(2);
    final cosv = (num.v / den.v).clamp(-1.0, 1.0);
    final deg = _deg(math.acos(cosv));
    final frac = num.rational != null && den.rational != null
        ? ' = ${Val(num.v / den.v, (num / den).ex).tex}'
        : ' \\approx ${Val(cosv).dec()}';
    ctx.card('Teorema del coseno', [
      '${kTriSides[i]}^{2} = ${kTriSides[j]}^{2} + ${kTriSides[k]}^{2} - 2\\,${kTriSides[j]}\\,${kTriSides[k]}\\cos $n',
      '\\cos $n = \\frac{${kTriSides[j]}^{2} + ${kTriSides[k]}^{2} - ${kTriSides[i]}^{2}}{2\\,${kTriSides[j]}\\,${kTriSides[k]}} = \\frac{${num.tex}}{${den.tex}}$frac',
      '$n = \\arccos\\left(${Val(cosv).dec()}\\right) \\approx ${_ang(deg)}',
    ], 'Despejamos el coseno del ángulo y usamos el arcocoseno.');
    return deg;
  }

  /// LLL: dos angulos con el coseno y el tercero por suma de angulos.
  static TriangleSolution sss(TriCtx ctx, List<double?> s) {
    final x = [for (final v in s) Val.of(v!)];
    final ang = <double?>[null, null, null];
    ang[0] = _cosAngle(ctx, x, 0);
    ang[1] = _cosAngle(ctx, x, 1);
    _sumStep(ctx, ang, 2);
    return TriangleSolution([for (final v in x) v.v], [for (final v in ang) v!], vals: x);
  }

  /// LAL: lado opuesto al angulo con el coseno; luego un angulo con el coseno y el otro por suma.
  static TriangleSolution sas(TriCtx ctx, List<double?> s, List<double?> a, int ai) {
    final j = (ai + 1) % 3, k = (ai + 2) % 3;
    final x = <Val?>[for (final v in s) v == null ? null : Val.of(v)];
    final ang = Val.of(a[ai]!);
    final cos = Val.cosD(a[ai]!);
    final c2 = x[j]!.sq() + x[k]!.sq() - Val.of(2) * x[j]! * x[k]! * cos;
    final side = c2.sqrt();
    x[ai] = side;
    final n = kTriAngles[ai], sn = kTriSides[ai];
    ctx.card('Teorema del coseno', [
      '$sn^{2} = ${kTriSides[j]}^{2} + ${kTriSides[k]}^{2} - 2\\,${kTriSides[j]}\\,${kTriSides[k]}\\cos $n',
      '$sn^{2} = ${x[j]!.paren}^{2} + ${x[k]!.paren}^{2} - 2\\cdot ${x[j]!.paren}\\cdot ${x[k]!.paren}\\cdot \\cos ${_ang(ang.v)} = ${c2.tex}',
      '$sn ${side.eqRoot(c2)}',
    ], 'Conocemos dos lados y el ángulo que forman: el coseno da el lado opuesto.');
    final full = [for (final v in x) v!];
    final angles = <double?>[null, null, null];
    angles[ai] = a[ai];
    // Angulo opuesto al lado menor de los dos conocidos (siempre agudo): coseno.
    final first = full[j].v <= full[k].v ? j : k;
    angles[first] = _cosAngle(ctx, full, first);
    _sumStep(ctx, angles, angles.indexWhere((v) => v == null));
    return TriangleSolution([for (final v in full) v.v], [for (final v in angles) v!], vals: full);
  }

  /// ALA / AAL: tercer angulo por suma y lados con el teorema del seno.
  static TriangleSolution asa(TriCtx ctx, List<double?> s, List<double?> a) {
    final ang = <double?>[...a];
    final miss = ang.indexWhere((v) => v == null);
    if (miss >= 0) _sumStep(ctx, ang, miss);
    final ks = s.indexWhere((v) => v != null);
    final known = Val.of(s[ks]!);
    final sinK = Val.sinD(ang[ks]!);
    final ratio = known / sinK;
    final x = <Val>[];
    final rows = <String>[
      '\\frac{a}{\\sin A} = \\frac{b}{\\sin B} = \\frac{c}{\\sin C}',
      '\\frac{${kTriSides[ks]}}{\\sin ${kTriAngles[ks]}} = \\frac{${known.tex}}{\\sin ${_ang(ang[ks]!)}} ${ratio.eq}',
    ];
    for (var q = 0; q < 3; q++) {
      if (q == ks) {
        x.add(known);
        continue;
      }
      final v = ratio * Val.sinD(ang[q]!);
      x.add(v);
      rows.add('${kTriSides[q]} = ${ratio.tex}\\cdot \\sin ${_ang(ang[q]!)} ${v.eq}');
    }
    ctx.card('Teorema del seno', rows, 'Cada lado es proporcional al seno de su ángulo opuesto.');
    return TriangleSolution([for (final v in x) v.v], [for (final v in ang) v!], vals: x);
  }

  /// LLA: el seno da un angulo; puede haber dos triangulos validos (caso ambiguo).
  static List<TriangleSolution> ssa(TriCtx ctx, List<double?> s, List<double?> a, int ai) {
    final other = [for (var q = 0; q < 3; q++) if (q != ai && s[q] != null) q].first;
    final third = 3 - ai - other;
    final sa = Val.of(s[ai]!), so = Val.of(s[other]!), angK = a[ai]!;
    final sinOther = so.v * math.sin(_rad(angK)) / sa.v;
    ctx.card('Teorema del seno', [
      '\\frac{${kTriSides[ai]}}{\\sin ${kTriAngles[ai]}} = \\frac{${kTriSides[other]}}{\\sin ${kTriAngles[other]}} \\Rightarrow \\sin ${kTriAngles[other]} = \\frac{${kTriSides[other]}\\sin ${kTriAngles[ai]}}{${kTriSides[ai]}}',
      '\\sin ${kTriAngles[other]} = \\frac{${so.tex}\\cdot \\sin ${_ang(angK)}}{${sa.tex}} \\approx ${Val(sinOther).dec()}',
    ], 'Despejamos el seno del ángulo desconocido.');
    if (sinOther > 1 + 1e-12) {
      throw const ArsenalException('Math ERROR: NO EXISTE EL TRIÁNGULO: EL SENO SALDRÍA MAYOR QUE 1.');
    }
    final base = _deg(math.asin(sinOther.clamp(-1.0, 1.0)));
    final cands = <double>[base];
    if ((180 - base - base).abs() > _eps) cands.add(180 - base);
    final valid = [for (final b in cands) if (180 - angK - b > _eps) b];
    if (valid.isEmpty) {
      throw const ArsenalException('Math ERROR: NO EXISTE EL TRIÁNGULO: LOS ÁNGULOS SUMARÍAN MÁS DE 180°.');
    }
    final out = <TriangleSolution>[];
    for (var q = 0; q < valid.length; q++) {
      final b = valid[q];
      final tag = valid.length > 1 ? ' (S_{${q + 1}})' : '';
      final angles = <double?>[null, null, null];
      angles[ai] = angK;
      angles[other] = b;
      ctx.card(
        valid.length > 1 ? 'Caso ambiguo: triángulo ${q + 1}' : 'Ángulo restante',
        [
          '${kTriAngles[other]}$tag = ${q == 0 ? '\\arcsin(${Val(sinOther).dec()})' : '180^{\\circ} - ${_ang(base)}'} = ${_ang(b)}',
        ],
        q == 0
            ? 'El arcoseno da el ángulo agudo${valid.length > 1 ? '; el seno también vale lo mismo para su suplementario' : ''}.'
            : 'El suplementario (180° - ${Val(base).dec(2)}°) también tiene ese seno y suma menos de 180° con el dato.',
        trick: valid.length > 1 && q == 0
            ? 'Ambigüedad LLA: el lado opuesto al dato es menor que el otro lado pero mayor que su altura.'
            : null,
      );
      _sumStep(ctx, angles, third);
      final sThird = sa * (Val.sinD(angles[third]!) / Val.sinD(angK));
      ctx.card('Teorema del seno', [
        '${kTriSides[third]} = \\frac{${kTriSides[ai]}\\sin ${kTriAngles[third]}}{\\sin ${kTriAngles[ai]}} = \\frac{${sa.tex}\\cdot \\sin ${_ang(angles[third]!)}}{\\sin ${_ang(angK)}} \\approx ${sThird.dec()}',
      ], 'Aplicamos de nuevo el teorema del seno para el lado que falta.');
      final x = List<double>.filled(3, 0);
      x[ai] = sa.v;
      x[other] = so.v;
      x[third] = sThird.v;
      final vx = <Val>[sa, sa, sa];
      vx[other] = so;
      vx[third] = sThird;
      out.add(TriangleSolution(x, [for (final v in angles) v!], vals: vx));
    }
    return out;
  }
}
