import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/inequality_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/statistics_solver.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_coefficient_view.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_stat_table_view.dart';

void _expectValidMathTex(String rawLatex, {required String context}) {
  final sanitized = CasioLcdScreen.sanitizeForMathTex(rawLatex);
  expect(
    () {
      final ast = SyntaxTree(
        greenRoot: TexParser(sanitized, const TexParserSettings()).parse(),
      );
      ast.buildWidget(
        MathOptions(
          style: MathStyle.display,
          fontSize: 18,
        ),
      );
    },
    returnsNormally,
    reason: 'LaTeX inválido en [$context]: $sanitized',
  );
}

void _expectValidResolution(StepByStepResolution res, String label) {
  _expectValidMathTex(res.originalInputLatex, context: '$label.original');
  _expectValidMathTex(res.exactResultLatex, context: '$label.exact');
  if (res.decimalApproxLatex.isNotEmpty) {
    _expectValidMathTex(res.decimalApproxLatex, context: '$label.decimal');
  }
  for (int i = 0; i < res.steps.length; i++) {
    _expectValidMathTex(
      res.steps[i].latexExpression,
      context: '$label.step[$i]',
    );
  }
}

void main() {
  group('Fase 7B · Solver de Inecuaciones (1.º y 2.º Grado)', () {
    test('1.º grado con inversión de signo: -2x + 4 < 10 => x > -3 y (-3, +∞)', () {
      final res = InequalitySolver.solveString('-2x + 4 < 10');

      expect(res.exactResultLatex, contains('x > -3'));
      expect(res.exactResultLatex, contains(r'(-3, +\infty)'));

      final warningStep = res.steps.firstWhere(
        (s) => s.warningTrick != null && s.warningTrick!.isNotEmpty,
      );
      expect(warningStep.warningTrick?.toLowerCase(), contains('negativo'));
      expect(warningStep.latexExpression, contains('x > -3'));

      // Sin 0x ni 1x feos en los pasos
      for (final step in res.steps) {
        expect(step.latexExpression, isNot(contains('1x')));
        expect(step.latexExpression, isNot(contains('0x')));
      }
      _expectValidResolution(res, '-2x + 4 < 10');
    });

    test('1.º grado con coeficiente positivo no invierte el signo: 3x - 5 >= 7 - x', () {
      final res = InequalitySolver.solveString('3x - 5 >= 7 - x');

      expect(res.exactResultLatex, contains(r'x \ge 3'));
      expect(res.exactResultLatex, contains(r'[3, +\infty)'));
      expect(
        res.steps.where((s) => s.warningTrick != null),
        isEmpty,
      );
      _expectValidResolution(res, '3x - 5 >= 7 - x');
    });

    test('1.º grado con fracciones: (x - 2)/3 - (x + 1)/4 <= 2 => x <= 35', () {
      final res = InequalitySolver.solveString('(x - 2)/3 - (x + 1)/4 <= 2');

      expect(res.exactResultLatex, contains(r'x \le 35'));
      expect(res.exactResultLatex, contains(r'(-\infty, 35]'));
      expect(res.steps.first.shortTitle, contains('12'));
      _expectValidResolution(res, 'frac-ineq');
    });

    test('1.º grado degenerada sin incógnita (identidad / absurdo)', () {
      final alwaysTrue = InequalitySolver.solveLinearCoeffs(
        a: 2,
        b: 1,
        c: 2,
        d: 5,
        sign: InequalitySign.less,
      );
      expect(alwaysTrue.exactResultLatex, contains(r'(-\infty, +\infty)'));
      _expectValidResolution(alwaysTrue, 'deg-always-true');

      final impossible = InequalitySolver.solveLinearCoeffs(
        a: 2,
        b: 5,
        c: 2,
        d: 1,
        sign: InequalitySign.less,
      );
      expect(impossible.exactResultLatex, contains(r'\emptyset'));
      _expectValidResolution(impossible, 'deg-impossible');
    });

    test('2.º grado con tabla de signos: x^2 - 4x + 3 <= 0 => [1, 3]', () {
      final res = InequalitySolver.solveString('x^2 - 4x + 3 <= 0');

      expect(res.steps.length, equals(3));
      expect(res.steps[0].latexExpression, contains('x_1 = 1'));
      expect(res.steps[0].latexExpression, contains('x_2 = 3'));
      expect(res.steps[1].latexExpression, contains(r'\begin{array}{c|ccc}'));
      expect(res.exactResultLatex, contains('[1, 3]'));
      _expectValidResolution(res, 'x^2 - 4x + 3 <= 0');
    });

    test('2.º grado con unión de intervalos: x^2 - 4x + 3 > 0 => (-∞, 1) U (3, +∞)', () {
      final res = InequalitySolver.solveQuadratic(
        a: 1,
        b: -4,
        c: 3,
        sign: InequalitySign.greater,
      );

      expect(res.exactResultLatex, contains(r'(-\infty, 1) \cup (3, +\infty)'));
      expect(res.steps[1].latexExpression, contains(r'\begin{array}{c|ccc}'));
      _expectValidResolution(res, 'x^2 - 4x + 3 > 0');
    });

    test('2.º grado casos Δ = 0 y Δ < 0 (punto aislado, vacío y toda la recta)', () {
      final singlePoint = InequalitySolver.solveQuadratic(
        a: 1,
        b: -4,
        c: 4,
        sign: InequalitySign.lessOrEqual,
      );
      expect(singlePoint.exactResultLatex, contains(r'\left\{2\right\}'));
      _expectValidResolution(singlePoint, 'quad-delta-0-single');

      final emptyDelta0 = InequalitySolver.solveQuadratic(
        a: 1,
        b: -4,
        c: 4,
        sign: InequalitySign.less,
      );
      expect(emptyDelta0.exactResultLatex, contains(r'\emptyset'));
      _expectValidResolution(emptyDelta0, 'quad-delta-0-empty');

      final negParabolaNeg = InequalitySolver.solveQuadratic(
        a: -1,
        b: 0,
        c: -1,
        sign: InequalitySign.less,
      );
      expect(negParabolaNeg.exactResultLatex, contains(r'(-\infty, +\infty)'));
      _expectValidResolution(negParabolaNeg, 'quad-delta-neg-all');

      final negParabolaPos = InequalitySolver.solveQuadratic(
        a: -1,
        b: 0,
        c: -1,
        sign: InequalitySign.greater,
      );
      expect(negParabolaPos.exactResultLatex, contains(r'\emptyset'));
      _expectValidResolution(negParabolaPos, 'quad-delta-neg-empty');
    });

    test('ExpressionParser.rawToLiveLatex formatea operadores <=, >=, <, >', () {
      expect(
        ExpressionParser.rawToLiveLatex('-2x+4<=10'),
        contains(r'\le'),
      );
      expect(
        ExpressionParser.rawToLiveLatex('3x-1>=5'),
        contains(r'\ge'),
      );
      _expectValidMathTex(
        ExpressionParser.rawToLiveLatex('-2x+4<=10', cursorPos: 6),
        context: 'liveLatex-ineq',
      );
    });
  });

  group('Fase 7B · Estadística de 1 Variable (StatisticsOneVarSolver)', () {
    test('Caso exacto de examen: xi = [2, 4, 6], fi = [1, 2, 1]', () {
      final result = StatisticsOneVarSolver.analyze([
        StatDataPoint(Rational(2), 1),
        StatDataPoint(Rational(4), 2),
        StatDataPoint(Rational(6), 1),
      ]);

      expect(result.nTotal, equals(4));
      expect(result.mean, equals(Rational(4)));
      expect(result.variance, equals(Rational(2)));
      expect(result.stdDevDouble, closeTo(1.41421356, 1e-6));
      expect(result.stdDevLatex, contains(r'\sqrt{2}'));
      expect(result.modes, equals([Rational(4)]));
      expect(result.median, equals(Rational(4)));
      expect(result.q1, equals(Rational(3)));
      expect(result.q3, equals(Rational(5)));

      final res = result.resolution;
      expect(res.steps.length, equals(4));
      expect(res.steps[0].latexExpression, contains(r'\begin{array}{c|c|c|c|c}'));
      expect(res.steps[0].latexExpression, contains('N = 4'));
      expect(res.steps[1].latexExpression, contains(r'\bar{x}'));
      expect(res.steps[2].latexExpression, contains(r'\sigma^2'));
      expect(res.steps[2].latexExpression, contains(r'\sqrt{2}'));
      expect(res.steps[2].warningTrick, isNotNull);
      expect(res.steps[3].latexExpression, contains('M_o &= 4'));
      expect(res.steps[3].latexExpression, contains('M_e &= 4'));
      expect(res.steps[3].latexExpression, contains('Q_1 &= 3'));
      expect(res.steps[3].latexExpression, contains('Q_3 = 5'));
      expect(res.exactResultLatex, contains(r'\bar{x} = 4'));
      expect(res.exactResultLatex, contains(r'\sigma = \sqrt{2}'));

      _expectValidResolution(res, 'stats-246');
    });

    test('Agrupa datos repetidos sin ordenar y calcula fracciones exactas', () {
      final result = StatisticsOneVarSolver.analyze([
        StatDataPoint(Rational(3), 1),
        StatDataPoint(Rational(1), 2),
        StatDataPoint(Rational(2), 1),
        StatDataPoint(Rational(1), 1),
      ]);

      // Valores agrupados: 1(x3), 2(x1), 3(x1) -> N = 5, sum = 8, sumSq = 16
      expect(result.nTotal, equals(5));
      expect(result.mean, equals(Rational(8, 5)));
      expect(result.variance, equals(Rational(16, 25)));
      expect(result.stdDevLatex, equals(r'\frac{4}{5}'));
      expect(result.modes, equals([Rational(1)]));
      expect(result.median, equals(Rational(1)));
      _expectValidResolution(result.resolution, 'stats-grouped-fraction');
    });

    test('Distribucion multimodal, uniforme amodal y rechazo de frecuencias no positivas', () {
      final bimodal = StatisticsOneVarSolver.analyze([
        StatDataPoint(Rational(1), 2),
        StatDataPoint(Rational(3), 1),
        StatDataPoint(Rational(5), 2),
      ]);
      expect(bimodal.modes, equals([Rational(1), Rational(5)]));
      _expectValidResolution(bimodal.resolution, 'stats-bimodal');

      final uniformAmodal = StatisticsOneVarSolver.analyze([
        StatDataPoint(Rational(1), 2),
        StatDataPoint(Rational(5), 2),
      ]);
      expect(uniformAmodal.modes, isEmpty);
      _expectValidResolution(uniformAmodal.resolution, 'stats-amodal');

      expect(
        () => StatisticsOneVarSolver.solve([StatDataPoint(Rational(3), 0)]),
        throwsFormatException,
      );
      expect(
        () => StatisticsOneVarSolver.solve(const []),
        throwsFormatException,
      );
    });
  });

  group('Fase 7B · Integración UI ClassWiz (Modos 8 y 9 + Responsivo Móvil)', () {
    testWidgets('Menú MODE paginado muestra 11 modos incluyendo 6:Inecuac. y 7:Estadíst. en Página 2', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu_page_next')), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();

      expect(find.text('Inecuaciones'), findsOneWidget);
      expect(find.text('Estadística'), findsOneWidget);
      expect(find.text('Matrices'), findsOneWidget);
      expect(find.text('Tutor IA'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Modo 6 (Inecuaciones): entrada por teclado, selector de signo y 2.º grado con D-Pad', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir MODE -> Página 2 -> Modo 6 (Inecuaciones)
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mode_6')));
      await tester.pumpAndSettle();

      expect(find.text('M6: INEC. 1°'), findsOneWidget);
      expect(find.byKey(const Key('ineq_deg_1')), findsOneWidget);
      expect(find.byKey(const Key('ineq_deg_2')), findsOneWidget);
      expect(find.byKey(const Key('lcd_ineq_sign_btn')), findsOneWidget);

      // Escribir '-2x + 4 < 10' usando teclado físico y chip '<'
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '-'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.tap(find.byKey(const Key('ineq_var_x')));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '+'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.tap(find.byKey(const Key('ineq_sign_less')));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '0'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      expect(find.textContaining('PASO 1/'), findsOneWidget);
      expect(find.byType(Math), findsWidgets);
      expect(tester.takeException(), isNull);

      // Cambiar a 2.º grado en Modo 6 -> plantilla CasioCoefficientView con celda de signo
      await tester.tap(find.byKey(const Key('ineq_deg_2')));
      await tester.pumpAndSettle();

      expect(find.text('M6: INEC. 2°'), findsOneWidget);
      expect(find.byType(CasioCoefficientView), findsOneWidget);
      expect(find.byKey(const Key('ineq_quad_sign_cell')), findsOneWidget);

      // Ciclar signo con la celda de signo en CasioCoefficientView (< -> <=)
      await tester.tap(find.byKey(const Key('ineq_quad_sign_cell')));
      await tester.pumpAndSettle();

      // Introducir a=1, b=-4, c=3 y resolver x² - 4x + 3 <= 0
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '-'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '3'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      expect(find.textContaining('PASO 1/3'), findsOneWidget);
      // Avanzar con D-Pad ▶ hasta paso 2 (tabla de signos) y comprobar cero excepciones
      await tester.tap(find.byKey(const Key('replay_right')));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 2/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Modo 7 (Estadística 1-Var): tabla LCD editable, D-Pad, OPTN y CALC STAT', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Ir a Modo 7 mediante MODE -> Página 2 -> Estadística
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mode_7')));
      await tester.pumpAndSettle();

      expect(find.text('M7: ESTADÍST.'), findsOneWidget);
      expect(find.byType(CasioStatTableView), findsOneWidget);
      expect(find.byKey(const Key('stat_cell_0_0')), findsOneWidget);
      expect(find.byKey(const Key('stat_cell_0_1')), findsOneWidget);

      // Introducir x₁=2 '=', x₂=4 '=', x₃=6 '='
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '6'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      // Subir con D-Pad ▲ dos veces a la fila de x₂=4 y ▶ hacia columna fᵢ para poner f₂=2
      await tester.tap(find.byKey(const Key('replay_up')));
      await tester.tap(find.byKey(const Key('replay_up')));
      await tester.tap(find.byKey(const Key('replay_right')));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();

      // Ejecutar CALC STAT -> muestra paso 1/4 con tabla de frecuencias
      await tester.tap(find.byKey(const Key('stat_calc_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 1/4'), findsOneWidget);
      expect(find.byType(Math), findsWidgets);
      expect(tester.takeException(), isNull);

      // Abrir OPTN -> abrir vista Exportar PNG
      await tester.tap(find.byKey(const Key('stat_optn_btn')));
      await tester.pumpAndSettle();
      expect(find.text('OPTN · Estadística 1-Var (STEP-BY-STEP LD)'), findsOneWidget);

      await tester.tap(find.text('2: Exportar Tabla y Pasos a PNG'));
      await tester.pumpAndSettle();
      expect(find.text('Exportar Desarrollo a PNG'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sin desbordamiento (overflow) en pantalla móvil 390x844 para Modos 6 y 7', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Abrir MENU paginado en móvil
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Entrar a Modo 6 (1.º y 2.º grado) en móvil
      await tester.tap(find.byKey(const Key('menu_mode_6')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('ineq_deg_2')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Entrar a Modo 7 y calcular estadística en móvil (reabrir MODE mantiene la Página 2)
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mode_7')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '5'));
      await tester.tap(find.byKey(const Key('stat_calc_btn')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
