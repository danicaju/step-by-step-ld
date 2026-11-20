import '../../../core/editor/exponent_navigation_helper.dart';
import '../models/step_resolution.dart';
import '../models/inequality_models.dart';
import 'linear_equation_solver.dart';

import 'inequalities/inequality_sign.dart';
import 'inequalities/inequality_parsing_helper.dart';
import 'inequalities/linear_inequality_1d_solver.dart';
import 'inequalities/quadratic_inequality_solver.dart';
import 'inequalities/rational_abs_inequality_solver.dart';
import 'inequalities/rational_inequality_solver.dart';
import 'inequalities/inequality_system_1d_solver.dart';
import 'inequalities/universal/inequality_family_detector.dart';
import 'inequalities/universal/number_line_step.dart';
import 'inequalities/universal/universal_inequality_solver.dart';
import 'equations/eq_poly.dart';
import 'exact/ext_parser.dart';
import '../parser/expression_parser.dart';

export 'inequalities/inequality_sign.dart';
export 'inequalities/inequality_parsing_helper.dart';
export 'inequalities/linear_inequality_1d_solver.dart';
export 'inequalities/quadratic_inequality_solver.dart';
export 'inequalities/rational_abs_inequality_solver.dart';
export 'inequalities/rational_inequality_solver.dart';
export 'inequalities/inequality_system_1d_solver.dart';
export '../models/inequality_models.dart';

class InequalitySolver {
  /// Obtiene los datos de renderizado visual asociados a una resolución de inecuación.
  static Inequality1DVisualData? getVisualData(StepByStepResolution res) {
    final attached = StepByStepResolution.attachments[res];
    if (attached is Inequality1DVisualData) return attached;
    return _legacyVisual(res);
  }

  static Inequality1DVisualData? _legacyVisual(StepByStepResolution res) =>
      UniversalInequalitySolver.visualDataExpando[res] ??
      LinearInequality1DSolver.visualDataExpando[res] ??
      QuadraticInequalitySolver.visualDataExpando[res] ??
      RationalAbsInequalitySolver.visualDataExpando[res] ??
      InequalitySystem1DSolver.visualDataExpando[res];

  /// `Abs(expr)` -> `|expr|` (la tecla Abs( escribe la funcion; el solver de valor absoluto usa barras).
  static String _absToBars(String s) {
    var out = s;
    while (true) {
      final i = out.indexOf('Abs(');
      if (i < 0) return out;
      var depth = 0;
      var end = -1;
      for (var k = i + 3; k < out.length; k++) {
        if (out[k] == '(') depth++;
        if (out[k] == ')') {
          depth--;
          if (depth == 0) {
            end = k;
            break;
          }
        }
      }
      final inner = out.substring(i + 4, end < 0 ? out.length : end);
      out = '${out.substring(0, i)}|$inner|${end < 0 ? '' : out.substring(end + 1)}';
    }
  }

  /// Resuelve una inecuación escrita como cadena de texto (de 1.º, 2.º grado o con valor absoluto).
  static StepByStepResolution solveString(
    String rawInput, {
    InequalitySign? fallbackSign,
  }) {
    final core = _solveCore(rawInput, fallbackSign: fallbackSign);
    final visual = _legacyVisual(core);
    final withLine = NumberLineStep.inject(core, visual);
    if (visual != null) StepByStepResolution.attachments[withLine] = visual;
    return withLine;
  }

  /// `true` si el enunciado no es lineal/cuadratico/racional clasico (raiz, log, exp, |.|,
  /// trigonometrica, mixta) o es un polinomio de grado >= 3.
  static bool _needsUniversal(String lhs, String rhs) {
    try {
      final a = ExtParser().parse(ExpressionParser.finalizeForEvaluation(lhs));
      final b = ExtParser().parse(ExpressionParser.finalizeForEvaluation(rhs.isEmpty ? '0' : rhs));
      if (InequalityFamilyDetector.detect(a, b) != InequalityFamily.general) return true;
      final ra = PolyOps.rationalOf(a), rb = PolyOps.rationalOf(b);
      if (ra == null || rb == null) return false;
      final deg = [ra.$1, ra.$2, rb.$1, rb.$2].map(PolyOps.degree).reduce((p, q) => p > q ? p : q);
      return deg >= 3 && PolyOps.degree(ra.$2) == 0 && PolyOps.degree(rb.$2) == 0;
    } on Object {
      return false;
    }
  }

