import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';

/// Abre un desplegable de la cabecera LCD y elige el ítem con la key indicada.
Future<void> pickHeader(WidgetTester tester, String dropdownKey, String itemKey) async {
  await tester.ensureVisible(find.byKey(Key(dropdownKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(dropdownKey)));
  await tester.pumpAndSettle();
  // El menu esta acotado a la LCD y hace scroll: se trae la fila a la vista.
  await tester.ensureVisible(find.byKey(Key(itemKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(itemKey)));
  await tester.pumpAndSettle();
}

/// ALPHA + tecla física por su etiqueta base (p. ej. `)` -> x, `(` -> y).
Future<void> alphaKey(WidgetTester tester, String label) async {
  await tester.tap(find.text('ALPHA'));
  await tester.pump();
  await tester.tap(find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == label));
  await tester.pumpAndSettle();
}

/// ALPHA + CALC (escribe `=`).
Future<void> alphaCalc(WidgetTester tester) async {
  await tester.tap(find.text('ALPHA'));
  await tester.pump();
  await tester.tap(find.text('OPTN'));
  await tester.pumpAndSettle();
}
