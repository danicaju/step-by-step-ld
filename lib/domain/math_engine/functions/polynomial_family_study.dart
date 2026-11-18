import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/equations/eq_poly.dart';
import 'function_family.dart';

/// Estudio de pizarra de las funciones polinomicas: constante, afin, parabola y cubica.
class PolynomialFamilyStudy {
  const PolynomialFamilyStudy._();

  static String _pt(String x, String y) => '\\left($x,\\,$y\\right)';
  static double _ev(Poly p, double x) =>
      p.entries.fold(0.0, (s, e) => s + e.value.toDouble() * _pow(x, e.key));
  static double _pow(double x, int k) {
    var r = 1.0;
    for (var i = 0; i < k; i++) {
      r *= x;
    }
    return r;
  }

  static List<MathStep> study(FunctionFamily fam, Poly p) => switch (fam) {
        FunctionFamily.constant => _constant(PolyOps.coeff(p, 0)),
        FunctionFamily.linear => _linear(PolyOps.coeff(p, 1), PolyOps.coeff(p, 0)),
        FunctionFamily.quadratic => _quadratic(p),
        _ => _cubic(p),
      };

  static List<MathStep> _constant(Rational k) => [
        fstep('Tipo de función', 'f(x) = ${rl(k)}',
            'Es una función constante: a todo x le corresponde el mismo valor k = ${rl(k)}. Su gráfica es una recta horizontal.'),
        fstep('Dominio e imagen', '\\text{Dom}(f) = \\mathbb{R},\\quad \\text{Im}(f) = \\left\\{${rl(k)}\\right\\}',
            'Se puede evaluar en cualquier x, pero solo se obtiene un valor.'),
        fstep('Pendiente y monotonía', 'm = 0', 'Pendiente 0: la función no crece ni decrece, es constante.'),
        fstep('Corte con el eje OY', 'f(0) = ${rl(k)} \\implies ${_pt('0', rl(k))}',
            'El corte con OY se obtiene evaluando en x = 0.'),
        k.isZero
            ? fstep('Cortes con el eje OX', 'f(x) = 0 \\;\\forall x',
                'Con k = 0 la gráfica coincide con el propio eje OX: todos sus puntos son cortes.')
            : fstep('Cortes con el eje OX', '${rl(k)} \\neq 0 \\implies \\text{sin cortes}',
                'Una recta horizontal distinta del eje OX nunca lo corta.'),
      ];

  static List<MathStep> _linear(Rational m, Rational n) {
    final up = m.isPositive;
    final sign = n.isNegative ? '-' : '+';
    return [
      fstep('Tipo de función', 'f(x) = ${rl(m)}x $sign ${rl(n.abs())}',
          'Función afín f(x) = mx + n: su gráfica es una recta.'),
      fstep('Pendiente y ordenada', 'm = ${rl(m)},\\quad n = ${rl(n)}',
          'La pendiente m mide cuánto sube la recta por cada unidad en x; n es el valor en x = 0.'),
      fstep(
          'Monotonía',
          up ? 'm > 0 \\implies \\text{creciente}' : 'm < 0 \\implies \\text{decreciente}',
          up
              ? 'Pendiente positiva: la recta sube de izquierda a derecha.'
              : 'Pendiente negativa: la recta baja de izquierda a derecha.'),
      fstep('Dominio e imagen', '\\text{Dom}(f) = \\mathbb{R},\\quad \\text{Im}(f) = \\mathbb{R}',
          'Una recta no horizontal recorre todos los valores de y.'),
      fstep('Corte con el eje OY', 'f(0) = ${rl(n)} \\implies ${_pt('0', rl(n))}',
          'Evaluamos en x = 0: el corte es la ordenada en el origen n.'),
      fstep(
          'Corte con el eje OX',
          '${rl(m)}x $sign ${rl(n.abs())} = 0 \\implies x = ${rl(-n / m)} \\implies ${_pt(rl(-n / m), '0')}',
          'Resolvemos f(x) = 0, es decir x = -n/m.'),
    ];
  }

