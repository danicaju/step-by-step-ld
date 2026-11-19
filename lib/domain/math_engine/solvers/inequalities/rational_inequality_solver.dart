import 'dart:math' as math;

import '../../models/inequality_models.dart';
import '../../models/step_resolution.dart';
import '../../parser/expression_parser.dart';
import '../equations/eq_poly.dart';
import '../exact/exact_number.dart';
import '../exact/ext_parser.dart';
import 'inequality_sign.dart';
import 'rational_abs_inequality_solver.dart';

/// Inecuaciones racionales `P(x)/Q(x) ⋚ 0` (o cualquier combinacion de fracciones):
/// puntos criticos, tabla de signos y solucion como union de intervalos.
class RationalInequalitySolver {
  const RationalInequalitySolver._();

  static (Poly, Poly)? _rational(String side) {
    try {
      final node = ExtParser().parse(ExpressionParser.finalizeForEvaluation(side));
      return PolyOps.rationalOf(node);
    } on Object {
      return null;
    }
  }

  /// `true` si algun miembro tiene `x` en el denominador.
  static bool isRational(String lhs, String rhs) {
    final l = _rational(lhs), r = _rational(rhs);
    if (l == null || r == null) return false;
    return PolyOps.degree(l.$2) > 0 || PolyOps.degree(r.$2) > 0;
  }

  static double _eval(Poly p, double x) {
    var acc = 0.0;
    p.forEach((k, v) => acc += v.toDouble() * math.pow(x, k));
    return acc;
  }

  static int _sign(double v) => v.abs() < 1e-12 ? 0 : (v > 0 ? 1 : -1);

  static String _s(int s) => s > 0 ? '+' : (s < 0 ? '-' : '0');

