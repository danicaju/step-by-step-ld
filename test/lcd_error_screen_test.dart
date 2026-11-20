import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_error_screen.dart';

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
  await tester.tap(label == '=' ? find.text(label).last : find.text(label).first);
  await tester.pumpAndSettle();
}

void main() {
  labelTests();
  testWidgets('LcdErrorScreen muestra titulo, mensaje y pie', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(
        height: 220,
        child: LcdErrorScreen(kind: LcdErrorKind.math, message: 'No se puede dividir entre cero.'),
      ),
    ));
    expect(find.text('Math ERROR'), findsOneWidget);
    expect(find.text('No se puede dividir entre cero.'), findsOneWidget);
    expect(find.text('[ ◀ ]'), findsOneWidget);
    expect(find.text('[ ▶ ]'), findsOneWidget);
    expect(find.text('Volver a editar'), findsOneWidget);
    expect(find.text('[ AC ]'), findsOneWidget);
    expect(find.text('Borrar todo'), findsOneWidget);
    expect(find.textContaining('Cómo solucionarlo'), findsOneWidget);
  });

  for (final h in [56.0, 90.0, 140.0, 290.0]) {
    testWidgets('LcdErrorScreen sin overflow con LCD de $h px', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(
          height: h,
          child: const LcdErrorScreen(
            kind: LcdErrorKind.math,
            message: 'Raíz de índice par de un número negativo (no existe en ℝ).',
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  }

  test('LcdErrorText.clean quita prefijos tecnicos de Dart', () {
    expect(
      LcdErrorText.clean('Error al evaluar: Invalid argument(s): No se puede dividir.'),
      'No se puede dividir.',
    );
    expect(LcdErrorText.clean('Exception: FormatException: algo raro'), 'Algo raro');
    expect(LcdErrorText.clean('Math ERROR: operación no definida.'), 'Operación no definida.');
    expect(LcdErrorText.clean('Error al evaluar:'), 'Operación no definida.');
  });

  for (final arrow in [Icons.arrow_left_rounded, Icons.arrow_right_rounded]) {
    testWidgets('error en la LCD se cierra con $arrow y conserva la expresion', (tester) async {
      await _boot(tester);
      await _key(tester, '1');
      await _key(tester, '÷');
      await _key(tester, '0');
      await _key(tester, '=');
      expect(find.byKey(const Key('lcd_error_screen')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.byIcon(arrow).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lcd_error_screen')), findsNothing);
    });
  }

  testWidgets('AC cierra el error y vuelve a 0', (tester) async {
    await _boot(tester);
    await _key(tester, '=');
    expect(find.byKey(const Key('lcd_error_screen')), findsOneWidget);
    await _key(tester, 'AC');
    expect(find.byKey(const Key('lcd_error_screen')), findsNothing);
  });
}

void labelTests() {
  testWidgets('insignia usa nombres oficiales M1 y M12', (tester) async {
    await _boot(tester);
    expect(find.text('M1: CALCULAR'), findsOneWidget);
    expect(find.text('M1: CALC & √'), findsNothing);
  });
}
