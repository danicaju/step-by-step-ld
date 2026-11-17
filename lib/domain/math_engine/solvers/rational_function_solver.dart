import 'dart:math' as math;
import '../core/rational.dart';
import '../models/calculus_models.dart';
import '../models/step_resolution.dart';

/// Estudio de funciones racionales f(x) = P(x)/Q(x) (grado <= 2 en ambos):
/// dominio, cortes con los ejes y asintotas vertical/horizontal. Nunca evalua f
/// en un cero del denominador (no hay crash en x = 3 para (2x+1)/(x-3)).
class RationalFunctionSolver {
  static StepByStepResolution analyze(String raw) {
    final (numRaw, denRaw) = _splitQuotient(raw);
    final p = RationalPolynomial.parseExpression(numRaw);
    final q = RationalPolynomial.parseExpression(denRaw);
    if (q.coeffsByDegree.isEmpty) {
      throw const FormatException('El denominador no puede ser 0.');
    }
    final qRoots = _roots(q);
    final pRoots = _roots(p);
    final canceled = qRoots.where(pRoots.contains).toList();
    final vertical = qRoots.where((r) => !canceled.contains(r)).toList();
    final holes = canceled;
    final xCuts = pRoots.where((r) => !qRoots.contains(r)).toList();
    final dp = _degree(p);
    final dq = _degree(q);

    final domain = qRoots.isEmpty
        ? r'\mathbb{R}'
        : r'\mathbb{R}\setminus\left\{'
            '${qRoots.map((r) => r.toLatex()).join(r',\,')}\\right\\}';
    final y0 = q.coeffsByDegree[0] == null
        ? null
        : (p.coeffsByDegree[0] ?? Rational(0)) / q.coeffsByDegree[0]!;
    String? horizontal;
    if (dp < dq) {
      horizontal = 'y = 0';
    } else if (dp == dq) {
      horizontal = 'y = ${(p.coeffsByDegree[dp]! / q.coeffsByDegree[dq]!).toLatex()}';
    }
    final oblique = dp == dq + 1;

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: '1. Dominio: Q(x) distinto de 0',
        latexExpression: r'D(f) = ' + domain,
        pedagogicalNote:
            'El dominio de una funcion racional excluye los valores de x que anulan el denominador.',
        warningTrick: qRoots.isEmpty ? null : 'Nunca evalues f en un cero del denominador.',
      ),
      MathStep(
        index: 2,
        shortTitle: '2. Cortes con los ejes',
        latexExpression: 'OX: ${xCuts.isEmpty ? r'\text{ninguno}' : xCuts.map((r) => '\\left(${r.toLatex()},\\,0\\right)').join(r';\;')}'
            r'\quad OY: '
            '${y0 == null ? r'\text{ninguno}' : '\\left(0,\\,${y0.toLatex()}\\right)'}',
        pedagogicalNote:
            'OX: P(x) = 0 con x en el dominio. OY: x = 0 si pertenece al dominio.',
      ),
      MathStep(
        index: 3,
        shortTitle: '3. Asintotas',
        latexExpression: [
          if (vertical.isNotEmpty)
            'AV: ${vertical.map((r) => 'x = ${r.toLatex()}').join(r',\;')}'
          else
            r'AV: \text{ninguna}',
          if (horizontal != null) 'AH: $horizontal' else r'AH: \text{ninguna}',
          if (oblique) r'AO: \text{oblicua (dividir P entre Q)}',
          if (holes.isNotEmpty)
            '\\text{hueco en } x = ${holes.map((r) => r.toLatex()).join(", ")}',
        ].join(r'\quad '),
        pedagogicalNote:
            'Vertical donde Q se anula y P no. Horizontal: se comparan los grados de P y Q.',
      ),
    ];

    final result = [
      'D = $domain',
      if (vertical.isNotEmpty) 'AV: ${vertical.map((r) => 'x = ${r.toLatex()}').join(r',\;')}',
      if (horizontal != null) 'AH: $horizontal',
    ].join(r',\; ');
    return StepByStepResolution(
      originalInputLatex: 'f(x) = \\frac{${_toLatex(p)}}{${_toLatex(q)}}',
      steps: steps,
      exactResultLatex: result,
      decimalApproxLatex: '',
    );
  }

  static (String, String) _splitQuotient(String raw) {
    final s = raw.replaceAll(' ', '');
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == '/' && depth == 0) {
        return (_unwrap(s.substring(0, i)), _unwrap(s.substring(i + 1)));
      }
    }
    return (_unwrap(s), '1');
  }

  static String _unwrap(String s) {
    if (s.startsWith('(') && s.endsWith(')')) {
      var depth = 0;
      for (var i = 0; i < s.length - 1; i++) {
        if (s[i] == '(') depth++;
        if (s[i] == ')') depth--;
        if (depth == 0) return s;
      }
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  static int _degree(RationalPolynomial p) =>
      p.coeffsByDegree.isEmpty ? 0 : p.coeffsByDegree.keys.reduce(math.max);

  /// Raices racionales exactas de un polinomio de grado <= 2.
  static List<Rational> _roots(RationalPolynomial p) {
    final c = p.coeffsByDegree;
    if (c.isEmpty) return [];
    final deg = _degree(p);
    final a = c[deg]!;
    final zeroRoot = (deg > 0 && c[0] == null);
    if (deg == 0) return [];
    if (deg == 1) return [zeroRoot ? Rational(0) : -(c[0]! / a)];
    if (deg == 2) {
      final b = c[1] ?? Rational(0);
      final k = c[0] ?? Rational(0);
      final disc = b * b - Rational(4) * a * k;
      final d = disc.simplify();
      if (d.numerator < 0) return [];
      final sn = math.sqrt(d.numerator.toDouble()).round();
      final sd = math.sqrt(d.denominator.toDouble()).round();
      if (sn * sn != d.numerator || sd * sd != d.denominator) {
        throw const FormatException('Se admiten raices racionales en el denominador y numerador.');
      }
      final root = Rational(sn, sd);
      final r1 = ((-b) + root) / (Rational(2) * a);
      final r2 = ((-b) - root) / (Rational(2) * a);
      final out = <Rational>[r1.simplify()];
      if (r1.simplify() != r2.simplify()) out.add(r2.simplify());
      out.sort((x, y) => x.toDouble().compareTo(y.toDouble()));
      return out;
    }
    throw const FormatException('Se admiten polinomios de grado 0, 1 o 2.');
  }

  static String _toLatex(RationalPolynomial p) {
    if (p.coeffsByDegree.isEmpty) return '0';
    final degs = p.coeffsByDegree.keys.toList()..sort((a, b) => b.compareTo(a));
    final buf = StringBuffer();
    for (var i = 0; i < degs.length; i++) {
      final d = degs[i];
      final c = p.coeffsByDegree[d]!;
      final neg = c.numerator < 0;
      final abs = c.abs();
      buf.write(neg ? (i == 0 ? '-' : ' - ') : (i == 0 ? '' : ' + '));
      final one = abs == Rational(1);
      final coef = (one && d > 0) ? '' : abs.toLatex();
      final x = d == 0 ? '' : (d == 1 ? 'x' : 'x^{$d}');
      buf.write('$coef$x');
    }
    return buf.toString();
  }
}
