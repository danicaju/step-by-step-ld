import '../models/step_resolution.dart';

enum NotableIdentityType {
  squareOfSum('Cuadrado de una suma: (a + b)²'),
  squareOfDiff('Cuadrado de una resta: (a - b)²'),
  sumTimesDiff('Suma por diferencia: (a + b)(a - b)');

  final String displayName;
  const NotableIdentityType(this.displayName);
}

class NotableIdentitiesSolver {
  /// Desarrolla paso a paso una identidad notable con coeficientes enteros (ax ± b)
  static StepByStepResolution solve({
    required NotableIdentityType type,
    required int aCoeff,
    required int bConst,
  }) {
    if (aCoeff == 0) {
      throw ArgumentError('El coeficiente de x no puede ser cero.');
    }
    if (bConst == 0) {
      throw ArgumentError('El término independiente no puede ser cero.');
    }

    final int a = aCoeff.abs();
    final int b = bConst.abs();
    final aStr = a == 1 ? 'x' : '${a}x';

    final int aSquared = a * a;
    final int bSquared = b * b;
    final int doubleAB = 2 * a * b;

    final a2Term = aSquared == 1 ? 'x^2' : '${aSquared}x^2';

    final List<MathStep> steps = [];
    final String originalLatex;
    final String exactResultLatex;

    switch (type) {
      case NotableIdentityType.squareOfSum:
        originalLatex = '($aStr + $b)^2';
        exactResultLatex = '$a2Term + ${doubleAB}x + $bSquared';

        steps.add(
          MathStep(
            index: 1,
            shortTitle: '1. Identificación de la fórmula teórica',
            latexExpression:
                '(A + B)^2 = A^2 + 2 \\cdot A \\cdot B + B^2 \\quad \\left(A = $aStr, \\; B = $b\\right)',
            pedagogicalNote:
                'El cuadrado de una suma es igual al cuadrado del primer término, más el doble producto del primero por el segundo, más el cuadrado del segundo término.',
            warningTrick:
                'El desarrollo es (A + B)² ≠ A² + B²: siempre debe incluirse el doble producto 2 · A · B.',
          ),
        );

        steps.add(
          MathStep(
            index: 2,
            shortTitle: '2. Sustitución literal de términos',
            latexExpression:
                '\\left($aStr\\right)^2 + 2 \\cdot \\left($aStr\\right) \\cdot ($b) + ($b)^2',
            pedagogicalNote:
                'Sustituimos cada término entre paréntesis para evitar errores de cálculo en exponentes y coeficientes.',
          ),
        );

        steps.add(
          MathStep(
            index: 3,
            shortTitle: '3. Operar monomios y potencias',
            latexExpression:
                '\\left($aStr\\right)^2 + 2 \\cdot \\left($aStr\\right) \\cdot ($b) + ($b)^2 = $exactResultLatex',
            pedagogicalNote:
                'Calculamos ($aStr)² = $a2Term, el doble producto 2 · ($aStr) · $b = ${doubleAB}x, y $b² = $bSquared.',
          ),
        );
        break;

      case NotableIdentityType.squareOfDiff:
        originalLatex = '($aStr - $b)^2';
        exactResultLatex = '$a2Term - ${doubleAB}x + $bSquared';

        steps.add(
          MathStep(
            index: 1,
            shortTitle: '1. Identificación de la fórmula teórica',
            latexExpression:
                '(A - B)^2 = A^2 - 2 \\cdot A \\cdot B + B^2 \\quad \\left(A = $aStr, \\; B = $b\\right)',
            pedagogicalNote:
                'El cuadrado de una resta es igual al cuadrado del primer término, menos el doble producto, más el cuadrado del segundo término.',
            warningTrick:
                'El desarrollo es (A - B)² ≠ A² - B²: el término central resta (-2·A·B) y el cuadrado final siempre suma (+B²).',
          ),
        );

        steps.add(
          MathStep(
            index: 2,
            shortTitle: '2. Sustitución literal de términos',
            latexExpression:
                '\\left($aStr\\right)^2 - 2 \\cdot \\left($aStr\\right) \\cdot ($b) + ($b)^2',
            pedagogicalNote:
                'Colocamos los signos de la regla: signo negativo solo en el doble producto central.',
          ),
        );

        steps.add(
          MathStep(
            index: 3,
            shortTitle: '3. Operar monomios y potencias',
            latexExpression:
                '\\left($aStr\\right)^2 - 2 \\cdot \\left($aStr\\right) \\cdot ($b) + ($b)^2 = $exactResultLatex',
            pedagogicalNote:
                'Calculamos cada término por separado obteniendo el trinomio cuadrado perfecto resultante.',
          ),
        );
        break;

      case NotableIdentityType.sumTimesDiff:
        originalLatex = '($aStr + $b)($aStr - $b)';
        exactResultLatex = '$a2Term - $bSquared';

        steps.add(
          MathStep(
            index: 1,
            shortTitle: '1. Identificación de la fórmula teórica',
            latexExpression:
                '(A + B)(A - B) = A^2 - B^2 \\quad \\left(A = $aStr, \\; B = $b\\right)',
            pedagogicalNote:
                'Suma por diferencia es igual a diferencia de cuadrados. Los productos cruzados (+AB y -AB) se anulan.',
            warningTrick:
                'En suma por diferencia NO hay término central con x: queda únicamente una diferencia de cuadrados (A² - B²).',
          ),
        );

        steps.add(
          MathStep(
            index: 2,
            shortTitle: '2. Sustitución literal de términos',
            latexExpression: '\\left($aStr\\right)^2 - ($b)^2',
            pedagogicalNote:
                'Elevamos al cuadrado el primer término y restamos el cuadrado del segundo.',
          ),
        );

        steps.add(
          MathStep(
            index: 3,
            shortTitle: '3. Operar potencias',
            latexExpression:
                '\\left($aStr\\right)^2 - ($b)^2 = $exactResultLatex',
            pedagogicalNote:
                'Calculamos ($aStr)² = $a2Term y $b² = $bSquared, obteniendo el binomio final irreducible.',
          ),
        );
        break;
    }

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: exactResultLatex,
      decimalApproxLatex: exactResultLatex,
    );
  }

  /// Parsea y resuelve una expresión de identidad notable:
  /// (ax + b)², (ax - b)², (ax + b)(ax - b), (ax - b)(ax + b)
  static StepByStepResolution solveExpressionString(String expression) {
    String s = expression.replaceAll(' ', '');
    if (s.isEmpty || s == '0') {
      throw const FormatException('Expresión de identidad notable vacía');
    }

    // Normalizar potencias como ^2 o ²
    // Caso 1: (ax ± b)² o (ax ± b)^2
    final squareRegex = RegExp(
      r'^\(([+-]?\d*)x([+-]\d+)\)(?:\^2|²)$',
      caseSensitive: false,
    );
    final mSquare = squareRegex.firstMatch(s);
    if (mSquare != null) {
      final aStr = mSquare.group(1)!;
      final bStr = mSquare.group(2)!;
      int a = 1;
      if (aStr == '-' || aStr == '-1') {
        a = 1;
      } else if (aStr.isNotEmpty && aStr != '+') {
        a = int.tryParse(aStr) ?? 1;
      }
      final bVal = int.tryParse(bStr) ?? 1;
      final isMinus = bVal < 0;
      return solve(
        type: isMinus
            ? NotableIdentityType.squareOfDiff
            : NotableIdentityType.squareOfSum,
        aCoeff: a == 0 ? 1 : a.abs(),
        bConst: bVal.abs() == 0 ? 1 : bVal.abs(),
      );
    }

    // Caso 2: (ax + b)(ax - b) o (ax - b)(ax + b)
    final diffRegex = RegExp(
      r'^\(([+-]?\d*)x([+-]\d+)\)\*?\(([+-]?\d*)x([+-]\d+)\)$',
      caseSensitive: false,
    );
    final mDiff = diffRegex.firstMatch(s);
    if (mDiff != null) {
      final a1Str = mDiff.group(1)!;
      final b1Str = mDiff.group(2)!;
      int a = 1;
      if (a1Str == '-' || a1Str == '-1') {
        a = 1;
      } else if (a1Str.isNotEmpty && a1Str != '+') {
        a = int.tryParse(a1Str) ?? 1;
      }
      final b1Val = int.tryParse(b1Str) ?? 1;
      return solve(
        type: NotableIdentityType.sumTimesDiff,
        aCoeff: a == 0 ? 1 : a.abs(),
        bConst: b1Val.abs() == 0 ? 1 : b1Val.abs(),
      );
    }

    // Caso 3: Entrada simplificada de binomio sin paréntesis final o simple (ej: ax + b)
    final simpleRegex =
        RegExp(r'^\(?([+-]?\d*)x([+-]\d+)\)?$', caseSensitive: false);
    final mSimple = simpleRegex.firstMatch(s);
    if (mSimple != null) {
      final aStr = mSimple.group(1)!;
      final bStr = mSimple.group(2)!;
      int a = 1;
      if (aStr == '-' || aStr == '-1') {
        a = 1;
      } else if (aStr.isNotEmpty && aStr != '+') {
        a = int.tryParse(aStr) ?? 1;
      }
      final bVal = int.tryParse(bStr) ?? 1;
      return solve(
        type: bVal < 0
            ? NotableIdentityType.squareOfDiff
            : NotableIdentityType.squareOfSum,
        aCoeff: a == 0 ? 1 : a.abs(),
        bConst: bVal.abs() == 0 ? 1 : bVal.abs(),
      );
    }

    throw const FormatException(
      'Formato no reconocido. Usa (ax + b)², (ax - b)² o (ax + b)(ax - b)',
    );
  }
}
