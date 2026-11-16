import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../parser/expression_parser.dart';
import 'quadratic_solver.dart';
import 'super_equation_solver.dart';
import 'polynomials/polynomial_models_and_ast.dart';
import 'polynomials/linear_from_coeffs_helper.dart';

export 'polynomials/polynomial_models_and_ast.dart';

/// Motor unificado de resolución paso a paso para ecuaciones polinómicas
/// de **1.º y 2.º grado** en forma libre o desordenada (Modo 2).
///
/// Soporta fracciones algebraicas (`(x-1)/2 + 3 = x`), paréntesis anidados,
/// identidades y potencias (`(x+1)^2 = 2x+5`), y términos desordenados en
/// ambos miembros (`2x^2 - 4x = x^2 - 3`, `5x = 2x^2`).
class PolynomialEquationSolver {
  /// Resuelve cualquier ecuación de 1.º, 2.º grado, irracional, exponencial, logarítmica o bicuadrada.
  static StepByStepResolution solveEquationString(String rawEquation) {
    final clean = rawEquation.replaceAll('\r', '').replaceAll(' ', '');
    final hasExpX = RegExp(
      r'\^\{[^}]*x[^}]*\}|\^\([^)]*x[^)]*\)|\^[0-9]*x[0-9]*',
    ).hasMatch(clean);
    final isAdvanced = clean.contains(r'\sqrt') ||
        clean.contains('sqrt') ||
        clean.contains(r'\log') ||
        clean.contains(r'\ln') ||
        clean.contains('log(') ||
        clean.contains('ln(') ||
        clean.contains('x^4') ||
        clean.contains('x^{4}') ||
        clean.contains('x⁴') ||
        hasExpX;
    if (isAdvanced) {
      return SuperEquationSolver.solve(rawEquation);
    }
    return solvePolynomialDirect(rawEquation);
  }

