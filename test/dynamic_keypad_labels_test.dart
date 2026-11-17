import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';

Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('SHIFT cambia la cara principal de sin y vuelve al cancelar', (tester) async {
    await _boot(tester);
    expect(find.text('sin'), findsOneWidget);
    await tester.tap(find.text('SHIFT'));
    await tester.pumpAndSettle();
    expect(find.text('sin'), findsNothing, reason: 'con SHIFT la cara principal pasa a sin⁻¹');
    await tester.tap(find.text('SHIFT'));
    await tester.pumpAndSettle();
    expect(find.text('sin'), findsOneWidget);
  });

  testWidgets('ALPHA transforma 7 en A y vuelve tras pulsar la tecla', (tester) async {
    await _boot(tester);
    expect(find.text('7'), findsWidgets);
    await tester.tap(find.text('ALPHA'));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsNothing);
    await tester.tap(find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == '7'));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsWidgets, reason: 'ALPHA se desactiva tras una pulsación');
  });
}
