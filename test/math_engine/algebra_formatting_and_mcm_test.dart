import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:casio_tutor_calc/domain/math_engine/ast/ast_nodes.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/algebraic_latex_formatter.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/function_graph_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_system_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/quadratic_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/radical_and_factor_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/ruffini_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';

void main() {
  final accentInTextRegex = RegExp(r'\\text\{[^}]*[áéíóúÁÉÍÓÚñÑ][^}]*\}');

  void assertCleanLatex(String latex) {
    expect(latex, isNot(contains('+ -')));
    expect(latex, isNot(contains('- -')));
    expect(latex, isNot(contains('(x - -')));
    expect(latex, isNot(contains(r'1\sqrt')));
    expect(latex, isNot(contains(r'\sqrt{1}')));
    expect(accentInTextRegex.hasMatch(latex), isFalse,
        reason: 'Hay tildes dentro de \\text{...}: $latex');
  }

  group('Bloque 1: m.c.m. y M.C.D. N-ario + Navegación D-Pad y coma', () {
    test('m.c.m.(12, 18, 24) = 72 con descomposicion factorial de los 3 numeros', () {
      final parser = ExpressionParser();
      final evaluator = StepEvaluator();

      final ast = parser.parse('mcm(12, 18, 24)');
      expect(ast, isA<McmNode>());
      expect((ast as McmNode).args.length, equals(3));

      final res = evaluator.evaluate(ast);
      expect(res.originalInputLatex, equals(r'\text{m.c.m.}\left(12 ; 18 ; 24\right)'));
      expect(res.exactResultLatex, equals('72'));
      expect(res.steps.length, equals(2));

      // Paso 1: Descomposición de TODOS los argumentos
      expect(res.steps[0].latexExpression, contains('12 = 2^{2} \\cdot 3'));
      expect(res.steps[0].latexExpression, contains('18 = 2 \\cdot 3^{2}'));
      expect(res.steps[0].latexExpression, contains('24 = 2^{3} \\cdot 3'));

      // Paso 2: Regla ESO comunes y no comunes al mayor exponente
      expect(res.steps[1].latexExpression, contains('2^{3} \\cdot 3^{2} = 72'));
      for (final s in res.steps) {
        assertCleanLatex(s.latexExpression);
      }
    });

    test('M.C.D.(24, 36, 60) = 12 con factores comunes y caso coprimos = 1', () {
      final parser = ExpressionParser();
      final evaluator = StepEvaluator();

      final ast = parser.parse('mcd(24, 36, 60)');
      expect(ast, isA<McdNode>());
      expect((ast as McdNode).args.length, equals(3));

      final res = evaluator.evaluate(ast);
      expect(res.exactResultLatex, equals('12'));
      expect(res.steps.length, equals(2));
      expect(res.steps[0].latexExpression, contains('24 = 2^{3} \\cdot 3'));
      expect(res.steps[0].latexExpression, contains('36 = 2^{2} \\cdot 3^{2}'));
      expect(res.steps[0].latexExpression, contains('60 = 2^{2} \\cdot 3 \\cdot 5'));
      expect(res.steps[1].latexExpression, contains('2^{2} \\cdot 3 = 12'));

      // 4 números con coprimos
      final coprimeRes = StepEvaluator().evaluate(parser.parse('mcd(8, 15, 25, 49)'));
      expect(coprimeRes.exactResultLatex, equals('1'));
      expect(coprimeRes.steps[1].latexExpression, contains(r'\text{M.C.D.}\left(8 ; 15 ; 25 ; 49\right) = 1'));
    });

    test('rawToLiveLatex formatea mcm/mcd N-ario con separador ; y casillas vacias', () {
      expect(
        ExpressionParser.rawToLiveLatex('mcm(12,18,24)'),
        equals(r'\text{m.c.m.}\left(12 ; 18 ; 24\right)'),
      );
      expect(
        ExpressionParser.rawToLiveLatex('mcd(24,36,60)'),
        equals(r'\text{M.C.D.}\left(24 ; 36 ; 60\right)'),
      );
      expect(
        ExpressionParser.rawToLiveLatex('mcm(12,', cursorPos: 7),
        contains('12 ; '),
      );
    });

    test('Navegacion con ▶ y . / , abre nuevos huecos en mcm(...) y cierra limpiamente', () {
      final step1 = ExpressionParser.handleMcmMcdRightArrow('mcm(12', 6);
      expect(step1, equals(('mcm(12,', 7)));

      final step2 = ExpressionParser.handleMcmMcdCommaOrDot('mcm(12,18', 9);
      expect(step2, equals(('mcm(12,18,', 10)));

      // Pulsar ▶ en un hueco vacío tras haber introducido >= 2 números cierra el paréntesis
      final stepClose = ExpressionParser.handleMcmMcdRightArrow('mcm(12,18,', 10);
      expect(stepClose, equals(('mcm(12,18)', 10)));

      // Si el alumno pulsa '=' directo con coma final o sin cerrar ')', finalize lo sanea
      expect(ExpressionParser.finalizeMcmMcdInput('mcm(12,18,24'), equals('mcm(12,18,24)'));
      expect(ExpressionParser.finalizeMcmMcdInput('mcm(12,18,'), equals('mcm(12,18)'));
    });

    testWidgets('Teclado Casio: SHIFT+x -> 12 -> ▶ -> 18 -> . -> 24 -> = calcula m.c.m.(12;18;24) = 72', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // SHIFT + × => inserta mcm(
      await tester.tap(find.text('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '×'));
      await tester.pumpAndSettle();

      // 12 + D-Pad derecha ▶ => mcm(12,
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.tap(find.byIcon(Icons.arrow_right_rounded));
      await tester.pumpAndSettle();

      // 18 + tecla '.' => mcm(12,18,
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '8'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '.'));
      await tester.pumpAndSettle();

      // 24 + '=' => resuelve m.c.m.(12 ; 18 ; 24) = 72 en 2 pasos
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      expect(find.text('PASO 1/2'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_right_rounded));
      await tester.pumpAndSettle();
      expect(find.text('PASO 2/2'), findsOneWidget);

      final lcd = tester.widget<CasioLcdScreen>(find.byType(CasioLcdScreen));
      expect(lcd.currentResolution, isNotNull);
      expect(lcd.currentResolution!.exactResultLatex, equals('72'));
      expect(lcd.currentResolution!.steps[1].latexExpression, contains('2^{3} \\cdot 3^{2} = 72'));
      expect(find.byType(Math), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Bloque 2 y 4: Formateador Algebraico Humano en TODOS los Solvers', () {
    test('AlgebraicLatexFormatter cumple reglas de 0, 1, -1, factores y fracciones', () {
      expect(AlgebraicLatexFormatter.linearExpression(1, 0), equals('x'));
      expect(AlgebraicLatexFormatter.linearExpression(-1, 0), equals('-x'));
      expect(AlgebraicLatexFormatter.linearExpression(1, -4), equals('x - 4'));
      expect(AlgebraicLatexFormatter.linearExpression(0, -5), equals('-5'));
      expect(AlgebraicLatexFormatter.quadraticExpression(-1, 1, 0), equals('-x^{2} + x'));
      expect(AlgebraicLatexFormatter.linearFactor(2), equals('(x - 2)'));
      expect(AlgebraicLatexFormatter.linearFactor(-2), equals('(x + 2)'));
      expect(AlgebraicLatexFormatter.linearFactor(0), equals('x'));
      expect(AlgebraicLatexFormatter.radical(1, 5), equals(r'\sqrt{5}'));
      expect(AlgebraicLatexFormatter.radical(3, 1), equals('3'));
      expect(AlgebraicLatexFormatter.radical(4, 0), equals('0'));
      expect(AlgebraicLatexFormatter.signedFraction(5, -6), equals(r'-\frac{5}{6}'));
      expect(AlgebraicLatexFormatter.signedFraction(5, 1), equals('5'));
      expect(AlgebraicLatexFormatter.signedFraction(5, -1), equals('-5'));
    });

    test('LinearEquationSolver no emite 0x, + -, 1x ni /1 en 6x = 5, x + 2 = 5, -x + 3 = 8', () {
      final res6x = LinearEquationSolver.solveEquationString('6x = 5');
      expect(res6x.steps.length, equals(1)); // Omite transposición innecesaria
      expect(res6x.steps.first.latexExpression, equals(r'6x = 5 \implies x = \frac{5}{6}'));
      expect(res6x.exactResultLatex, equals(r'x = \frac{5}{6}'));
      for (final s in res6x.steps) {
        expect(s.latexExpression, isNot(contains('0x')));
        assertCleanLatex(s.latexExpression);
      }

      final resUnit = LinearEquationSolver.solveEquationString('x + 2 = 5');
      expect(resUnit.exactResultLatex, equals('x = 3'));
      for (final s in resUnit.steps) {
        expect(s.latexExpression, isNot(contains('1x')));
        expect(s.latexExpression, isNot(contains(r'\frac{3}{1}')));
        assertCleanLatex(s.latexExpression);
      }

      final resNegUnit = LinearEquationSolver.solveEquationString('-x + 3 = 8');
      expect(resNegUnit.exactResultLatex, equals('x = -5'));
      for (final s in resNegUnit.steps) {
        expect(s.latexExpression, isNot(contains('-1x')));
        expect(s.latexExpression, isNot(contains('{-1}')));
        assertCleanLatex(s.latexExpression);
      }

      final resIncomp = LinearEquationSolver.solveEquationString('2x + 3 = 2x + 5');
      expect(resIncomp.steps.last.latexExpression, equals('0 = 2'));
      expect(resIncomp.steps.last.latexExpression, isNot(contains('0x')));
      assertCleanLatex(resIncomp.exactResultLatex);
    });

    test('RuffiniSolver, QuadraticSolver, SystemSolver, RadicalSolver y GraphSolver limpios', () {
      // Ruffini con raíces negativas y raíz 0: x^3 + 2x^2 - 5x - 6
      final ruffini = RuffiniSolver.factorize([1, 2, -5, -6]);
      expect(ruffini.exactResultLatex, equals('(x + 1)(x - 2)(x + 3)'));
      for (final s in ruffini.steps) {
        assertCleanLatex(s.latexExpression);
      }

      final ruffiniZero = RuffiniSolver.factorize([1, 0, -4, 0]);
      expect(ruffiniZero.exactResultLatex, equals('x(x - 2)(x + 2)'));
      expect(ruffiniZero.exactResultLatex, isNot(contains('(x - 0)')));
      expect(ruffiniZero.exactResultLatex, isNot(contains('(x + 0)')));

      // Cuadrática con coeficiente negativo y c = 0: -x^2 - 4x = 0
      final quadNeg = QuadraticEquationSolver.solve(a: -1, b: -4, c: 0);
      expect(quadNeg.originalInputLatex, isNot(contains('-1x')));
      expect(quadNeg.originalInputLatex, isNot(contains('+ -')));
      for (final s in quadNeg.steps) {
        expect(s.latexExpression, isNot(contains('-1x')));
        assertCleanLatex(s.latexExpression);
      }
      assertCleanLatex(quadNeg.exactResultLatex);

      // Cuadrática irracional con a < 0: -x^2 + 2x + 4 = 0
      final quadIrr = QuadraticEquationSolver.solve(a: -1, b: 2, c: 4);
      expect(quadIrr.exactResultLatex, isNot(contains('{-2}')));
      for (final s in quadIrr.steps) {
        assertCleanLatex(s.latexExpression);
      }

      // Radicales: 12 -> 2\sqrt{3}, 36 -> 6
      final rad12 = RadicalAndFactorSolver.simplifySquareRoot(12);
      expect(rad12.exactResultLatex, equals(r'2\sqrt{3}'));
      final rad36 = RadicalAndFactorSolver.simplifySquareRoot(36);
      expect(rad36.exactResultLatex, equals('6'));
      expect(rad36.steps.last.latexExpression, isNot(contains(r'\sqrt{1}')));

      // Sistemas 2x2 con los 3 métodos: sin 1x, -1y, 0y ni divisores negativos
      for (final m in SystemResolutionMethod.values) {
        final sys = LinearSystemSolver.solve(
          a1: 1,
          b1: -1,
          c1: 2,
          a2: -2,
          b2: 3,
          c2: -1,
          method: m,
        );
        expect(sys.exactResultLatex, equals(r'x = 5, \; y = 3'));
        for (final s in sys.steps) {
          expect(s.latexExpression, isNot(contains('0y')));
          assertCleanLatex(s.latexExpression);
        }
      }

      // Gráficas: lineal y = x - 4 y cuadrática y = -x^2 + 3
      final linGraph = FunctionGraphSolver.analyzeLinear(m: 1, n: -4);
      expect(linGraph.resolution.originalInputLatex, equals('y = x - 4'));
      for (final s in linGraph.resolution.steps) {
        expect(s.latexExpression, isNot(contains('1 x')));
        assertCleanLatex(s.latexExpression);
      }

      final quadGraph = FunctionGraphSolver.analyzeQuadratic(a: -1, b: 0, c: 3);
      for (final s in quadGraph.resolution.steps) {
        expect(s.latexExpression, isNot(contains('+ (0)')));
        assertCleanLatex(s.latexExpression);
      }
    });
  });

  group('Bloque 3: Pantalla LCD sin mensajes cortados (...) ni desbordamientos', () {
    testWidgets('CasioLcdScreen muestra titulo completo con FittedBox y nota larga con Scrollbar', (tester) async {
      const longTitle = 'Candidatos a raiz entera (Divisores de a₀)';
      const longNote =
          'Segun el Teorema del Resto, las raices enteras de un polinomio con coeficientes enteros deben ser divisores del termino independiente y hay que comprobar tambien el signo contrario.';

      final res = StepByStepResolution(
        originalInputLatex: 'P(x) = x^3 - 6x^2 + 11x - 6',
        steps: const [
          MathStep(
            index: 1,
            shortTitle: longTitle,
            latexExpression: r'\text{Divisores de } -6 = \{\pm 1, \pm 2, \pm 3, \pm 6\}',
            pedagogicalNote: longNote,
          ),
        ],
        exactResultLatex: '(x - 1)(x - 2)(x - 3)',
        decimalApproxLatex: 'x = 1, 2, 3',
      );

      for (final size in [const Size(390, 260), const Size(360, 150)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CasioLcdScreen(
                    currentInputLatex: '0',
                    currentResolution: res,
                    activeStepIndex: 0,
                    isShiftActive: false,
                    isAlphaActive: false,
                    isMemoryActive: true,
                    showDecimalApprox: false,
                    modeLabel: 'M4: RUFFINI',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleText = tester.widget<Text>(find.text(longTitle));
        expect(titleText.overflow, isNot(equals(TextOverflow.ellipsis)));

        final noteText = tester.widget<Text>(find.text(longNote));
        expect(noteText.maxLines, isNull);
        expect(noteText.overflow, isNot(equals(TextOverflow.ellipsis)));
        expect(find.byType(SingleChildScrollView), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
