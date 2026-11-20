import '../arithmetic/casio_iberia_arsenal.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'line_equations_steps.dart';
import 'line_term_format.dart';

/// Punto marcado en la grafica de la recta (A, B o P).
class LinePoint {
  final String label;
  final Rational x, y;
  const LinePoint(this.label, this.x, this.y);
}

/// Las 6 ecuaciones de la recta en el plano (coeficientes exactos).
class LineEquationsResult {
  final Rational x0, y0, v1, v2;
  final Rational? slope; // null si es vertical
  final Rational? intercept;
  final int a, b, c; // forma general Ax + By + C = 0
  final StepByStepResolution resolution;
  final List<LinePoint> points;

  const LineEquationsResult(
    this.x0,
    this.y0,
    this.v1,
    this.v2,
    this.slope,
    this.intercept,
    this.a,
    this.b,
    this.c,
    this.resolution, {
    this.points = const [],
  });

  bool get isVertical => v1.isZero;
  bool get isHorizontal => v2.isZero;
}

/// Resuelve la recta desde cualquiera de sus 6 formas de entrada.
class LineEquationsSolver {
  const LineEquationsSolver._();

  static String _r(Rational r) => LineTex.r(r);
  static String _p(Rational r) => LineTex.p(r);

  /// Desde dos puntos A y B.
  static LineEquationsResult fromPoints(Rational x1, Rational y1, Rational x2, Rational y2) {
    if (x1 == x2 && y1 == y2) throw const ArsenalException('Math ERROR: A y B son el mismo punto.');
    final dx = x2 - x1, dy = y2 - y1;
    return _solve(
      x1,
      y1,
      dx,
      dy,
      intro: [
        'A(${_r(x1)},\\; ${_r(y1)}),\\quad B(${_r(x2)},\\; ${_r(y2)})',
        '\\vec{v} = \\overrightarrow{AB} = (x_{2} - x_{1},\\; y_{2} - y_{1}) = (${_r(x2)} - ${_p(x1)},\\; ${_r(y2)} - ${_p(y1)}) = (${_r(dx)},\\; ${_r(dy)})',
      ],
      introNote: 'El vector director es AB = B - A; usamos A como punto de la recta.',
      points: [LinePoint('A', x1, y1), LinePoint('B', x2, y2)],
    );
  }

  /// Desde un punto y un vector director.
  static LineEquationsResult fromPointVector(Rational x0, Rational y0, Rational v1, Rational v2) {
    if (v1.isZero && v2.isZero) throw const ArsenalException('Math ERROR: El vector director no puede ser (0, 0).');
    return _solve(
      x0,
      y0,
      v1,
      v2,
      intro: ['P(${_r(x0)},\\; ${_r(y0)}),\\quad \\vec{v} = (${_r(v1)},\\; ${_r(v2)})'],
      introNote: 'Datos: un punto de la recta y su vector director.',
      points: [LinePoint('P', x0, y0)],
    );
  }

  /// Desde un punto y la pendiente m (vector director (1, m)).
  static LineEquationsResult fromPointSlope(Rational x0, Rational y0, Rational m) => _solve(
        x0,
        y0,
        Rational(1),
        m,
        intro: [
          'P(${_r(x0)},\\; ${_r(y0)}),\\quad m = ${_r(m)}',
          '\\vec{v} = (1,\\; m) = (1,\\; ${_r(m)})',
        ],
        introNote: 'Con pendiente m, un vector director es (1, m).',
        points: [LinePoint('P', x0, y0)],
      );

  /// Desde la explicita `y = mx + n`: punto (0, n) y vector (1, m).
  static LineEquationsResult fromExplicit(Rational m, Rational n) => _solve(
        Rational(0),
        n,
        Rational(1),
        m,
        intro: [
          'y = ${LineTex.linear([(m, 'x'), (n, '')])}',
          'P(0,\\; ${_r(n)}),\\quad \\vec{v} = (1,\\; m) = (1,\\; ${_r(m)})',
        ],
        introNote: 'Con x = 0 sale el punto (0, n); la pendiente m da el vector director (1, m).',
        points: [LinePoint('P', Rational(0), n)],
      );

  /// Desde la general `Ax + By + C = 0`: v = (-B, A) y un punto sobre un eje.
  static LineEquationsResult fromGeneral(Rational a, Rational b, Rational c) {
    if (a.isZero && b.isZero) throw const ArsenalException('Math ERROR: A y B no pueden ser 0 a la vez.');
    final Rational px, py;
    final String pointTex;
    if (b.isZero) {
      px = -c / a;
      py = Rational(0);
      pointTex = 'B = 0 \\Rightarrow x = -\\frac{C}{A} = ${_r(px)}:\\; P(${_r(px)},\\; 0)';
    } else {
      px = Rational(0);
      py = -c / b;
      pointTex = 'x = 0 \\Rightarrow y = -\\frac{C}{B} = ${_r(py)}:\\; P(0,\\; ${_r(py)})';
    }
    return _solve(
      px,
      py,
      -b,
      a,
      intro: [
        '${LineTex.general(a, b, c)},\\quad \\vec{n} = (A,\\; B) = (${_r(a)},\\; ${_r(b)})',
        '\\vec{v} = (-B,\\; A) = (${_r(-b)},\\; ${_r(a)}),\\quad $pointTex',
      ],
      introNote: 'El vector normal es (A, B); un vector director es perpendicular: (-B, A).',
      points: [LinePoint('P', px, py)],
    );
  }

  /// Desde la continua `(x - x0)/v1 = (y - y0)/v2` (los denominadores no pueden ser 0).
  static LineEquationsResult fromContinuous(Rational x0, Rational v1, Rational y0, Rational v2) {
    if (v1.isZero || v2.isZero) {
      throw const ArsenalException('Math ERROR: Un denominador de la continua no puede ser 0.');
    }
    return _solve(
      x0,
      y0,
      v1,
      v2,
      intro: [
        '\\frac{${LineTex.shift('x', x0)}}{${_r(v1)}} = \\frac{${LineTex.shift('y', y0)}}{${_r(v2)}}',
        'P(${_r(x0)},\\; ${_r(y0)}),\\quad \\vec{v} = (${_r(v1)},\\; ${_r(v2)})',
      ],
      introNote: 'En la continua, los numeradores dan el punto y los denominadores el vector director.',
      points: [LinePoint('P', x0, y0)],
    );
  }

  static LineEquationsResult _solve(
    Rational x0,
    Rational y0,
    Rational v1,
    Rational v2, {
    required List<String> intro,
    required String introNote,
    required List<LinePoint> points,
  }) {
    final m = v1.isZero ? null : v2 / v1;
    final n = m == null ? null : y0 - m * x0;
    final gen = LineGeneralForm.of(x0, y0, v1, v2);
    final steps = LineSteps.build(x0, y0, v1, v2, gen, intro: intro, introNote: introNote);
    final res = StepByStepResolution(
      originalInputLatex: intro.first,
      steps: steps,
      exactResultLatex: gen.latex,
      decimalApproxLatex: m == null ? '' : 'm = ${_r(m)}',
    );
    return LineEquationsResult(x0, y0, v1, v2, m, n, gen.a, gen.b, gen.c, res, points: points);
  }
}