  /// Resuelve ecuaciones estrictamente polinómicas (lineales, cuadráticas, cúbicas...)
  static StepByStepResolution solvePolynomialDirect(String rawEquation) {
    final normalized = _normalizeInput(rawEquation);
    final eqParts = normalized.split('=');
    if (eqParts.length != 2 ||
        eqParts[0].trim().isEmpty ||
        eqParts[1].trim().isEmpty) {
      throw const FormatException(
        'La ecuación debe tener exactamente dos miembros separados por "=" '
        '(ej. 2x^2 - 4x = x^2 - 3 o (x-1)/2 + 3 = x).',
      );
    }

    final leftRaw = eqParts[0].trim();
    final rightRaw = eqParts[1].trim();
    final originalLatex =
        '${ExpressionParser.rawToLiveLatex(leftRaw)} = ${ExpressionParser.rawToLiveLatex(rightRaw)}';

    final leftAst = EqSideParser(leftRaw).parse();
    final rightAst = EqSideParser(rightRaw).parse();

    final denominators = <int>[];
    bool hasParensOrPowers = _containsParensOrPowers(leftAst) ||
        _containsParensOrPowers(rightAst);
    bool hasMinusBeforeFraction = _containsMinusBeforeFraction(leftAst) ||
        _containsMinusBeforeFraction(rightAst);

    _collectConstantDenominators(leftAst, denominators);
    _collectConstantDenominators(rightAst, denominators);

    final steps = <MathStep>[];
    String lastEquationLatex = originalLatex;

    void addStepIfNew({
      required String shortTitle,
      required String latexExpression,
      required String pedagogicalNote,
      String? warningTrick,
    }) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: shortTitle,
          latexExpression: latexExpression,
          pedagogicalNote: pedagogicalNote,
          warningTrick: warningTrick,
        ),
      );
      lastEquationLatex = latexExpression;
    }

    RationalPoly leftPoly = _evalAst(leftAst);
    RationalPoly rightPoly = _evalAst(rightAst);

    // 1. Eliminar denominadores mediante el m.c.m. si existen fracciones numéricas
    final uniqueDenoms = denominators.where((d) => d > 1).toSet().toList();
    if (uniqueDenoms.isNotEmpty) {
      final lcm = Rational.lcmMany(uniqueDenoms);
      final factLatex = uniqueDenoms.map((d) {
        final fact = Rational.primeFactorizationLatex(d);
        return '$d = $fact';
      }).join(r', \; ');

      final String clearedLeftLatex = _formatClearedSide(leftAst, lcm);
      final String clearedRightLatex = _formatClearedSide(rightAst, lcm);
      final String clearedEquationLatex =
          '$clearedLeftLatex = $clearedRightLatex';

      addStepIfNew(
        shortTitle: 'Mínimo Común Denominador (m.c.m.)',
        latexExpression:
            '\\text{m.c.m.}\\left(${uniqueDenoms.join(', ')}\\right) = $lcm \\quad \\left($factLatex\\right)',
        pedagogicalNote:
            'Calculamos el m.c.m. de todos los denominadores numéricos para multiplicar ambos miembros y eliminar las fracciones.',
      );

      addStepIfNew(
        shortTitle: 'Multiplicar ambos miembros por el m.c.m.',
        latexExpression: clearedEquationLatex,
        pedagogicalNote:
            'Multiplicamos cada término por $lcm y dividimos entre su denominador correspondiente.',
        warningTrick: hasMinusBeforeFraction
            ? '¡Cuidado con el signo menos delante de una fracción! El signo afecta a todo el numerador, cambiando el signo de cada término al eliminar el denominador.'
            : null,
      );

      leftPoly = leftPoly.scale(Rational(lcm));
      rightPoly = rightPoly.scale(Rational(lcm));
    }

    // 2. Desarrollar paréntesis y productos si existían antes de simplificar
    if (hasParensOrPowers) {
      final expandedLeftLatex = leftPoly.toLatex();
      final expandedRightLatex = rightPoly.toLatex();
      final expandedEqLatex = '$expandedLeftLatex = $expandedRightLatex';

      if (expandedEqLatex != lastEquationLatex) {
        addStepIfNew(
          shortTitle: 'Desarrollar productos, potencias y paréntesis',
          latexExpression: expandedEqLatex,
          pedagogicalNote:
              'Aplicamos la propiedad distributiva y resolvemos las potencias e identidades notables en ambos miembros.',
        );
      }
    }

    // 3. Pasar todo al primer miembro e igualar a cero: P(x) = 0
    final diffPoly = leftPoly - rightPoly;
    final int deg = diffPoly.degree;

    if (deg > 2) {
      return SuperEquationSolver.solve(rawEquation);
    }

    final int lcmDiffDen = Rational.lcmMany(
      diffPoly.coeffs.map((c) => c.denominator).toList(),
    );
    final scaledDiff = diffPoly.scale(Rational(lcmDiffDen));
    final int rawA = scaledDiff.at(2).numerator;
    final int rawB = scaledDiff.at(1).numerator;
    final int rawC = scaledDiff.at(0).numerator;

    final int commonDiv = [rawA, rawB, rawC]
        .where((x) => x != 0)
        .map((x) => x.abs())
        .fold(0, (acc, val) => acc == 0 ? val : Rational.gcd(acc, val));
    final signFlip = rawA < 0 ? -1 : (rawA == 0 && rawB < 0 ? -1 : 1);
    final effectiveDiv = (commonDiv > 0 ? commonDiv : 1) * signFlip;

    final int a = rawA ~/ effectiveDiv;
    final int b = rawB ~/ effectiveDiv;
    final int c = rawC ~/ effectiveDiv;

    // 4. Si el grado es <= 1, resolvemos como lineal de primer grado (sin igualar innecesariamente a cero)
    if (a == 0) {
      return LinearFromCoeffsHelper.solveLinearFromCoeffs(
        b: b,
        c: c,
        originalLatex: originalLatex,
        prefixSteps: steps,
        lastEquationLatex: lastEquationLatex,
      );
    }

    final String finalPolyLatex = AlgebraicLatexFormatter.polynomialExpression(
      [a, b, c],
      variable: 'x',
    );
    final String standardZeroLatex = '$finalPolyLatex = 0';

    if (standardZeroLatex != lastEquationLatex) {
      final bool needsSignFlip = rawA < 0 || (rawA == 0 && rawB < 0);
      final bool needsDiv = commonDiv > 1;

      addStepIfNew(
        shortTitle: 'Transponer términos al primer miembro',
        latexExpression: standardZeroLatex,
        pedagogicalNote:
            'Pasamos todos los términos al primer miembro cambiando su signo al cruzar el "=" y reducimos términos semejantes.',
        warningTrick: (needsSignFlip || needsDiv)
            ? 'Dividimos toda la ecuación entre $effectiveDiv para que el coeficiente principal sea positivo y simplificar los cálculos posteriores.'
            : null,
      );
    }

    // 5. Ecuación cuadrática completa o incompleta
    final quadResolution = QuadraticEquationSolver.solve(
      a: a,
      b: b,
      c: c,
    );

    final mergedSteps = <MathStep>[...steps];
    for (int i = 0; i < quadResolution.steps.length; i++) {
      final s = quadResolution.steps[i];
      mergedSteps.add(
        MathStep(
          index: mergedSteps.length + 1,
          shortTitle: s.shortTitle,
          latexExpression: s.latexExpression,
          pedagogicalNote: s.pedagogicalNote,
          warningTrick: s.warningTrick,
        ),
      );
    }

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: mergedSteps,
      exactResultLatex: quadResolution.exactResultLatex,
      decimalApproxLatex: quadResolution.decimalApproxLatex,
    );
  }

  static String _normalizeInput(String raw) {
    var s = raw
        .trim()
        .replaceAll('\uE000', '')
        .replaceAll('−', '-')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll(r'\cdot', '*')
        .replaceAll(r'\times', '*')
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '')
        .replaceAll('X', 'x');

    // Convertir \frac{num}{den} -> (num)/(den) y frac(num,den) -> (num)/(den)
    while (s.contains(r'\frac{')) {
      final idx = s.indexOf(r'\frac{');
      final numOpen = idx + 5;
      final numClose = _findMatchingDelim(s, numOpen, '{', '}');
      if (numClose == -1 ||
          numClose + 1 >= s.length ||
          s[numClose + 1] != '{') {
        throw const FormatException('Fracción LaTeX mal formada.');
      }
      final denOpen = numClose + 1;
      final denClose = _findMatchingDelim(s, denOpen, '{', '}');
      if (denClose == -1) {
        throw const FormatException('Fracción LaTeX mal formada.');
      }
      final numInner = s.substring(numOpen + 1, numClose);
      final denInner = s.substring(denOpen + 1, denClose);
      s = '${s.substring(0, idx)}($numInner)/($denInner)${s.substring(denClose + 1)}';
    }

    s = s
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('{', '(')
        .replaceAll('}', ')');
    return s;
  }

  static int _findMatchingDelim(
    String s,
    int openIdx,
    String openCh,
    String closeCh,
  ) {
    int depth = 1;
    for (int i = openIdx + 1; i < s.length; i++) {
      if (s[i] == openCh) depth++;
      if (s[i] == closeCh) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static bool _containsParensOrPowers(EqAstNode node) => switch (node) {
        ParenAst() => true,
        UnaryNegAst(:final inner) => _containsParensOrPowers(inner),
        BinAst(:final op, :final left, :final right) =>
          (op == '^' && left is! VarAst) ||
              (op == '*' && (left is ParenAst || right is ParenAst)) ||
              _containsParensOrPowers(left) ||
              _containsParensOrPowers(right),
        _ => false,
      };

  static bool _containsMinusBeforeFraction(EqAstNode node) => switch (node) {
        UnaryNegAst(:final inner) => _containsFraction(inner) ||
            _containsMinusBeforeFraction(inner),
        ParenAst(:final inner) => _containsMinusBeforeFraction(inner),
        BinAst(:final op, :final left, :final right) =>
          (op == '-' && _containsFraction(right)) ||
              _containsMinusBeforeFraction(left) ||
              _containsMinusBeforeFraction(right),
        _ => false,
      };

  static bool _containsFraction(EqAstNode node) => switch (node) {
        BinAst(:final op, :final left, :final right) =>
          op == '/' || _containsFraction(left) || _containsFraction(right),
        ParenAst(:final inner) => _containsFraction(inner),
        UnaryNegAst(:final inner) => _containsFraction(inner),
        _ => false,
      };

  static void _collectConstantDenominators(
    EqAstNode node,
    List<int> out,
  ) {
    switch (node) {
      case BinAst(:final op, :final left, :final right):
        if (op == '/') {
          final denPoly = _evalAst(right);
          if (!denPoly.isConstant || denPoly.at(0).isZero) {
            throw const FormatException(
              'Los denominadores no pueden contener la incógnita x ni ser cero.',
            );
          }
          final d = denPoly.at(0);
          if (d.denominator == 1) {
            final absVal = d.numerator.abs();
            if (absVal > 1) out.add(absVal);
          } else {
            out.add(d.numerator.abs());
          }
        }
        _collectConstantDenominators(left, out);
        _collectConstantDenominators(right, out);
      case UnaryNegAst(:final inner):
        _collectConstantDenominators(inner, out);
      case ParenAst(:final inner):
        _collectConstantDenominators(inner, out);
      case NumAst():
      case VarAst():
        break;
    }
  }

  static RationalPoly _evalAst(EqAstNode node) => switch (node) {
        NumAst(:final value) => RationalPoly.constant(value),
        VarAst() => RationalPoly.x(),
        UnaryNegAst(:final inner) => -_evalAst(inner),
        ParenAst(:final inner) => _evalAst(inner),
        BinAst(:final op, :final left, :final right) => switch (op) {
            '+' => _evalAst(left) + _evalAst(right),
            '-' => _evalAst(left) - _evalAst(right),
            '*' => _evalAst(left) * _evalAst(right),
            '/' => () {
                final den = _evalAst(right);
                if (!den.isConstant) {
                  throw const FormatException(
                    'No se admite la incógnita x en el denominador.',
                  );
                }
                return _evalAst(left).divideByScalar(den.at(0));
              }(),
            '^' => () {
                final expPoly = _evalAst(right);
                if (!expPoly.isConstant || expPoly.at(0).denominator != 1) {
                  throw const FormatException(
                    'El exponente debe ser un número entero no negativo.',
                  );
                }
                return _evalAst(left).powInt(expPoly.at(0).numerator);
              }(),
            _ => throw FormatException('Operador desconocido: $op'),
          },
      };

  static String _formatClearedSide(EqAstNode node, int lcm) {
    final pieces = <({bool isNeg, EqAstNode node})>[];
    _flattenAdditive(node, false, pieces);
    if (pieces.isEmpty) return '0';

    final buf = StringBuffer();
    for (int i = 0; i < pieces.length; i++) {
      final item = pieces[i];
      final termLatex = _formatClearedPiece(
        item.node,
        lcm,
        leadNeg: item.isNeg,
        isFirst: i == 0,
      );
      buf.write(termLatex);
    }
    return buf.toString();
  }

  static void _flattenAdditive(
    EqAstNode node,
    bool flipSign,
    List<({bool isNeg, EqAstNode node})> out,
  ) {
    switch (node) {
      case BinAst(op: '+', :final left, :final right):
        _flattenAdditive(left, flipSign, out);
        _flattenAdditive(right, flipSign, out);
      case BinAst(op: '-', :final left, :final right):
        _flattenAdditive(left, flipSign, out);
        _flattenAdditive(right, !flipSign, out);
      case UnaryNegAst(:final inner):
        _flattenAdditive(inner, !flipSign, out);
      default:
        out.add((isNeg: flipSign, node: node));
    }
  }

  static String _formatClearedPiece(
    EqAstNode node,
    int lcm, {
    required bool leadNeg,
    required bool isFirst,
  }) {
    if (node is BinAst && node.op == '/') {
      final denPoly = _evalAst(node.right);
      final denVal = denPoly.at(0);
      final factor = (Rational(lcm) / denVal);
      final numPoly = (_evalAst(node.left) *
              RationalPoly.constant(leadNeg ? -factor : factor))
          .toLatex();
      if (isFirst) return numPoly;
      if (numPoly.startsWith('-')) return ' - ${numPoly.substring(1)}';
      return ' + $numPoly';
    }

    final poly = _evalAst(node).scale(Rational(leadNeg ? -lcm : lcm));
    final latex = poly.toLatex();
    if (isFirst) return latex;
    if (latex.startsWith('-')) return ' - ${latex.substring(1)}';
    return ' + $latex';
  }
}
