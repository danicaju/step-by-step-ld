import 'dart:math' as math;
import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

class QuadraticEquationSolver {
  /// Resuelve la ecuación ax² + bx + c = 0 siguiendo el estándar pedagógico de ESO/Bachillerato
  static StepByStepResolution solve({
    required int a,
    required int b,
    required int c,
  }) {
    if (a == 0) {
      throw ArgumentError(
          'El coeficiente "a" no puede ser cero en una ecuación de 2.º grado.');
    }

    final originalLatex = '${AlgebraicLatexFormatter.quadraticExpression(a, b, c)} = 0';

    // 1. CASO INCOMPLETA PURA: b = 0 (ej: 2x² - 18 = 0)
    if (b == 0 && c != 0) {
      return _solvePureIncomplete(a, c, originalLatex);
    }

    // 2. CASO INCOMPLETA MIXTA: c = 0 (ej: 3x² - 12x = 0)
    if (c == 0 && b != 0) {
      return _solveMixedIncomplete(a, b, originalLatex);
    }

    // Caso degenerado: b = 0 y c = 0 (ax² = 0)
    if (b == 0 && c == 0) {
      return _solveTrivial(a, originalLatex);
    }

    // 3. CASO COMPLETA: a != 0, b != 0, c != 0
    return _solveComplete(a, b, c, originalLatex);
  }

