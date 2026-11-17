import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/calculator_settings.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';

/// Helpers E2E: pulsaciones reales de teclas fisicas sobre CalculatorScreen.
bool balanced(String s) {
  var d = 0;
  for (final ch in s.split('')) {
    if (ch == '{') d++;
    if (ch == '}') d--;
    if (d < 0) return false;
  }
  return d == 0;
}

Future<void> boot(WidgetTester t, {Size size = const Size(430, 900)}) async {
  CalculatorSettings.reset();
  await t.binding.setSurfaceSize(size);
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(const ProviderScope(child: MaterialApp(home: CalculatorScreen())));
  await t.pumpAndSettle();
}

Future<void> tapF(WidgetTester t, Finder f) async {
  await t.tap(f.first);
  await t.pumpAndSettle();
}

Future<void> key(WidgetTester t, String label) =>
    tapF(t, find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == label));

/// Teclea una secuencia de etiquetas de teclas fisicas.
Future<void> keys(WidgetTester t, List<String> labels) async {
  for (final l in labels) {
    await key(t, l);
  }
}

Future<void> pad(WidgetTester t, String dir) => tapF(t, find.byKey(Key('replay_$dir')));

Future<void> shiftKey(WidgetTester t, String label) async {
  await tapF(t, find.text('SHIFT'));
  await key(t, label);
}

CasioLcdScreen lcd(WidgetTester t) => t.widget<CasioLcdScreen>(find.byType(CasioLcdScreen));

String live(WidgetTester t) => lcd(t)
    .currentInputLatex
    .replaceAll(' ', '')
    .replaceAll(r'\textcolor{#2E86DE}{\mid}', '');

String? result(WidgetTester t) => lcd(t).currentResolution?.exactResultLatex;
