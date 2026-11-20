import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../equations/eq_poly.dart';
import '../exact/exact_number.dart';
import '../exact/ext_expr.dart';
import '../exact/ext_math.dart';
import '../inequalities/universal/numeric_function.dart';
import 'free_system_rewrite.dart';
import 'multivar_poly.dart';

/// Sistemas 2x2 no lineales: una ecuacion lineal + otra polinomica (sustitucion), o dos
/// ecuaciones solo en `x^2`, `y^2` (reduccion). Comprueba cada par en el sistema original.
class NonlinearSystemSolver {
  const NonlinearSystemSolver._();

  static MathStep _st(String title, String latex, String note, [String? warn]) =>
      MathStep(index: 0, shortTitle: title, latexExpression: latex, pedagogicalNote: note, warningTrick: warn);

  static bool _valid(List<(XNode, XNode)> eqs, ExNum x, ExNum y) {
    final env = {'X': x.approx, 'Y': y.approx};
    for (final (l, r) in eqs) {
      final a = NumFn.evalEnv(l, env), b = NumFn.evalEnv(r, env);
      if (a == null || b == null || (a - b).abs() > 1e-6 * (1 + a.abs() + b.abs())) return false;
    }
    return true;
  }

  static String _pair(ExNum x, ExNum y) => '\\left(${x.toLatex()},\\, ${y.toLatex()}\\right)';