  /// Incompleta pura (b = 0): ax² + c = 0 -> Despeje directo
  static StepByStepResolution _solvePureIncomplete(
      int a, int c, String originalLatex) {
    final List<MathStep> steps = [];

    // Paso 1: Transponer término independiente
    final negC = -c;
    final lhsTerm = AlgebraicLatexFormatter.monomialTerm(a, 'x', power: 2);
    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Transponer el término independiente',
        latexExpression: '$lhsTerm = $negC',
        pedagogicalNote:
            'Resolución directa sin fórmula general: al no haber término en x (b = 0), despejamos directamente x².',
      ),
    );

    // Paso 2: Despejar x² (solo si a != 1)
    final rawFraction = Rational.raw(negC, a);
    final simplifiedFraction = rawFraction.simplify();

    if (a != 1) {
      final unsimplifiedLatex = AlgebraicLatexFormatter.signedFraction(negC, a);
      final simplifiedLatex = simplifiedFraction.toLatex();
      final eqLatex = (a == -1 || unsimplifiedLatex == simplifiedLatex)
          ? 'x^2 = $simplifiedLatex'
          : 'x^2 = $unsimplifiedLatex = $simplifiedLatex';
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Despejar x²',
          latexExpression: eqLatex,
          pedagogicalNote: a == -1
              ? 'Multiplicamos ambos miembros por -1 para dejar x² positivo.'
              : 'Dividimos entre el coeficiente $a para aislar x² en el miembro izquierdo.',
        ),
      );
    }

    // Si el cociente es negativo, no hay soluciones reales
    if (simplifiedFraction.numerator < 0) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Sin solución real',
          latexExpression:
              'x = \\pm\\sqrt{${simplifiedFraction.toLatex()}} \\implies \\text{Sin solucion real}',
          pedagogicalNote:
              'No existe ningún número real cuyo cuadrado sea negativo, por lo que la ecuación no tiene soluciones reales.',
          warningTrick:
              'Un número real al cuadrado nunca puede ser negativo.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: r'\text{Sin solucion real}',
        decimalApproxLatex: r'\text{Sin sol}',
      );
    }

    // Si es cuadrado perfecto entero
    if (simplifiedFraction.denominator == 1) {
      final int val = simplifiedFraction.numerator;
      final rootInt = math.sqrt(val).toInt();
      if (rootInt * rootInt == val) {
        steps.add(
          MathStep(
            index: steps.length + 1,
            shortTitle: 'Extraer raíz cuadrada a ambos lados',
            latexExpression:
                'x = \\pm\\sqrt{$val} \\implies x_1 = $rootInt, \\; x_2 = -$rootInt',
            pedagogicalNote:
                'Al sacar la raíz cuadrada siempre surgen dos soluciones con signos opuestos: la rama positiva y la rama negativa (±).',
            warningTrick:
                'La raíz cuadrada produce dos soluciones reales de signo opuesto: +$rootInt y -$rootInt.',
          ),
        );
        return StepByStepResolution(
          originalInputLatex: originalLatex,
          steps: steps,
          exactResultLatex: 'x_1 = $rootInt, \\; x_2 = -$rootInt',
          decimalApproxLatex: 'x_1 = $rootInt, \\; x_2 = -$rootInt',
        );
      }
    }

    final dec = math.sqrt(simplifiedFraction.numerator / simplifiedFraction.denominator)
        .toStringAsFixed(6)
        .replaceAll('.', ',');

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Extraer raíz cuadrada',
        latexExpression:
            'x = \\pm\\sqrt{${simplifiedFraction.toLatex()}}',
        pedagogicalNote:
            'Expresamos las dos soluciones en forma de radical exacto irreducible.',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'x = \\pm\\sqrt{${simplifiedFraction.toLatex()}}',
      decimalApproxLatex: '\\pm $dec',
    );
  }

  /// Incompleta mixta (c = 0): ax² + bx = 0 -> Factor común x
  static StepByStepResolution _solveMixedIncomplete(
      int a, int b, String originalLatex) {
    final List<MathStep> steps = [];

    // Paso 1: Sacar factor común x
    final linearInside = AlgebraicLatexFormatter.linearExpression(a, b);
    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Extraer factor común x',
        latexExpression: 'x \\cdot ($linearInside) = 0',
        pedagogicalNote:
            'Resolución directa sin fórmula general: al no haber término independiente (c = 0), sacamos factor común x. '
            'Un producto es igual a cero si y solo si al menos uno de sus factores es nulo.',
      ),
    );

    // Paso 2: Aplicar el teorema del producto nulo
    final rawRoot2 = Rational.raw(-b, a);
    final simplifiedRoot2 = rawRoot2.simplify();
    final simpLatex = simplifiedRoot2.toLatex();

    final String branch2Latex;
    if (a == 1) {
      branch2Latex = '$linearInside = 0 \\implies x_2 = $simpLatex';
    } else if (a == -1) {
      branch2Latex = '$linearInside = 0 \\implies -x = ${-b} \\implies x_2 = $simpLatex';
    } else {
      final aX = AlgebraicLatexFormatter.monomialTerm(a, 'x');
      final rawFrac = AlgebraicLatexFormatter.signedFraction(-b, a);
      final solChain = rawFrac == simpLatex ? simpLatex : '$rawFrac = $simpLatex';
      branch2Latex = '$linearInside = 0 \\implies $aX = ${-b} \\implies x_2 = $solChain';
    }

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Separar los dos factores igualados a cero',
        latexExpression:
            '\\begin{cases} x_1 = 0 \\\\ $branch2Latex \\end{cases}',
        pedagogicalNote:
            'El primer factor nos da directamente la primera solución: x₁ = 0. '
            'El segundo factor es una ecuación de primer grado que despejamos para obtener x₂.',
        warningTrick:
            'En toda ecuación cuadrática sin término independiente (c = 0), una de las soluciones siempre es x = 0.',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'x_1 = 0, \\; x_2 = $simpLatex',
      decimalApproxLatex: 'x_1 = 0, \\; x_2 = ${simplifiedRoot2.toDecimalLatex()}',
    );
  }

  /// Caso trivial: ax² = 0
  static StepByStepResolution _solveTrivial(int a, String originalLatex) {
    final steps = [
      MathStep(
        index: 1,
        shortTitle: 'Solución doble en el origen',
        latexExpression: 'x^2 = 0 \\implies x_1 = x_2 = 0',
        pedagogicalNote: 'La única solución real es x = 0 (con multiplicidad 2).',
      ),
    ];
    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'x_1 = x_2 = 0',
      decimalApproxLatex: '0',
    );
  }

  /// Caso completa: ax² + bx + c = 0 -> Fórmula general
  static StepByStepResolution _solveComplete(
      int a, int b, int c, String originalLatex) {
    final List<MathStep> steps = [];

    // Paso 1: Identificación explícita de coeficientes
    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Identificación de los coeficientes',
        latexExpression: 'a = $a, \\quad b = $b, \\quad c = $c',
        pedagogicalNote:
            'Identificamos los coeficientes a (término en x²), b (término en x) y c (término independiente) respetando escrupulosamente sus signos.',
      ),
    );

    // Paso 2: Sustitución literal en la fórmula general
    final bParen = b < 0 ? '($b)' : '$b';
    final aParen = a < 0 ? '($a)' : '$a';
    final cParen = c < 0 ? '($c)' : '$c';
    final bSquared = b * b;
    final fourAC = 4 * a * c;
    final twoA = 2 * a;
    final discriminant = bSquared - fourAC;

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Sustitución literal en la fórmula general',
        latexExpression:
            'x = \\frac{-$bParen \\pm \\sqrt{$bParen^2 - 4 \\cdot $aParen \\cdot $cParen}}{2 \\cdot $aParen}',
        pedagogicalNote:
            'Aplicamos la fórmula general: x = (-b ± √(b² - 4ac)) / (2a). '
            'Encerramos siempre los números negativos entre paréntesis para no cometer fallos de signo.',
        warningTrick: b < 0
            ? 'Como b = $b es negativo, aplicamos la regla de signos: -($b) = +${-b} y ($b)² = +$bSquared.'
            : null,
      ),
    );

    // Paso 3: Cálculo del discriminante Delta
    final String discType;
    if (discriminant > 0) {
      discType = '\\Delta > 0 \\implies \\text{Existen 2 soluciones reales distintas.}';
    } else if (discriminant == 0) {
      discType = '\\Delta = 0 \\implies \\text{Existe 1 solucion real doble } (x_1 = x_2)';
    } else {
      discType = '\\Delta < 0 \\implies \\text{No tiene soluciones reales (raiz de numero negativo).}';
    }

    final String discNote = discriminant > 0
        ? 'El discriminante es positivo (Δ > 0): existen 2 soluciones reales distintas.'
        : (discriminant == 0
            ? 'El discriminante es cero (Δ = 0): existe 1 solución real doble (x₁ = x₂).'
            : 'El discriminante es negativo (Δ < 0): no tiene soluciones reales (raíz de número negativo).');

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Cálculo del discriminante (Δ = b² - 4ac)',
        latexExpression:
            '\\Delta = $bSquared${AlgebraicLatexFormatter.differenceTerm(fourAC)} = $discriminant \\quad ($discType)',
        pedagogicalNote: discNote,
        warningTrick: discriminant < 0
            ? 'Un discriminante negativo ($discriminant < 0) indica que la raíz cuadrada no tiene solución real.'
            : null,
      ),
    );

    if (discriminant < 0) {
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: r'\text{Sin soluciones reales}',
        decimalApproxLatex: r'\text{Sin sol}',
      );
    }

    // Paso 4: Desglose de ramas
    final sqrtDiscDouble = math.sqrt(discriminant);
    final sqrtDiscInt = sqrtDiscDouble.toInt();
    final isDiscSquare = sqrtDiscInt * sqrtDiscInt == discriminant;

    if (isDiscSquare) {
      final num1 = -b + sqrtDiscInt;
      final num2 = -b - sqrtDiscInt;

      final root1 = Rational.raw(num1, twoA).simplify();
      final root2 = Rational.raw(num2, twoA).simplify();
      final rawFrac1 = AlgebraicLatexFormatter.signedFraction(num1, twoA);
      final rawFrac2 = AlgebraicLatexFormatter.signedFraction(num2, twoA);
      final r1L = root1.toLatex();
      final r2L = root2.toLatex();
      final eq1 = rawFrac1 == r1L ? r1L : '$rawFrac1 = $r1L';
      final eq2 = rawFrac2 == r2L ? r2L : '$rawFrac2 = $r2L';

      steps.add(
        MathStep(
          index: 4,
          shortTitle: 'Desglose y cálculo de las dos soluciones',
          latexExpression:
              'x = \\frac{${-b} \\pm $sqrtDiscInt}{$twoA} \\implies '
              '\\begin{cases} '
              'x_1 = \\frac{${-b} + $sqrtDiscInt}{$twoA} = $eq1 \\\\[6pt] '
              'x_2 = \\frac{${-b} - $sqrtDiscInt}{$twoA} = $eq2 '
              '\\end{cases}',
          pedagogicalNote:
              'Separamos la rama positiva (+) y la rama negativa (-), operamos los numeradores y simplificamos cada fracción a su forma irreducible.',
        ),
      );

      final exact = root1 == root2
          ? 'x = ${root1.toLatex()}'
          : 'x_1 = ${root1.toLatex()}, \\; x_2 = ${root2.toLatex()}';
      final dec = root1 == root2
          ? root1.toDecimalLatex()
          : 'x_1 = ${root1.toDecimalLatex()}, \\; x_2 = ${root2.toDecimalLatex()}';

      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: exact,
        decimalApproxLatex: dec,
      );
    }

    // Si el discriminante no es cuadrado perfecto (radical exacto), normalizar signo del denominador
    final absTwoA = twoA.abs();
    final numBase = twoA > 0 ? -b : b;
    final numBaseStr = numBase == 0 ? '' : '$numBase ';
    final exactR1 = twoA > 0
        ? '\\frac{${-b} + \\sqrt{$discriminant}}{$absTwoA}'
        : '\\frac{${numBase == 0 ? "-" : "$numBase - "}\\sqrt{$discriminant}}{$absTwoA}';
    final exactR2 = twoA > 0
        ? '\\frac{${-b} - \\sqrt{$discriminant}}{$absTwoA}'
        : '\\frac{$numBaseStr+ \\sqrt{$discriminant}}{$absTwoA}';
    final exactPlusMinus = '\\frac{${numBase == 0 ? "" : "$numBase "}\\pm \\sqrt{$discriminant}}{$absTwoA}';

    final decRoot1 = ((-b + sqrtDiscDouble) / twoA).toStringAsFixed(6).replaceAll('.', ',');
    final decRoot2 = ((-b - sqrtDiscDouble) / twoA).toStringAsFixed(6).replaceAll('.', ',');

    steps.add(
      MathStep(
        index: 4,
        shortTitle: 'Soluciones exactas con radical',
        latexExpression: 'x_1 = $exactR1, \\quad x_2 = $exactR2',
        pedagogicalNote:
            'Al no ser el discriminante un cuadrado perfecto, expresamos el resultado exacto manteniendo el radical.',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'x = $exactPlusMinus',
      decimalApproxLatex: 'x_1 = $decRoot1, \\; x_2 = $decRoot2',
    );
  }
}
