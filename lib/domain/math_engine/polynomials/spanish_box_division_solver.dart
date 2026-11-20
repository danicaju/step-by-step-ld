import '../arithmetic/casio_iberia_arsenal.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../parser/expression_parser.dart';
import '../solvers/equations/eq_poly.dart';
import '../solvers/exact/ext_parser.dart';

/// Un paso de la caja: termino del cociente, polinomio que se resta y resto parcial.
class BoxStep {
  final int degree; // grado del termino del cociente
  final Rational coeff;
  final Poly subtrahend; // termino * Q (se muestra con el signo cambiado)
  final Poly remainder; // resto tras restar
  const BoxStep(this.degree, this.coeff, this.subtrahend, this.remainder);
}

class BoxDivisionResult {
  final Poly dividend;
  final Poly divisor;
  final Poly quotient;
  final Poly remainder;
  final List<BoxStep> steps;
  final StepByStepResolution resolution;

  const BoxDivisionResult(this.dividend, this.divisor, this.quotient, this.remainder, this.steps, this.resolution);

  int get topDegree => PolyOps.degree(dividend);
}

/// Division larga de polinomios en caja espanola: `P(x) : Q(x) = C(x)` con resto `R(x)`.
class SpanishBoxDivisionSolver {
  const SpanishBoxDivisionSolver._();

  /// Lee un polinomio en `x` desde texto (`x^3 - 2x + 1`).
  static Poly parsePoly(String raw, String name) {
    final text = raw.trim();
    if (text.isEmpty || text == '0') {
      throw ArsenalException('Sintaxis incompleta: Escribe $name.');
    }
    try {
      final node = ExtParser().parse(ExpressionParser.finalizeForEvaluation(text));
      final p = PolyOps.polyOf(node);
      if (p == null) throw const FormatException('El texto no es un polinomio.');
      return PolyOps.clean(p);
    } on ArsenalException {
      rethrow;
    } on Object {
      throw ArsenalException('Sintaxis incompleta: $name debe ser un polinomio en x.');
    }
  }

  static String _num(Rational r) => ArsenalLatex.rat(r);

  /// Polinomio completo de grado [top] con `0x^k` en los huecos.
  static String complete(Poly p, int top) {
    final buf = StringBuffer();
    for (var k = top; k >= 0; k--) {
      final c = PolyOps.coeff(p, k);
      final body = c.isZero
          ? (k == 0 ? '0' : (k == 1 ? '0x' : '0x^{$k}'))
          : _term(c.abs(), k);
      if (k == top) {
        buf.write(c.isNegative ? '-$body' : body);
      } else {
        buf.write(c.isNegative ? ' - $body' : ' + $body');
      }
    }
    return buf.toString();
  }

  static String _term(Rational abs, int k) {
    final coef = (abs == Rational(1) && k > 0) ? '' : _num(abs);
    return k == 0 ? coef : (k == 1 ? '${coef}x' : '${coef}x^{$k}');
  }

  /// Termino en texto plano para las notas: `2x³`, `x`, `-5`.
  static String plainTerm(Rational c, int k) {
    const sup = {'0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹'};
    final abs = c.abs();
    final num = abs.isInteger ? '${abs.numerator}' : '${abs.numerator}/${abs.denominator}';
    final coef = (abs == Rational(1) && k > 0) ? '' : num;
    final x = k == 0 ? '' : (k == 1 ? 'x' : 'x${'$k'.split('').map((d) => sup[d]).join()}');
    return '${c.isNegative ? '-' : ''}$coef$x';
  }

  static String _signed(Rational c, int k) {
    final t = _term(c.abs(), k);
    return c.isNegative ? '-$t' : t;
  }

