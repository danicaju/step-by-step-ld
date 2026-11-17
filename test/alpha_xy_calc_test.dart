import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'support/header_select.dart';

Future<void> _boot(WidgetTester tester, int mode) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: CalculatorScreen())));
  await tester.pumpAndSettle();
  await tester.tap(find.text('MODE'));
  await tester.pumpAndSettle();
  for (var g = 0; g < 4 && find.byKey(Key('menu_mode_$mode')).evaluate().isEmpty; g++) {
    await tester.tap(find.byKey(const Key('menu_page_next')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(Key('menu_mode_$mode')));
  await tester.pumpAndSettle();
}

Future<void> _num(WidgetTester tester, String l) async {
  await tester.tap(find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == l));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ALPHA muestra x e y minusculas en ) y (', (tester) async {
    await _boot(tester, 1);
    await tester.tap(find.text('ALPHA'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CasioPhysicalKey, 'x'), findsWidgets);
    expect(find.widgetWithText(CasioPhysicalKey, 'y'), findsWidgets);
    expect(find.widgetWithText(CasioPhysicalKey, 'X'), findsWidgets);
  });

  testWidgets('M2: ALPHA+CALC cambia de miembro y resuelve 3x-2=7', (tester) async {
    await _boot(tester, 2);
    await _num(tester, '3');
    await alphaKey(tester, ')');
    await _num(tester, '-');
    await _num(tester, '2');
    await alphaCalc(tester);
    await _num(tester, '7');
    await tester.tap(find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == '='));
    await tester.pumpAndSettle();
    final lcd = tester.widget<CasioLcdScreen>(find.byType(CasioLcdScreen));
    expect(lcd.currentResolution?.exactResultLatex, equals('x = 3'));
  });

  testWidgets('M7: ALPHA+) inserta x y el desplegable Signo existe sin barra inferior', (tester) async {
    await _boot(tester, 7);
    expect(find.byKey(const Key('hdr_ineqsys_sign')), findsOneWidget);
    expect(find.byKey(const Key('ineq_sys_var_x')), findsNothing);
    await alphaKey(tester, ')');
    await pickHeader(tester, 'hdr_ineqsys_sign', 'ineq_sign_greaterOrEqual');
    expect(tester.takeException(), isNull);
  });
}
