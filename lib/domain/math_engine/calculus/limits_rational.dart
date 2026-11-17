import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/equations/eq_poly.dart';
import 'domain_solver.dart';
import 'limit_models.dart';

MathStep _s(String title, String latex, String note, {String? trick}) =>
    MathStep(index: 0, shortTitle: title, latexExpression: latex, pedagogicalNote: note, warningTrick: trick);

String _q(Rational r) => domainRationalLatex(r);

/// `x - a` en LaTeX.
String linFactor(Rational a) =>
    a.isZero ? 'x' : (a.isNegative ? 'x + ${_q(a.abs())}' : 'x - ${_q(a)}');

String _frac(Poly p, Poly q) => '\\frac{${PolyOps.latex(p)}}{${PolyOps.latex(q)}}';

String _approach(Rational a, LimSide s) =>
    'x \\to ${_q(a)}${s == LimSide.left ? '^{-}' : (s == LimSide.right ? '^{+}' : '')}';

/// Division polinomica P = Q * S + R.
(Poly, Poly) polyDivMod(Poly p, Poly q) {
  var rem = PolyOps.clean(p);
  final quot = <int, Rational>{};
  final dq = PolyOps.degree(q);
  if (dq < 0) throw const FormatException('Division entre el polinomio nulo.');
  final lq = PolyOps.coeff(q, dq);
  var guard = 0;
  while (PolyOps.degree(rem) >= dq && rem.isNotEmpty && guard++ < 64) {
    final dr = PolyOps.degree(rem);
    final c = PolyOps.coeff(rem, dr) / lq;
    quot[dr - dq] = c;
    rem = PolyOps.sub(rem, PolyOps.scale(PolyOps.mul(q, PolyOps.x(dr - dq)), c));
  }
  return (PolyOps.clean(quot), rem);
}

/// Limites exactos de cocientes de polinomios (P/Q), con pasos didacticos.
class RationalLimits {
  const RationalLimits._();

  static int _sign(Rational r) => r.isZero ? 0 : (r.isNegative ? -1 : 1);

  /// Multiplicidad de `a` como raiz de [p] y cociente reducido.
  static (int, Poly) _strip(Poly p, Rational a) {
    var cur = p;
    var m = 0;
    while (cur.isNotEmpty && PolyOps.eval(cur, a).isZero && m < 12) {
      cur = PolyOps.deflate(cur, a);
      m++;
    }
    return (m, cur);
  }

  /// `lim_{x -> a} P/Q` por la izquierda, derecha o ambos lados.
  static LimitValue atPoint(Poly p, Poly q, Rational a, LimSide side, List<MathStep> steps) {
    final pa = PolyOps.eval(p, a);
    final qa = PolyOps.eval(q, a);
    steps.add(_s(
      'Sustitucion directa',
      '\\lim_{${_approach(a, side)}} ${_frac(p, q)} = \\frac{${_q(pa)}}{${_q(qa)}}',
      'Sustituimos x = ${_q(a)} en el numerador y en el denominador.',
    ));
    if (!qa.isZero) {
      final v = pa / qa;
      steps.add(_s('Resultado', '= ${_q(v)}', 'El denominador no se anula: el limite es el valor de la funcion.'));
      return LimitValue.number(v);
    }
    if (pa.isZero) return _zeroOverZero(p, q, a, side, steps);

    // k/0 con k distinto de 0: infinito por el signo de cada lado.
    final (m, qr) = _strip(q, a);
    final s0 = _sign(pa) * _sign(PolyOps.eval(qr, a));
    final sr = s0;
    final sl = m.isOdd ? -s0 : s0;
    steps.add(_s(
      'Limites laterales',
      '\\frac{${_q(pa)}}{0} \\Rightarrow \\lim_{x \\to ${_q(a)}^{-}} = ${sl > 0 ? '+' : '-'}\\infty,\\quad '
          '\\lim_{x \\to ${_q(a)}^{+}} = ${sr > 0 ? '+' : '-'}\\infty',
      'No es una indeterminacion: un numero distinto de 0 dividido entre 0 da infinito; el signo se obtiene estudiando cada lado.',
    ));
    if (side == LimSide.right) return LimitValue.infinite(sr);
    if (side == LimSide.left) return LimitValue.infinite(sl);
    if (sl == sr) return LimitValue.infinite(sl);
    steps.add(_s('Conclusion', '\\nexists', 'Los limites laterales son distintos: el limite no existe.'));
    return LimitValue.none;
  }

