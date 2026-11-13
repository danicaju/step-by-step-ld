import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_system_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/notable_identities_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/ruffini_solver.dart';

void main() {
  group('Fase 4B: Solver de Polinomios y Regla de Ruffini', () {
    test('Ruffini factoriza P(x) = x³ - 7x + 6 y detecta grado ausente x²', () {
      // Coeficientes: [1, 0, -7, 6]
      final res = RuffiniSolver.factorize([1, 0, -7, 6]);

      // Raíces esperadas: 1, 2, -3 => Factorización: (x - 1)(x - 2)(x + 3)
      expect(res.exactResultLatex, equals('(x - 1)(x - 2)(x + 3)'));

      // Paso 1: Divisores de 6 y aviso pedagógico sobre el 0 en x²
      expect(res.steps[0].latexExpression, contains(r'\text{Divisores de } 6'));
      expect(res.steps[0].warningTrick, isNotNull);
      expect(res.steps[0].warningTrick, contains('0 en la tabla de Ruffini'));

      // Paso 2: Tabla de Ruffini en LaTeX con formato array
      final ruffiniStep = res.steps.firstWhere(
        (s) => s.shortTitle.contains('Tabla de Ruffini'),
      );
      expect(ruffiniStep.latexExpression, contains(r'\begin{array}{r|rrrr}'));
      expect(ruffiniStep.latexExpression, contains(r'\boxed{0}'));
      expect(ruffiniStep.warningTrick, isNotNull);
      expect(ruffiniStep.warningTrick, contains('cambia el signo de la raíz'));

      // Último paso: Factorización completa y lista de raíces
      expect(res.steps.last.latexExpression, contains('(x - 1)(x - 2)(x + 3)'));
      expect(res.decimalApproxLatex, contains('x = 1'));
      expect(res.decimalApproxLatex, contains('x = 2'));
      expect(res.decimalApproxLatex, contains('x = -3'));
    });

    test('Ruffini con polinomio de grado 4 bicuadrado: x⁴ - 5x² + 4', () {
      final res = RuffiniSolver.factorize([1, 0, -5, 0, 4]);

      // Raíces: 1, -1, 2, -2
      expect(res.exactResultLatex, contains('(x - 1)'));
      expect(res.exactResultLatex, contains('(x + 1)'));
      expect(res.exactResultLatex, contains('(x - 2)'));
      expect(res.exactResultLatex, contains('(x + 2)'));

      // Alerta de examen para grados ausentes x³ y x
      expect(res.steps[0].warningTrick, contains('x³'));
      expect(res.steps[0].warningTrick, contains('x'));
    });

    test('Ruffini grado 6: x⁶ - 14x⁴ + 49x² - 36 factoriza todas las raíces', () {
      final res = RuffiniSolver.factorize([1, 0, -14, 0, 49, 0, -36]);

      expect(res.exactResultLatex, contains('(x - 1)'));
      expect(res.exactResultLatex, contains('(x + 1)'));
      expect(res.exactResultLatex, contains('(x - 2)'));
      expect(res.exactResultLatex, contains('(x + 2)'));
      expect(res.exactResultLatex, contains('(x - 3)'));
      expect(res.exactResultLatex, contains('(x + 3)'));
      expect(res.steps[0].shortTitle, contains('a₀'));
      expect(res.steps[0].warningTrick, contains('x⁵, x³, x'));
    });

    test('Ruffini grado 5 con término independiente nulo (factor común x)', () {
      final res = RuffiniSolver.factorize([1, 0, -5, 0, 4, 0]);

      expect(res.steps[0].shortTitle, contains('Sacar factor común x'));
      expect(res.exactResultLatex, startsWith('x('));
      expect(res.exactResultLatex, contains('(x - 1)'));
      expect(res.exactResultLatex, contains('(x + 2)'));
      expect(res.decimalApproxLatex, contains('x = 0'));
    });

    test('Ruffini con polinomio nulo o sin raíces', () {
      final resZero = RuffiniSolver.factorize([0, 0]);
      expect(resZero.exactResultLatex, equals('0'));

      final divisors = RuffiniSolver.getDivisors(12);
      expect(divisors, contains(1));
      expect(divisors, contains(-1));
      expect(divisors, contains(12));
      expect(divisors, contains(-12));
    });
  });

  group('Fase 4B: Solver de Sistemas 2x2 por los 3 Métodos', () {
    const int a1 = 2, b1 = 1, c1 = 7;
    const int a2 = 1, b2 = -1, c2 = 2;

    test('Método de Sustitución: 2x + y = 7, x - y = 2 => x = 3, y = 1', () {
      final res = LinearSystemSolver.solve(
        a1: a1,
        b1: b1,
        c1: c1,
        a2: a2,
        b2: b2,
        c2: c2,
        method: SystemResolutionMethod.sustitucion,
      );

      expect(res.exactResultLatex, equals(r'x = 3, \; y = 1'));
      expect(res.steps.length, equals(4));

      // Paso 1: Despejar y en la 1.ª ecuación
      expect(res.steps[0].shortTitle, contains('Despejar una incógnita'));
      expect(res.steps[0].latexExpression, contains('y = 7 - 2x'));

      // Paso 2: Sustituir en la otra ecuación
      expect(res.steps[1].shortTitle, contains('Sustituir en la otra ecuación'));
      expect(res.steps[1].latexExpression, contains(r'\textcolor{#2563EB}'));

      // Paso 3: Hallar x
      expect(res.steps[2].latexExpression, contains('x = 3'));

      // Paso 4: Hallar y
      expect(res.steps[3].latexExpression, contains('y = 7 - 2x = 1'));
    });

    test('Método de Igualación: 2x + y = 7, x - y = 2 => x = 3, y = 1', () {
      final res = LinearSystemSolver.solve(
        a1: a1,
        b1: b1,
        c1: c1,
        a2: a2,
        b2: b2,
        c2: c2,
        method: SystemResolutionMethod.igualacion,
      );

      expect(res.exactResultLatex, equals(r'x = 3, \; y = 1'));
      expect(res.steps.length, equals(4));

      // Paso 1: Despejes
      expect(res.steps[0].shortTitle, contains('Despejar la misma incógnita'));
      expect(res.steps[0].latexExpression, contains(r'\begin{cases}'));

      // Paso 2: Igualar y multiplicar en cruz
      expect(res.steps[1].shortTitle, contains('Igualar expresiones y multiplicar en cruz'));

      // Paso 3 y 4: Valores
      expect(res.steps[2].latexExpression, contains('y = 1'));
      expect(res.steps[3].latexExpression, contains('x ='));
      expect(res.steps[3].latexExpression, contains('3'));
    });

    test('Método de Reducción: 2x + y = 7, x - y = 2 => x = 3, y = 1', () {
      final res = LinearSystemSolver.solve(
        a1: a1,
        b1: b1,
        c1: c1,
        a2: a2,
        b2: b2,
        c2: c2,
        method: SystemResolutionMethod.reduccion,
      );

      expect(res.exactResultLatex, equals(r'x = 3, \; y = 1'));
      expect(res.steps.length, equals(4));

      // Paso 1: Multiplicadores de fila
      expect(res.steps[0].shortTitle, contains('coeficientes opuestos'));
      expect(res.steps[0].latexExpression, contains(r'\begin{array}'));

      // Paso 2: Suma vertical con anulación en rojo (sin 0y fantasma)
      expect(res.steps[1].shortTitle, contains('Sumar las dos ecuaciones verticalmente'));
      expect(res.steps[1].latexExpression, contains(r'\textcolor{#DC2626}{0}'));
      expect(res.steps[1].latexExpression, isNot(contains('0y')));

      // Paso 3 y 4: Despejes
      expect(res.steps[2].latexExpression, contains('x ='));
      expect(res.steps[2].latexExpression, contains('= 3'));
      expect(res.steps[3].latexExpression, contains('y = 1'));
    });

    test('Equivalencia de los 3 métodos en el mismo sistema', () {
      final resSust = LinearSystemSolver.solve(
        a1: 3, b1: 2, c1: 8,
        a2: 2, b2: -3, c2: 1,
        method: SystemResolutionMethod.sustitucion,
      );
      final resIgual = LinearSystemSolver.solve(
        a1: 3, b1: 2, c1: 8,
        a2: 2, b2: -3, c2: 1,
        method: SystemResolutionMethod.igualacion,
      );
      final resRed = LinearSystemSolver.solve(
        a1: 3, b1: 2, c1: 8,
        a2: 2, b2: -3, c2: 1,
        method: SystemResolutionMethod.reduccion,
      );

      // Los 3 métodos deben llegar a la misma solución: x = 2, y = 1
      expect(resSust.exactResultLatex, equals(r'x = 2, \; y = 1'));
      expect(resIgual.exactResultLatex, equals(r'x = 2, \; y = 1'));
      expect(resRed.exactResultLatex, equals(r'x = 2, \; y = 1'));
    });

    test('Casos singulares: Sistema Incompatible (SI) y Sistema Compatible Indeterminado (SCI)', () {
      // 2x + y = 4 y 4x + 2y = 8 (Coincidentes => SCI)
      final resSci = LinearSystemSolver.solve(
        a1: 2, b1: 1, c1: 4,
        a2: 4, b2: 2, c2: 8,
      );
      expect(resSci.exactResultLatex, contains('S.C.I.'));
      expect(resSci.steps[1].warningTrick, contains('0 = 0'));

      // 2x + y = 4 y 2x + y = 6 (Paralelas => SI)
      final resSi = LinearSystemSolver.solve(
        a1: 2, b1: 1, c1: 4,
        a2: 2, b2: 1, c2: 6,
      );
      expect(resSi.exactResultLatex, contains('S.I.'));
      expect(resSi.steps[1].warningTrick, contains('no tiene solución'));
    });
  });

  group('Fase 4B: Solver de Identidades Notables', () {
    test('Cuadrado de una resta: (2x - 3)² = 4x² - 12x + 9 con trampa de examen', () {
      final res = NotableIdentitiesSolver.solve(
        type: NotableIdentityType.squareOfDiff,
        aCoeff: 2,
        bConst: 3,
      );

      expect(res.exactResultLatex, equals('4x^2 - 12x + 9'));
      expect(res.steps.length, equals(3));

      // Paso 1: Fórmula teórica y aviso de no olvidar el término central
      expect(res.steps[0].latexExpression, contains('(A - B)^2 = A^2 - 2 \\cdot A \\cdot B + B^2'));
      expect(res.steps[0].warningTrick, isNotNull);
      expect(res.steps[0].warningTrick, contains('(A - B)² ≠ A² - B²'));

      // Paso 2: Sustitución literal
      expect(res.steps[1].latexExpression, contains(r'\left(2x\right)^2 - 2 \cdot \left(2x\right) \cdot (3) + (3)^2'));

      // Paso 3: Resultado operado
      expect(res.steps[2].latexExpression, contains('4x^2 - 12x + 9'));
    });

    test('Cuadrado de una suma: (3x + 2)² = 9x² + 12x + 4', () {
      final res = NotableIdentitiesSolver.solve(
        type: NotableIdentityType.squareOfSum,
        aCoeff: 3,
        bConst: 2,
      );

      expect(res.exactResultLatex, equals('9x^2 + 12x + 4'));
      expect(res.steps[0].warningTrick, isNotNull);
      expect(res.steps[0].warningTrick, contains('(A + B)² ≠ A² + B²'));
    });

    test('Suma por diferencia: (2x + 5)(2x - 5) = 4x² - 25', () {
      final res = NotableIdentitiesSolver.solve(
        type: NotableIdentityType.sumTimesDiff,
        aCoeff: 2,
        bConst: 5,
      );

      expect(res.exactResultLatex, equals('4x^2 - 25'));
      expect(res.steps[0].warningTrick, isNotNull);
      expect(res.steps[0].warningTrick, contains('NO hay término central'));
    });

    test('Validación: coeficientes no nulos', () {
      expect(
        () => NotableIdentitiesSolver.solve(
          type: NotableIdentityType.squareOfSum,
          aCoeff: 0,
          bConst: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => NotableIdentitiesSolver.solve(
          type: NotableIdentityType.squareOfSum,
          aCoeff: 1,
          bConst: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