  static List<MathStep> _quadratic(Poly p) {
    final a = PolyOps.coeff(p, 2), b = PolyOps.coeff(p, 1), c = PolyOps.coeff(p, 0);
    final xv = -b / (Rational(2) * a);
    final yv = PolyOps.eval(p, xv);
    final up = a.isPositive;
    final disc = b * b - Rational(4) * a * c;
    final roots = PolyRoots.quadratic(a, b, c);
    final String rootsTex;
    if (roots.isEmpty) {
      rootsTex = '\\Delta < 0 \\implies \\text{sin cortes con OX}';
    } else if (roots.length == 1) {
      rootsTex = '\\Delta = 0 \\implies x = ${roots[0].toLatex()} \\implies ${_pt(roots[0].toLatex(), '0')}';
    } else {
      rootsTex =
          'x = \\frac{-b \\pm \\sqrt{\\Delta}}{2a} \\implies x_{1} = ${roots[0].toLatex()},\\; x_{2} = ${roots[1].toLatex()}';
    }
    return [
      fstep('Tipo de función', 'f(x) = ${PolyOps.latex(p)}',
          'Es una función cuadrática: su gráfica es una parábola. Dominio R.'),
      fstep('Coeficientes y concavidad', 'a = ${rl(a)},\\quad b = ${rl(b)},\\quad c = ${rl(c)}',
          up ? 'a > 0: las ramas van hacia arriba y el vértice es un mínimo.' : 'a < 0: las ramas van hacia abajo y el vértice es un máximo.'),
      fstep(
          'Vértice',
          'x_{v} = -\\frac{b}{2a} = ${rl(xv)},\\quad y_{v} = f(${rl(xv)}) = ${rl(yv)} \\implies \\text{Vertice}${_pt(rl(xv), rl(yv))}',
          'La abscisa del vértice es -b/(2a); la ordenada se obtiene sustituyendo en f.'),
      fstep('Eje de simetría', 'x = ${rl(xv)}',
          'La parábola es simétrica respecto de la recta vertical que pasa por el vértice.'),
      fstep(
          'Imagen y monotonía',
          up
              ? '\\text{Im}(f) = \\left[${rl(yv)},\\,+\\infty\\right)'
              : '\\text{Im}(f) = \\left(-\\infty,\\,${rl(yv)}\\right]',
          up ? 'Decrece hasta el vértice y crece después.' : 'Crece hasta el vértice y decrece después.'),
      fstep('Corte con el eje OY', 'f(0) = ${rl(c)} \\implies ${_pt('0', rl(c))}',
          'El corte con OY es el término independiente c.'),
      fstep('Cortes con el eje OX', '\\Delta = b^{2} - 4ac = ${rl(disc)};\\quad $rootsTex',
          'El discriminante decide: Δ>0 dos cortes, Δ=0 uno (el vértice) y Δ<0 ninguno.'),
    ];
  }

  static List<MathStep> _cubic(Poly p) {
    final a = PolyOps.coeff(p, 3), b = PolyOps.coeff(p, 2), c = PolyOps.coeff(p, 1), d = PolyOps.coeff(p, 0);
    final up = a.isPositive;
    final roots = PolyRoots.real(p);
    final steps = <MathStep>[
      fstep('Tipo de función', 'f(x) = ${PolyOps.latex(p)}', 'Es una función cúbica (polinomio de grado 3). Dominio R.'),
      fstep(
          'Ramas en el infinito',
          up
              ? '\\lim_{x \\to -\\infty} f = -\\infty,\\quad \\lim_{x \\to +\\infty} f = +\\infty'
              : '\\lim_{x \\to -\\infty} f = +\\infty,\\quad \\lim_{x \\to +\\infty} f = -\\infty',
          'Con grado impar las ramas van en sentidos opuestos; el signo de a (${rl(a)}) decide cuál sube. Por eso Im(f) = R.'),
      fstep('Corte con el eje OY', 'f(0) = ${rl(d)} \\implies ${_pt('0', rl(d))}',
          'El corte con OY es el término independiente d.'),
    ];
    final rr = PolyRoots.rationalRoot(PolyOps.toIntegers(p));
    if (rr != null) {
      final q = PolyOps.deflate(p, rr);
      steps.add(fstep(
          'Ruffini',
          'f(${rl(rr)}) = 0 \\implies f(x) = ${rr.isZero ? 'x' : '(x ${rr.isNegative ? '+' : '-'} ${rl(rr.abs())})'}\\left(${PolyOps.latex(q)}\\right)',
          'Probamos divisores del término independiente con Ruffini: ${rl(rr)} es raíz y queda un cociente de grado 2.'));
    }
    steps.add(fstep(
      'Cortes con el eje OX',
      roots.isEmpty ? '\\text{sin cortes}' : [for (final r in roots) _pt(r.toLatex(), '0')].join(',\\; '),
      'Las raíces reales de f(x) = 0 son las abscisas de los cortes.',
    ));
    // Extremos relativos: f'(x) = 3a x^2 + 2b x + c.
    final dpoly = <int, Rational>{2: Rational(3) * a, 1: Rational(2) * b, 0: c};
    final ex = PolyRoots.quadratic(Rational(3) * a, Rational(2) * b, c);
    final exTex = <String>[];
    for (final r in ex) {
      final x0 = r.approx;
      final second = 6 * a.toDouble() * x0 + 2 * b.toDouble();
      final label = second < -1e-9 ? '\\text{max}' : (second > 1e-9 ? '\\text{min}' : '');
      exTex.add('$label${_pt(r.toLatex(), fapx(_ev(p, x0)))}');
    }
    steps.add(fstep(
      'Extremos relativos',
      "f'(x) = ${PolyOps.latex(dpoly)} = 0 \\implies ${ex.isEmpty ? '\\text{sin extremos}' : exTex.join(',\\;')}",
      ex.isEmpty
          ? 'La derivada no se anula: la cúbica es siempre estrictamente monótona, sin máximos ni mínimos.'
          : "Los extremos relativos están donde f'(x) = 0; el signo de f''(x) = 6ax + 2b decide si es máximo o mínimo.",
    ));
    final xi = -b / (Rational(3) * a);
    steps.add(fstep(
        'Punto de inflexión',
        "f''(x) = 6ax + 2b = 0 \\implies x_{i} = ${rl(xi)},\\; ${_pt(rl(xi), rl(PolyOps.eval(p, xi)))}",
        'La cúbica cambia de curvatura en x = -b/(3a): es su centro de simetría.'));
    return steps;
  }
}
