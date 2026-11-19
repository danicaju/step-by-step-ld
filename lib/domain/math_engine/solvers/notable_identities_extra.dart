import '../models/step_resolution.dart';

/// Cubo de un binomio `(ax ± b)^3` y diferencia de cuadrados `A^2 - B^2 = (A + B)(A - B)`.
class NotableIdentitiesExtra {
  const NotableIdentitiesExtra._();

  static String _mono(int coef, int deg) {
    if (deg == 0) return '$coef';
    final x = deg == 1 ? 'x' : 'x^{$deg}';
    return coef == 1 ? x : '$coef$x';
  }

  /// `(ax + b)^3` o `(ax - b)^3` con `a, b > 0`.
  static StepByStepResolution cube({required bool minus, required int a, required int b}) {
    final aStr = a == 1 ? 'x' : '${a}x';
    final s = minus ? '-' : '+';
    final t3 = a * a * a, t2 = 3 * a * a * b, t1 = 3 * a * b * b, t0 = b * b * b;
    // (a - b)^3 = A^3 - 3A^2B + 3AB^2 - B^3  (signos alternados)
    final result = minus
        ? '${_mono(t3, 3)} - ${_mono(t2, 2)} + ${_mono(t1, 1)} - $t0'
        : '${_mono(t3, 3)} + ${_mono(t2, 2)} + ${_mono(t1, 1)} + $t0';
    final original = '($aStr $s $b)^3';
    final formula = minus
        ? r'(A - B)^3 = A^3 - 3A^2B + 3AB^2 - B^3'
        : r'(A + B)^3 = A^3 + 3A^2B + 3AB^2 + B^3';
    final sub = minus
        ? '\\left($aStr\\right)^3 - 3\\left($aStr\\right)^2($b) + 3\\left($aStr\\right)($b)^2 - ($b)^3'
        : '\\left($aStr\\right)^3 + 3\\left($aStr\\right)^2($b) + 3\\left($aStr\\right)($b)^2 + ($b)^3';
    return StepByStepResolution(
      originalInputLatex: original,
      steps: [
        MathStep(
          index: 1,
          shortTitle: '1. Identificación de la fórmula teórica',
          latexExpression: '$formula \\quad \\left(A = $aStr,\\; B = $b\\right)',
          pedagogicalNote:
              'El cubo de un binomio tiene cuatro términos: el cubo del primero, tres veces el cuadrado del primero por el segundo, tres veces el primero por el cuadrado del segundo y el cubo del segundo.',
          warningTrick: 'Error típico: (A ${minus ? '-' : '+'} B)³ NO es A³ ${minus ? '-' : '+'} B³. Faltan los dos términos con coeficiente 3.',
        ),
        MathStep(
          index: 2,
          shortTitle: '2. Sustitución literal de términos',
          latexExpression: sub,
          pedagogicalNote: 'Sustituimos A y B en la fórmula, dejando cada potencia indicada entre paréntesis.',
        ),
        MathStep(
          index: 3,
          shortTitle: '3. Calcular cada término',
          latexExpression:
              '\\begin{array}{l} A^3 = $aStr^3 = ${_mono(t3, 3)} \\\\ 3A^2B = 3 \\cdot $a^2 \\cdot $b \\cdot x^2 = ${_mono(t2, 2)} \\\\ 3AB^2 = 3 \\cdot $a \\cdot $b^2 \\cdot x = ${_mono(t1, 1)} \\\\ B^3 = $b^3 = $t0 \\end{array}',
          pedagogicalNote: 'Calculamos por separado las cuatro potencias y productos; así no se pierde ningún coeficiente.',
        ),
        MathStep(
          index: 4,
          shortTitle: '4. Resultado ordenado',
          latexExpression: '$original = $result',
          pedagogicalNote: minus
              ? 'En (A - B)³ los signos se alternan: + - + - empezando por el cubo del primer término.'
              : 'Todos los términos son positivos porque B es positivo.',
        ),
      ],
      exactResultLatex: result,
      decimalApproxLatex: result,
    );
  }

  /// `a^2 x^2 - b^2 = (ax + b)(ax - b)`; `a` y `b` son las raices cuadradas de los coeficientes.
  static StepByStepResolution differenceOfSquares({required int a, required int b}) {
    final aStr = a == 1 ? 'x' : '${a}x';
    final a2 = a * a, b2 = b * b;
    final original = '${_mono(a2, 2)} - $b2';
    final result = '($aStr + $b)($aStr - $b)';
    return StepByStepResolution(
      originalInputLatex: original,
      steps: [
        MathStep(
          index: 1,
          shortTitle: '1. Reconocer una diferencia de cuadrados',
          latexExpression: '${_mono(a2, 2)} = \\left($aStr\\right)^2,\\quad $b2 = $b^2 \\;\\Rightarrow\\; A^2 - B^2 \\quad \\left(A = $aStr,\\; B = $b\\right)',
          pedagogicalNote:
              'Dos términos con signo menos y que son cuadrados perfectos: calculamos la raíz cuadrada de cada uno para obtener A y B.',
        ),
        MathStep(
          index: 2,
          shortTitle: '2. Aplicar A² - B² = (A + B)(A - B)',
          latexExpression: 'A^2 - B^2 = (A + B)(A - B) \\;\\Rightarrow\\; $result',
          pedagogicalNote: 'Una diferencia de cuadrados se factoriza como suma por diferencia de las raíces.',
        ),
        MathStep(
          index: 3,
          shortTitle: '3. Comprobación multiplicando',
          latexExpression: '$result = \\left($aStr\\right)^2 - $b^2 = $original',
          pedagogicalNote: 'Al multiplicar suma por diferencia, los productos cruzados se anulan y vuelve la expresión inicial.',
          warningTrick: 'Una SUMA de cuadrados (A² + B²) no se factoriza en los números reales.',
        ),
      ],
      exactResultLatex: result,
      decimalApproxLatex: result,
    );
  }
}
