import '../core/number_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/calculus/sym_latex.dart';
import '../solvers/exact/ext_expr.dart';
import 'non_elementary_integral_handler.dart';

/// Ultimo recurso para integrales definidas: cuando ninguna tecnica simbolica halla
/// la primitiva, se integra con Simpson adaptativo (error < 1e-9) sobre cualquiera
/// de las 8 familias. Lanza `ExMathError` si el integrando es impropio en [a, b].
class GenericQuadratureIntegral {
  const GenericQuadratureIntegral._();

  static StepByStepResolution definite(XNode f, Rational a, Rational b) {
    final v = NonElementaryIntegralHandler.numericValue(f, a.toDouble(), b.toDouble());
    final aL = a.toLatex();
    final bL = b.toLatex();
    final fx = SymLatex.tex(f);
    final integral = '\\int_{$aL}^{$bL} $fx\\,dx';
    final val = NumberFormatter.decimal(v);
    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: '1. Identificar el integrando',
        latexExpression: 'f(x) = $fx',
        pedagogicalNote: 'Buscamos una primitiva F(x) con tabla, sustitución y partes, pero no se obtiene una expresión elemental manejable.',
      ),
      MathStep(
        index: 2,
        shortTitle: '2. Cuadratura adaptativa de Simpson',
        latexExpression:
            '\\int_{l}^{r} f\\,dx \\approx \\frac{r - l}{6}\\left[f(l) + 4f\\left(\\frac{l + r}{2}\\right) + f(r)\\right]',
        pedagogicalNote:
            'Sin F(x) no se puede aplicar Barrow. En cada subintervalo [l, r] aproximamos f(x) por una parábola (regla de Simpson) y subdividimos solo donde hace falta hasta un error menor que 10⁻⁹.',
      ),
      MathStep(
        index: 3,
        shortTitle: '3. Resultado numérico',
        latexExpression: '$integral \\approx $val',
        pedagogicalNote: 'Valor aproximado con 6 decimales.',
        warningTrick: 'Es un valor aproximado: no hay resultado exacto con funciones elementales.',
      ),
    ];
    return StepByStepResolution(
      originalInputLatex: integral,
      steps: steps,
      exactResultLatex: val,
      decimalApproxLatex: val,
    );
  }
}
