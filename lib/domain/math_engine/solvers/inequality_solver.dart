import '../models/step_resolution.dart';
import '../models/inequality_models.dart';
import 'linear_equation_solver.dart';

import 'inequalities/inequality_sign.dart';
import 'inequalities/inequality_parsing_helper.dart';
import 'inequalities/linear_inequality_1d_solver.dart';
import 'inequalities/quadratic_inequality_solver.dart';
import 'inequalities/rational_abs_inequality_solver.dart';
import 'inequalities/inequality_system_1d_solver.dart';

export 'inequalities/inequality_sign.dart';
export 'inequalities/inequality_parsing_helper.dart';
export 'inequalities/linear_inequality_1d_solver.dart';
export 'inequalities/quadratic_inequality_solver.dart';
export 'inequalities/rational_abs_inequality_solver.dart';
export 'inequalities/inequality_system_1d_solver.dart';
export '../models/inequality_models.dart';

class InequalitySolver {
  /// Obtiene los datos de renderizado visual asociados a una resolución de inecuación.
  static Inequality1DVisualData? getVisualData(StepByStepResolution res) =>
      LinearInequality1DSolver.visualDataExpando[res] ??
      QuadraticInequalitySolver.visualDataExpando[res] ??
      RationalAbsInequalitySolver.visualDataExpando[res] ??
      InequalitySystem1DSolver.visualDataExpando[res];

  /// Resuelve una inecuación escrita como cadena de texto (de 1.º, 2.º grado o con valor absoluto).
  static StepByStepResolution solveString(
    String rawInput, {
    InequalitySign? fallbackSign,
  }) {
    final cleaned = rawInput
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
    if (cleaned.contains('|') || cleaned.contains(r'\left|')) {
      return RationalAbsInequalitySolver.solveAbsoluteValue(cleaned, fallbackSign: fallbackSign);
    }

    final split = InequalityParsingHelper.splitByInequalitySign(cleaned, fallbackSign: fallbackSign);
    final lhs = split.lhs;
    final rhs = split.rhs;
    final sign = split.sign;

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
