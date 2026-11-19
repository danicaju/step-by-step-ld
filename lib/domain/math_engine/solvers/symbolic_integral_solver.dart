import '../calculus/non_elementary_integral_handler.dart';
import '../calculus/universal_rational_integrator.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'calculus/calculus_step_texts.dart';
import 'calculus/sym_build.dart';
import 'calculus/sym_integrator.dart';
import 'calculus/sym_latex.dart';
import 'exact/exact_number.dart';
import 'exact/ext_expr.dart';
import 'exact/ext_parser.dart';

/// Integrales simbolicas: indefinida `\int f(x)dx` y definida (regla de Barrow)
/// con linealidad, tabla de inmediatas, sustitucion y partes.
class SymbolicIntegralSolver {
  const SymbolicIntegralSolver._();

  static String _t(XNode n) => SymLatex.tex(n);

  static XNode parse(String raw) => ExtParser().parse(raw);

  /// Primitiva F(x) y pasos intermedios; lanza [ExtUnsupported] si no se sabe integrar.
  static ({XNode antiderivative, List<MathStep> steps}) antiderivative(XNode f) {
    final steps = <MathStep>[];
    void log(String title, String latex, String note) {
      steps.add(MathStep(
        index: steps.length + 1,
        shortTitle: title,
        latexExpression: latex,
        pedagogicalNote: note,
      ));
    }

    final isSum = f is XBin && (f.op == '+' || f.op == '-');
    final big = SymIntegrator(log: log).integrate(f);
    if (big == null) {
      throw const ExtUnsupported('No se ha podido integrar esta función con los métodos del curso');
    }
    if (!_verify(f, big)) {
      throw const ExtUnsupported('No se ha podido verificar la primitiva');
    }
    if (isSum) {
      steps.insert(
        0,
        MathStep(
          index: 1,
          shortTitle: 'Linealidad de la integral',
          latexExpression:
              '\\int \\left(${_t(f)}\\right)dx = \\sum \\int \\text{(cada termino)}\\,dx',
          pedagogicalNote:
              'La integral de una suma es la suma de las integrales y las constantes salen fuera: ∫(a·f + b·g)dx = a∫f dx + b∫g dx.',
        ),
      );
    }
    return (antiderivative: big, steps: steps);
  }

  /// Comprueba numericamente que F'(x) = f(x) en varios puntos.
  static bool _verify(XNode f, XNode big) {
    var good = 0;
    for (final x in const [0.31, 0.77, 1.3, 2.1, 3.4, -0.6, -1.7]) {
      final fv = Sx.numAt(f, x);
      const h = 1e-5;
      final a = Sx.numAt(big, x + h);
      final b = Sx.numAt(big, x - h);
      if (fv == null || a == null || b == null) continue;
      final d = (a - b) / (2 * h);
      if ((d - fv).abs() > 1e-4 * (1 + fv.abs())) return false;
      good++;
    }
    return good >= 2;
  }

  static StepByStepResolution indefinite(String raw) {
    final f = parse(raw);
    final ({XNode antiderivative, List<MathStep> steps}) r;
    try {
      r = antiderivative(f);
    } on ExtUnsupported {
      // Racionales generales y familias sin primitiva elemental.
      final alt = UniversalRationalIntegrator.indefinite(f) ?? NonElementaryIntegralHandler.indefinite(f);
      if (alt != null) return alt;
      rethrow;
    }
    final steps = <MathStep>[
      CalculusStepTexts.prepare(f),
      CalculusStepTexts.method(f, r.steps),
      for (final s in r.steps)
        MathStep(
          index: 0,
          shortTitle: s.shortTitle,
          latexExpression: s.latexExpression,
          pedagogicalNote: s.pedagogicalNote,
        ),
      MathStep(
        index: 0,
        shortTitle: '3. Cálculo de la primitiva F(x)',
        latexExpression: 'F(x) = ${_t(r.antiderivative)}',
        pedagogicalNote: 'Esta es una primitiva de f(x), antes de añadir la constante. Comprobación: derivando F(x) debe salir f(x).',
      ),
      MathStep(
        index: 0,
        shortTitle: '4. Cierre: constante de integración + C',
        latexExpression: '\\int ${_t(f)}\\,dx = ${_t(r.antiderivative)} + C',
        pedagogicalNote:
            'La derivada de una constante es 0, así que si F(x) es una primitiva, F(x) + C también lo es para cualquier C. Por eso la integral indefinida es una familia de funciones.',
        warningTrick: 'Una integral indefinida sin + C es una respuesta incompleta.',
      ),
    ];
    final res = '${_t(r.antiderivative)} + C';
    return StepByStepResolution(
      originalInputLatex: '\\int ${_t(f)}\\,dx',
      steps: _reindex(steps),
      exactResultLatex: res,
      decimalApproxLatex: res,
    );
  }

