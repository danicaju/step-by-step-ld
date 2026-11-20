import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'line_term_format.dart';

/// Forma general con enteros coprimos y primer coeficiente positivo.
class LineGeneralForm {
  final int a, b, c;
  const LineGeneralForm(this.a, this.b, this.c);

  factory LineGeneralForm.of(Rational x0, Rational y0, Rational v1, Rational v2) {
    final ra = v2, rb = -v1;
    final rc = -(ra * x0 + rb * y0);
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
    return LineGeneralForm(ia, ib, ic);
  }

  String get latex => LineTex.general(Rational(a), Rational(b), Rational(c));
}

/// Pasos "como en clase" de las 6 ecuaciones de la recta (punto P y vector director v).
abstract final class LineSteps {
  static String _arr(List<String> rows) => '\\begin{array}{l} ${rows.join(' \\\\ ')} \\end{array}';

  static List<MathStep> build(
    Rational x0,
    Rational y0,
    Rational v1,
    Rational v2,
    LineGeneralForm gen, {
    required List<String> intro,
    required String introNote,
  }) {
    final r = LineTex.r, p = LineTex.p;
    final vertical = v1.isZero, horizontal = v2.isZero;
    final m = vertical ? null : v2 / v1;
    final n = m == null ? null : y0 - m * x0;
    final steps = <MathStep>[];
    void add(String title, String latex, String note, {String? trick}) => steps.add(MathStep(
          index: steps.length + 1,
          shortTitle: title,
          latexExpression: latex,
          pedagogicalNote: note,
          warningTrick: trick,
        ));

    // Paso 1: punto, vector director y pendiente.
    final slope = vertical
        ? 'v_{x} = 0 \\;\\Rightarrow\\; \\text{recta vertical, sin pendiente}'
        : (horizontal
            ? 'm = \\frac{v_{y}}{v_{x}} = \\frac{0}{${r(v1)}} = 0 \\;\\Rightarrow\\; \\text{recta horizontal}'
            : 'm = \\frac{v_{y}}{v_{x}} = \\frac{${r(v2)}}{${r(v1)}} = ${r(m!)}');
    add('Punto y vector director', _arr([...intro, slope]), introNote);

    add(
      'Ecuación vectorial',
      '(x,\\; y) = (${r(x0)},\\; ${r(y0)}) + t\\,(${r(v1)},\\; ${r(v2)}),\\quad t \\in \\mathbb{R}',
      'Un punto de la recta más un múltiplo t del vector director recorre toda la recta.',
    );
    add(
      'Ecuaciones paramétricas',
      '\\left\\{\\begin{array}{l} x = ${LineTex.linear([(x0, ''), (v1, 't')])} \\\\ y = ${LineTex.linear([(y0, ''), (v2, 't')])} \\end{array}\\right.',
      'Igualamos coordenada a coordenada de la ecuación vectorial.',
    );
    add(
      'Ecuación continua',
      vertical
          ? 'x = ${r(x0)}'
          : (horizontal
              ? 'y = ${r(y0)}'
              : '\\frac{${LineTex.shift('x', x0)}}{${r(v1)}} = \\frac{${LineTex.shift('y', y0)}}{${r(v2)}}'),
      vertical || horizontal
          ? 'Una componente del vector director es 0: no se puede dividir entre 0 y la recta es ${vertical ? 'vertical' : 'horizontal'}.'
          : 'Despejamos t en las paramétricas e igualamos los dos resultados.',
      trick: vertical || horizontal ? 'Con una componente nula no existe la forma continua estándar.' : null,
    );
    final lhs = y0.isZero ? 'y' : LineTex.shift('y', y0);
    add(
      'Ecuación punto-pendiente',
      m == null ? 'x = ${r(x0)}' : '$lhs = ${LineTex.slopeTimes(m, x0)}',
      m == null ? 'La recta vertical no tiene pendiente.' : 'Con la pendiente m y un punto: y - y0 = m (x - x0).',
    );
    add(
      'Ecuación explícita',
      m == null
          ? 'x = ${r(x0)}'
          : _arr([
              'n = y_{0} - m\\,x_{0} = ${r(y0)} - ${p(m)}\\cdot ${p(x0)} = ${r(n!)}',
              LineTex.explicit(m, n),
            ]),
      m == null
          ? 'Una recta vertical no se puede escribir como y = mx + n.'
          : 'Despejamos y; la ordenada en el origen es n = y0 - m·x0.',
      trick: m == null ? 'Su ecuación es x = constante.' : null,
    );
    final rawA = v2, rawB = -v1, rawC = -(v2 * x0 + (-v1) * y0);
    final raw = LineTex.general(rawA, rawB, rawC);
    add(
      'Ecuación general',
      _arr([
        'A = v_{y} = ${r(rawA)},\\quad B = -v_{x} = ${r(rawB)},\\quad C = -(A x_{0} + B y_{0}) = ${r(rawC)}',
        if (raw != gen.latex) '$raw \\;\\Rightarrow\\; ${gen.latex}' else gen.latex,
        '\\vec{n} = (A,\\; B) = (${gen.a},\\; ${gen.b})',
      ]),
      'Pasamos todo a un lado con coeficientes enteros sin divisores comunes y A ≥ 0. El vector normal (A, B) es perpendicular a la recta.',
    );
    add(
      'Resumen y gráfica',
      m == null ? 'x = ${r(x0)} \\;\\Leftrightarrow\\; ${gen.latex}' : '${LineTex.explicit(m, n!)} \\;\\Leftrightarrow\\; ${gen.latex}',
      'La gráfica muestra la recta, los puntos conocidos y el vector director v.',
    );
    return steps;
  }
}
