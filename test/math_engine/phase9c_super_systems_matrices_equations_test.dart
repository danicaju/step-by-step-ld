import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_system_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/matrix_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/super_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/polynomial_equation_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Actualización 9C: 1. Sistemas de Ecuaciones (2, 3 y 4 Ec. con Entrada Desordenada)', () {
    test('Parser de entrada desordenada agrupa incógnitas a la izquierda y constantes a la derecha', () {
      final parsed = LinearSystemSolver.parseUnorderedEquation(
        '2y + 3x - 5 = x + 1',
        vars: ['x', 'y', 'z', 'w'],
      );

      expect(parsed.coefficients['x'], equals(Rational(2)));
      expect(parsed.coefficients['y'], equals(Rational(2)));
      expect(parsed.constant, equals(Rational(6)));
      expect(parsed.orderedLatex, contains('2x + 2y = 6'));
    });

    test('Parser maneja paréntesis y signos negativos en ambos miembros', () {
      final parsed = LinearSystemSolver.parseUnorderedEquation(
        '2*(x - 1) + 3y = 4*y - 8',
        vars: ['x', 'y'],
      );

      // 2x - 2 + 3y = 4y - 8 => 2x - y = -6
      expect(parsed.coefficients['x'], equals(Rational(2)));
      expect(parsed.coefficients['y'], equals(Rational(-1)));
      expect(parsed.constant, equals(Rational(-6)));
    });

    test('Sistema 2x2 con entrada desordenada incluye paso pedagógico de reordenación', () {
      final res = LinearSystemSolver.solveFromEquations([
        '2y + 3x - 5 = x + 1', // 2x + 2y = 6 => x + y = 3
        'x - y = 1',
      ], method: SystemResolutionMethod.reduccion);

      expect(res.steps.first.shortTitle, contains('Reordenacion'));
      expect(res.exactResultLatex, contains('x = 2'));
      expect(res.exactResultLatex, contains('y = 1'));
    });

    test('Sistema 3x3 se resuelve limpiamente por Reducción progresiva', () {
      // x + y + z = 6
      // x - y + z = 2
      // 2x + y - z = 1
      final rows = [
        [Rational(1), Rational(1), Rational(1), Rational(6)],
        [Rational(1), Rational(-1), Rational(1), Rational(2)],
        [Rational(2), Rational(1), Rational(-1), Rational(1)],
      ];

      final res = LinearSystemSolver.solveNxN(
        augmentedRows: rows,
        method: SystemResolutionMethod.reduccion,
      );

      expect(res.steps.length, greaterThanOrEqualTo(3));
      expect(res.exactResultLatex, contains('x = 1'));
      expect(res.exactResultLatex, contains('y = 2'));
      expect(res.exactResultLatex, contains('z = 3'));
    });

    test('Sistema 4x4 se resuelve con 4 incógnitas (x, y, z, w)', () {
      // x + y + z + w = 10
      // x - y + z - w = -2
      // 2x + y - z + w = 5
      // 3x - 2y + 2z + w = 9
      final rows = [
        [Rational(1), Rational(1), Rational(1), Rational(1), Rational(10)],
        [Rational(1), Rational(-1), Rational(1), Rational(-1), Rational(-2)],
        [Rational(2), Rational(1), Rational(-1), Rational(1), Rational(5)],
        [Rational(3), Rational(-2), Rational(2), Rational(1), Rational(9)],
      ];

      final res = LinearSystemSolver.solveNxN(
        augmentedRows: rows,
        method: SystemResolutionMethod.reduccion,
      );

      expect(res.exactResultLatex, contains('x = 1'));
      expect(res.exactResultLatex, contains('y = 2'));
      expect(res.exactResultLatex, contains('z = 3'));
      expect(res.exactResultLatex, contains('w = 4'));
    });
  });

  group('Actualización 9C: 2. Matrices (Hasta 4x4, Gauss, Cramer, Transpuesta y k·A)', () {
    test('Determinante 4x4 exacto mediante desarrollo de Laplace por la fila 1', () {
      // Matriz identidad 4x4 con escala
      final mat = RationalMatrix.fromInts([
        [2, 0, 0, 0],
        [0, 3, 0, 0],
        [0, 0, 4, 0],
        [0, 0, 0, 5],
      ]);

      final det = mat.determinantValue();
      expect(det, equals(Rational(120)));

      final res = MatrixSolver.determinant(mat);
      expect(res.steps.length, equals(3));
      expect(res.steps.first.shortTitle, contains('Laplace'));
      expect(res.exactResultLatex, contains('120'));
    });

    test('Matriz Inversa y Adjunta para 4x4', () {
      final mat = RationalMatrix.fromInts([
        [1, 0, 0, 0],
        [0, 2, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1],
      ]);

      final invRes = MatrixSolver.inverse(mat);
      expect(invRes.exactResultLatex, contains(r'\frac{1}{2}'));
    });

    test('Regla de Cramer para sistema matricial A·X = B (3x3)', () {
      // A = [ [1, 1, 1], [1, -1, 1], [2, 1, -1] ]
      // B = [ 6, 2, 1 ]^t
      // Solución: x = 1, y = 2, z = 3
      final a = RationalMatrix.fromInts([
        [1, 1, 1],
        [1, -1, 1],
        [2, 1, -1],
      ]);
      final b = RationalMatrix.fromInts([
        [6],
        [2],
        [1],
      ]);

      final res = MatrixSolver.cramer(a, b);
      expect(res.steps.length, equals(3));
      expect(res.steps.first.shortTitle, contains('Determinante principal'));
      expect(res.exactResultLatex, contains('x = 1'));
      expect(res.exactResultLatex, contains('y = 2'));
      expect(res.exactResultLatex, contains('z = 3'));
    });

    test('Gauss y Rango: cálculo de matriz escalonada y clasificación', () {
      final a = RationalMatrix.fromInts([
        [1, 2, 1],
        [2, 4, 2], // proporcional
        [1, 1, 3],
      ]);

      final res = MatrixSolver.gauss(a);
      expect(res.exactResultLatex, contains(r'\text{rg}(A) = 2'));
    });

    test('Visualización clara de k·A en 3 pasos exactos en la LCD', () {
      final mat = RationalMatrix.fromInts([
        [1, 2],
        [3, 4],
      ]);

      final res = MatrixSolver.scalarMultiply(Rational(3), mat);
      expect(res.steps.length, equals(3));
      // Paso 1: escalar delante
      expect(res.steps[0].shortTitle, contains('Escalar k delante'));
      expect(res.steps[0].latexExpression, startsWith('3 \\cdot'));
      // Paso 2: multiplicación elemento a elemento
      expect(res.steps[1].shortTitle, contains('Multiplicar elemento por elemento'));
      expect(res.steps[1].latexExpression, contains('3 \\cdot 1'));
      // Paso 3: resultado final
      expect(res.steps[2].shortTitle, contains('Matriz resultado simplificada'));
      expect(res.steps[2].latexExpression, contains('12'));
    });

    test('Multiplicación de matrices rectangulares A (2x3) y B (3x2)', () {
      final a = RationalMatrix.fromInts([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      final b = RationalMatrix.fromInts([
        [7, 8],
        [9, 1],
        [2, 3],
      ]);

      final res = MatrixSolver.multiply(a, b);
      expect(res.steps.length, equals(3));
      // Fila 1 Col 1: 1*7 + 2*9 + 3*2 = 7 + 18 + 6 = 31
      expect(res.exactResultLatex, contains('31'));
    });

    test('Ocultar MatB en operaciones unarias', () {
      expect(MatrixOperation.determinant.needsMatrixB, isFalse);
      expect(MatrixOperation.inverse.needsMatrixB, isFalse);
      expect(MatrixOperation.adjoint.needsMatrixB, isFalse);
      expect(MatrixOperation.transpose.needsMatrixB, isFalse);
      expect(MatrixOperation.scalarMultiply.needsMatrixB, isFalse);
      expect(MatrixOperation.gauss.needsMatrixB, isFalse);
      // Solo binarias
      expect(MatrixOperation.multiply.needsMatrixB, isTrue);
      expect(MatrixOperation.add.needsMatrixB, isTrue);
      expect(MatrixOperation.subtract.needsMatrixB, isTrue);
      expect(MatrixOperation.cramer.needsMatrixB, isTrue);
    });
  });

  group('Actualización 9C: 3. Súper-Solver de Ecuaciones (Exponenciales, Logarítmicas, Irracionales, Bicuadradas y Racionales)', () {
    test('Ecuación Exponencial por igualación de bases: 2^{x+1} = 8', () {
      final res = SuperEquationSolver.solve('2^{x+1} = 8');
      expect(res.exactResultLatex, equals('x = 2'));
    });

    test('Ecuación Exponencial con potencias negativas: 3^{2x-1} = 1/27', () {
      final res = SuperEquationSolver.solve('3^{2x-1} = 1/27');
      expect(res.exactResultLatex, contains('-1'));
    });

    test('Ecuación Exponencial por cambio de variable t = 2^x: 4^x - 5*2^x + 4 = 0', () {
      final res = SuperEquationSolver.solve('4^x - 5*2^x + 4 = 0');
      expect(res.steps.first.shortTitle, contains('Cambio de variable'));
      expect(res.exactResultLatex, contains('2'));
      expect(res.exactResultLatex, contains('0'));
    });

    test('Ecuación Exponencial con bases distintas tomando logaritmos: 5^x = 7', () {
      final res = SuperEquationSolver.solve('5^x = 7');
      expect(res.exactResultLatex, contains(r'\frac{\ln(7)}{\ln(5)}'));
    });

    test('Ecuación Logarítmica por inyectividad: ln(2x - 1) = ln(x + 5)', () {
      final res = SuperEquationSolver.solve(r'\ln(2x - 1) = \ln(x + 5)');
      expect(res.exactResultLatex, contains('x = 6'));
    });

    test('Ecuación Logarítmica descarta obligatoriamente raíces con argumento <= 0', () {
      // log(x) + log(x - 3) = 1  => x(x - 3) = 10 => x^2 - 3x - 10 = 0 => x = 5, x = -2 (descartada)
      final res = SuperEquationSolver.solve(r'\log(x) + \log(x - 3) = 1');
      expect(res.steps.last.shortTitle, contains('Argumentos > 0'));
      expect(res.steps.last.latexExpression, contains('Descartada'));
      expect(res.exactResultLatex, equals('x = 5'));
    });

    test('Ecuación Irracional aislando radical y descartando raíz extraña en comprobación', () {
      // \sqrt{2x + 3} = x => 2x + 3 = x^2 => x^2 - 2x - 3 = 0 => x = 3 (válida), x = -1 (extraña)
      final res = SuperEquationSolver.solve(r'\sqrt{2x + 3} = x');
      expect(res.steps[0].shortTitle, contains('Aislar el radical'));
      expect(res.steps[1].shortTitle, contains('Elevar al cuadrado'));
      expect(res.steps.last.shortTitle, contains('Comprobacion obligatoria'));
      expect(res.steps.last.latexExpression, anyOf(contains('extraña'), contains('extrana')));
      expect(res.exactResultLatex, equals('x = 3'));
    });

    test('Ecuación Bicuadrada con cambio t = x²: x^4 - 5x^2 + 4 = 0', () {
      final res = SuperEquationSolver.solve('x^4 - 5x^2 + 4 = 0');
      expect(res.steps.first.shortTitle, contains('Cambio de variable t = x²'));
      expect(res.exactResultLatex, contains('x = -2'));
      expect(res.exactResultLatex, contains('x = -1'));
      expect(res.exactResultLatex, contains('x = 1'));
      expect(res.exactResultLatex, contains('x = 2'));
    });

    test('Ecuación Racional con x en denominador', () {
      final res = SuperEquationSolver.solve(r'\frac{2x}{x-1} = 3');
      expect(res.steps.first.shortTitle, contains('valores prohibidos'));
      expect(res.exactResultLatex, contains('x = 3'));
    });

    test('PolynomialEquationSolver delega automáticamente en SuperEquationSolver para irracionales y exponenciales', () {
      final resIrr = PolynomialEquationSolver.solveEquationString(r'\sqrt{2x + 3} = x');
      expect(resIrr.exactResultLatex, equals('x = 3'));

      final resExp = PolynomialEquationSolver.solveEquationString('2^{x+1} = 8');
      expect(resExp.exactResultLatex, equals('x = 2'));
    });

    test('Regla de oro: Cero tildes y caracteres no ASCII dentro de \\text{...}', () {
      final solvers = [
        SuperEquationSolver.solve(r'\sqrt{2x + 3} = x'),
        SuperEquationSolver.solve(r'\log(x) + \log(x - 3) = 1'),
        SuperEquationSolver.solve('4^x - 5*2^x + 4 = 0'),
        SuperEquationSolver.solve('x^4 - 5x^2 + 4 = 0'),
      ];

      for (final res in solvers) {
        for (final step in res.steps) {
          final latex = step.latexExpression;
          final matches = RegExp(r'\\text\{([^}]+)\}').allMatches(latex);
          for (final m in matches) {
            final inner = m.group(1)!;
            expect(
              RegExp(r'[áéíóúÁÉÍÓÚñÑ¿¡]').hasMatch(inner),
              isFalse,
              reason: 'Caracter prohibido en \\text{$inner} del paso: ${step.shortTitle}',
            );
          }
        }
      }
    });
  });
}
