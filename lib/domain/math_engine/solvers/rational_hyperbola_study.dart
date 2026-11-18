import '../core/rational.dart';
import '../models/step_resolution.dart';

/// Estudio paso a paso de f(x) = (p x + q) / (r x + s) como se explica en clase:
/// dominio, asintota vertical (limites laterales), asintota horizontal y cortes con los ejes.
///
/// El texto con tildes va en `shortTitle`/`pedagogicalNote`; dentro de `\text{}` solo ASCII.
class RationalHyperbolaStudy {
  const RationalHyperbolaStudy._();

  /// `true` si (p x + q)/(r x + s) es una hiperbola (r != 0 y p s - q r != 0).
  static bool isHyperbola(int p, int q, int r, int s) => r != 0 && p * s - q * r != 0;

  /// Centro de simetria: (x_AV, y_AH) = (-s/r, p/r).
  static (Rational, Rational) center(int p, int r, int s) => (Rational(-s, r), Rational(p, r));

  static String _lin(int a, int b) {
    final x = a == 1 ? 'x' : (a == -1 ? '-x' : '${a}x');
    if (a == 0) return '$b';
    if (b == 0) return x;
    return b > 0 ? '$x + $b' : '$x - ${-b}';
  }

  static String _inf(int sign) => sign >= 0 ? r'+\infty' : r'-\infty';

  static StepByStepResolution analyze(int p, int q, int r, int s) {
    final (a, h) = center(p, r, s);
    final aTex = a.toLatex();
    final hTex = h.toLatex();
    final num = _lin(p, q);
    final den = _lin(r, s);
    final fx = '\\frac{$num}{$den}';
    final numAtA = p * (-s) + q * r; // (p a + q) * r, mismo signo que N(a)*r
    // Signo de f cerca de a: N(a) * (r (x - a))^-1  ->  x -> a-: -sign(N(a) r)... con N(a) r = numAtA
    final signLeft = numAtA > 0 ? -1 : 1;
    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: '1. Dominio: el denominador no puede ser 0',
        latexExpression: '$den = 0 \\;\\Rightarrow\\; x = $aTex \\qquad \\text{Dom}(f) = \\mathbb{R}\\setminus\\left\\{$aTex\\right\\}',
        pedagogicalNote:
            'El dominio de una función racional son todos los números reales salvo los que anulan el denominador. Igualamos rx + s a 0 y despejamos x.',
        warningTrick: 'Nunca evalúes f en el valor que anula el denominador: ahí no está definida.',
      ),
      MathStep(
        index: 2,
        shortTitle: '2. Asíntota vertical con límites laterales',
        latexExpression: '\\text{AV}: x = $aTex \\qquad '
            '\\lim_{x \\to $aTex^{-}} f(x) = ${_inf(signLeft)} \\quad '
            '\\lim_{x \\to $aTex^{+}} f(x) = ${_inf(-signLeft)}',
        pedagogicalNote:
            'En x = $aTex el denominador vale 0 y el numerador no, así que f se dispara a infinito. El signo de cada límite lateral sale de estudiar el signo de numerador y denominador a la izquierda y a la derecha.',
      ),
      MathStep(
        index: 3,
        shortTitle: '3. Asíntota horizontal con el límite en el infinito',
        latexExpression: '\\lim_{x \\to \\pm\\infty} $fx = \\frac{$p}{$r} = $hTex \\qquad \\text{AH}: y = $hTex',
        pedagogicalNote:
            'Cuando x tiende a más o menos infinito mandan los términos de mayor grado: f(x) se parece a p·x / r·x = p/r. Por eso la recta y = p/r es la asíntota horizontal.',
      ),
      MathStep(
        index: 4,
        shortTitle: '4. Cortes con los ejes',
        latexExpression: '\\text{OX}\\ (y=0):\\ ${p == 0 ? r'\text{ninguno}' : '$num = 0 \\Rightarrow x = ${Rational(-q, p).toLatex()},\\ \\left(${Rational(-q, p).toLatex()},\\,0\\right)'}'
            ' \\qquad \\text{OY}\\ (x=0):\\ ${s == 0 ? r'\text{ninguno}' : 'f(0) = \\frac{$q}{$s} = ${Rational(q, s).toLatex()},\\ \\left(0,\\,${Rational(q, s).toLatex()}\\right)'}',
        pedagogicalNote:
            'Corte con OX: hacemos y = 0, es decir, el numerador igual a 0. Corte con OY: hacemos x = 0 y calculamos f(0), siempre que 0 esté en el dominio.',
      ),
    ];
    return StepByStepResolution(
      originalInputLatex: 'f(x) = $fx',
      steps: steps,
      exactResultLatex: '\\text{AV}: x = $aTex,\\; \\text{AH}: y = $hTex',
      decimalApproxLatex: '',
    );
  }
}