  static LimitValue _zeroOverZero(Poly p, Poly q, Rational a, LimSide side, List<MathStep> steps) {
    steps.add(_s(
      'Indeterminacion 0/0',
      '\\frac{0}{0}',
      'Numerador y denominador valen 0: factorizamos (x - ${_q(a)}) con la regla de Ruffini y simplificamos.',
    ));
    var np = p, nq = q;
    var guard = 0;
    while (PolyOps.eval(np, a).isZero && PolyOps.eval(nq, a).isZero && guard++ < 12) {
      np = PolyOps.deflate(np, a);
      nq = PolyOps.deflate(nq, a);
      steps.add(_s(
        'Factorizar y simplificar',
        '${_frac(p, q)} = \\frac{(${linFactor(a)})\\left(${PolyOps.latex(np)}\\right)}{(${linFactor(a)})\\left(${PolyOps.latex(nq)}\\right)} = ${_frac(np, nq)}',
        'Dividimos P(x) y Q(x) entre (${linFactor(a)}) y cancelamos el factor comun.',
      ));
      p = np;
      q = nq;
      if (np.isEmpty) break;
    }
    if (np.isEmpty) {
      steps.add(_s('Resultado', '= 0', 'El numerador es identicamente nulo tras simplificar.'));
      return LimitValue.number(Rational(0));
    }
    return atPoint(np, nq, a, side, steps);
  }

  /// `lim_{x -> +-inf} P/Q` comparando grados.
  static LimitValue atInfinity(Poly p, Poly q, {required bool plus, required List<MathStep> steps}) {
    final dp = PolyOps.degree(p), dq = PolyOps.degree(q);
    final tgt = plus ? r'+\infty' : r'-\infty';
    final lim = '\\lim_{x \\to $tgt}';
    if (dp < 0) return LimitValue.number(Rational(0));
    final lp = PolyOps.coeff(p, dp), lq = PolyOps.coeff(q, dq);
    final both = dp > 0 && dq > 0;
    steps.add(_s(
      both ? 'Indeterminacion infinito/infinito' : 'Comparar grados',
      '$lim ${_frac(p, q)} = ${both ? '\\frac{\\infty}{\\infty}' : '\\ldots'}',
      both
          ? 'Dividimos numerador y denominador entre la mayor potencia de x: x^{$dq} (el termino de mayor grado manda).'
          : 'Comparamos el grado del numerador ($dp) con el del denominador ($dq).',
    ));
    final dd = dp - dq;
    final lead = '\\frac{${_q(lp)}\\,x^{$dp}}{${_q(lq)}\\,x^{$dq}}';
    if (dd < 0) {
      steps.add(_s('Grado(P) menor que grado(Q)', '$lim $lead = $lim \\frac{${_q(lp / lq)}}{x^{${-dd}}} = 0',
          'Si el denominador tiene mayor grado, el cociente tiende a 0.'));
      return LimitValue.number(Rational(0));
    }
    if (dd == 0) {
      steps.add(_s('Grados iguales', '$lim $lead = \\frac{${_q(lp)}}{${_q(lq)}} = ${_q(lp / lq)}',
          'Con el mismo grado, el limite es el cociente de los coeficientes principales.'));
      return LimitValue.number(lp / lq);
    }
    final sg = _sign(lp / lq) * (plus ? 1 : (dd.isEven ? 1 : -1));
    steps.add(_s('Grado(P) mayor que grado(Q)', '$lim $lead = $lim ${_q(lp / lq)}\\,x^{$dd} = ${sg > 0 ? '+' : '-'}\\infty',
        'Si el numerador tiene mayor grado, el limite es infinito; el signo depende del coeficiente y de la paridad de $dd.'));
    return LimitValue.infinite(sg);
  }

