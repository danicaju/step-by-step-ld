import '../../core/algebraic_latex_formatter.dart';

class System2x2Helpers {
  /// Representa una ecuación lineal en dos variables: ax + by = c
  static String formatEquation(int a, int b, int c) {
    return AlgebraicLatexFormatter.twoVarEquation(a, b, c);
  }

  /// Despeja `varName` en `ax + by = c` con formato limpio sin dobles signos ni denominador negativo.
  static String isolateVariableExpr({
    required int targetCoeff,
    required int otherCoeff,
    required String otherVar,
    required int constant,
  }) {
    if (targetCoeff == 1) {
      if (otherCoeff == 0) return '$constant';
      if (constant == 0) {
        return AlgebraicLatexFormatter.monomialTerm(-otherCoeff, otherVar, isFirst: true);
      }
      return '$constant${AlgebraicLatexFormatter.monomialTerm(-otherCoeff, otherVar, isFirst: false)}';
    }
    if (targetCoeff == -1) {
      return AlgebraicLatexFormatter.linearExpression(
        otherCoeff,
        -constant,
        variable: otherVar,
      );
    }

    final den = targetCoeff.abs();
    final numConst = targetCoeff > 0 ? constant : -constant;
    final numOther = targetCoeff > 0 ? -otherCoeff : otherCoeff;
    final numLatex = numConst == 0 && numOther == 0
        ? '0'
        : numConst == 0
            ? AlgebraicLatexFormatter.monomialTerm(numOther, otherVar, isFirst: true)
            : '$numConst${AlgebraicLatexFormatter.monomialTerm(numOther, otherVar, isFirst: false)}';
    return '\\frac{$numLatex}{$den}';
  }
}