  static StepByStepResolution _solveCore(
    String rawInput, {
    InequalitySign? fallbackSign,
  }) {
    final cleaned = _absToBars(ExponentNavigationHelper.flattenSimplePowers(rawInput))
        .replaceAll(' ', '')
        .replaceAll(r'\cdot', '*')
        .replaceAll(r'\times', '*')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll(r'\left(', '(')
        .replaceAll(r'\right)', ')')
        .replaceAll('²', '^2')
        .replaceAll('X', 'x');

    if (cleaned.isEmpty || cleaned == '0') {
      throw const FormatException('Escribe una inecuación válida.');
    }

    // Detectar si contiene valor absoluto: |...| o \left|...\right|
    final split = InequalityParsingHelper.splitByInequalitySign(cleaned, fallbackSign: fallbackSign);
    final lhs = split.lhs;
    final rhs = split.rhs;
    final sign = split.sign;

    if (cleaned.contains('|') || cleaned.contains(r'\left|')) {
      // Varios valores absolutos (|A|+|B|, |A|·|B|...): estudio general por tramos.
      if ('|'.allMatches(cleaned).length > 2) {
        return UniversalInequalitySolver.solve(lhs, rhs, sign);
      }
      try {
        return RationalAbsInequalitySolver.solveAbsoluteValue(cleaned, fallbackSign: fallbackSign);
      } on Object {
        return UniversalInequalitySolver.solve(lhs, rhs, sign);
      }
    }

    // Raices, logaritmos, exponenciales, valor absoluto compuesto, trigonometricas o grado >= 3.
    if (_needsUniversal(lhs, rhs)) {
      return UniversalInequalitySolver.solve(lhs, rhs, sign);
    }

    // Racional: x en algun denominador -> tabla de signos.
    if (RationalInequalitySolver.isRational(lhs, rhs)) {
      final rational = RationalInequalitySolver.solve(lhs, rhs, sign);
      if (rational != null) return rational;
    }

    // Detectar si contiene grado 2 (x^2)
    if (lhs.contains('x^2') || rhs.contains('x^2')) {
      final leftPoly = InequalityParsingHelper.parseQuadraticSide(lhs);
      final rightPoly = InequalityParsingHelper.parseQuadraticSide(rhs);
      final a = leftPoly.a - rightPoly.a;
      final b = leftPoly.b - rightPoly.b;
      final c = leftPoly.c - rightPoly.c;
      final customOrig =
          '${InequalityParsingHelper.formatSideFromRawPolyOrFallback(lhs)} ${sign.latex} ${InequalityParsingHelper.formatSideFromRawPolyOrFallback(rhs)}';
      if (a == 0) {
        return LinearInequality1DSolver.solveLinearTerms(
          leftTerms: [LinearTerm(xCoeff: b, constant: c)],
          rightTerms: const [LinearTerm(xCoeff: 0, constant: 0)],
          sign: sign,
          customOriginalLatex: customOrig,
        );
      }
      return QuadraticInequalitySolver.solveQuadratic(
        a: a,
        b: b,
        c: c,
        sign: sign,
        customOriginalLatex: customOrig,
      );
    }

    // Inecuación lineal con posibles fracciones o paréntesis
    final leftTerms = InequalityParsingHelper.parseLinearSide(lhs);
    final rightTerms = rhs == '0'
        ? <LinearTerm>[const LinearTerm(xCoeff: 0, constant: 0)]
        : InequalityParsingHelper.parseLinearSide(rhs);

    final effectiveLeft = leftTerms.isEmpty
        ? [const LinearTerm(xCoeff: 0, constant: 0)]
        : leftTerms;
    final effectiveRight = rightTerms.isEmpty
        ? [const LinearTerm(xCoeff: 0, constant: 0)]
        : rightTerms;

    return LinearInequality1DSolver.solveLinearTerms(
      leftTerms: effectiveLeft,
      rightTerms: effectiveRight,
      sign: sign,
      customOriginalLatex:
          '${InequalityParsingHelper.formatLinearSideLatex(effectiveLeft)} ${sign.latex} ${InequalityParsingHelper.formatLinearSideLatex(effectiveRight)}',
    );
  }

  static StepByStepResolution solveLinearCoeffs({
    required int a,
    int b = 0,
    int c = 0,
    int d = 0,
    required InequalitySign sign,
  }) =>
      LinearInequality1DSolver.solveLinearCoeffs(
        a: a,
        b: b,
        c: c,
        d: d,
        sign: sign,
      );

  static StepByStepResolution solveLinearTerms({
    required List<LinearTerm> leftTerms,
    required List<LinearTerm> rightTerms,
    required InequalitySign sign,
    String? customOriginalLatex,
  }) =>
      LinearInequality1DSolver.solveLinearTerms(
        leftTerms: leftTerms,
        rightTerms: rightTerms,
        sign: sign,
        customOriginalLatex: customOriginalLatex,
      );

  static StepByStepResolution solveQuadratic({
    required int a,
    required int b,
    required int c,
    required InequalitySign sign,
    String? customOriginalLatex,
  }) =>
      QuadraticInequalitySolver.solveQuadratic(
        a: a,
        b: b,
        c: c,
        sign: sign,
        customOriginalLatex: customOriginalLatex,
      );

  static ({StepByStepResolution resolution, Inequality1DVisualData visualData}) solveSystem1D(
    List<String> rawInequalities,
  ) =>
      InequalitySystem1DSolver.solveSystem1D(
        rawInequalities,
        solveSingle: solveString,
        getVisual: getVisualData,
      );
}
