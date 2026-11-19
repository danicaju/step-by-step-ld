import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/calculator_settings.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/trig_and_angles_solver.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
  );
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(CasioPhysicalKey, label).first);
  await tester.pumpAndSettle();
}

Future<void> _openSetup(WidgetTester tester) async {
  await tester.tap(find.text('SHIFT'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('MODE'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('lcd_setup_menu')), findsOneWidget);
}

void main() {
  setUp(CalculatorSettings.reset);
  tearDown(CalculatorSettings.reset);

  group('Formato numerico (dominio)', () {
    test('Fix 2 redondea a 2 decimales', () {
      CalculatorSettings.numberFormat = NumberFormatMode.fix;
      CalculatorSettings.digits = 2;
      expect(Rational(1, 3).toDecimalLatex(), '0,33');
      expect(Rational(3).toDecimalLatex(), '3,00');
    });

    test('Sci 3 usa mantisa y potencia de 10', () {
      CalculatorSettings.numberFormat = NumberFormatMode.sci;
      CalculatorSettings.digits = 3;
      expect(Rational(12345).toDecimalLatex(), r'1,23\times 10^{4}');
    });

    test('ab/c muestra fraccion mixta y d/c impropia', () {
      expect(Rational(3, 2).toLatex(), r'\frac{3}{2}');
      CalculatorSettings.mixedFractions = true;
      expect(Rational(3, 2).toLatex(), r'1\frac{1}{2}');
      expect(Rational(-7, 3).toLatex(), r'-2\frac{1}{3}');
    });

    test('separador punto', () {
      CalculatorSettings.decimalComma = false;
      expect(Rational(1, 4).toDecimalLatex(), '0.25');
    });

    test('GRA: sin(100 gra) = 1', () {
      final ast = ExpressionParser().parse('sin(100)');
      final res = StepEvaluator().evaluate(ast, angleUnit: AngleUnit.grad);
      expect(res.exactResultLatex, '1');
    });
  });

  group('SETUP en la LCD', () {
    testWidgets('abre con SHIFT+MODE, pagina 1/4 y D-Pad pasa a pagina 2/4', (tester) async {
      await _boot(tester);
      await _openSetup(tester);
      expect(find.text('SETUP  1/4'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('SETUP  2/4'), findsOneWidget);
    });

    testWidgets('1 -> 3 elige GRA y el indicador lo muestra', (tester) async {
      await _boot(tester);
      await _openSetup(tester);
      await _key(tester, '1');
      await _key(tester, '3');
      expect(
        find.descendant(of: find.byKey(const Key('lcd_angle_badge')), matching: find.text('GRA')),
        findsOneWidget,
      );
    });

    testWidgets('2 -> 2 -> 2 elige Fix con 2 decimales', (tester) async {
      await _boot(tester);
      await _openSetup(tester);
      await _key(tester, '2');
      await _key(tester, '2');
      await _key(tester, '2');
      expect(CalculatorSettings.numberFormat, NumberFormatMode.fix);
      expect(CalculatorSettings.digits, 2);
    });

    testWidgets('3 -> 2 elige fraccion mixta ab/c', (tester) async {
      await _boot(tester);
      await _openSetup(tester);
      await _key(tester, '3');
      await _key(tester, '2');
      expect(CalculatorSettings.mixedFractions, isTrue);
    });

    testWidgets('4 -> 1 separador punto; 8 -> 2 restaura configuracion', (tester) async {
      await _boot(tester);
      await _openSetup(tester);
      await _key(tester, '4');
      await _key(tester, '1');
      expect(CalculatorSettings.decimalComma, isFalse);
      await _openSetup(tester);
      await _key(tester, '8');
      await _key(tester, '2');
      expect(CalculatorSettings.decimalComma, isTrue);
    });
  });
}
