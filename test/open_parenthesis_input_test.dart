import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/calculator_settings.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
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
  await tester.tap(find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == label).first);
  await tester.pumpAndSettle();
}

CasioLcdScreen _lcd(WidgetTester tester) =>
    tester.widget<CasioLcdScreen>(find.byType(CasioLcdScreen));

void main() {
  setUp(CalculatorSettings.reset);

  testWidgets('(2+3 sin cerrar evalua a 5 sin Syntax ERROR', (tester) async {
    await _boot(tester);
    for (final k in ['(', '2', '+', '3', '=']) {
      await _key(tester, k);
    }
    expect(_lcd(tester).currentResolution, isNotNull);
    expect(_lcd(tester).currentResolution!.exactResultLatex, '5');
  });

  testWidgets('sin( con 30 sin cerrar da 1/2 y ▶ no hace falta', (tester) async {
    await _boot(tester);
    for (final k in ['sin', '3', '0', '=']) {
      await _key(tester, k);
    }
    expect(_lcd(tester).currentResolution!.exactResultLatex, r'\frac{1}{2}');
  });

  testWidgets('pulsar ) sobrescribe el cierre automatico', (tester) async {
    await _boot(tester);
    for (final k in ['(', '2', '+', '3', ')', '×', '2', '=']) {
      await _key(tester, k);
    }
    expect(_lcd(tester).currentResolution!.exactResultLatex, '10');
  });
}
