import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_dpad.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'package:casio_tutor_calc/presentation/widgets/windows_side_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Actualización 9A: Estabilidad, UX y Correcciones', () {
    testWidgets('1. Layout Apaisado Responsivo (844x390 landscape) divide en 2 columnas sin overflow', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Debe montar en 2 columnas: chasis a la izquierda y WindowsSidePanel a la derecha sin overflow
      expect(tester.takeException(), isNull);
      expect(find.byType(WindowsSidePanel), findsOneWidget);
      expect(find.byType(CasioReplayPad), findsOneWidget);
    });

    test('2. Salida de bloques estructurados con D-Pad ▶ (raíces, exponentes, trigonometría)', () {
      // Raíz cuadrada: √(5 + ▶ => √(5)
      final r1 = ExpressionParser.handleStructuredBlockRightArrow('√(5', 3);
      expect(r1, isNotNull);
      expect(r1!.$1, equals('√(5)'));
      expect(r1.$2, equals(4));

      // Exponente: 2^(2+x + ▶ => 2^(2+x)
      final r2 = ExpressionParser.handleStructuredBlockRightArrow('2^(2+x', 6);
      expect(r2, isNotNull);
      expect(r2!.$1, equals('2^(2+x)'));
      expect(r2.$2, equals(7));

      // Trig: sin(30 + ▶ => sin(30)
      final r3 = ExpressionParser.handleStructuredBlockRightArrow('sin(30', 6);
      expect(r3, isNotNull);
      expect(r3!.$1, equals('sin(30)'));
      expect(r3.$2, equals(7));
    });

    test('2b. Expresiones anidadas y potencias trigonométricas en parser y evaluador', () {
      final parser = ExpressionParser();
      final evaluator = StepEvaluator();

      // √(sin(x)) y 2^(2*(x+1)) formatean sin romper paréntesis
      final latexRoot = ExpressionParser.rawToLiveLatex('√(sin(x))');
      expect(latexRoot, contains(r'\sqrt{\sin\left(x\right)}'));

      final latexPow = ExpressionParser.rawToLiveLatex('2^(2*(x+1))');
      expect(latexPow, contains(r'2^{2 \cdot (x + 1)}'));

      // sin(sin(x)) y sin(cos(x))
      final latexNestedTrig = ExpressionParser.rawToLiveLatex('sin(cos(x))');
      expect(latexNestedTrig, contains(r'\sin\left(\cos\left(x\right)\right)'));

      // sin^2(30) evalúa a 0.25 (1/4)
      final ast1 = parser.parse('sin^2(30)');
      final res1 = evaluator.evaluate(ast1);
      expect(res1.exactResultLatex, contains(r'\frac{1}{4}'));

      // sin(30)^2 evalúa a 0.25 (1/4)
      final ast2 = parser.parse('sin(30)^2');
      final res2 = evaluator.evaluate(ast2);
      expect(res2.exactResultLatex, contains(r'\frac{1}{4}'));
    });

    test('3. Desaparición inmediata del 0 inicial excepto para punto decimal', () {
      // 0 + '5' => '5'
      final (raw5, cur5) = ExpressionParser.insertAtCursor('0', 1, '5', keepLeadingZero: false);
      expect(raw5, equals('5'));
      expect(cur5, equals(1));

      // 0 + '.' => '0.'
      final (rawDot, curDot) = ExpressionParser.insertAtCursor('0', 1, '.', keepLeadingZero: true);
      expect(rawDot, equals('0.'));
      expect(curDot, equals(2));

      // 0 + '+' => '+'
      final (rawPlus, curPlus) = ExpressionParser.insertAtCursor('0', 1, '+', keepLeadingZero: false);
      expect(rawPlus, equals('+'));
      expect(curPlus, equals(1));

      // 0 + 'x' => 'x'
      final (rawX, curX) = ExpressionParser.insertAtCursor('0', 1, 'x', keepLeadingZero: false);
      expect(rawX, equals('x'));
      expect(curX, equals(1));
    });

    test('5. Notables con huecos a y b vacíos y placeholders en live LaTeX', () {
      // ( + )^2 renderiza con a y b
      final liveEmpty = ExpressionParser.rawToLiveLatex('( + )^2');
      expect(liveEmpty, contains(r'{\color{gray} a}'));
      expect(liveEmpty, contains(r'{\color{gray} b}'));

      // Con cursor en slot a:
      final liveCursorA = ExpressionParser.rawToLiveLatex('( + )^2', cursorPos: 1);
      expect(liveCursorA, contains(r'{\color{gray} b}'));
    });

    testWidgets('6. Modo 5: Botón muestra vector icons y texto correcto según vista activa', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir menú y seleccionar Modo 5 (Gráficas) pulsando la tecla física '5'
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '5'));
      await tester.pumpAndSettle();

      // Antes de resolver no hay conmutador de vista (solo Tipo y la plantilla f(x)).
      expect(find.byKey(const Key('mode5_view_toggle')), findsNothing);
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '5'));
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      // Con resultado y _showGraphView == true, el botón debe decir 'Ver Pasos' con icono format_list
      expect(find.text('Ver Pasos'), findsOneWidget);
      expect(find.byIcon(Icons.format_list_numbered_rounded), findsOneWidget);

      // Al pulsar el botón, conmuta a vista de pasos y el botón debe decir 'Ver Gráfica' con show_chart
      await tester.tap(find.byKey(const Key('mode5_view_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Ver Gráfica'), findsOneWidget);
      expect(find.byIcon(Icons.show_chart_rounded), findsOneWidget);
    });
  });
}
