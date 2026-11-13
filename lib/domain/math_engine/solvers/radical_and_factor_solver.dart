import 'dart:math' as math;
import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

class RadicalAndFactorSolver {
  /// Descomposición en factores primos (`FACT`, tecla SHIFT + FACT de Casio)
  static StepByStepResolution factorize(int n) {
    final originalLatex = '$n';
    final List<MathStep> steps = [];

    if (n <= 1) {
      steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Número sin descomposición prima',
          latexExpression: '$n = $n',
          pedagogicalNote: n == 1
              ? 'El número 1 no se considera primo ni compuesto por definición matemática.'
              : 'Solo se descomponen en factores primos los enteros positivos mayores que 1.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: '$n',
        decimalApproxLatex: '$n',
      );
    }

    // 1. Divisiones sucesivas por números primos
    int current = n;
    int divisor = 2;
    final List<String> divisionLines = [];
    final Map<int, int> primePowers = {};

    while (current > 1) {
      if (current % divisor == 0) {
        final next = current ~/ divisor;
        divisionLines.add('$current & $divisor');
        primePowers[divisor] = (primePowers[divisor] ?? 0) + 1;
        current = next;
      } else {
        divisor++;
        if (divisor * divisor > current && current > 1) {
          divisionLines.add('$current & $current');
          primePowers[current] = (primePowers[current] ?? 0) + 1;
          current = 1;
          break;
        }
      }
    }
    divisionLines.add(r'1 & \quad');

    // Paso 1: Tabla de divisiones sucesivas estilo ESO
    final tableLatex =
        '\\begin{array}{r|l}\n${divisionLines.join(r' \\ ')}\n\\end{array}';
    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Divisiones sucesivas entre números primos',
        latexExpression: tableLatex,
        pedagogicalNote:
            'Probamos los números primos en orden creciente (2, 3, 5, 7, 11...). '
            'Si es divisible, anotamos el cociente a la izquierda y repetimos hasta llegar a 1.',
      ),
    );

    // Paso 2: Agrupación en potencias
    final factorizationLatex = primePowers.entries.map((e) {
      return e.value > 1 ? '${e.key}^{${e.value}}' : '${e.key}';
    }).join(r' \cdot ');

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Expresar en potencias de factores primos',
        latexExpression: '$n = $factorizationLatex',
        pedagogicalNote:
            'Agrupamos los factores repetidos como potencias. Esta descomposición es única según el Teorema Fundamental de la Aritmética.',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: factorizationLatex,
      decimalApproxLatex: '$n',
    );
  }

  /// Simplificación y extracción de factores de una raíz cuadrada (\sqrt{n})
  static StepByStepResolution simplifySquareRoot(int n) {
    final originalLatex = '\\sqrt{$n}';
    final List<MathStep> steps = [];

    // Caso negativo: no existe en reales
    if (n < 0) {
      steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Raíz cuadrada de número negativo',
          latexExpression: '\\sqrt{$n} \\implies \\text{Sin solucion real}',
          pedagogicalNote:
              'En ESO y Bachillerato no existe la raíz cuadrada real de un número negativo.',
          warningTrick:
              'Un radicando negativo dentro de una raíz cuadrada no tiene solución real.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: r'\text{No real}',
        decimalApproxLatex: r'\text{No real}',
      );
    }

    if (n == 0 || n == 1) {
      steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Raíz inmediata',
          latexExpression: '\\sqrt{$n} = $n',
          pedagogicalNote: 'La raíz cuadrada de $n es exactamente $n.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: '$n',
        decimalApproxLatex: '$n',
      );
    }

    // Comprobar si es cuadrado perfecto
    final sqrtDouble = math.sqrt(n);
    final sqrtInt = sqrtDouble.toInt();
    final isPerfectSquare = sqrtInt * sqrtInt == n;

    if (isPerfectSquare) {
      steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Cuadrado perfecto',
          latexExpression: '\\sqrt{$n} = \\sqrt{$sqrtInt^2} = $sqrtInt',
          pedagogicalNote:
              '$n es un cuadrado perfecto ($sqrtInt · $sqrtInt = $n), por lo que la raíz se resuelve de forma entera.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: '$sqrtInt',
        decimalApproxLatex: '$sqrtInt',
      );
    }

    // Descomponer en factores primos
    int value = n;
    final Map<int, int> factors = {};
    int divisor = 2;
    while (value > 1) {
      while (value % divisor == 0) {
        factors[divisor] = (factors[divisor] ?? 0) + 1;
        value ~/= divisor;
      }
      divisor++;
      if (divisor * divisor > value && value > 1) {
        factors[value] = (factors[value] ?? 0) + 1;
        break;
      }
    }

    // Separar factores que salen fuera (cuadrados) y los que quedan dentro
    int outsideFactor = 1;
    int insideFactor = 1;
    final List<String> decomposedInside = [];

    factors.forEach((base, exp) {
      final pairs = exp ~/ 2;
      final remainder = exp % 2;

      for (int i = 0; i < pairs; i++) {
        outsideFactor *= base;
        decomposedInside.add('$base^2');
      }
      if (remainder > 0) {
        insideFactor *= base;
        decomposedInside.add('$base');
      }
    });

    // Paso 1: Factorizar el radicando
    final factLatex = Rational.primeFactorizationLatex(n);
    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Descomposición factorial del radicando',
        latexExpression: '\\sqrt{$n} = \\sqrt{$factLatex}',
        pedagogicalNote:
            'Factorizamos el número $n en factores primos para identificar potencias con exponente mayor o igual a 2.',
      ),
    );

    // Si no se puede extraer ningún factor (ej: \sqrt{15} = \sqrt{3 \cdot 5})
    if (outsideFactor == 1) {
      steps.add(
        MathStep(
          index: 2,
          shortTitle: 'Radical irreducible',
          latexExpression: '\\sqrt{$n}',
          pedagogicalNote:
              'Ningún factor primo tiene exponente 2 o superior, por lo que no es posible extraer nada fuera de la raíz.',
        ),
      );
      final dec = sqrtDouble.toStringAsFixed(6).replaceAll('.', ',');
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: '\\sqrt{$n}',
        decimalApproxLatex: dec,
      );
    }

    // Paso 2: Agrupar potencias de exponente 2
    final groupedInsideLatex = decomposedInside.join(r' \cdot ');
    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Agrupar potencias cuadradas',
        latexExpression: '\\sqrt{$n} = \\sqrt{$groupedInsideLatex}',
        pedagogicalNote:
            'Separamos los exponentes pares para aplicar la propiedad: √(a² · b) = a·√b.',
      ),
    );

    // Paso 3: Extraer factores fuera del radical
    final String exactLatex = AlgebraicLatexFormatter.radical(
      outsideFactor,
      insideFactor,
    );

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Extraer factores fuera del radical',
        latexExpression:
            '\\sqrt{$groupedInsideLatex} = $exactLatex',
        pedagogicalNote:
            'Dividimos el exponente de los factores cuadrados entre el índice de la raíz (2) y los sacamos multiplicando fuera.',
      ),
    );

    final dec = sqrtDouble.toStringAsFixed(6).replaceAll('.', ',');
    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: exactLatex,
      decimalApproxLatex: dec,
    );
  }
}