  static List<MathStep> _reindex(List<MathStep> s) => [
        for (var i = 0; i < s.length; i++)
          MathStep(
            index: i + 1,
            shortTitle: s[i].shortTitle,
            latexExpression: s[i].latexExpression,
            pedagogicalNote: s[i].pedagogicalNote,
            warningTrick: s[i].warningTrick,
          ),
      ];

  static StepByStepResolution definite(String raw, Rational a, Rational b) {
    final f = parse(raw);
    final ({XNode antiderivative, List<MathStep> steps}) r;
    try {
      r = antiderivative(f);
    } on ExtUnsupported {
      final alt = UniversalRationalIntegrator.definite(f, a, b) ?? NonElementaryIntegralHandler.definite(f, a, b);
      if (alt != null) return alt;
      rethrow;
    }
    final big = r.antiderivative;
    // Integrando no acotado en [a, b] -> integral impropia.
    final lo = a.toDouble() < b.toDouble() ? a.toDouble() : b.toDouble();
    final hi = a.toDouble() < b.toDouble() ? b.toDouble() : a.toDouble();
    for (var i = 0; i <= 40; i++) {
      final x = lo + (hi - lo) * i / 40;
      if (Sx.numAt(f, x) == null) {
        throw const ExMathError('Integral impropia: la función no está definida en todo [a, b]');
      }
    }
    final fb = Sx.evalAt(big, ExNum.rational(b));
    final fa = Sx.evalAt(big, ExNum.rational(a));
    if (fb == null || fa == null) throw const ExMathError();
    final total = fb - fa;
    final aL = a.toLatex();
    final bL = b.toLatex();
    final subB = Sx.subst(big, (n) => n is XVar, XNum(b));
    final subA = Sx.subst(big, (n) => n is XVar, XNum(a));
    final symB = Sx.rebuild(subB);
    final symA = Sx.rebuild(subA);
    final symTotal = Sx.collectSum(Sx.rebuild(Sx.sub(subB, subA)));
    final totalLatex = total.isExact ? total.toLatex() : _t(symTotal);
    final steps = <MathStep>[
      CalculusStepTexts.prepare(f),
      CalculusStepTexts.method(f, r.steps),
      for (final s in r.steps)
        MathStep(
          index: 0,
          shortTitle: s.shortTitle,
          latexExpression: s.latexExpression,
          pedagogicalNote: s.pedagogicalNote,
        ),
      MathStep(
        index: 0,
        shortTitle: '3. Cálculo de la primitiva F(x)',
        latexExpression: 'F(x) = \\int ${_t(f)}\\,dx = ${_t(big)}',
        pedagogicalNote:
            'Calculamos una primitiva de f(x) sin la constante: en una integral definida la C se cancela al restar.',
      ),
      MathStep(
        index: 0,
        shortTitle: '4. Regla de Barrow: [F(x)] entre a y b',
        latexExpression:
            '\\left[F(x)\\right]_{$aL}^{$bL} = F($bL) - F($aL) = \\left(${_t(subB)}\\right) - \\left(${_t(subA)}\\right)',
        pedagogicalNote:
            '∫ₐᵇ f(x)dx = F(b) - F(a): sustituimos primero el límite superior y restamos la sustitución del límite inferior.',
        warningTrick: 'Pon F(a) entre paréntesis para no equivocarte con los signos.',
      ),
      MathStep(
        index: 0,
        shortTitle: '5. Operar y simplificar',
        latexExpression:
            'F($bL) - F($aL) = ${_t(symB)} - \\left(${_t(symA)}\\right) = $totalLatex',
        pedagogicalNote: 'Calculamos F(b) y F(a) con valores exactos y restamos.',
      ),
    ];
    final dec = total.decimalLatex();
    return StepByStepResolution(
      originalInputLatex: '\\int_{$aL}^{$bL} ${_t(f)}\\,dx',
      steps: _reindex(steps),
      exactResultLatex: totalLatex,
      decimalApproxLatex: dec.isEmpty ? totalLatex : dec,
    );
  }
}
