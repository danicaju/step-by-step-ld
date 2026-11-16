import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'linear_equations/linear_equation_parser.dart';

export 'linear_equations/linear_equation_parser.dart';

/// Término de una ecuación lineal: \pm \frac{a x + b}{d}
class LinearTerm {
  final int xCoeff;
  final int constant;
  final int denominator;
  final bool isSubtract;

  const LinearTerm({
    required this.xCoeff,
    required this.constant,
    this.denominator = 1,
    this.isSubtract = false,
  });

  String toLatex() {
    final numStr = AlgebraicLatexFormatter.linearExpression(xCoeff, constant);

    if (denominator == 1) {
      if (isSubtract) {
        if (xCoeff != 0 && constant != 0) return '- ($numStr)';
        if (numStr.startsWith('-')) return '+ ${numStr.substring(1)}';
        return '- $numStr';
      }
      return numStr;
    }
    final signStr = isSubtract ? '- ' : '+ ';
    return '$signStr\\frac{$numStr}{$denominator}';
  }
}

class LinearEquationSolver {

  static String _formatSideLatex(List<LinearTerm> terms) {
    if (terms.isEmpty) return '0';
    final buffer = StringBuffer();
    for (int i = 0; i < terms.length; i++) {
      String part = terms[i].toLatex().trim();
      if (i == 0) {
        if (part.startsWith('+ ')) {
          part = part.substring(2).trimLeft();
        }
        buffer.write(part);
      } else {
        if (!part.startsWith('+') && !part.startsWith('-')) {
          buffer.write(' + $part');
        } else if (part.startsWith('-') && !part.startsWith('- ')) {
          buffer.write(' - ${part.substring(1)}');
        } else {
          buffer.write(' $part');
        }
      }
    }
    return buffer.toString();
  }

