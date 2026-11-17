import 'dart:math' as math;

import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/equations/eq_poly.dart';
import '../solvers/exact/ext_expr.dart';
import 'domain_solver.dart';
import 'function_numeric.dart';
import 'limit_models.dart';
import 'limits_rational.dart';

export 'domain_solver.dart';
export 'function_numeric.dart';
export 'limit_models.dart';

/// Punto al que tiende x: un numero `a` (con lado) o +-infinito.
class LimitPoint {
  final Rational? a;
  final bool plusInf;
  final bool minusInf;
  final LimSide side;

  const LimitPoint.at(Rational this.a, {this.side = LimSide.both})
      : plusInf = false,
        minusInf = false;
  const LimitPoint.plusInfinity()
      : a = null,
        plusInf = true,
        minusInf = false,
        side = LimSide.both;
  const LimitPoint.minusInfinity()
      : a = null,
        plusInf = false,
        minusInf = true,
        side = LimSide.both;

  bool get atInfinity => plusInf || minusInf;

  String get latex {
    if (plusInf) return r'x \to +\infty';
    if (minusInf) return r'x \to -\infty';
    final s = side == LimSide.left ? '^{-}' : (side == LimSide.right ? '^{+}' : '');
    return 'x \\to ${domainRationalLatex(a!)}$s';
  }
}

class StudyResult {
  final FunctionModel model;
  final DomainResult domain;
  final AsymptoteSet asymptotes;
  final StepByStepResolution resolution;
  const StudyResult(this.model, this.domain, this.asymptotes, this.resolution);
}

/// Dominio, limites (con indeterminaciones) y asintotas de f(x).
///
/// Exacto para polinomicas y racionales (cualquier grado) y para un radical
/// resuelto con el conjugado; para el resto (exp, log, trig...) estima numericamente.
class LimitsAsymptotesSolver {
  const LimitsAsymptotesSolver._();

  static List<MathStep> _renumber(List<MathStep> raw) => [
        for (var i = 0; i < raw.length; i++)
          MathStep(
            index: i + 1,
            shortTitle: '${i + 1}. ${raw[i].shortTitle}',
            latexExpression: raw[i].latexExpression,
            pedagogicalNote: raw[i].pedagogicalNote,
            warningTrick: raw[i].warningTrick,
          ),
      ];

  // ------------------------------------------------------------------ limite

  static (LimitValue, StepByStepResolution) limit(String raw, LimitPoint pt) {
    final f = FunctionModel.parse(raw);
    final steps = <MathStep>[
      MathStep(
        index: 0,
        shortTitle: 'Limite pedido',
        latexExpression: '\\lim_{${pt.latex}} ${f.latex}',
        pedagogicalNote: 'Estudiamos el comportamiento de f(x) cuando x se acerca al valor indicado.',
      ),
    ];
    final v = _compute(f, pt, steps);
    final text = '\\lim_{${pt.latex}} f(x) = ${v.latex}';
    steps.add(MathStep(
      index: 0,
      shortTitle: 'Resultado',
      latexExpression: text,
      pedagogicalNote: v.estimated
          ? 'Valor estimado numericamente acercandose al punto; para funciones no racionales es una aproximacion fiable, no una demostracion.'
          : (v.exists ? 'Limite calculado de forma exacta.' : 'Los limites laterales no coinciden.'),
    ));
    return (
      v,
      StepByStepResolution(
        originalInputLatex: '\\lim_{${pt.latex}} ${f.latex}',
        steps: _renumber(steps),
        exactResultLatex: v.latex,
        decimalApproxLatex: v.isFinite && v.finite != null && !v.finite!.isInteger ? v.finite!.toDecimalLatex() : '',
      ),
    );
  }

  static LimitValue _compute(FunctionModel f, LimitPoint pt, List<MathStep> steps) {
    final rat = PolyOps.rationalOf(f.node);
    if (rat != null) {
      final (p, q) = rat;
      if (pt.atInfinity) return RationalLimits.atInfinity(p, q, plus: pt.plusInf, steps: steps);
      return RationalLimits.atPoint(p, q, pt.a!, pt.side, steps);
    }
    if (!pt.atInfinity) {
      final conj = _conjugate(f.node, pt.a!, pt.side, steps);
      if (conj != null) return conj;
      final exact = _exactSubstitution(f, pt.a!, pt.side, steps);
      if (exact != null) return exact;
    }
    return _estimate(f, pt, steps);
  }