  /// Asintotas exactas de P/Q: (vertical, horizontal, oblicua) con sus pasos.
  static (AsymptoteSet, List<MathStep>) asymptotes(Poly p, Poly q) {
    final steps = <MathStep>[];
    final vertical = <Asymptote>[];
    final horizontal = <Asymptote>[];
    final oblique = <Asymptote>[];

    final roots = PolyRoots.real(q);
    final vLines = <String>[];
    for (final r in roots) {
      final rat = r.asRational;
      if (rat != null) {
        final (_, pr) = _strip(p, rat);
        final (mq, _) = _strip(q, rat);
        final (mp, _) = _strip(p, rat);
        if (mp >= mq) continue; // hueco o cero: no hay asintota
        final left = RationalLimits.atPoint(p, q, rat, LimSide.left, <MathStep>[]);
        final right = RationalLimits.atPoint(p, q, rat, LimSide.right, <MathStep>[]);
        if (left.isInfinite || right.isInfinite) {
          vertical.add(Asymptote.vertical('x = ${_q(rat)}', rat.toDouble()));
          vLines.add('x = ${_q(rat)}:\\; ${left.latex}\\,/\\,${right.latex}');
        }
        if (pr.isEmpty) continue;
      } else if (PolyOps.eval(p, Rational.fromDouble(r.approx, 1000000)).abs().toDouble() > 1e-6) {
        vertical.add(Asymptote.vertical('x = ${r.toLatex()}', r.approx));
        vLines.add('x = ${r.toLatex()}');
      }
    }
    steps.add(_s(
      'Asintotas verticales',
      vertical.isEmpty ? r'\text{ninguna}' : vertical.map((a) => a.latex).join(r',\;'),
      'Vertical en cada x = a donde Q(a) = 0 y el limite lateral es infinito (limites: ${vLines.isEmpty ? 'ninguno' : 'izquierda / derecha en cada punto'}).',
    ));

    final dp = PolyOps.degree(p), dq = PolyOps.degree(q);
    final hSteps = <MathStep>[];
    final lp = atInfinity(p, q, plus: true, steps: hSteps);
    final lm = atInfinity(p, q, plus: false, steps: hSteps);
    for (final (v, tag) in [(lp, r'+\infty'), (lm, r'-\infty')]) {
      if (v.isFinite && v.finite != null && !horizontal.any((h) => h.n == v.finite!.toDouble() && h.tag.isEmpty)) {
        final same = lp.isFinite && lm.isFinite && lp.finite == lm.finite;
        horizontal.add(Asymptote.line('y = ${v.latex}', 0, v.finite!.toDouble(), tag: same ? '' : '\\to $tag'));
        if (same) break;
      }
    }
    steps.add(_s(
      'Asintotas horizontales',
      '\\lim_{x \\to +\\infty} f(x) = ${lp.latex},\\quad \\lim_{x \\to -\\infty} f(x) = ${lm.latex}'
          '${horizontal.isEmpty ? r'\Rightarrow \text{ninguna}' : '\\Rightarrow ${horizontal.map((a) => a.latex).join(r',\;')}'}',
      'Si el limite en el infinito es un numero k, y = k es asintota horizontal.',
    ));

    if (dq >= 1 && dp == dq + 1) {
      final (s, r) = polyDivMod(p, q);
      final m = PolyOps.coeff(s, 1), n = PolyOps.coeff(s, 0);
      final line = 'y = ${PolyOps.latex(s)}';
      oblique.add(Asymptote.line(line, m.toDouble(), n.toDouble()));
      steps.add(_s(
        'Asintota oblicua',
        '${PolyOps.latex(p)} = \\left(${PolyOps.latex(q)}\\right)\\left(${PolyOps.latex(s)}\\right) + ${r.isEmpty ? '0' : '\\left(${PolyOps.latex(r)}\\right)'} \\Rightarrow $line',
        'Como grado(P) = grado(Q) + 1, dividimos P entre Q: el cociente mx + n es la asintota oblicua.',
      ));
    } else {
      steps.add(_s('Asintota oblicua', r'\text{ninguna}',
          'Solo existe cuando grado(P) = grado(Q) + 1 (y no hay horizontal).'));
    }
    return (AsymptoteSet(vertical: vertical, horizontal: horizontal, oblique: oblique), steps);
  }
}