  static StepByStepResolution solve({
    required List<EqForm> forms,
    required List<(XNode, XNode)> originals,
    required String originalLatex,
    required List<String> conditions,
    required MathStep orderStep,
  }) {
    final steps = <MathStep>[orderStep];
    final cands = <(ExNum, ExNum)>[];
    final linIdx = [0, 1].where((i) => forms[i].poly.degree == 1).toList();
    if (linIdx.isNotEmpty) {
      _substitution(forms, linIdx.first, steps, cands);
    } else if (_onlySquares(forms[0].poly) && _onlySquares(forms[1].poly)) {
      _reduction(forms, steps, cands);
    } else {
      throw const FormatException(
          'Sistema no lineal no soportado: se necesita una ecuación lineal o dos ecuaciones solo en x² e y².');
    }

    final valid = <(ExNum, ExNum)>[];
    final dropped = <(ExNum, ExNum)>[];
    for (final c in cands) {
      final dup = valid.any((v) => (v.$1.approx - c.$1.approx).abs() < 1e-9 && (v.$2.approx - c.$2.approx).abs() < 1e-9);
      if (dup) continue;
      (_valid(originals, c.$1, c.$2) ? valid : dropped).add(c);
    }
    valid.sort((a, b) {
      final c = a.$1.approx.compareTo(b.$1.approx);
      return c != 0 ? c : a.$2.approx.compareTo(b.$2.approx);
    });

    steps.add(_st(
      'Comprobar en el sistema original y en el dominio',
      [
        for (final c in valid) '${_pair(c.$1, c.$2)}\\; \\text{valida}',
        for (final c in dropped) '${_pair(c.$1, c.$2)}\\; \\text{descartada}',
        if (cands.isEmpty) r'\text{No hay pares reales}',
      ].join(r' \quad '),
      conditions.isEmpty
          ? 'Sustituimos cada par en las dos ecuaciones originales. Solo valen los que las cumplen.'
          : 'Sustituimos cada par en las ecuaciones originales y comprobamos las condiciones de existencia (${conditions.join(', ')}). Los pares que las incumplen son soluciones extrañas y se descartan.',
      dropped.isEmpty ? null : 'Al quitar denominadores o logaritmos pueden aparecer soluciones falsas: comprueba siempre.',
    ));

    final result = valid.isEmpty
        ? r'\text{Sin solucion real}'
        : '\\left\\{${valid.map((c) => _pair(c.$1, c.$2)).join(r',\; ')}\\right\\}';
    steps.add(_st(
      'Soluciones del sistema',
      valid.isEmpty ? result : '(x, y) \\in $result',
      valid.isEmpty
          ? 'Ningún par real cumple a la vez las dos ecuaciones: el sistema es incompatible.'
          : 'El sistema tiene ${valid.length} ${valid.length == 1 ? 'solución' : 'soluciones'}: cada par (x, y) cumple las dos ecuaciones.',
    ));
    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: [for (var i = 0; i < steps.length; i++) _renumber(steps[i], i + 1)],
      exactResultLatex: result,
      decimalApproxLatex: result,
    );
  }

  static MathStep _renumber(MathStep s, int i) => MathStep(
        index: i,
        shortTitle: s.shortTitle,
        latexExpression: s.latexExpression,
        pedagogicalNote: s.pedagogicalNote,
        warningTrick: s.warningTrick,
      );

  // ------------------------------------------------------------ sustitucion
  static void _substitution(List<EqForm> forms, int li, List<MathStep> steps, List<(ExNum, ExNum)> cands) {
    final lin = forms[li].poly, other = forms[1 - li].poly;
    final a = lin.coef([1, 0, 0]), b = lin.coef([0, 1, 0]), c = lin.constantTerm;
    final solveY = !b.isZero;
    final MPoly expr = solveY
        ? MPoly.variable(0).scale(-a / b) + MPoly.constant(-c / b)
        : MPoly.constant(-c / a);
    final solved = solveY ? 'y' : 'x', rem = solveY ? 'x' : 'y';
    steps.add(_st(
      'Despejar una incógnita de la ecuación lineal',
      '${lin.latex()} = 0 \\implies $solved = ${expr.latex()}',
      'Despejamos $solved en la ecuación de primer grado para sustituirla después en la otra.',
    ));
    final q = other.substitute(solveY ? 1 : 0, expr);
    steps.add(_st(
      'Sustituir en la otra ecuación',
      '${other.latex()} = 0 \\;\\xrightarrow{$solved = ${expr.latex()}}\\; ${q.latex()} = 0',
      'Al sustituir $solved queda una ecuación con una sola incógnita, $rem. Desarrollamos y agrupamos.',
    ));
    final uni = q.univariate(solveY ? 0 : 1);
    if (uni == null) throw const FormatException('No se pudo reducir el sistema a una ecuación con una incógnita.');
    final poly = PolyOps.clean(uni);
    if (poly.isEmpty) {
      throw const FormatException('Sistema compatible indeterminado: la segunda ecuación se cumple siempre tras sustituir.');
    }
    final deg = PolyOps.degree(poly);
    if (deg == 0) return;
    final roots = PolyRoots.real(poly);
    final disc = deg == 2
        ? PolyOps.coeff(poly, 1) * PolyOps.coeff(poly, 1) - Rational(4) * PolyOps.coeff(poly, 2) * PolyOps.coeff(poly, 0)
        : null;
    steps.add(_st(
      deg == 2 ? 'Resolver la ecuación de 2.º grado' : 'Resolver la ecuación en $rem',
      [
        if (disc != null) '\\Delta = b^{2} - 4ac = ${disc.toLatex()}',
        roots.isEmpty ? r'\text{Sin raices reales}' : roots.map((r) => '$rem = ${r.toLatex()}').join(r',\;\; '),
      ].join(r' \quad '),
      deg == 2
          ? 'Aplicamos la fórmula de la ecuación de segundo grado. Si el discriminante es negativo no hay soluciones reales; si es 0 hay una doble.'
          : 'Calculamos las raíces reales de la ecuación resultante.',
    ));
    final pairs = <String>[];
    for (final r in roots) {
      final ExNum xv, yv;
      if (solveY) {
        xv = r;
        yv = ExNum.rational(-a / b) * r + ExNum.rational(-c / b);
      } else {
        yv = r;
        xv = ExNum.rational(-c / a);
      }
      cands.add((xv, yv));
      pairs.add(_pair(xv, yv));
    }
    steps.add(_st(
      'Calcular la otra incógnita',
      roots.isEmpty
          ? r'\text{No hay valores que sustituir}'
          : [for (var i = 0; i < roots.length; i++) '$rem = ${roots[i].toLatex()} \\Rightarrow $solved = ${solveY ? cands[i].$2.toLatex() : cands[i].$1.toLatex()}'].join(r',\;\; '),
      'Sustituimos cada valor de $rem en la expresión de $solved para obtener los pares ${pairs.isEmpty ? '' : '(x, y)'}.',
    ));
  }

  // --------------------------------------------------------------- reduccion
  static bool _onlySquares(MPoly p) => p.terms.keys.every((k) => k == MPoly.zeroKey || k == '2,0,0,0' || k == '0,2,0,0');

  static void _reduction(List<EqForm> forms, List<MathStep> steps, List<(ExNum, ExNum)> cands) {
    final p = forms[0].poly, q = forms[1].poly;
    final a1 = p.coef([2, 0, 0]), b1 = p.coef([0, 2, 0]), c1 = -p.constantTerm;
    final a2 = q.coef([2, 0, 0]), b2 = q.coef([0, 2, 0]), c2 = -q.constantTerm;
    final det = a1 * b2 - a2 * b1;
    if (det.isZero) throw const FormatException('Las dos ecuaciones en x² e y² no son independientes.');
    final xs = (c1 * b2 - c2 * b1) / det, ys = (a1 * c2 - a2 * c1) / det;
    steps.add(_st(
      'Reducción en x² e y²',
      '\\begin{cases} ${_sq(a1, b1)} = ${c1.toLatex()} \\\\ ${_sq(a2, b2)} = ${c2.toLatex()} \\end{cases} \\implies x^{2} = ${xs.toLatex()},\\; y^{2} = ${ys.toLatex()}',
      'Las dos ecuaciones solo tienen x² e y²: las tratamos como un sistema lineal en esas dos cantidades y lo resolvemos por reducción.',
    ));
    if (xs.isNegative || ys.isNegative) {
      steps.add(_st('Raíces cuadradas', r'\text{Un cuadrado no puede ser negativo}', 'Como x² o y² resulta negativo, no hay soluciones reales.'));
      return;
    }
    final xr = xs.isZero ? [ExNum.integer(0)] : [ExtMath.nthRoot(xs, 2), -ExtMath.nthRoot(xs, 2)];
    final yr = ys.isZero ? [ExNum.integer(0)] : [ExtMath.nthRoot(ys, 2), -ExtMath.nthRoot(ys, 2)];
    for (final x in xr) {
      for (final y in yr) {
        cands.add((x, y));
      }
    }
    steps.add(_st(
      'Raíces cuadradas: todas las combinaciones (±x, ±y)',
      'x = ${xs.isZero ? '0' : '\\pm ${xr.first.toLatex()}'},\\quad y = ${ys.isZero ? '0' : '\\pm ${yr.first.toLatex()}'}',
      'Cada cuadrado tiene dos raíces, una positiva y otra negativa; combinándolas salen hasta cuatro pares.',
      'No olvides el signo ±: cada raíz cuadrada tiene dos valores.',
    ));
  }

  static String _sq(Rational a, Rational b) {
    String t(Rational c, String v, bool first) {
      if (c.isZero) return '';
      final body = c.abs() == Rational(1) ? v : '${c.abs().toLatex()}$v';
      return first ? (c.isNegative ? '-$body' : body) : (c.isNegative ? ' - $body' : ' + $body');
    }

    final s = '${t(a, 'x^{2}', true)}${t(b, 'y^{2}', a.isZero)}';
    return s.isEmpty ? '0' : s;
  }
}
