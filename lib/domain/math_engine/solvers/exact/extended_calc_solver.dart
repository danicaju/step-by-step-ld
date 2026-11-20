import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../trig_and_angles_solver.dart';
import 'ext_evaluator.dart';
import 'ext_expr.dart';
import 'ext_parser.dart';
import 'identity_simplifier.dart';

export 'ext_expr.dart' show ExtUnsupported;
export 'exact_number.dart' show ExMathError;
export '../symbolic/m1_symbolic_solver.dart' show M1SymbolicSolver;

/// M1 extendido: evaluacion exacta + decimal de expresiones combinadas
/// (radicales, potencias racionales, |x|, n!, nCr, nPr, logs, e, pi y trig inversa).
class ExtendedCalcSolver {
  const ExtendedCalcSolver._();

  static final RegExp _fracPow = RegExp(r'\^\([^()]*[/.][^()]*\)|\^\d*\.\d');
  static final RegExp _simpleRadical = RegExp(r'^\d*(√|³√)\(?\d+\)?$');

  /// Indica si la expresion necesita el motor extendido en lugar del clasico.
  static bool needsExtended(String raw) {
    final s = raw.replaceAll(' ', '');
    if (s.contains('|') ||
        s.contains('!') ||
        s.contains('ℯ') ||
        s.contains('∛') ||
        RegExp(r'nCr|nPr|ncr|npr|[Aa]bs\(|sinh|cosh|tanh').hasMatch(s)) {
      return true;
    }
    if (_fracPow.hasMatch(s)) return true;
    final hasRadical = s.contains('√') || s.contains('sqrt') || s.contains('root');
    if (hasRadical && !_simpleRadical.hasMatch(s)) return true;
    try {
      if (ExtParser.tokenize(s).contains('e')) return true;
    } on ExtUnsupported {
      return false;
    }
    return false;
  }

  static StepByStepResolution solve(
    String raw, {
    AngleUnit angle = AngleUnit.deg,
    Map<String, Rational> memory = const {},
  }) =>
      solveWithAns(raw, angle: angle, memory: memory).$1;

  /// Resolucion paso a paso + aproximacion racional para la memoria ANS.
  static (StepByStepResolution, Rational) solveWithAns(
    String raw, {
    AngleUnit angle = AngleUnit.deg,
    Map<String, Rational> memory = const {},
  }) {
    final root = ExtParser().parse(raw);
    final identitySteps = <MathStep>[];
    final simplified = IdentitySimplifier.apply(root, identitySteps, angle: angle);
    final ev = ExtEvaluator(angle: angle, memory: memory);
    final value = ev.eval(simplified);
    final merged = [...identitySteps, ...ev.steps];
    final steps = <MathStep>[
      for (var i = 0; i < merged.length; i++)
        MathStep(
          index: i + 1,
          shortTitle: merged[i].shortTitle,
          latexExpression: merged[i].latexExpression,
          pedagogicalNote: merged[i].pedagogicalNote,
          warningTrick: merged[i].warningTrick,
        ),
    ];

    final isInverse = root is XFn && const {'asin', 'acos', 'atan'}.contains(root.name);
    final unitSuffix = isInverse && angle == AngleUnit.deg ? '^\\circ' : '';
    final exact = '${value.toLatex()}$unitSuffix';
    final dec = value.decimalLatex();
    final decimal = dec.isEmpty ? exact : '$dec$unitSuffix';

    if (steps.isEmpty || ((root is XBin || root is XNeg) && identitySteps.isEmpty)) {
      steps.add(MathStep(
        index: steps.length + 1,
        shortTitle: 'Operar y simplificar',
        latexExpression: '${root.latex()} = $exact',
        pedagogicalNote:
            'Operamos respetando la jerarquía (paréntesis, potencias y raíces, productos y cocientes, sumas y restas) y simplificamos el resultado.',
      ));
    }
    if (!value.isRational && dec.isNotEmpty) {
      steps.add(MathStep(
        index: steps.length + 1,
        shortTitle: 'Aproximación decimal',
        latexExpression: '$exact \\approx $decimal',
        pedagogicalNote:
            'Pulsa S⬄D para alternar entre el valor exacto y su aproximación decimal.',
      ));
    }

    final res = StepByStepResolution(
      originalInputLatex: root.latex(),
      steps: steps,
      exactResultLatex: exact,
      decimalApproxLatex: decimal,
    );
    return (res, value.asRational ?? Rational.fromDouble(value.approx, 100000));
  }
}
