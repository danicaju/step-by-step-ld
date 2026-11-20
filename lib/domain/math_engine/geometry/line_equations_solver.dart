import '../arithmetic/casio_iberia_arsenal.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

/// Las 6 ecuaciones de la recta en el plano (coeficientes exactos).
class LineEquationsResult {
  final Rational x0, y0, v1, v2;
  final Rational? slope; // null si es vertical
  final Rational? intercept;
  final int a, b, c; // forma general Ax + By + C = 0
  final StepByStepResolution resolution;

  const LineEquationsResult(this.x0, this.y0, this.v1, this.v2, this.slope, this.intercept, this.a, this.b, this.c, this.resolution);

  bool get isVertical => v1.isZero;
  bool get isHorizontal => v2.isZero;
}

class LineEquationsSolver {
  const LineEquationsSolver._();

  static String _r(Rational r) => ArsenalLatex.rat(r);
  static String _p(Rational r) => ArsenalLatex.ratParen(r);

  /// `x - x0` (o `x + |x0|`, o `x` si x0 = 0).
  static String _shift(String v, Rational k) =>
      k.isZero ? v : (k.isNegative ? '$v + ${_r(k.abs())}' : '$v - ${_r(k)}');

  /// `x0 + t v1` con el signo bien escrito.
  static String _param(Rational p, Rational v, {String t = 't'}) {
    final coef = v.abs() == Rational(1) ? t : '${_r(v.abs())}$t';
    if (v.isZero) return _r(p);
    if (p.isZero) return v.isNegative ? '-$coef' : coef;
    return '${_r(p)} ${v.isNegative ? '-' : '+'} $coef';
  }

  static String _general(int a, int b, int c) {
    final parts = <String>[];
    void add(int k, String sym) {
      if (k == 0) return;
      final abs = k.abs();
      final body = sym.isEmpty ? '$abs' : (abs == 1 ? sym : '$abs$sym');
      parts.add(parts.isEmpty ? (k < 0 ? '-$body' : body) : (k < 0 ? '- $body' : '+ $body'));
    }

    add(a, 'x');
    add(b, 'y');
    add(c, '');
    return '${parts.isEmpty ? '0' : parts.join(' ')} = 0';
  }

  /// Desde dos puntos A y B.
  static LineEquationsResult fromPoints(Rational x1, Rational y1, Rational x2, Rational y2) {
    if (x1 == x2 && y1 == y2) throw const ArsenalException('Math ERROR: A y B son el mismo punto.');
    return _solve(x1, y1, x2 - x1, y2 - y1,
        intro: '\\vec{AB} = (${_r(x2)} - ${_p(x1)},\\; ${_r(y2)} - ${_p(y1)}) = (${_r(x2 - x1)},\\; ${_r(y2 - y1)})',
        introNote: 'El vector director es AB = B - A; usamos A como punto de la recta.');
  }

  /// Desde un punto y un vector director.
  static LineEquationsResult fromPointVector(Rational x0, Rational y0, Rational v1, Rational v2) {
    if (v1.isZero && v2.isZero) throw const ArsenalException('Math ERROR: El vector director no puede ser (0, 0).');
    return _solve(x0, y0, v1, v2,
        intro: 'P(${_r(x0)},\\; ${_r(y0)}),\\quad \\vec{v} = (${_r(v1)},\\; ${_r(v2)})', introNote: 'Datos: un punto y un vector director.');
  }

  /// Desde un punto y la pendiente m (vector director (1, m)).
  static LineEquationsResult fromPointSlope(Rational x0, Rational y0, Rational m) => _solve(x0, y0, Rational(1), m,
      intro: 'P(${_r(x0)},\\; ${_r(y0)}),\\quad m = ${_r(m)} \\Rightarrow \\vec{v} = (1,\\; ${_r(m)})',
      introNote: 'Con pendiente m, un vector director es (1, m).');

