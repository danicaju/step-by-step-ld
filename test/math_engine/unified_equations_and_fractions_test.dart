import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/polynomial_equation_solver.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/windows_side_panel.dart';

void main() {
  group('PolynomialEquationSolver (1.º y 2.º grado libre / desordenado)', () {
    test('Resuelve ecuación lineal simple: 2x + 4 = 16 -> x = 6', () {
      final res = PolynomialEquationSolver.solveEquationString('2x + 4 = 16');
      expect(res.exactResultLatex, equals('x = 6'));
      expect(res.steps, isNotEmpty);
    });

    test('Resuelve ecuación lineal con fracciones: (x-1)/2 + 3 = x -> x = 5', () {
      final res = PolynomialEquationSolver.solveEquationString('(x-1)/2 + 3 = x');
      expect(res.exactResultLatex, equals('x = 5'));
    });

    test('Resuelve ecuación de 2.º grado desordenada: 2x^2 - 4x = x^2 - 3', () {
      final res = PolynomialEquationSolver.solveEquationString('2x^2 - 4x = x^2 - 3');
      expect(res.exactResultLatex, contains('3'));
      expect(res.exactResultLatex, contains('1'));
      expect(res.steps.length, greaterThanOrEqualTo(3));
    });

    test('Resuelve ecuación cuadrática con paréntesis notable: (x+1)^2 = 2x + 5', () {
      final res = PolynomialEquationSolver.solveEquationString('(x+1)^2 = 2x + 5');
      expect(res.exactResultLatex, contains('-2'));
      expect(res.exactResultLatex, contains('2'));
    });

    test('Resuelve cuadrática incompleta desordenada: 5x = 2x^2 -> 0 y 5/2', () {
      final res = PolynomialEquationSolver.solveEquationString('5x = 2x^2');
      expect(res.exactResultLatex, contains('0'));
      expect(res.exactResultLatex, contains(r'\frac{5}{2}'));
    });

    test('Detecta identidad e incompatible sin fallos ni \\text con tildes', () {
      final identity = PolynomialEquationSolver.solveEquationString('2(x + 1) = 2x + 2');
      expect(identity.exactResultLatex.toLowerCase(), contains('infinit'));

      final impossible = PolynomialEquationSolver.solveEquationString('x + 1 = x + 5');
      expect(impossible.exactResultLatex, contains('Sin solucion'));

      for (final step in [...identity.steps, ...impossible.steps]) {
        final tex = step.latexExpression;
        expect(tex, isNot(contains('\r')));
        final textBlocks = RegExp(r'\\text\{([^}]*)\}').allMatches(tex);
        for (final m in textBlocks) {
          expect(m.group(1), isNot(matches(RegExp(r'[áéíóúÁÉÍÓÚñÑ]'))));
        }
      }
    });
  });

  group('ExpressionParser fracciones verticales y navegación ▼/▲', () {
    test('Fracción vacía "/" nunca mete 0 en el numerador y coloca el cursor arriba', () {
      final latexTop = ExpressionParser.rawToLiveLatex('/', cursorPos: 0);
      expect(latexTop, startsWith(r'\frac{\textcolor{#2E86DE}{\blacksquare}}{'));
      expect(latexTop, isNot(contains('0')));

      final latexBottom = ExpressionParser.rawToLiveLatex('/', cursorPos: 1);
      expect(latexBottom, startsWith(r'\frac{\square}{\textcolor{#2E86DE}{\blacksquare}}'));
    });

    test('Todas las divisiones y fracciones anidadas se renderizan con \\frac', () {
      final simpleFrac = ExpressionParser.rawToLiveLatex('(x-1)/2');
      expect(simpleFrac, contains(r'\frac{'));
      expect(simpleFrac, isNot(contains('/')));

      final nestedFrac = ExpressionParser.rawToLiveLatex('(1/2)/3');
      expect(nestedFrac, contains(r'\frac{\frac{1}{2}}{3}'));
      expect(nestedFrac, isNot(contains('/')));
    });

    test('jumpFractionUpDown salta entre numerador y denominador', () {
      const expr = '12/34';
      final downPos = ExpressionParser.jumpFractionUpDown(expr, 1, isUp: false);
      expect(downPos, isNotNull);
      expect(downPos!, greaterThanOrEqualTo(3));

      final upPos = ExpressionParser.jumpFractionUpDown(expr, 4, isUp: true);
      expect(upPos, isNotNull);
      expect(upPos!, lessThanOrEqualTo(2));
    });
  });

  group('Refactorización de precisión UI en CalculatorScreen', () {
    testWidgets('Tecla a/b en pantalla vacía crea fracción vacía sin 0 en numerador',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('a/b'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('replay_down')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      final lcdBeforeEval = tester.widget<CasioLcdScreen>(find.byType(CasioLcdScreen));
      expect(lcdBeforeEval.currentInputLatex, contains(r'\frac{'));
      expect(lcdBeforeEval.currentInputLatex, contains('3'));
      expect(lcdBeforeEval.currentInputLatex, contains('4'));
      expect(lcdBeforeEval.currentInputLatex, isNot(contains(r'\frac{03}')));
      expect(
        tester.widgetList<Math>(find.byType(Math)).every((m) => m.parseError == null),
        isTrue,
      );

      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      final lcdAfterEval = tester.widget<CasioLcdScreen>(find.byType(CasioLcdScreen));
      expect(lcdAfterEval.currentResolution?.exactResultLatex, equals(r'\frac{3}{4}'));
    });

    testWidgets('Tecla log■□ usa widget custom en vez de texto plano log■□', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('log■□'), findsNothing);
      expect(find.text('log'), findsWidgets);
    });

    testWidgets('Modo 2 (Ecuaciones) mantiene el "=" fijo entre miembros y resuelve 1.º y 2.º grado',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mode_2')));
      await tester.pumpAndSettle();

      expect(find.text('M2: ECUACIONES'), findsOneWidget);
      expect(find.byKey(const Key('eq_sign_equals')), findsOneWidget);

      // DEL sobre el primer miembro vacío no debe romper la pantalla ni borrar '='
      await tester.tap(find.text('DEL'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('eq_var_x')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('eq_sign_equals')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      final lcd = tester.widget<CasioLcdScreen>(find.byType(CasioLcdScreen));
      expect(lcd.currentResolution?.exactResultLatex, equals('x = 6'));
    });

    testWidgets('MENU paginado 3 páginas (11 modos) y limpieza de botones de teclado/AppBar',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
      );
      await tester.pumpAndSettle();

      // Limpieza de botones antiguos en teclado, AppBar y panel lateral
      expect(find.text('TUTOR IA'), findsNothing);
      expect(find.text('STICKER'), findsNothing);
      expect(find.text('SCAN IA'), findsNothing);
      expect(find.text('Sticker Goodnotes'), findsNothing);
      expect(find.text('Exportar Sticker Goodnotes'), findsNothing);
      expect(find.text('Preguntar al Tutor IA'), findsNothing);

      expect(find.text('SHIFT'), findsOneWidget);
      expect(find.text('ALPHA'), findsOneWidget);
      expect(find.text('MODE'), findsOneWidget);
      expect(find.text('CALC'), findsOneWidget);
      expect(find.text('OPTN'), findsOneWidget);
      expect(find.text('DEG'), findsOneWidget);
      expect(find.byKey(const Key('lcd_angle_badge')), findsOneWidget);
      expect(find.byKey(const Key('lcd_theme_toggle')), findsOneWidget);
      expect(find.byKey(const Key('lcd_sound_toggle')), findsOneWidget);
      expect(find.byKey(const Key('appbar_export_png')), findsOneWidget);
      expect(find.byKey(const Key('appbar_copy_latex')), findsOneWidget);
      expect(find.byKey(const Key('appbar_history')), findsOneWidget);
      expect(find.byType(WindowsSidePanel), findsOneWidget);
      await tester.tap(find.text('DESGLOSE PASO A PASO'));
      await tester.pumpAndSettle();
      expect(find.text('EXPORTAR PNG'), findsOneWidget);
      expect(find.text('COPIAR LaTeX'), findsOneWidget);

      // Comprobar paginación 1/3 -> 2/3 -> 3/3 en MENU
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu_page_indicator')), findsOneWidget);
      expect(find.text('PÁGINA 1/3'), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_1')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_4')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_5')), findsNothing);

      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      expect(find.text('PÁGINA 2/3'), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_5')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_8')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_9')), findsNothing);

      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      expect(find.text('PÁGINA 3/3'), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_9')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_11')), findsOneWidget);
    });
  });
}
