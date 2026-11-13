import 'package:casio_tutor_calc/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CasioCalculatorApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CasioCalculatorApp()));
    expect(find.text('STEP-BY-STEP LD'), findsOneWidget);
    expect(find.text('NATURAL-V.P.A.M. // STEP ENGINE'), findsOneWidget);
    expect(find.byKey(const Key('appbar_export_png')), findsOneWidget);
    expect(find.byKey(const Key('appbar_copy_latex')), findsOneWidget);
    expect(find.byKey(const Key('appbar_history')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
