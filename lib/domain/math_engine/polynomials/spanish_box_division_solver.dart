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
      throw ArsenalException('Sintaxis incompleta: escribe $name.');
    }
    try {
      final node = ExtParser().parse(ExpressionParser.finalizeForEvaluation(text));
      final p = PolyOps.polyOf(node);
      if (p == null) throw const FormatException('no polinomio');
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

  static String _signed(Rational c, int k) {
    final t = _term(c.abs(), k);
    return c.isNegative ? '-$t' : t;
  }

  static BoxDivisionResult divide(Poly dividend, Poly divisor) {
    final p = PolyOps.clean(dividend), q = PolyOps.clean(divisor);
    if (q.isEmpty) throw const ArsenalException('Math ERROR: el divisor no puede ser 0.');
    if (p.isEmpty) throw const ArsenalException('Sintaxis incompleta: escribe el dividendo.');
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
            'Ordenamos por grados decrecientes y completamos con 0x^k los términos que faltan, para alinear las columnas.',
      ),
    ];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final lead = PolyOps.degree(i == 0 ? p : steps[i - 1].remainder);
      final leadC = PolyOps.coeff(i == 0 ? p : steps[i - 1].remainder, lead);
      mathSteps.add(MathStep(
        index: mathSteps.length + 1,
        shortTitle: 'Dividir los términos principales',
        latexExpression: '\\frac{${_signed(leadC, lead)}}{${_signed(lq, dq)}} = ${_signed(s.coeff, s.degree)}',
        pedagogicalNote:
            'Dividimos el término de mayor grado del resto entre el de mayor grado del divisor; el resultado es el siguiente término del cociente.',
      ));
      mathSteps.add(MathStep(
        index: mathSteps.length + 1,
        shortTitle: 'Multiplicar y restar',
        latexExpression: '-\\left(${PolyOps.latex(s.subtrahend)}\\right) \\Rightarrow ${s.remainder.isEmpty ? '0' : PolyOps.latex(s.remainder)}',
        pedagogicalNote:
            'Multiplicamos el término por el divisor, lo escribimos con el signo cambiado debajo del dividendo y sumamos por columnas.',
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