  static List<String> _buildExpandedSide(
    List<LinearTerm> terms,
    int commonDen,
  ) {
    final parts = <String>[];
    for (int i = 0; i < terms.length; i++) {
      final t = terms[i];
      final factor = commonDen ~/ t.denominator;
      final sign = t.isSubtract ? '-' : (i > 0 ? '+' : '');
      final numExpr = AlgebraicLatexFormatter.linearExpression(t.xCoeff, t.constant);
      final hasTwoTerms = t.xCoeff != 0 && t.constant != 0;
      if (factor == 1) {
        final wrapped = hasTwoTerms ? '($numExpr)' : numExpr;
        parts.add(sign.isEmpty ? wrapped : '$sign $wrapped');
      } else {
        parts.add('$sign \\textcolor{#2563EB}{$factor} \\cdot ($numExpr)'.trimLeft());
      }
    }
    return parts;
  }
  /// Resuelve una ecuación lineal con fracciones y pasos pedagógicos de ESO:
  /// Ejemplo clásico de examen: \frac{x-2}{3} - \frac{x+1}{4} = 2
  static StepByStepResolution solveFractionEquation({
    required List<LinearTerm> leftTerms,
    required List<LinearTerm> rightTerms,
    String? customOriginalLatex,
  }) {
    final originalLatex = customOriginalLatex ??
        '${_formatSideLatex(leftTerms)} = ${_formatSideLatex(rightTerms)}';

    final List<MathStep> steps = [];

    // Recopilar todos los denominadores
    final allDenominators = [
      ...leftTerms.map((t) => t.denominator),
      ...rightTerms.map((t) => t.denominator),
    ].where((d) => d > 1).toList();

    int commonDen = 1;
    if (allDenominators.isNotEmpty) {
      commonDen = allDenominators.reduce((a, b) => Rational.lcm(a, b));
    }

    // Comprobar si hay trampa de signo negativo delante de binomio
    bool hasNegativeFractionWithBinomial = false;
    for (final t in [...leftTerms, ...rightTerms]) {
      if (t.isSubtract && t.denominator > 1 && t.xCoeff != 0 && t.constant != 0) {
        hasNegativeFractionWithBinomial = true;
        break;
      }
    }

    // Paso 1: Quitar denominadores con m.c.m. si commonDen > 1
    if (commonDen > 1) {
      final factLatex = Rational.primeFactorizationLatex(commonDen);

      final leftExpandedParts = _buildExpandedSide(leftTerms, commonDen);
      final rightExpandedParts = _buildExpandedSide(rightTerms, commonDen);

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Quitar denominadores con el m.c.m.',
          latexExpression:
              '\\begin{aligned} '
              '\\text{m.c.m. de denominadores} = $commonDen \\quad ($commonDen = $factLatex) \\\\[4pt] '
              '${leftExpandedParts.join(' ')} = ${rightExpandedParts.join(' ')} '
              '\\end{aligned}',
          pedagogicalNote:
              'Multiplicamos todos los términos de la ecuación por el m.c.m. ($commonDen) para eliminar las fracciones dividiendo cada factor por su denominador.',
          warningTrick: hasNegativeFractionWithBinomial
              ? 'El signo menos delante de una fracción afecta a todos los términos del numerador: -(A + B)/d → (-A - B)/d.'
              : null,
        ),
      );
    }

    // Multiplicar los factores y operar paréntesis
    int leftTotalX = 0;
    int leftTotalConst = 0;
    for (final t in leftTerms) {
      final factor = commonDen ~/ t.denominator;
      final sign = t.isSubtract ? -1 : 1;
      leftTotalX += sign * factor * t.xCoeff;
      leftTotalConst += sign * factor * t.constant;
    }

    int rightTotalX = 0;
    int rightTotalConst = 0;
    for (final t in rightTerms) {
      final factor = commonDen ~/ t.denominator;
      final sign = t.isSubtract ? -1 : 1;
      rightTotalX += sign * factor * t.xCoeff;
      rightTotalConst += sign * factor * t.constant;
    }

    // Paso 2: Transposición de términos (solo si realmente hay términos que mover)
    final netXLeft = leftTotalX - rightTotalX;
    final netConstRight = rightTotalConst - leftTotalConst;

    final bool needsTransposition =
        rightTotalX != 0 || leftTotalConst != 0 || (leftTotalX == 0 && rightTotalX == 0 && leftTotalConst == 0 && rightTotalConst == 0 ? false : false);
    if (needsTransposition) {
      final xLeftPart = AlgebraicLatexFormatter.monomialTerm(leftTotalX, 'x', isFirst: true);
      final xRightMoved = AlgebraicLatexFormatter.monomialTerm(
        -rightTotalX,
        'x',
        isFirst: leftTotalX == 0,
      );
      final lhsTransposed = '$xLeftPart$xRightMoved'.isEmpty ? '0' : '$xLeftPart$xRightMoved';

      final cRightPart = AlgebraicLatexFormatter.constantTerm(rightTotalConst, isFirst: true);
      final cLeftMoved = AlgebraicLatexFormatter.constantTerm(
        -leftTotalConst,
        isFirst: rightTotalConst == 0,
      );
      final rhsTransposed = '$cRightPart$cLeftMoved'.isEmpty ? '0' : '$cRightPart$cLeftMoved';

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Transposición de términos',
          latexExpression: '$lhsTransposed = $rhsTransposed',
          pedagogicalNote:
              'Agrupamos los términos con x en el primer miembro y los términos independientes en el segundo miembro, cambiando el signo al cruzar el igual.',
        ),
      );
    }

    // Paso 3: Reducción y Despeje
    if (netXLeft == 0) {
      final isIdentity = netConstRight == 0;
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: isIdentity ? 'Identidad (Infinitas soluciones)' : 'Ecuación incompatible (Sin solución)',
          latexExpression: '0 = $netConstRight',
          pedagogicalNote: isIdentity
              ? 'Cualquier número real satisface la ecuación (0 = 0).'
              : 'Es imposible que 0 sea igual a $netConstRight. La ecuación no tiene solución.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: isIdentity ? r'\text{Infinitas soluciones}' : r'\text{Sin solucion}',
        decimalApproxLatex: isIdentity ? r'\text{Infinitas}' : r'\text{Sin sol}',
      );
    }

    final rawRational = Rational.raw(netConstRight, netXLeft);
    final simplified = rawRational.simplify();
    final String stepLatex;
    final String stepNote;

    if (netXLeft == 1) {
      stepLatex = 'x = ${simplified.toLatex()}';
      stepNote = 'La incógnita x queda despejada directamente sin necesidad de dividir.';
    } else if (netXLeft == -1) {
      stepLatex = '-x = $netConstRight \\implies x = ${simplified.toLatex()}';
      stepNote = 'Multiplicamos ambos miembros por -1 para cambiar el signo de -x a x.';
    } else {
      final lhsTerm = AlgebraicLatexFormatter.monomialTerm(netXLeft, 'x', isFirst: true);
      final unsimplifiedLatex = AlgebraicLatexFormatter.signedFraction(netConstRight, netXLeft);
      final simplifiedLatex = simplified.toLatex();
      stepLatex = unsimplifiedLatex == simplifiedLatex
          ? '$lhsTerm = $netConstRight \\implies x = $simplifiedLatex'
          : '$lhsTerm = $netConstRight \\implies x = $unsimplifiedLatex = $simplifiedLatex';
      stepNote =
          'Dividimos el término independiente entre $netXLeft y simplificamos al máximo cuando es posible.';
    }

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: netXLeft.abs() == 1 && !needsTransposition
            ? 'Solución directa'
            : 'Reducción y despeje de la incógnita x',
        latexExpression: stepLatex,
        pedagogicalNote: stepNote,
      ),
    );

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'x = ${simplified.toLatex()}',
      decimalApproxLatex: simplified.toDecimalLatex(),
    );
  }

  /// Preset clásico de ESO con fracciones y trampa de signo:
  /// \frac{x-2}{3} - \frac{x+1}{4} = 2
  static StepByStepResolution solveClassicPreset() {
    return solveFractionEquation(
      leftTerms: const [
        LinearTerm(xCoeff: 1, constant: -2, denominator: 3),
        LinearTerm(xCoeff: 1, constant: 1, denominator: 4, isSubtract: true),
      ],
      rightTerms: const [
        LinearTerm(xCoeff: 0, constant: 2, denominator: 1),
      ],
      customOriginalLatex: r'\frac{x - 2}{3} - \frac{x + 1}{4} = 2',
    );
  }

  /// Ecuación lineal directa sin denominadores: ax + b = cx + d
  static StepByStepResolution solveDirect({
    required int a,
    required int b,
    required int c,
    required int d,
  }) {
    return solveFractionEquation(
      leftTerms: [
        LinearTerm(xCoeff: a, constant: b),
      ],
      rightTerms: [
        LinearTerm(xCoeff: c, constant: d),
      ],
      customOriginalLatex:
          '${a}x ${b >= 0 ? '+ $b' : '- ${b.abs()}'} = ${c}x ${d >= 0 ? '+ $d' : '- ${d.abs()}'}',
    );
  }

  /// Parsea y resuelve una ecuación lineal introducida como texto por el alumno.
  /// Soporta: "2x + 4 = 16", "2*x = 8", "2(x - 3) = 4", "(x-2)/3 - (x+1)/4 = 2", etc.
  static StepByStepResolution solveEquationString(String equationStr) {
    String cleaned = LinearEquationParser.normalizeEquationInput(equationStr);
    if (cleaned.isEmpty || cleaned == '0') {
      throw const FormatException('Ecuación vacía');
    }
    // Si el usuario aún no ha puesto '=', asumimos '= 0'
    if (!cleaned.contains('=')) {
      cleaned = '$cleaned=0';
    }

    final parts = cleaned.split('=');
    if (parts.length != 2) {
      throw const FormatException('La ecuación debe contener un único signo =');
    }
    if (parts[0].isEmpty || parts[1].isEmpty) {
      throw const FormatException('Completa ambos miembros de la ecuación');
    }

    LinearEquationParser.checkBalancedParens(parts[0]);
    LinearEquationParser.checkBalancedParens(parts[1]);

    final leftTerms = LinearEquationParser.parseLinearTerms(parts[0]);
    final rightTerms = LinearEquationParser.parseLinearTerms(parts[1]);

    if (leftTerms.isEmpty && rightTerms.isEmpty) {
      throw const FormatException('No se encontraron términos en la ecuación');
    }

    final effectiveLeft = leftTerms.isEmpty
        ? [const LinearTerm(xCoeff: 0, constant: 0)]
        : leftTerms;
    final effectiveRight = rightTerms.isEmpty
        ? [const LinearTerm(xCoeff: 0, constant: 0)]
        : rightTerms;

    return solveFractionEquation(
      leftTerms: effectiveLeft,
      rightTerms: effectiveRight,
      customOriginalLatex:
          '${_formatSideLatex(effectiveLeft)} = ${_formatSideLatex(effectiveRight)}',
    );
  }
}
