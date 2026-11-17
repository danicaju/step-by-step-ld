import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'support/header_select.dart';

Future<void> _openMode(WidgetTester tester, int mode) async {
  await tester.tap(find.text('MODE'));
  await tester.pumpAndSettle();
  for (var g = 0; g < 4 && find.byKey(Key('menu_mode_$mode')).evaluate().isEmpty; g++) {
    await tester.tap(find.byKey(const Key('menu_page_next')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(Key('menu_mode_$mode')));
  await tester.pumpAndSettle();
}

Future<void> _boot(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: CalculatorScreen())));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('M3: tamano y metodo en cabecera LCD, sin barra inferior', (tester) async {
    await _boot(tester);
    await _openMode(tester, 3);
    expect(find.byKey(const Key('hdr_sys_size')), findsOneWidget);
    expect(find.byKey(const Key('hdr_sys_method')), findsOneWidget);
    expect(find.byKey(const Key('sys3_solve_btn')), findsNothing);
    await pickHeader(tester, 'hdr_sys_size', 'sys_dim_3');
    expect(find.text('3 Ec.'), findsWidgets);
  });

  testWidgets('M3: D-Pad sube a la cabecera y cambia el tamano con la flecha derecha', (tester) async {
    await _boot(tester);
    await _openMode(tester, 3);
    await tester.tap(find.byIcon(Icons.arrow_drop_up_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_right_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('3 Ec.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M4: Ruffini/Notables y Grado en cabecera', (tester) async {
    await _boot(tester);
    await _openMode(tester, 4);
    expect(find.byKey(const Key('hdr_poly_kind')), findsOneWidget);
    expect(find.byKey(const Key('ruffini_tab_3')), findsNothing, reason: 'sin botones de grado abajo');
  });

  testWidgets('M6: sin boton Signo azul; barra inferior solo x y signos', (tester) async {
    await _boot(tester);
    await _openMode(tester, 6);
    expect(find.byKey(const Key('lcd_ineq_sign_btn')), findsNothing);
    expect(find.byKey(const Key('hdr_ineq_kind')), findsOneWidget);
    expect(find.byKey(const Key('ineq_var_x')), findsOneWidget);
    expect(find.byKey(const Key('ineq_sign_less')), findsOneWidget);
  });

  testWidgets('M11 y M12: sin boton Calcular', (tester) async {
    await _boot(tester);
    await _openMode(tester, 11);
    expect(find.byKey(const Key('complex_solve_btn')), findsNothing);
    await _openMode(tester, 12);
    expect(find.byKey(const Key('calculus_solve_btn')), findsNothing);
  });

  testWidgets('Menu: swipe horizontal cambia de pagina', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('MODE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1/3'), findsWidgets);
    await tester.fling(find.byKey(const Key('menu_grid_gesture')), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.textContaining('2/3'), findsWidgets);
    await tester.fling(find.byKey(const Key('menu_grid_gesture')), const Offset(300, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.textContaining('1/3'), findsWidgets);
  });
}