  static BoxDivisionResult divide(Poly dividend, Poly divisor) {
    final p = PolyOps.clean(dividend), q = PolyOps.clean(divisor);
    if (q.isEmpty) throw const ArsenalException('Math ERROR: El divisor no puede ser 0.');
    if (p.isEmpty) throw const ArsenalException('Sintaxis incompleta: Escribe el dividendo.');
    final dq = PolyOps.degree(q);
    final lq = PolyOps.coeff(q, dq);
    final top = PolyOps.degree(p);

    final steps = <BoxStep>[];
    var rem = p;
    final quot = <int, Rational>{};
    var guard = 0;
    while (rem.isNotEmpty && PolyOps.degree(rem) >= dq && guard++ < 64) {
      final dr = PolyOps.degree(rem);
      final c = PolyOps.coeff(rem, dr) / lq;
      final k = dr - dq;
      quot[k] = c;
      final sub = PolyOps.scale(PolyOps.mul(q, PolyOps.x(k)), c);
      rem = PolyOps.sub(rem, sub);
      steps.add(BoxStep(k, c, sub, rem));
    }
    final quotient = PolyOps.clean(quot);

    final mathSteps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Ordenar y completar',
        latexExpression: '\\left(${complete(p, top)}\\right) : \\left(${PolyOps.latex(q)}\\right)',
        pedagogicalNote:
            'Dibujamos la caja: el dividendo ordenado y completo (con 0x^k en los huecos) a la izquierda y el divisor dentro de la caja.',
      ),
    ];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final before = i == 0 ? p : steps[i - 1].remainder;
      final lead = PolyOps.degree(before);
      final leadC = PolyOps.coeff(before, lead);
      final leadTxt = plainTerm(leadC, lead), divTxt = plainTerm(lq, dq), termTxt = plainTerm(s.coeff, s.degree);
      mathSteps.add(MathStep(
        index: mathSteps.length + 1,
        shortTitle: 'Dividir los términos principales (${i + 1}/${steps.length})',
        latexExpression: '\\frac{${_signed(leadC, lead)}}{${_signed(lq, dq)}} = ${_signed(s.coeff, s.degree)}',
        pedagogicalNote:
            'Dividimos $leadTxt (mayor grado del resto) entre $divTxt (mayor grado del divisor): $termTxt. Es el siguiente término del cociente.',
      ));
      final restTxt = s.remainder.isEmpty ? '0' : PolyOps.latex(s.remainder);
      mathSteps.add(MathStep(
        index: mathSteps.length + 1,
        shortTitle: 'Multiplicar y restar (${i + 1}/${steps.length})',
        latexExpression:
            '${_signed(s.coeff, s.degree)} \\cdot \\left(${PolyOps.latex(q)}\\right) = ${PolyOps.latex(s.subtrahend)} \\;\\Rightarrow\\; R_{${i + 1}}(x) = $restTxt',
        pedagogicalNote:
            'Multiplicamos $termTxt por todo el divisor y lo escribimos con el signo cambiado bajo el dividendo; sumamos por columnas y queda el resto parcial.',
      ));
    }
    final check =
        '${PolyOps.latex(p)} = \\left(${PolyOps.latex(q)}\\right)\\left(${quotient.isEmpty ? '0' : PolyOps.latex(quotient)}\\right)'
        '${rem.isEmpty ? '' : ' + \\left(${PolyOps.latex(rem)}\\right)'}';
    mathSteps.add(MathStep(
      index: mathSteps.length + 1,
      shortTitle: 'Cociente, resto y comprobación',
      latexExpression: 'C(x) = ${quotient.isEmpty ? '0' : PolyOps.latex(quotient)},\\quad R(x) = ${rem.isEmpty ? '0' : PolyOps.latex(rem)}\\;\\Rightarrow\\; $check',
      pedagogicalNote:
          'Paramos cuando el grado del resto es menor que el del divisor. Prueba: dividendo = divisor · cociente + resto.',
      warningTrick: rem.isEmpty ? 'Resto 0: la división es exacta y Q(x) divide a P(x).' : null,
    ));

    final res = StepByStepResolution(
      originalInputLatex: '\\left(${PolyOps.latex(p)}\\right) : \\left(${PolyOps.latex(q)}\\right)',
      steps: mathSteps,
      exactResultLatex: 'C(x) = ${quotient.isEmpty ? '0' : PolyOps.latex(quotient)},\\; R(x) = ${rem.isEmpty ? '0' : PolyOps.latex(rem)}',
      decimalApproxLatex: '',
    );
    return BoxDivisionResult(p, q, quotient, rem, steps, res);
  }

  /// Atajo: divide dos textos.
  static BoxDivisionResult divideText(String p, String q) =>
      divide(parsePoly(p, 'el dividendo P(x)'), parsePoly(q, 'el divisor Q(x)'));
}
