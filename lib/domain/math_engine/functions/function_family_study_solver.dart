import '../calculus/limits_asymptotes_solver.dart';
import '../models/step_resolution.dart';
import '../solvers/trig_and_angles_solver.dart';
import 'angle_format.dart';
import 'exp_log_trig_family_study.dart';
import 'function_family.dart';
import 'function_family_classifier.dart';
import 'polynomial_family_study.dart';
import 'rational_radical_family_study.dart';

export 'function_family.dart';

/// Estudio de f(x) con su familia detectada (para el visor y el encuadre).
class FamilyStudy {
  final StudyResult result;
  final FamilyInfo info;
  final bool degrees;
  const FamilyStudy(this.result, this.info, this.degrees);

  FunctionFamily get family => info.family;
}

/// Fachada del estudio didactico por familia: clasifica, valida el tipo elegido en
/// el desplegable `Tipo` de M5 y devuelve el estudio paso a paso + asintotas.
class FunctionFamilyStudySolver {
  const FunctionFamilyStudySolver._();

  /// [expectedKind]: 1 = libre (autodeteccion); 2..8 = tipo del desplegable.
  static FamilyStudy study(String raw, {int expectedKind = 1, bool degrees = false}) {
    final model = FunctionModel.parse(raw).withAngle(degrees ? AngleUnit.deg : AngleUnit.rad);
    final info = FunctionFamilyClassifier.detect(model.node);
    final fam = info.family;
    if (fam == FunctionFamily.unknown) {
      if (expectedKind > 1) {
        throw FormatException(
            'No es del tipo $expectedKind: ${kM5KindLabels[expectedKind - 1]}. Usa el tipo 1 (función libre).');
      }
      final g = LimitsAsymptotesSolver.study(raw);
      return FamilyStudy(StudyResult(model, g.domain, g.asymptotes, g.resolution), info, degrees);
    }
    if (expectedKind > 1 && fam.kind != expectedKind) {
      throw FormatException(
          'Esta función es de tipo ${fam.kind}: ${kM5KindLabels[fam.kind - 1]}. Cámbialo con el desplegable Tipo.');
    }
    final domain = DomainSolver.of(model);
    var set = AsymptoteSet.empty;
    final List<MathStep> raw0;
    switch (fam) {
      case FunctionFamily.constant || FunctionFamily.linear || FunctionFamily.quadratic || FunctionFamily.cubic:
        raw0 = PolynomialFamilyStudy.study(fam, info.poly);
      case FunctionFamily.rational:
        raw0 = RationalRadicalFamilyStudy.rational(info.poly, info.den);
        set = LimitsAsymptotesSolver.study(raw).asymptotes;
      case FunctionFamily.radicalEven || FunctionFamily.radicalOdd:
        raw0 = RationalRadicalFamilyStudy.radical(info);
      case FunctionFamily.exponential:
        raw0 = ExpLogTrigFamilyStudy.study(info);
        set = AsymptoteSet(horizontal: [Asymptote.line('y = ${rl(info.d)}', 0, info.d.toDouble())]);
      case FunctionFamily.logarithmic:
        raw0 = ExpLogTrigFamilyStudy.study(info);
        final x0 = (-info.c / info.b);
        set = AsymptoteSet(vertical: [Asymptote.vertical('x = ${rl(x0)}', x0.toDouble())]);
      case FunctionFamily.tangent:
        raw0 = ExpLogTrigFamilyStudy.study(info, deg: degrees);
        set = AsymptoteSet(vertical: _tanAsymptotes(info, degrees));
      default:
        raw0 = ExpLogTrigFamilyStudy.study(info, deg: degrees);
    }
    final dom = fam == FunctionFamily.tangent
        ? '\\mathbb{R} \\setminus \\left\\{${AngleFormat.latex(_tanX0(info, degrees), degrees)} + k \\cdot ${AngleFormat.latex(_tanPeriod(info, degrees), degrees)}\\right\\}'
        : domain.latex;
    final result = [
      '\\text{Dom}(f) = $dom',
      if (set.vertical.isNotEmpty && fam != FunctionFamily.tangent) 'AV: ${set.vertical.map((a) => a.latex).join(r',\;')}',
      if (set.horizontal.isNotEmpty) 'AH: ${set.horizontal.map((a) => a.latex).join(r',\;')}',
      if (set.oblique.isNotEmpty) 'AO: ${set.oblique.map((a) => a.latex).join(r',\;')}',
    ].join(r',\;');
    final res = StepByStepResolution(
      originalInputLatex: 'f(x) = ${model.latex}',
      steps: numberSteps(raw0),
      exactResultLatex: result,
      decimalApproxLatex: '',
    );
    return FamilyStudy(StudyResult(model, domain, set, res), info, degrees);
  }

  static double _tanPeriod(FamilyInfo i, bool deg) => AngleFormat.turn(deg) / 2 / i.b.toDouble().abs();
  static double _tanX0(FamilyInfo i, bool deg) =>
      (AngleFormat.turn(deg) / 4 - i.c.toDouble()) / i.b.toDouble();

  /// Asintotas verticales de la tangente en una ventana amplia (k de -12 a 12).
  static List<Asymptote> _tanAsymptotes(FamilyInfo i, bool deg) {
    final x0 = _tanX0(i, deg), t = _tanPeriod(i, deg);
    return [
      for (var k = -12; k <= 12; k++)
        Asymptote.vertical('x = ${AngleFormat.plain(x0 + k * t, deg)}', x0 + k * t),
    ];
  }
}