  static LimitValue? _exactSubstitution(FunctionModel f, Rational a, LimSide side, List<MathStep> steps) {
    final x = f.at(a.toDouble());
    if (x == null) return null;
    final ad = a.toDouble();
    if (side != LimSide.right && f.at(ad - 1e-7) == null) return null;
    if (side != LimSide.left && f.at(ad + 1e-7) == null) return null;
    // Sustitucion exacta solo si el resultado es racional.
    final rr = _asRational(x);
    if (rr == null) return null;
    steps.add(MathStep(
      index: 0,
      shortTitle: 'Sustitucion directa',
      latexExpression: 'f(${domainRationalLatex(a)}) = ${domainRationalLatex(rr)}',
      pedagogicalNote: 'La funcion esta definida y es continua en ese punto: el limite es f(a).',
    ));
    return LimitValue.number(rr);
  }

  static Rational? _asRational(double v) {
    for (var d = 1; d <= 720; d++) {
      final n = (v * d).roundToDouble();
      if ((v - n / d).abs() < 1e-9 * math.max(1, v.abs())) return Rational(n.toInt(), d);
    }
    return null;
  }

  // ---------------------------------------------------------------- conjugado

  /// Parte `c*sqrt(g) + h` de una suma/resta; `null` si no tiene esa forma.
  static (int, Poly, Poly)? _radicalSum(XNode n) {
    if (n is! XBin || (n.op != '+' && n.op != '-')) return null;
    final sgn = n.op == '-' ? -1 : 1;
    (Poly, bool)? pick(XNode a) {
      if (a is XRoot && (a.index == null || (a.index is XNum && (a.index as XNum).value == Rational(2)))) {
        final g = PolyOps.polyOf(a.rad);
        return g == null ? null : (g, true);
      }
      return null;
    }
    final lr = pick(n.l), rr = pick(n.r);
    final lp = PolyOps.polyOf(n.l), rp = PolyOps.polyOf(n.r);
    if (lr != null && rp != null) return (1, lr.$1, PolyOps.scale(rp, Rational(sgn)));
    if (rr != null && lp != null) return (sgn, rr.$1, lp);
    return null;
  }

  static Rational? _sqrtRat(Rational r) {
    if (r.isNegative) return null;
    final a = math.sqrt(r.numerator.toDouble()).round();
    final b = math.sqrt(r.denominator.toDouble()).round();
    return a * a == r.numerator && b * b == r.denominator ? Rational(a, b) : null;
  }

  static LimitValue? _conjugate(XNode node, Rational a, LimSide side, List<MathStep> steps) {
    if (node is! XBin || node.op != '/') return null;
    final numRad = _radicalSum(node.l);
    final denRad = _radicalSum(node.r);
    final numPoly = PolyOps.polyOf(node.l);
    final denPoly = PolyOps.polyOf(node.r);
    Poly top, bottom;
    Rational factor;
    final String conjLatex;
    if (numRad != null && denPoly != null) {
      final (c, g, h) = numRad;
      final ga = _sqrtRat(PolyOps.eval(g, a));
      if (ga == null) return null;
      final conjVal = Rational(c) * ga - PolyOps.eval(h, a);
      if (conjVal.isZero) return null;
      top = PolyOps.sub(g, PolyOps.mul(h, h));
      bottom = denPoly;
      factor = Rational(1) / conjVal;
      conjLatex = '${node.l.latex()} \\cdot \\frac{${c > 0 ? '' : '-'}\\sqrt{${PolyOps.latex(g)}} - \\left(${PolyOps.latex(h)}\\right)}'
          '{${c > 0 ? '' : '-'}\\sqrt{${PolyOps.latex(g)}} - \\left(${PolyOps.latex(h)}\\right)}';
    } else if (denRad != null && numPoly != null) {
      final (c, g, h) = denRad;
      final ga = _sqrtRat(PolyOps.eval(g, a));
      if (ga == null) return null;
      final conjVal = Rational(c) * ga - PolyOps.eval(h, a);
      top = numPoly;
      bottom = PolyOps.sub(g, PolyOps.mul(h, h));
      factor = conjVal;
      conjLatex = '\\frac{${node.l.latex()}}{${node.r.latex()}} \\cdot \\frac{${c > 0 ? '' : '-'}\\sqrt{${PolyOps.latex(g)}} - \\left(${PolyOps.latex(h)}\\right)}'
          '{${c > 0 ? '' : '-'}\\sqrt{${PolyOps.latex(g)}} - \\left(${PolyOps.latex(h)}\\right)}';
    } else {
      return null;
    }
    // Solo aplica como metodo si hay indeterminacion 0/0 en el punto.
    final pa = PolyOps.eval(top, a), qa = PolyOps.eval(bottom, a);
    if (!(pa.isZero && qa.isZero)) return null;
    steps.add(MathStep(
      index: 0,
      shortTitle: 'Multiplicar por el conjugado',
      latexExpression: conjLatex,
      pedagogicalNote: 'Hay una raiz cuadrada y sale 0/0: multiplicamos numerador y denominador por el conjugado para usar (A - B)(A + B) = A^2 - B^2.',
    ));
    steps.add(MathStep(
      index: 0,
      shortTitle: 'Expresion sin raiz',
      latexExpression: '\\frac{${PolyOps.latex(top)}}{${PolyOps.latex(bottom)}} \\cdot ${domainRationalLatex(factor)}',
      pedagogicalNote: 'Desaparece la raiz; el factor restante se evalua en x = ${domainRationalLatex(a)}.',
    ));
    final inner = RationalLimits.atPoint(top, bottom, a, side, steps);
    if (!inner.isFinite || inner.finite == null) return inner;
    final total = inner.finite! * factor;
    steps.add(MathStep(
      index: 0,
      shortTitle: 'Producto final',
      latexExpression: '${domainRationalLatex(inner.finite!)} \\cdot ${domainRationalLatex(factor)} = ${domainRationalLatex(total)}',
      pedagogicalNote: 'Multiplicamos el limite racional por el factor del conjugado.',
    ));
    return LimitValue.number(total);
  }

