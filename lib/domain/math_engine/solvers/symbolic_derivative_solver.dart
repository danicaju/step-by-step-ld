import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'calculus/sym_build.dart';
import 'calculus/sym_diff.dart';
import 'calculus/sym_latex.dart';
import 'exact/exact_number.dart';
import 'exact/ext_expr.dart';
import 'exact/ext_parser.dart';

/// Derivadas simbolicas f'(x) y recta tangente sobre el AST completo
/// (no solo polinomios), con regla del producto, cociente y cadena paso a paso.
class SymbolicDerivativeSolver {
  const SymbolicDerivativeSolver._();

  static XNode parse(String raw) => ExtParser().parse(raw);

  static String _t(XNode n) => SymLatex.tex(n);

  static String _kinds(XNode f) {
    final k = <String>[];
    void walk(XNode n) {
      switch (n) {
        case XBin(:final l, :final op, :final r):
          if (op == '*' && Sx.hasX(l) && Sx.hasX(r)) k.add('producto');
          if (op == '/' && Sx.hasX(r)) k.add('cociente');
          walk(l);
          walk(r);
        case XNeg(:final a):
          walk(a);
        case XPow(:final base, :final exp):
          k.add(Sx.hasX(exp) ? 'exponencial' : 'potencia');
          walk(base);
          walk(exp);
        case XRoot(:final rad):
          k.add('raíz');
          walk(rad);
        case XFn(:final name, :final arg):
          k.add(name);
          if (arg is! XVar) k.add('cadena');
          walk(arg);
        default:
          break;
      }
    }

    walk(f);
    final uniq = k.toSet().toList();
    return uniq.isEmpty ? 'constante' : uniq.join(', ');
  }

  /// `f'(x)` simbolica con pasos.
  static ({XNode derivative, List<MathStep> steps}) differentiate(XNode f) {
    final steps = <MathStep>[];
    void log(String title, String latex, String note) {
      steps.add(MathStep(
        index: steps.length + 2,
        shortTitle: title,
        latexExpression: latex,
        pedagogicalNote: note,
      ));
    }

    final df = SymDiff(log: log).d(f);
    return (derivative: df, steps: steps);
  }

  static StepByStepResolution derivative(String expressionRaw) {
    final f = parse(expressionRaw);
    final r = differentiate(f);
    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Identificar las reglas de derivación',
        latexExpression: "f(x) = ${_t(f)}",
        pedagogicalNote:
            'Reconocemos la estructura de f(x) para elegir las reglas: ${_kinds(f)}. Tabla: (xⁿ)\' = n·xⁿ⁻¹, (sen u)\' = cos u · u\', (cos u)\' = -sen u · u\', (eᵘ)\' = eᵘ · u\', (ln u)\' = u\'/u.',
      ),
      ...r.steps.map((s) => MathStep(
            index: s.index,
            shortTitle: s.shortTitle,
            latexExpression: s.latexExpression,
            pedagogicalNote: s.pedagogicalNote,
          )),
    ];
    steps.add(MathStep(
      index: steps.length + 1,
      shortTitle: "Resultado f'(x)",
      latexExpression: "f'(x) = ${_t(r.derivative)}",
      pedagogicalNote:
          'Simplificamos el resultado. Las derivadas trigonométricas suponen ángulos en radianes.',
    ));
    final res = "f'(x) = ${_t(r.derivative)}";
    return StepByStepResolution(
      originalInputLatex: 'f(x) = ${_t(f)}',
      steps: steps,
      exactResultLatex: res,
      decimalApproxLatex: res,
    );
  }

  static StepByStepResolution tangentLine(String expressionRaw, Rational x0) {
    final f = parse(expressionRaw);
    final df = differentiate(f).derivative;
    final xv = ExNum.rational(x0);
    final y0 = Sx.evalAt(f, xv);
    final m = Sx.evalAt(df, xv);
    if (y0 == null || m == null) throw const ExMathError();
    final x0l = x0.toLatex();
    final sub = Sx.subst(f, (n) => n is XVar, XNum(x0));
    final subD = Sx.subst(df, (n) => n is XVar, XNum(x0));
    final n = y0 - m * xv; // y = m x + n
    String line() {
      final mm = m.toLatex();
      final mPart = m.isRational && m.asRational == Rational(1)
          ? 'x'
          : (m.isRational && m.asRational == Rational(-1) ? '-x' : '${m.terms.length > 1 ? '\\left($mm\\right)' : mm}x');
      if (m.isZero) return n.toLatex();
      if (n.isZero) return mPart;
      final nl = n.toLatex();
      return nl.startsWith('-') ? '$mPart - ${nl.substring(1)}' : '$mPart + $nl';
    }

    final steps = [
      MathStep(
        index: 1,
        shortTitle: 'Punto de tangencia f(x0)',
        latexExpression:
            'f($x0l) = ${_t(sub)} = ${y0.toLatex()} \\implies P\\left($x0l, ${y0.toLatex()}\\right)',
        pedagogicalNote: 'Evaluamos f en x₀ para obtener la ordenada del punto de tangencia.',
      ),
      ...differentiate(f).steps.map((s) => MathStep(
            index: s.index,
            shortTitle: s.shortTitle,
            latexExpression: s.latexExpression,
            pedagogicalNote: s.pedagogicalNote,
          )),
      MathStep(
        index: 2,
        shortTitle: "Pendiente m = f'(x0)",
        latexExpression:
            "f'(x) = ${_t(df)} \\implies m = f'($x0l) = ${_t(subD)} = ${m.toLatex()}",
        pedagogicalNote: 'La derivada en x₀ es la pendiente de la recta tangente.',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Ecuación de la recta tangente',
        latexExpression:
            'y - ${_wrapNeg(y0)} = ${_wrapNeg(m)} \\cdot \\left(x - ${_wrapNeg(xv)}\\right) \\implies y = ${line()}',
        pedagogicalNote:
            'Aplicamos y - f(x₀) = f\'(x₀)·(x - x₀) y despejamos y.',
        warningTrick: 'Cuidado con los signos: x - (-a) = x + a.',
      ),
    ];
    final exact = 'y = ${line()}';
    final num = m.approx;
    final dec = 'y \\approx ${ExNum.opaque('', num).decimalLatex()}x ${n.approx < 0 ? '-' : '+'} ${ExNum.opaque('', n.approx.abs()).decimalLatex()}';
    return StepByStepResolution(
      originalInputLatex: 'f(x) = ${_t(f)},\\; x_{0} = $x0l',
      steps: [
        for (var i = 0; i < steps.length; i++)
          MathStep(
            index: i + 1,
            shortTitle: steps[i].shortTitle,
            latexExpression: steps[i].latexExpression,
            pedagogicalNote: steps[i].pedagogicalNote,
            warningTrick: steps[i].warningTrick,
          ),
      ],
      exactResultLatex: exact,
      decimalApproxLatex: m.isRational && n.isRational ? exact : dec,
    );
  }

  static String _wrapNeg(ExNum v) =>
      v.approx < 0 || (v.isExact && v.terms.length > 1) ? '\\left(${v.toLatex()}\\right)' : v.toLatex();
}
