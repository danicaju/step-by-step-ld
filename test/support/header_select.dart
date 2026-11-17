import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