  // --------------------------------------------------------- estimacion numerica

  static LimitValue _estimateSeq(List<double?> v) {
    final vals = v.whereType<double>().toList();
    if (vals.length < 2) return LimitValue.none;
    final last = vals.last, prev = vals[vals.length - 2];
    final growing = vals.length >= 3 && vals[0].abs() < vals[1].abs() && vals[1].abs() < last.abs();
    if (last.abs() > 1e5 && last.abs() > prev.abs() * 1.5 ||
        (growing && last.abs() > 8 && (last.abs() - prev.abs()) > 1)) {
      return LimitValue.infinite(last > 0 ? 1 : -1, estimated: true);
    }
    if ((last - prev).abs() < 1e-3 * math.max(1, last.abs())) {
      final r = _asRational(last);
      return r != null ? LimitValue.number(r, estimated: true) : LimitValue.decimal(last);
    }
    return LimitValue.none;
  }

  static LimitValue _side(FunctionModel f, double a, int dir) =>
      _estimateSeq([for (final h in const [1e-3, 1e-5, 1e-7]) f.at(a + dir * h)]);

  static LimitValue _estimate(FunctionModel f, LimitPoint pt, List<MathStep> steps) {
    LimitValue v;
    if (pt.atInfinity) {
      final s = pt.plusInf ? 1.0 : -1.0;
      v = _estimateSeq([for (final k in const [1e3, 1e6, 1e8]) f.at(s * k)]);
    } else {
      final a = pt.a!.toDouble();
      final l = _side(f, a, -1), r = _side(f, a, 1);
      v = switch (pt.side) {
        LimSide.left => l,
        LimSide.right => r,
        LimSide.both => (l.exists && r.exists && (l.inf == r.inf) && (l.inf != 0 || (l.toDouble - r.toDouble).abs() < 1e-3))
            ? r
            : LimitValue.none,
      };
      steps.add(MathStep(
        index: 0,
        shortTitle: 'Limites laterales',
        latexExpression: '\\lim_{x \\to ${domainRationalLatex(pt.a!)}^{-}} = ${l.latex},\\quad \\lim_{x \\to ${domainRationalLatex(pt.a!)}^{+}} = ${r.latex}',
        pedagogicalNote: 'Evaluamos f muy cerca del punto por cada lado (h = 0,001; 0,00001; 0,0000001).',
      ));
      return v;
    }
    steps.add(MathStep(
      index: 0,
      shortTitle: 'Comportamiento en el infinito',
      latexExpression: '\\lim_{${pt.latex}} f(x) \\approx ${v.latex}',
      pedagogicalNote: 'Evaluamos f para valores de x muy grandes en valor absoluto y observamos a que se aproxima.',
    ));
    return v;
  }