  static LineEquationsResult _solve(Rational x0, Rational y0, Rational v1, Rational v2,
      {required String intro, required String introNote}) {
    final vertical = v1.isZero;
    final m = vertical ? null : v2 / v1;
    final n = m == null ? null : y0 - m * x0;

    // Forma general con enteros coprimos y primer coeficiente positivo.
    var ra = v2, rb = -v1;
    var rc = -(ra * x0 + rb * y0);
    final l = Rational.lcmMany([ra.denominator, rb.denominator, rc.denominator]);
    var ia = (ra * Rational(l)).numerator, ib = (rb * Rational(l)).numerator, ic = (rc * Rational(l)).numerator;
    final g = Rational.gcdMany([ia, ib, ic]);
    ia ~/= g;
    ib ~/= g;
    ic ~/= g;
    if (ia < 0 || (ia == 0 && ib < 0)) {
      ia = -ia;
      ib = -ib;
      ic = -ic;
    }
    ra = Rational(ia);

    final steps = <MathStep>[
      MathStep(index: 1, shortTitle: 'Datos', latexExpression: intro, pedagogicalNote: introNote),
      MathStep(
        index: 2,
        shortTitle: 'Ecuación vectorial',
        latexExpression: '(x,\\; y) = (${_r(x0)},\\; ${_r(y0)}) + t\\,(${_r(v1)},\\; ${_r(v2)}),\\quad t \\in \\mathbb{R}',
        pedagogicalNote: 'Un punto más un múltiplo del vector director recorre toda la recta.',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Ecuaciones paramétricas',
        latexExpression: '\\left\\{\\begin{array}{l} x = ${_param(x0, v1)} \\\\ y = ${_param(y0, v2)} \\end{array}\\right.',
        pedagogicalNote: 'Igualamos coordenada a coordenada de la ecuación vectorial.',
      ),
      MathStep(
        index: 4,
        shortTitle: 'Ecuación continua',
        latexExpression: vertical
            ? 'x = ${_r(x0)}'
            : (v2.isZero
                ? 'y = ${_r(y0)}'
                : '\\frac{${_shift('x', x0)}}{${_r(v1)}} = \\frac{${_shift('y', y0)}}{${_r(v2)}}'),
        pedagogicalNote: vertical || v2.isZero
            ? 'Una componente del vector director es 0: no se puede dividir entre 0, y la recta es ${vertical ? 'vertical' : 'horizontal'}.'
            : 'Despejamos t en las paramétricas e igualamos.',
        warningTrick: vertical || v2.isZero ? 'Con una componente nula no existe la forma continua con denominador 0.' : null,
      ),
      MathStep(
        index: 5,
        shortTitle: 'Ecuación punto-pendiente',
        latexExpression: m == null ? 'x = ${_r(x0)}' : 'y - ${_p(y0)} = ${_r(m)}\\,\\left(${_shift('x', x0)}\\right)',
        pedagogicalNote: m == null
            ? 'La recta vertical no tiene pendiente.'
            : 'La pendiente es m = v2 / v1 = ${_r(m)}.',
      ),
      MathStep(
        index: 6,
        shortTitle: 'Ecuación explícita',
        latexExpression: m == null
            ? 'x = ${_r(x0)}'
            : 'y = ${m.isZero ? '' : '${_r(m)}x'}${n!.isZero ? (m.isZero ? '0' : '') : '${m.isZero || n.isNegative ? '' : ' + '}${n.isNegative ? ' - ${_r(n.abs())}' : _r(n)}'}',
        pedagogicalNote: m == null ? 'No se puede despejar y.' : 'Despejamos y: n = y0 - m·x0 = ${_r(n!)}.',
      ),
      MathStep(
        index: 7,
        shortTitle: 'Ecuación general',
        latexExpression: _general(ia, ib, ic),
        pedagogicalNote: 'A = v2, B = -v1 y C = -(A·x0 + B·y0), con coeficientes enteros sin divisores comunes.',
      ),
    ];
    final res = StepByStepResolution(
      originalInputLatex: intro,
      steps: steps,
      exactResultLatex: _general(ia, ib, ic),
      decimalApproxLatex: m == null ? '' : 'm = ${_r(m)}',
    );
    return LineEquationsResult(x0, y0, v1, v2, m, n, ia, ib, ic, res);
  }
}
