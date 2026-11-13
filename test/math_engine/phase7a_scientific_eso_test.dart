import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calc_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/trig_and_angles_solver.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = ExpressionParser();
  final evaluator = StepEvaluator();

  group('Fase 7A - Trigonometría Exacta y Modo DEG/RAD', () {
    test('sin(30°) = 1/2 y cos(45°) = sqrt(2)/2 con paso de racionalización', () {
      final sin30 = evaluator.evaluate(
        parser.parse('sin(30)'),
        angleUnit: AngleUnit.deg,
      );
      expect(sin30.exactResultLatex, equals(r'\frac{1}{2}'));
      expect(sin30.decimalApproxLatex, equals('0,5'));

      final cos45 = evaluator.evaluate(
        parser.parse('cos(45)'),
        angleUnit: AngleUnit.deg,
      );
      expect(cos45.exactResultLatex, equals(r'\frac{\sqrt{2}}{2}'));
      expect(
        cos45.steps.any((s) => s.latexExpression.contains(r'\frac{1}{\sqrt{2}}')),
        isTrue,
      );

      final sin60 = evaluator.evaluate(parser.parse('sin(60)'), angleUnit: AngleUnit.deg);
      expect(sin60.exactResultLatex, equals(r'\frac{\sqrt{3}}{2}'));

      final tan30 = evaluator.evaluate(parser.parse('tan(30)'), angleUnit: AngleUnit.deg);
      expect(tan30.exactResultLatex, equals(r'\frac{\sqrt{3}}{3}'));
    });

    test('Reducción al primer cuadrante y tangente indefinida en 90°', () {
      final sin150 = evaluator.evaluate(parser.parse('sin(150)'), angleUnit: AngleUnit.deg);
      expect(sin150.exactResultLatex, equals(r'\frac{1}{2}'));
      expect(sin150.steps.any((s) => s.shortTitle.contains('cuadrante')), isTrue);

      final cos120 = evaluator.evaluate(parser.parse('cos(120)'), angleUnit: AngleUnit.deg);
      expect(cos120.exactResultLatex, equals(r'-\frac{1}{2}'));

      final tan225 = evaluator.evaluate(parser.parse('tan(225)'), angleUnit: AngleUnit.deg);
      expect(tan225.exactResultLatex, equals('1'));

      final tan90 = evaluator.evaluate(parser.parse('tan(90)'), angleUnit: AngleUnit.deg);
      expect(tan90.exactResultLatex, equals(r'\text{No definido}'));
      expect(tan90.steps.first.warningTrick, isNotNull);
    });

    test('Soporte exacto en RAD (pi/6, pi/4) y trigonométricas inversas', () {
      final sinPi6 = evaluator.evaluate(
        parser.parse('sin(pi/6)'),
        angleUnit: AngleUnit.rad,
      );
      expect(sinPi6.exactResultLatex, equals(r'\frac{1}{2}'));

      final asinHalfDeg = evaluator.evaluate(
        parser.parse('sin⁻¹(1/2)'),
        angleUnit: AngleUnit.deg,
      );
      expect(asinHalfDeg.exactResultLatex, equals(r'30^\circ'));

      final asinHalfRad = evaluator.evaluate(
        parser.parse('sin⁻¹(1/2)'),
        angleUnit: AngleUnit.rad,
      );
      expect(asinHalfRad.exactResultLatex, equals(r'\frac{\pi}{6}'));

      final atan1Deg = evaluator.evaluate(
        parser.parse('tan⁻¹(1)'),
        angleUnit: AngleUnit.deg,
      );
      expect(atan1Deg.exactResultLatex, equals(r'45^\circ'));

      final domainErr = evaluator.evaluate(
        parser.parse('sin⁻¹(2)'),
        angleUnit: AngleUnit.deg,
      );
      expect(domainErr.exactResultLatex, equals(r'\text{No existe}'));
      expect(domainErr.steps.first.warningTrick, isNotNull);
    });
  });

  group('Fase 7A - Sistema Sexagesimal (° \' ")', () {
    test('Suma con acarreos en base 60: 10°40\' + 5°30\' = 16°10\' y con segundos', () {
      final res = evaluator.evaluate(parser.parse("10°40' + 5°30'"));
      expect(res.exactResultLatex, equals(r"16^\circ 10'"));
      expect(res.steps.any((s) => s.shortTitle.contains('base 60')), isTrue);

      final resFull = evaluator.evaluate(parser.parse("25°40'50'' + 12°35'40''"));
      expect(resFull.exactResultLatex, equals(r"38^\circ 16' 30''"));
    });

    test('Resta sexagesimal con préstamo en base 60 y conversión decimal -> DMS', () {
      final subRes = evaluator.evaluate(parser.parse("25°15'20'' - 12°40'50''"));
      expect(subRes.exactResultLatex, equals(r"12^\circ 34' 30''"));
      expect(subRes.steps.any((s) => s.shortTitle.contains('Préstamo')), isTrue);

      final decToDms = evaluator.evaluate(parser.parse('34.52°'));
      expect(decToDms.exactResultLatex, equals(r"34^\circ 31' 12''"));
      expect(decToDms.steps.length, equals(3));
    });
  });

  group('Fase 7A - Logaritmos Paso a Paso (ESO/Bachillerato)', () {
    test('Resuelve log_2(8) = 3, log_3(1/9) = -2 y log_4(32) = 5/2 por potencias', () {
      final log28 = evaluator.evaluate(parser.parse('log_(2,8)'));
      expect(log28.exactResultLatex, equals('3'));
      expect(log28.steps.any((s) => s.latexExpression.contains('2^{3}')), isTrue);

      final log3Frac = evaluator.evaluate(parser.parse('log_(3,1/9)'));
      expect(log3Frac.exactResultLatex, equals('-2'));
      expect(
        log3Frac.steps.any((s) => s.warningTrick != null && s.latexExpression.contains('3^{-2}')),
        isTrue,
      );

      final log432 = evaluator.evaluate(parser.parse('log_(4,32)'));
      expect(log432.exactResultLatex, equals(r'\frac{5}{2}'));
      expect(log432.decimalApproxLatex, equals('2,5'));

      final log1000 = evaluator.evaluate(parser.parse('log(1000)'));
      expect(log1000.exactResultLatex, equals('3'));

      final ln1 = evaluator.evaluate(parser.parse('ln(1)'));
      expect(ln1.exactResultLatex, equals('0'));
    });

    test('Detecta errores de dominio en argumentos <= 0 o base = 1', () {
      final logZero = evaluator.evaluate(parser.parse('log(0)'));
      expect(logZero.exactResultLatex, equals(r'\text{No existe}'));
      expect(logZero.steps.first.warningTrick, isNotNull);

      final logNeg = evaluator.evaluate(parser.parse('log_(2,-4)'));
      expect(logNeg.exactResultLatex, equals(r'\text{No existe}'));

      final badBase = evaluator.evaluate(parser.parse('log_(1,8)'));
      expect(badBase.exactResultLatex, equals(r'\text{No existe}'));
    });
  });

  group('Fase 7A - Porcentajes (%) y Notación Científica (×10ˣ)', () {
    test('Porcentajes simples e índice de variación (descuento e incremento)', () {
      final pctStandalone = evaluator.evaluate(parser.parse('25%'));
      expect(pctStandalone.exactResultLatex, equals(r'\frac{1}{4}'));
      expect(pctStandalone.decimalApproxLatex, equals('0,25'));

      final pctOf = evaluator.evaluate(parser.parse('200*20%'));
      expect(pctOf.exactResultLatex, equals('40'));

      final discount = evaluator.evaluate(parser.parse('120-20%'));
      expect(discount.exactResultLatex, equals('96'));
      expect(discount.steps.first.latexExpression, contains('0,8'));

      final increase = evaluator.evaluate(parser.parse('100+21%'));
      expect(increase.exactResultLatex, equals('121'));
    });

    test('Notación científica: normalización y producto/cociente paso a paso', () {
      final singleSci = evaluator.evaluate(parser.parse('3.2*10^-5'));
      expect(singleSci.exactResultLatex, equals(r'3,2 \cdot 10^{-5}'));
      expect(singleSci.decimalApproxLatex, equals('0,000032'));

      final prodSci = evaluator.evaluate(parser.parse('(4*10^5)*(3*10^-2)'));
      expect(prodSci.exactResultLatex, equals(r'1,2 \cdot 10^{4}'));
      expect(prodSci.decimalApproxLatex, equals('12000'));
      expect(prodSci.steps.length, equals(3));

      final divSci = evaluator.evaluate(parser.parse('(6*10^4):(2*10^-3)'));
      expect(divSci.exactResultLatex, equals(r'3 \cdot 10^{7}'));
      expect(divSci.steps.first.warningTrick, isNotNull);
    });
  });

  group('Fase 7A - Tecla CALC (Valor numérico con paréntesis)', () {
    test('Evalúa -x^2 - 2x en x = -3 obteniendo -3 y advirtiendo -(-3)^2 = -9', () {
      final ast = parser.parse('-x^2 - 2x');
      final res = CalcSolver.evaluateCalc(
        expr: ast,
        xValue: Rational(-3),
      );
      expect(res.exactResultLatex, equals('-3'));
      expect(
        res.steps.first.latexExpression,
        contains(r'-\left(-3\right)^{2}'),
      );
      expect(res.steps.first.warningTrick, isNotNull);
    });

    test('Evalúa -x^2 + 3x - 5 en x = -2 obteniendo -15', () {
      final ast = parser.parse('-x^2 + 3x - 5');
      final res = CalcSolver.evaluateCalc(
        expr: ast,
        xValue: Rational(-2),
      );
      expect(res.exactResultLatex, equals('-15'));
    });
  });

  group('Fase 7A - Blindaje LaTeX en flutter_math_fork', () {
    testWidgets('Todas las resoluciones 7A renderizan en Math.tex sin errores', (tester) async {
      final samples = [
        evaluator.evaluate(parser.parse('cos(45)'), angleUnit: AngleUnit.deg),
        evaluator.evaluate(parser.parse('sin(pi/6)'), angleUnit: AngleUnit.rad),
        evaluator.evaluate(parser.parse('tan(90)'), angleUnit: AngleUnit.deg),
        evaluator.evaluate(parser.parse("25°40'50'' + 12°35'40''")),
        evaluator.evaluate(parser.parse('34.52°')),
        evaluator.evaluate(parser.parse('log_(4,32)')),
        evaluator.evaluate(parser.parse('log(0)')),
        evaluator.evaluate(parser.parse('120-20%')),
        evaluator.evaluate(parser.parse('(4*10^5)*(3*10^-2)')),
        CalcSolver.evaluateCalc(expr: parser.parse('-x^2 - 2x'), xValue: Rational(-3)),
      ];

      final allLatexStrings = <String>[
        for (final r in samples) ...[
          r.originalInputLatex,
          r.exactResultLatex,
          r.decimalApproxLatex,
          for (final s in r.steps) s.latexExpression,
        ],
        ExpressionParser.rawToLiveLatex('log_(2,8)'),
        ExpressionParser.rawToLiveLatex('sin⁻¹(1/2)'),
        ExpressionParser.rawToLiveLatex('3.2*10^(-5)'),
        ExpressionParser.rawToLiveLatex("25°40'50''"),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (final tex in allLatexStrings)
                    Math.tex(
                      CasioLcdScreen.sanitizeForMathTex(tex),
                      onErrorFallback: (err) => Text('LATEX_ERROR: $tex -> $err'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('LATEX_ERROR'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Fase 7A - Interacción UI en CalculatorScreen', () {
    testWidgets('Teclas científicas nuevas visibles sin overflow en móvil (390x844)', (tester) async {
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

      expect(find.text('CALC'), findsOneWidget);
      expect(find.text('° \' "'), findsOneWidget);
      expect(find.text('sin'), findsOneWidget);
      expect(find.text('cos'), findsOneWidget);
      expect(find.text('tan'), findsOneWidget);
      expect(find.text('log■□'), findsNothing);
      expect(find.text('log'), findsOneWidget);
      expect(find.text('×10ˣ'), findsOneWidget);
      expect(find.byKey(const Key('lcd_angle_badge')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Flujo completo SETUP (DEG/RAD), log■□ con ▶, DMS y CALC desde teclado', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Conmutar DEG -> RAD desde SHIFT + MODE -> 2 y volver a DEG desde badge LCD
      await tester.tap(find.text('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      expect(find.text('CONFIG / SETUP'), findsOneWidget);
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('lcd_angle_badge')),
          matching: find.text('RAD'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('lcd_angle_badge')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('lcd_angle_badge')),
          matching: find.text('DEG'),
        ),
        findsOneWidget,
      );

      // 2. Logaritmo base 2 de 8 usando tecla log■□ (widget custom) + D-Pad derecha ▶ + =
      await tester.tap(find.widgetWithText(CasioPhysicalKey, 'log'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('replay_right')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '8'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 1/2'), findsWidgets);

      // 3. Porcentaje con SHIFT + ×10ˣ (%): 120 - 20% = 96
      await tester.tap(find.widgetWithText(CasioPhysicalKey, 'AC'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '0'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '-'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '0'));
      await tester.tap(find.text('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '×10ˣ'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();
      expect(find.textContaining('variación'), findsWidgets);

      // 4. Sexagesimal con SHIFT + . (° ' "): 10°40' + 5°30' = 16°10'
      await tester.tap(find.widgetWithText(CasioPhysicalKey, 'AC'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '0'));
      await tester.tap(find.text('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '.'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '0'));
      await tester.tap(find.text('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '.'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '+'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '5'));
      await tester.tap(find.text('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '.'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '3'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '0'));
      await tester.tap(find.text('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '.'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();
      expect(find.textContaining('Suma por columnas'), findsWidgets);
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();
      expect(find.textContaining('base 60'), findsWidgets);

      // 5. Limpiar con AC y probar CALC de -x^2 - 2x en x = -3
      await tester.tap(find.widgetWithText(CasioPhysicalKey, 'AC'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '-'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, ')'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, 'x²'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '-'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, ')'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CALC'));
      await tester.pumpAndSettle();
      expect(find.text('CALC: EVALUAR EN x'), findsOneWidget);

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '-'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '3'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sustitución de X'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
