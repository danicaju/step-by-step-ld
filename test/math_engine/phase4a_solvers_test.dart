import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/ast/ast_nodes.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/quadratic_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/radical_and_factor_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';

void main() {
  group('Fase 4A: Descomposición Factorial (FACT) y Radicales Exactos', () {
    test('FACT: Descomposición prima de 360 estilo Casio ClassWiz', () {
      final res = RadicalAndFactorSolver.factorize(360);

      expect(res.exactResultLatex, equals(r'2^{3} \cdot 3^{2} \cdot 5'));
      expect(res.steps.length, equals(2));
      // Paso 1 contiene la tabla de divisiones sucesivas estilo ESO
      expect(res.steps[0].latexExpression, contains(r'\begin{array}{r|l}'));
      expect(res.steps[0].latexExpression, contains('360 & 2'));
      // Paso 2 contiene la agrupación en potencias
      expect(res.steps[1].latexExpression, contains(r'360 = 2^{3} \cdot 3^{2} \cdot 5'));
    });

    test('FACT: Descomposición de números primos o casos límite (n <= 1)', () {
      final res1 = RadicalAndFactorSolver.factorize(1);
      expect(res1.exactResultLatex, equals('1'));
      expect(res1.steps[0].pedagogicalNote, contains('no se considera primo'));

      final res13 = RadicalAndFactorSolver.factorize(13);
      expect(res13.exactResultLatex, equals('13'));
    });

    test('Radicales: Cuadrado perfecto exacto (√36 = 6)', () {
      final res = RadicalAndFactorSolver.simplifySquareRoot(36);

      expect(res.exactResultLatex, equals('6'));
      expect(res.steps.length, equals(1));
      expect(res.steps[0].shortTitle, equals('Cuadrado perfecto'));
    });

    test('Radicales: Extracción de factores de radical no exacto (√72 = 6√2)', () {
      final res = RadicalAndFactorSolver.simplifySquareRoot(72);

      expect(res.exactResultLatex, equals(r'6\sqrt{2}'));
      expect(res.steps.length, equals(3));
      // Paso 1: descomposición del radicando
      expect(res.steps[0].latexExpression, contains(r'\sqrt{2^{3} \cdot 3^{2}}'));
      // Paso 2: agrupación de cuadrados
      expect(res.steps[1].latexExpression, contains('2^2'));
      expect(res.steps[1].latexExpression, contains('3^2'));
      // Paso 3: factores fuera de la raíz
      expect(res.steps[2].latexExpression, contains(r'6\sqrt{2}'));
      expect(res.decimalApproxLatex, contains(','));
    });

    test('Radicales: Radical irreducible (√15 no puede extraer factores)', () {
      final res = RadicalAndFactorSolver.simplifySquareRoot(15);

      expect(res.exactResultLatex, equals(r'\sqrt{15}'));
      expect(res.steps[1].shortTitle, equals('Radical irreducible'));
    });

    test('Radicales: Radicando negativo (√(-9) ∉ ℝ)', () {
      final res = RadicalAndFactorSolver.simplifySquareRoot(-9);

      expect(res.exactResultLatex, equals(r'\text{No real}'));
      expect(res.steps[0].warningTrick, isNotNull);
      expect(res.steps[0].warningTrick, contains('solución real'));
    });

    test('StepEvaluator y Parser: Integración de √ en expresiones del AST', () {
      final parser = ExpressionParser();
      final evaluator = StepEvaluator();

      // Raíz sola no exacta
      final astSqrt72 = parser.parse('√72');
      expect(astSqrt72, isA<SqrtNode>());
      final res72 = evaluator.evaluate(astSqrt72);
      expect(res72.exactResultLatex, equals(r'6\sqrt{2}'));

      // Raíz exacta combinada con suma: √36 + 4 = 6 + 4 = 10
      final astCombined = parser.parse('√36+4');
      final resCombined = evaluator.evaluate(astCombined);
      expect(resCombined.exactResultLatex, equals('10'));
    });
  });

  group('Fase 4A: Solver de Ecuaciones de 1.º Grado con Fracciones', () {
    test('Preset clásico ESO: (x-2)/3 - (x+1)/4 = 2 con trampa de signo', () {
      final res = LinearEquationSolver.solveClassicPreset();

      // Solución: 4(x-2) - 3(x+1) = 24 => 4x - 8 - 3x - 3 = 24 => x - 11 = 24 => x = 35
      expect(res.exactResultLatex, equals('x = 35'));
      expect(res.steps.length, greaterThanOrEqualTo(3));

      // Paso 1: m.c.m. de denominadores y alerta de signo menos delante de fracción
      expect(res.steps[0].latexExpression, contains(r'\text{m.c.m. de denominadores} = 12'));
      expect(res.steps[0].warningTrick, isNotNull);
      expect(res.steps[0].warningTrick, contains('signo menos'));

      // Resaltado en azul del factor amplificador
      expect(res.steps[0].latexExpression, contains(r'\textcolor{#2563EB}{4}'));
      expect(res.steps[0].latexExpression, contains(r'\textcolor{#2563EB}{3}'));
    });

    test('Ecuación directa: 3x - 5 = 7 - x => 4x = 12 => x = 3', () {
      final res = LinearEquationSolver.solveDirect(
        a: 3,
        b: -5,
        c: -1,
        d: 7,
      );

      expect(res.exactResultLatex, equals('x = 3'));
    });

    test('Ecuación con solución fraccionaria irreducible: 2x + 1 = 6 => 2x = 5 => x = 5/2', () {
      final res = LinearEquationSolver.solveDirect(
        a: 2,
        b: 1,
        c: 0,
        d: 6,
      );

      expect(res.exactResultLatex, equals(r'x = \frac{5}{2}'));
      expect(res.decimalApproxLatex, equals('2,5'));
    });

    test('Casos límite de 1.º grado: Identidad y Ecuación incompatible', () {
      // 2x + 3 = 2x + 3 => 0x = 0 (Infinitas soluciones)
      final resIdentity = LinearEquationSolver.solveDirect(
        a: 2,
        b: 3,
        c: 2,
        d: 3,
      );
      expect(resIdentity.exactResultLatex, equals(r'\text{Infinitas soluciones}'));

      // 2x + 3 = 2x + 5 => 0 = 2 (Sin solucion)
      final resIncomp = LinearEquationSolver.solveDirect(
        a: 2,
        b: 3,
        c: 2,
        d: 5,
      );
      expect(resIncomp.exactResultLatex, equals(r'\text{Sin solucion}'));
    });
  });

  group('Fase 4A: Solver Pedagógico de Ecuaciones de 2.º Grado (ax² + bx + c = 0)', () {
    test('Incompleta Pura (b = 0): x² - 9 = 0 => x = ±3 sin fórmula general', () {
      final res = QuadraticEquationSolver.solve(a: 1, b: 0, c: -9);

      expect(res.exactResultLatex, equals(r'x_1 = 3, \; x_2 = -3'));
      // No debe contener la fórmula general completa
      expect(res.steps[0].pedagogicalNote, contains('sin fórmula general'));
      expect(res.steps[1].latexExpression, contains(r'x = \pm\sqrt{9}'));
      expect(res.steps[1].latexExpression, contains('x_1 = 3'));
    });

    test('Incompleta Pura sin soluciones reales: x² + 4 = 0 => x² = -4 ∉ ℝ', () {
      final res = QuadraticEquationSolver.solve(a: 1, b: 0, c: 4);

      expect(res.exactResultLatex, equals(r'\text{Sin solucion real}'));
      expect(res.steps.last.warningTrick, isNotNull);
      expect(res.steps.last.warningTrick, contains('al cuadrado nunca puede ser negativo'));
    });

    test('Incompleta Mixta (c = 0): x² - 4x = 0 => x(x - 4) = 0 => x1 = 0, x2 = 4', () {
      final res = QuadraticEquationSolver.solve(a: 1, b: -4, c: 0);

      expect(res.exactResultLatex, equals(r'x_1 = 0, \; x_2 = 4'));
      expect(res.steps[0].shortTitle.toLowerCase(), contains('factor común'));
      expect(res.steps[0].pedagogicalNote, contains('sin fórmula general'));
      expect(res.steps[1].shortTitle, contains('factores igualados a cero'));
    });

    test('Completa con 2 soluciones reales: x² - 5x + 6 = 0 => x1 = 3, x2 = 2', () {
      final res = QuadraticEquationSolver.solve(a: 1, b: -5, c: 6);

      expect(res.exactResultLatex, equals(r'x_1 = 3, \; x_2 = 2'));
      expect(res.steps.length, equals(4));

      // Paso 1: Coeficientes a, b, c identificados
      expect(res.steps[0].shortTitle, contains('coeficientes'));
      expect(res.steps[0].latexExpression, contains('a = 1, \\quad b = -5, \\quad c = 6'));

      // Paso 2: Sustitución literal con paréntesis en negativos
      expect(res.steps[1].latexExpression, contains(r'\frac{-(-5) \pm \sqrt{(-5)^2 - 4 \cdot 1 \cdot 6}}{2 \cdot 1}'));

      // Paso 3: Discriminante Delta = 1 > 0
      expect(res.steps[2].latexExpression, contains('= 1'));
      expect(res.steps[2].latexExpression, contains(r'\Delta > 0'));

      // Paso 4: Dos ramas de soluciones
      expect(res.steps[3].latexExpression, contains('x_1 ='));
      expect(res.steps[3].latexExpression, contains('= 3'));
      expect(res.steps[3].latexExpression, contains('x_2 ='));
      expect(res.steps[3].latexExpression, contains('= 2'));
    });

    test('Completa con raíz doble (Δ = 0): x² - 6x + 9 = 0 => x = 3', () {
      final res = QuadraticEquationSolver.solve(a: 1, b: -6, c: 9);

      expect(res.exactResultLatex, equals('x = 3'));
      expect(res.steps[2].latexExpression, contains(r'\Delta = 0'));
      expect(res.steps[2].latexExpression, contains('Existe 1 solucion real doble'));
    });

    test('Completa sin solución real (Δ < 0): x² + 2x + 5 = 0 => Δ = -16 < 0', () {
      final res = QuadraticEquationSolver.solve(a: 1, b: 2, c: 5);

      expect(res.exactResultLatex, equals(r'\text{Sin soluciones reales}'));
      expect(res.steps[2].latexExpression, contains('= -16'));
      expect(res.steps[2].latexExpression, contains(r'\Delta < 0'));
      expect(res.steps[2].warningTrick, isNotNull);
      expect(res.steps[2].warningTrick, contains('discriminante negativo'));
    });

    test('Validación: a no puede ser 0', () {
      expect(
        () => QuadraticEquationSolver.solve(a: 0, b: 2, c: 1),
        throwsArgumentError,
      );
    });
  });

  group('Mejoras ESO: Ecuaciones Lineales, Live LaTeX y Legibilidad', () {
    test('LinearEquationSolver soporta 2*x, paréntesis 2(x-3), fracciones x/2 y \\frac', () {
      final resMul = LinearEquationSolver.solveEquationString('2*x + 4 = 16');
      expect(resMul.exactResultLatex, equals('x = 6'));
      expect(resMul.originalInputLatex, equals('2x + 4 = 16'));

      final resParen = LinearEquationSolver.solveEquationString('2(x - 3) + 1 = 5');
      expect(resParen.exactResultLatex, equals('x = 5'));

      final resHalf = LinearEquationSolver.solveEquationString('x/2 + 1 = 5');
      expect(resHalf.exactResultLatex, equals('x = 8'));

      final resFrac = LinearEquationSolver.solveEquationString(
        r'\frac{x-2}{3} - \frac{x+1}{4} = 2',
      );
      expect(resFrac.exactResultLatex, equals('x = 35'));
      expect(resFrac.steps.first.warningTrick, isNot(contains(r'\frac')));
    });

    test('ExpressionParser.rawToLiveLatex formatea fracciones con x e igualdad =', () {
      final latex = ExpressionParser.rawToLiveLatex('x/2+1=5');
      expect(latex, contains(r'\frac{x}{2}'));
      expect(latex, contains(' = '));
    });

    test('Notas y avisos en lenguaje ESO sin símbolos universitarios ni LaTeX crudo', () {
      final quadNoSol = QuadraticEquationSolver.solve(a: 1, b: 2, c: 5);
      expect(quadNoSol.steps[2].warningTrick, isNot(contains(r'\mathbb')));
      expect(quadNoSol.steps[2].pedagogicalNote, isNot(contains(r'\mathbb')));

      final negSqrt = RadicalAndFactorSolver.simplifySquareRoot(-9);
      expect(negSqrt.steps.first.latexExpression, isNot(contains(r'\notin')));
      expect(negSqrt.steps.first.warningTrick, isNot(contains('ℝ')));
    });
  });
}
