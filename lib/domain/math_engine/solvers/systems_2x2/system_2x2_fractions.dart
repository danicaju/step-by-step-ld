import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../linear_system_solver.dart';

/// Sistema 2x2 con coeficientes racionales (`x/2 + y/3 = 4`): primero se quitan los
/// denominadores multiplicando cada ecuacion por su m.c.m. y despues se resuelve con
/// el metodo elegido (los coeficientes enteros que usa el resto de motores).
class System2x2Fractions {
  const System2x2Fractions._();

  static String _term(Rational c, String v, {required bool first}) {
    final abs = c.abs();
    final body = abs == Rational(1) ? v : '${abs.toLatex()}$v';
    if (first) return c.isNegative ? '-$body' : body;
    return c.isNegative ? ' - $body' : ' + $body';
  }

  /// `a x + b y = c` con fracciones verticales y sin terminos nulos.
  static String equationLatex(Rational a, Rational b, Rational c) {
    final buf = StringBuffer();
    var first = true;
    for (final (coef, v) in [(a, 'x'), (b, 'y')]) {
      if (coef.isZero) continue;
      buf.write(_term(coef, v, first: first));
      first = false;
    }
    if (first) buf.write('0');
    return '$buf = ${c.toLatex()}';
  }

  static StepByStepResolution solve({
    required List<Rational> row1,
    required List<Rational> row2,
    SystemResolutionMethod method = SystemResolutionMethod.sustitucion,
  }) {
    final all = [...row1, ...row2];
    int lcmOf(List<Rational> r) => Rational.lcmMany([for (final c in r) c.denominator]);
    final m1 = lcmOf(row1), m2 = lcmOf(row2);
    List<int> scale(List<Rational> r, int m) => [for (final c in r) (c * Rational(m)).numerator];
    final s1 = scale(row1, m1), s2 = scale(row2, m2);
    final inner = LinearSystemSolver.solve(
      a1: s1[0],
      b1: s1[1],
      c1: s1[2],
      a2: s2[0],
      b2: s2[1],
      c2: s2[2],
      method: method,
    );
    if (all.every((c) => c.isInteger)) return inner;

    final given =
        '\\begin{cases} ${equationLatex(row1[0], row1[1], row1[2])} \\\\ ${equationLatex(row2[0], row2[1], row2[2])} \\end{cases}';
    final cleared = '\\begin{cases} ${LinearSystemSolver.formatEquation(s1[0], s1[1], s1[2])} \\\\ '
        '${LinearSystemSolver.formatEquation(s2[0], s2[1], s2[2])} \\end{cases}';
    final multipliers = [
      if (m1 != 1) 'E_{1} \\cdot $m1',
      if (m2 != 1) 'E_{2} \\cdot $m2',
    ].join(',\\; ');
    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Quitar denominadores',
        latexExpression: '$given \\;\\xrightarrow{$multipliers}\\; $cleared',
        pedagogicalNote:
            'Multiplicamos cada ecuación por el m.c.m. de sus denominadores (${m1 == 1 ? '1' : m1} y ${m2 == 1 ? '1' : m2}) para trabajar con coeficientes enteros; las soluciones no cambian.',
        warningTrick: 'Hay que multiplicar TODOS los términos de la ecuación, también el término independiente.',
      ),
      for (final s in inner.steps)
        MathStep(
          index: s.index + 1,
          shortTitle: s.shortTitle,
          latexExpression: s.latexExpression,
          pedagogicalNote: s.pedagogicalNote,
          warningTrick: s.warningTrick,
        ),
    ];
    return StepByStepResolution(
      originalInputLatex: given,
      steps: steps,
      exactResultLatex: inner.exactResultLatex,
      decimalApproxLatex: inner.decimalApproxLatex,
    );
  }
}