  // ------------------------------------------------------------------ estudio

  static StudyResult study(String raw) {
    final f = FunctionModel.parse(raw);
    final domain = DomainSolver.of(f);
    final rat = PolyOps.rationalOf(f.node);
    final steps = <MathStep>[...domain.steps];
    final AsymptoteSet set;
    if (rat != null && PolyOps.degree(rat.$2) >= 0) {
      final (s, aSteps) = RationalLimits.asymptotes(rat.$1, rat.$2);
      set = s;
      steps.addAll(aSteps);
    } else {
      final (s, aSteps) = _numericAsymptotes(f, domain);
      set = s;
      steps.addAll(aSteps);
    }
    final result = [
      '\\mathrm{Dom}(f) = ${domain.latex}',
      if (set.vertical.isNotEmpty) 'AV: ${set.vertical.map((a) => a.latex).join(r',\;')}',
      if (set.horizontal.isNotEmpty) 'AH: ${set.horizontal.map((a) => a.latex).join(r',\;')}',
      if (set.oblique.isNotEmpty) 'AO: ${set.oblique.map((a) => a.latex).join(r',\;')}',
    ].join(r',\;');
    final res = StepByStepResolution(
      originalInputLatex: 'f(x) = ${f.latex}',
      steps: _renumber(steps),
      exactResultLatex: result,
      decimalApproxLatex: '',
    );
    return StudyResult(f, domain, set, res);
  }

  static (AsymptoteSet, List<MathStep>) _numericAsymptotes(FunctionModel f, DomainResult domain) {
    final vertical = <Asymptote>[];
    final horizontal = <Asymptote>[];
    final oblique = <Asymptote>[];
    for (final b in domain.finiteBoundaries) {
      final r = _side(f, b, 1), l = _side(f, b, -1);
      if ((r.isInfinite && domain.contains(b + 1e-6)) || (l.isInfinite && domain.contains(b - 1e-6))) {
        final latex = domain.intervals
            .expand((i) => [i.lo, i.hi])
            .firstWhere((e) => e.v == b, orElse: () => DomainBound(b, '$b'))
            .latex;
        vertical.add(Asymptote.vertical('x = $latex', b, estimated: true));
      }
    }
    for (final (sgn, tag) in [(1.0, r'+\infty'), (-1.0, r'-\infty')]) {
      if (!domain.contains(sgn * 1e6)) continue;
      final v = _estimateSeq([for (final k in const [1e3, 1e6, 1e8]) f.at(sgn * k)]);
      if (v.isFinite) {
        horizontal.add(Asymptote.line('y = ${v.latex}', 0, v.toDouble, tag: '\\to $tag', estimated: true));
      } else if (v.isInfinite) {
        final x1 = sgn * 1e6, x2 = sgn * 1e7;
        final y1 = f.at(x1), y2 = f.at(x2);
        if (y1 == null || y2 == null) continue;
        final m = (y2 - y1) / (x2 - x1);
        final n = y1 - m * x1;
        final mr = _asRational(m), nr = _asRational(n);
        if (mr != null && nr != null && !mr.isZero && (f.at(sgn * 1e8) ?? 0) - (m * sgn * 1e8 + n) < 1e-3) {
          final body = PolyOps.latex({1: mr, 0: nr});
          oblique.add(Asymptote.line('y = $body', mr.toDouble(), nr.toDouble(), tag: '\\to $tag', estimated: true));
        }
      }
    }
    final set = AsymptoteSet(vertical: vertical, horizontal: horizontal, oblique: oblique);
    String list(List<Asymptote> l) => l.isEmpty ? r'\text{ninguna}' : l.map((a) => '${a.latex}\\;(${a.tag.isEmpty ? '' : a.tag})').join(r',\;');
    return (
      set,
      [
        MathStep(
          index: 0,
          shortTitle: 'Asintotas (estimacion numerica)',
          latexExpression: 'AV: ${vertical.isEmpty ? r'\text{ninguna}' : vertical.map((a) => a.latex).join(r',\;')}\\quad AH: ${list(horizontal)}\\quad AO: ${list(oblique)}',
          pedagogicalNote:
              'La funcion no es racional: las asintotas se detectan estudiando los extremos del dominio y los limites en el infinito; son estimaciones.',
        ),
      ],
    );
  }
}
