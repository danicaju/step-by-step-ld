import '../core/algebraic_latex_formatter.dart';
import '../models/step_resolution.dart';
import 'ruffini_solver.dart';

/// División de un polinomio entre `(x - r)` con la regla de Ruffini: cociente `C(x)` y resto `R`
/// (`P(x) = (x - r) · C(x) + R`), con la tabla construida columna a columna como en la pizarra.
class RuffiniDivision {
  const RuffiniDivision._();

  static String _poly(List<int> c) => RuffiniSolver.polynomialToLatex(c);

  /// Polinomio completo (con `0x^k`) para alinear columnas.
  static String _complete(List<int> c) {
    final n = c.length - 1;
    final buf = StringBuffer();
    for (var i = 0; i < c.length; i++) {
      final deg = n - i;
      final abs = c[i].abs();
      final body = deg == 0
          ? '$abs'
          : (deg == 1 ? '${abs == 1 ? '' : abs}x' : '${abs == 1 ? '' : abs}x^{$deg}');
      if (i == 0) {
        buf.write(c[i] < 0 ? '-$body' : body);
      } else {
        buf.write(c[i] < 0 ? ' - $body' : ' + $body');
      }
    }
    return buf.toString();
  }

  /// Tabla parcial: solo las primeras [filled] columnas del cociente.
  static String _table(List<int> coeffs, int root, List<int> products, List<int> sums, int filled, {bool withRemainder = false}) {
    final n = coeffs.length;
    final row2 = [for (var i = 0; i < n - 1; i++) i < filled - 1 ? '${products[i]}' : ''];
    final row3 = [for (var i = 0; i < n; i++) i < filled ? '${sums[i]}' : ''];
    if (withRemainder && filled == n) row3[n - 1] = '\\boxed{${sums[n - 1]}}';
    return '\\begin{array}{r|${'r' * n}}\n'
        ' & ${coeffs.join(' & ')} \\\\\n'
        '$root & & ${row2.join(' & ')} \\\\\n'
        '\\hline\n'
        ' & ${row3.join(' & ')}\n'
        '\\end{array}';
  }

  static StepByStepResolution divide(List<int> input, int root) {
    final coeffs = List<int>.from(input);
    while (coeffs.length > 1 && coeffs.first == 0) {
      coeffs.removeAt(0);
    }
    if (coeffs.length < 2) {
      throw const FormatException('Para dividir entre (x - r) el polinomio necesita grado 1 o más.');
    }
    final n = coeffs.length;
    final products = <int>[];
    final sums = <int>[coeffs.first];
    for (var i = 1; i < n; i++) {
      products.add(sums[i - 1] * root);
      sums.add(coeffs[i] + products[i - 1]);
    }
    final remainder = sums.last;
    final quotient = sums.sublist(0, n - 1);
    final divisor = AlgebraicLatexFormatter.linearFactor(root);
    final qLatex = _poly(quotient);
    final missing = [for (var i = 1; i < n - 1; i++) if (coeffs[i] == 0) n - 1 - i];
    final given = '\\left(${_poly(coeffs)}\\right) : $divisor';

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: '1. Planteamiento de la división',
        latexExpression: 'P(x) = ${_poly(coeffs)}, \\quad \\text{divisor: } $divisor \\;\\Rightarrow\\; r = $root',
        pedagogicalNote:
            'La regla de Ruffini sirve para dividir un polinomio entre (x - r). La raíz que va en la tabla es r = $root (el valor que anula el divisor; cambia el signo respecto a ${divisor.replaceAll(RegExp(r'[()]'), '')}).',
      ),
    ];
    if (missing.isNotEmpty) {
      steps.add(MathStep(
        index: steps.length + 1,
        shortTitle: '${steps.length + 1}. Completar el polinomio con ceros',
        latexExpression: 'P(x) = ${_complete(coeffs)}',
        pedagogicalNote:
            'Faltan los términos de grado ${missing.join(', ')}. Hay que escribir un 0 en la tabla para cada grado ausente, si no las columnas se desalinean.',
        warningTrick: 'Error de examen: olvidar el 0 de un grado ausente.',
      ));
    }
    steps.add(MathStep(
      index: steps.length + 1,
      shortTitle: '${steps.length + 1}. Montar la tabla: bajar el primer coeficiente',
      latexExpression: _table(coeffs, root, products, sums, 1),
      pedagogicalNote:
          'Escribimos los coeficientes en la fila superior y la raíz $root a la izquierda. El primer coeficiente (${coeffs.first}) se baja tal cual.',
    ));
    for (var col = 1; col < n; col++) {
      final isLast = col == n - 1;
      steps.add(MathStep(
        index: steps.length + 1,
        shortTitle: '${steps.length + 1}. ${isLast ? 'Última columna: el resto' : 'Multiplicar por la raíz y sumar'}',
        latexExpression: _table(coeffs, root, products, sums, col + 1, withRemainder: isLast),
        pedagogicalNote:
            'Multiplicamos ${sums[col - 1]} por la raíz ($root) y obtenemos ${products[col - 1]}; lo colocamos bajo ${coeffs[col]} y sumamos: ${coeffs[col]} + (${products[col - 1]}) = ${sums[col]}.',
        warningTrick: isLast
            ? (remainder == 0
                ? 'El último número es el resto: es 0, así que la división es exacta.'
                : 'El último número es el resto: no es 0, así que la división no es exacta.')
            : null,
      ));
    }
    steps.add(MathStep(
      index: steps.length + 1,
      shortTitle: '${steps.length + 1}. Cociente y resto',
      latexExpression: 'C(x) = $qLatex, \\quad R = $remainder',
      pedagogicalNote:
          'Los números de la última fila son los coeficientes del cociente (un grado menos que P(x)) y el último es el resto.',
    ));
    steps.add(MathStep(
      index: steps.length + 1,
      shortTitle: '${steps.length + 1}. Comprobación: P(x) = (x - r) · C(x) + R',
      latexExpression: '${_poly(coeffs)} = $divisor\\left($qLatex\\right) ${remainder == 0 ? '' : (remainder > 0 ? '+ $remainder' : '- ${remainder.abs()}')}'
          ' \\;\\Rightarrow\\; P($root) = $remainder',
      pedagogicalNote:
          'Teorema del resto: el resto de dividir P(x) entre (x - r) es P(r) = $remainder.',
      warningTrick: remainder == 0 ? 'Resto 0: x = $root es raíz de P(x) y (x - r) es un factor.' : null,
    ));

    return StepByStepResolution(
      originalInputLatex: given,
      steps: steps,
      exactResultLatex: 'C(x) = $qLatex,\\; R = $remainder',
      decimalApproxLatex: 'C(x) = $qLatex,\\; R = $remainder',
    );
  }
}
