import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/calculator_settings.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/complex/pol_rec_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/trig_and_angles_solver.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_menu_navigation.dart';

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
  // Se busca por el label base: con SHIFT/ALPHA la cara visible cambia (AC -> OFF, = -> ≈...).
  await tester.tap(find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == label).first);
  await tester.pumpAndSettle();
}

Future<void> _shift(WidgetTester tester, String label) async {
  await tester.tap(find.text('SHIFT'));
  await tester.pumpAndSettle();
  await _key(tester, label);
}

CasioLcdScreen _lcd(WidgetTester tester) =>
    tester.widget<CasioLcdScreen>(find.byType(CasioLcdScreen));

void main() {
  setUp(CalculatorSettings.reset);

  group('Pol / Rec (dominio)', () {
    test('Pol(1, 1) = r raiz de 2, theta 45 grados', () {
      final out = PolRecSolver.pol(Rational(1), Rational(1), AngleUnit.deg);
      expect(out.first, closeTo(1.41421356, 1e-6));
      expect(out.second, closeTo(45, 1e-9));
      expect(out.resolution.steps.length, 3);
    });

    test('Rec(2, 60) = x 1, y raiz de 3', () {
      final out = PolRecSolver.rec(Rational(2), 60, AngleUnit.deg);
      expect(out.first, closeTo(1, 1e-9));
      expect(out.second, closeTo(1.7320508, 1e-6));
    });

    test('Pol en gradianes devuelve 50 gra para (1, 1)', () {
      final out = PolRecSolver.pol(Rational(1), Rational(1), AngleUnit.grad);
      expect(out.second, closeTo(50, 1e-9));
    });
  });

  group('Sobrescritura (INS)', () {
    test('overwrite sustituye el token siguiente', () {
      final (raw, pos) = ExpressionParser.insertAtCursor('12', 1, '9', overwrite: true);
      expect(raw, '19');
      expect(pos, 2);
    });

    test('insercion normal desplaza', () {
      final (raw, _) = ExpressionParser.insertAtCursor('12', 1, '9');
      expect(raw, '192');
    });
  });

  group('Teclas SHIFT en la calculadora', () {
    testWidgets('SHIFT+AC apaga la LCD, bloquea teclas y AC enciende limpia', (tester) async {
      await _boot(tester);
      await _key(tester, '7');
      await _shift(tester, 'AC');
      expect(find.byKey(const Key('lcd_powered_off')), findsOneWidget);
      expect(find.text('CASIO'), findsOneWidget);
      await _key(tester, '5');
      expect(find.byKey(const Key('lcd_powered_off')), findsOneWidget);
      await _key(tester, 'AC');
      expect(find.byKey(const Key('lcd_powered_off')), findsNothing);
      expect(_lcd(tester).currentInputLatex.contains('7'), isFalse);
    });

    testWidgets('SHIFT+= (aproximacion) resuelve y muestra el decimal de un toque', (tester) async {
      await _boot(tester);
      await _key(tester, '1');
      await _key(tester, '÷');
      await _key(tester, '3');
      await _shift(tester, '=');
      expect(_lcd(tester).showDecimalApprox, isTrue);
      expect(_lcd(tester).currentResolution, isNotNull);
    });

    testWidgets('SHIFT++ inserta Pol( y Pol(3, 4) da r = 5', (tester) async {
      await _boot(tester);
      await _shift(tester, '+');
      await _key(tester, '3');
      await tester.tap(find.byIcon(Icons.arrow_right_rounded));
      await tester.pumpAndSettle();
      await _key(tester, '4');
      await _key(tester, '=');
      final res = _lcd(tester).currentResolution;
      expect(res, isNotNull);
      expect(res!.exactResultLatex.contains('r = 5'), isTrue);
    });

    testWidgets('SHIFT+- inserta Rec( y Rec(2, 0) da x = 2', (tester) async {
      await _boot(tester);
      await _shift(tester, '-');
      await _key(tester, '2');
      await tester.tap(find.byIcon(Icons.arrow_right_rounded));
      await tester.pumpAndSettle();
      await _key(tester, '0');
      await _key(tester, '=');
      final res = _lcd(tester).currentResolution;
      expect(res, isNotNull);
      expect(res!.exactResultLatex.contains('x = 2'), isTrue);
    });
  });

  group('Visor de memorias', () {
    testWidgets('OPTN/CALC abre la tabla con todo a 0 y AC vuelve', (tester) async {
      await _boot(tester);
      await tester.tap(find.text('OPTN'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lcd_memory_viewer')), findsOneWidget);
      for (final n in ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M']) {
        expect(find.text('$n=0'), findsOneWidget);
      }
      await _key(tester, 'AC');
      expect(find.byKey(const Key('lcd_memory_viewer')), findsNothing);
    });

    testWidgets('= guarda ANS en la variable enfocada', (tester) async {
      await _boot(tester);
      await _key(tester, '5');
      await _key(tester, '=');
      await tester.tap(find.text('OPTN'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_right_rounded));
      await tester.pumpAndSettle();
      await _key(tester, '=');
      expect(find.text('B=5'), findsOneWidget);
      await _key(tester, 'DEL');
      expect(find.text('B=0'), findsOneWidget);
    });
  });

  group('MENU 2D', () {
    test('menuMove: horizontal, vertical y salto de pagina', () {
      expect(menuMove(0, 'right'), 1);
      expect(menuMove(0, 'down'), 2);
      expect(menuMove(2, 'up'), 0);
      expect(menuMove(1, 'right'), 4); // borde derecho -> pagina 2, columna izquierda
      expect(menuMove(0, 'left'), 9); // borde izquierdo -> ultima pagina, columna derecha
      expect(menuMove(5, 'down'), 7);
    });

    testWidgets('digito 4 entra directo a M4 sin pulsar =', (tester) async {
      await _boot(tester);
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await _key(tester, '4');
      expect(find.byKey(const Key('hdr_poly_kind')), findsOneWidget);
    });

    testWidgets('1 y luego 2 entra a M12; 1 solo entra a M1 tras la espera', (tester) async {
      await _boot(tester);
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await _key(tester, '1');
      await _key(tester, '2');
      expect(find.byKey(const Key('hdr_calculus_op')), findsOneWidget);

      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await _key(tester, '1');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hdr_calculus_op')), findsNothing);
      expect(find.text('M1: CALCULAR'), findsOneWidget);
    });

    testWidgets('D-Pad ▶ y ▼ mueven el foco en 2D y = entra al modo enfocado', (tester) async {
      await _boot(tester);
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_right_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
      await tester.pumpAndSettle();
      await _key(tester, '=');
      // índice 0 -> ▶ 1 -> ▼ 3 = M4 (Polinomios / Ruffini)
      expect(find.byKey(const Key('hdr_poly_kind')), findsOneWidget);
    });
  });
}