  static StepByStepResolution? solve(String lhs, String rhs, InequalitySign sign) {
    final l = _rational(lhs), r = _rational(rhs);
    if (l == null || r == null) return null;
    var num = PolyOps.clean(PolyOps.sub(PolyOps.mul(l.$1, r.$2), PolyOps.mul(r.$1, l.$2)));
    var den = PolyOps.clean(PolyOps.mul(l.$2, r.$2));
    if (num.isEmpty || den.isEmpty) return null;
    if (PolyOps.coeff(den, PolyOps.degree(den)).isNegative) {
      num = PolyOps.neg(num);
      den = PolyOps.neg(den);
    }
    final numRoots = PolyRoots.real(num);
    final denRoots = PolyRoots.real(den);
    bool near(ExNum a, ExNum b) => (a.approx - b.approx).abs() < 1e-9;

    final pts = <({ExNum v, bool isNum, bool isDen})>[];
    for (final root in [...numRoots, ...denRoots]) {
      if (pts.any((p) => near(p.v, root))) continue;
      pts.add((
        v: root,
        isNum: numRoots.any((e) => near(e, root)),
        isDen: denRoots.any((e) => near(e, root)),
      ));
    }
    pts.sort((a, b) => a.v.approx.compareTo(b.v.approx));
    final n = pts.length;

    // Un punto de prueba por tramo.
    final tests = <double>[];
    for (var i = 0; i <= n; i++) {
      if (n == 0) {
        tests.add(0);
      } else if (i == 0) {
        tests.add(pts.first.v.approx - 1);
      } else if (i == n) {
        tests.add(pts.last.v.approx + 1);
      } else {
        tests.add((pts[i - 1].v.approx + pts[i].v.approx) / 2);
      }
    }
    final sN = [for (final t in tests) _sign(_eval(num, t))];
    final sD = [for (final t in tests) _sign(_eval(den, t))];
    final sat = [for (var i = 0; i <= n; i++) sign.matchesSign(sN[i] * sD[i])];
    final closed = [for (final p in pts) !sign.isStrict && p.isNum && !p.isDen];

    // Union de intervalos: tramos y puntos en orden (seg0, pt0, seg1, ...).
    final inSet = <bool>[for (var i = 0; i <= n; i++) ...[sat[i], if (i < n) closed[i]]];
    final intervals = <InequalityInterval>[];
    var k = 0;
    while (k < inSet.length) {
      if (!inSet[k]) {
        k++;
        continue;
      }
      var j = k;
      while (j + 1 < inSet.length && inSet[j + 1]) {
        j++;
      }
      // Indice par = tramo i = k/2; impar = punto (k-1)/2.
      final firstIsPt = k.isOdd, lastIsPt = j.isOdd;
      final startPt = firstIsPt ? (k - 1) ~/ 2 : (k ~/ 2) - 1;
      final endPt = lastIsPt ? (j - 1) ~/ 2 : (j ~/ 2);
      final unboundedLeft = !firstIsPt && k == 0;
      final unboundedRight = !lastIsPt && j == inSet.length - 1;
      intervals.add(InequalityInterval(
        start: unboundedLeft ? double.negativeInfinity : pts[startPt].v.approx,
        end: unboundedRight ? double.infinity : pts[endPt].v.approx,
        startLabel: unboundedLeft ? null : pts[startPt].v.toLatex(),
        endLabel: unboundedRight ? null : pts[endPt].v.toLatex(),
        includeStart: firstIsPt,
        includeEnd: lastIsPt,
      ));
      k = j + 1;
    }

    String latexOf(InequalityInterval i) {
      if (!i.isLeftUnbounded && !i.isRightUnbounded && i.start == i.end) return '\\left\\{${i.startLabel}\\right\\}';
      return i.toIntervalLatex();
    }

    final solution = intervals.isEmpty
        ? r'\emptyset'
        : (intervals.length == 1 && intervals.first.isLeftUnbounded && intervals.first.isRightUnbounded)
            ? r'(-\infty, +\infty)'
            : intervals.map(latexOf).join(r' \cup ');

    String ptLatex(int i) => pts[i].v.toLatex();
    String segLatex(int i) {
      final a = i == 0 ? r'-\infty' : ptLatex(i - 1);
      final b = i == n ? r'+\infty' : ptLatex(i);
      return '($a, $b)';
    }

    final numLatex = PolyOps.latex(num), denLatex = PolyOps.latex(den);
    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Todo a un miembro: P(x)/Q(x) frente a 0',
        latexExpression: '$lhs ${sign.latex} $rhs \\implies \\frac{$numLatex}{$denLatex} ${sign.latex} 0',
        pedagogicalNote:
            'Para estudiar el signo pasamos todo a un miembro, lo reducimos a una sola fracción y la comparamos con 0.',
        warningTrick: 'No multipliques por el denominador: su signo cambia y no sabes si hay que invertir la desigualdad.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Puntos críticos: ceros de P(x) y de Q(x)',
        latexExpression:
            'P(x) = $numLatex = 0 \\implies ${numRoots.isEmpty ? r'\text{sin raices reales}' : numRoots.map((e) => 'x = ${e.toLatex()}').join(r',\; ')}'
            ' \\qquad Q(x) = $denLatex = 0 \\implies ${denRoots.isEmpty ? r'\text{sin raices reales}' : denRoots.map((e) => 'x = ${e.toLatex()}').join(r',\; ')}',
        pedagogicalNote:
            'Los ceros del numerador anulan la fracción y los del denominador son los valores prohibidos. Entre dos puntos críticos consecutivos el signo no cambia.',
        warningTrick: 'Las raíces del denominador siempre quedan con paréntesis (abiertas): ahí la fracción no existe.',
      ),
    ];

    final cols = 2 * n + 1;
    final header = [for (var i = 0; i <= n; i++) ...[segLatex(i), if (i < n) ptLatex(i)]];
    final rowN = [
      for (var i = 0; i <= n; i++) ...[_s(sN[i]), if (i < n) (pts[i].isNum ? '0' : _s(_sign(_eval(num, pts[i].v.approx))))],
    ];
    final rowD = [
      for (var i = 0; i <= n; i++) ...[_s(sD[i]), if (i < n) (pts[i].isDen ? '0' : _s(_sign(_eval(den, pts[i].v.approx))))],
    ];
    final rowQ = [
      for (var i = 0; i <= n; i++) ...[
        _s(sN[i] * sD[i]),
        if (i < n) (pts[i].isDen ? r'\nexists' : (pts[i].isNum ? '0' : _s(_sign(_eval(num, pts[i].v.approx)) * _sign(_eval(den, pts[i].v.approx))))),
      ],
    ];
    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Tabla de signos',
        latexExpression: '\\begin{array}{c|${'c' * cols}}\n'
            'x & ${header.join(' & ')} \\\\\n\\hline\n'
            'P(x) & ${rowN.join(' & ')} \\\\\n'
            'Q(x) & ${rowD.join(' & ')} \\\\\n\\hline\n'
            '\\frac{P}{Q} & ${rowQ.join(' & ')}\n\\end{array}',
        pedagogicalNote:
            'Evaluamos el signo de P y de Q en un punto de cada tramo. El signo del cociente es el producto de los signos (más por menos da menos).',
      ),
    );
    steps.add(
      MathStep(
        index: 4,
        shortTitle: 'Solución: tramos que cumplen la desigualdad',
        latexExpression: 'x \\in $solution',
        pedagogicalNote:
            'Nos quedamos con los tramos cuyo signo cumple ${sign.symbol} 0. Un cero del numerador entra solo si la desigualdad no es estricta (≤ o ≥); un cero del denominador nunca entra.',
        warningTrick: pts.any((p) => p.isDen) ? 'Los valores que anulan el denominador están excluidos aunque la desigualdad sea ≤ o ≥.' : null,
      ),
    );

    final res = StepByStepResolution(
      originalInputLatex: '$lhs ${sign.latex} $rhs',
      steps: steps,
      exactResultLatex: solution,
      decimalApproxLatex: solution,
    );
    RationalAbsInequalitySolver.visualDataExpando[res] = Inequality1DVisualData(
      criticalPoints: [
        for (var i = 0; i < n; i++) CriticalPoint(value: pts[i].v.approx, label: ptLatex(i), isClosed: closed[i]),
      ],
      primaryIntervals: intervals,
      signTestIntervals: [
        for (var i = 0; i <= n; i++)
          InequalityInterval(
            start: i == 0 ? double.negativeInfinity : pts[i - 1].v.approx,
            end: i == n ? double.infinity : pts[i].v.approx,
            startLabel: i == 0 ? null : ptLatex(i - 1),
            endLabel: i == n ? null : ptLatex(i),
            isSatisfied: sat[i],
          ),
      ],
      solutionLatex: solution,
    );
    return res;
  }
}
