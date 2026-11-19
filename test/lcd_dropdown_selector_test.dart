import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_dropdown_selector.dart';
import 'support/e2e_helpers.dart';
import 'support/header_select.dart';

Widget host({
  required List<LcdDropdownItem<int>> items,
  required ValueChanged<int> onChanged,
  required LcdDropdownController ctrl,
  GlobalKey? bounds,
  int? columns,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          height: 220,
          child: Container(
            key: bounds,
            color: const Color(0xFFC8D6CD),
            alignment: Alignment.topLeft,
            child: LcdDropdownSelector<int>(
              widgetKey: const Key('dd'),
              prefix: 'Op',
              value: 0,
              items: items,
              columns: columns,
              controller: ctrl,
              boundsKey: bounds,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
}

List<LcdDropdownItem<int>> many(int n) => [
      for (int i = 0; i < n; i++)
        LcdDropdownItem(value: i, label: 'Opcion larga $i', key: Key('it_$i')),
    ];

void main() {
  group('LcdDropdownNav', () {
    test('1 columna: arriba y abajo ciclan', () {
      final nav = LcdDropdownNav(count: 5);
      nav.move('up');
      expect(nav.index, 4);
      nav.move('down');
      expect(nav.index, 0);
    });

    test('2 columnas: navegacion y auto-columnas', () {
      final nav = LcdDropdownNav(count: 5, columns: 2);
      nav.move('right');
      expect(nav.index, 1);
      nav.move('down');
      expect(nav.index, 3);
      nav.move('left');
      expect(nav.index, 2);
      nav.move('down');
      expect(nav.index, 4);
      nav.move('down');
      expect(nav.index, 0);
      expect(LcdDropdownNav.autoColumns(['<', '≤', '>', '≥']), 2);
      expect(LcdDropdownNav.autoColumns(['Opcion larga uno', 'b', 'c', 'd']), 1);
      expect(LcdDropdownNav.digitIndex('3', 5), 2);
      expect(LcdDropdownNav.digitIndex('7', 5), isNull);
      expect(LcdDropdownNav.digitIndex('0', 5), isNull);
    });
  });

  group('LcdDropdownSelector overlay', () {
    testWidgets('12 opciones: prefijos 1:-9:, filas de 28 px, acotado a la LCD', (t) async {
      final ctrl = LcdDropdownController();
      final bounds = GlobalKey();
      await t.pumpWidget(host(items: many(12), onChanged: (_) {}, ctrl: ctrl, bounds: bounds));
      await t.tap(find.byKey(const Key('dd')));
      await t.pumpAndSettle();
      expect(ctrl.isOpen, isTrue);
      expect(find.text('1:'), findsOneWidget);
      expect(find.text('9:'), findsOneWidget);
      expect(find.text('10:'), findsNothing);
      final panel = t.getRect(find.byKey(const Key('lcd_dropdown_panel')));
      final lcd = t.getRect(find.byKey(bounds));
      expect(panel.bottom, lessThanOrEqualTo(lcd.bottom - 24 + 3));
      expect(t.getSize(find.byKey(const Key('it_0'))).height, 28);
      expect(find.byKey(const Key('lcd_dropdown_more_down')), findsOneWidget);
      expect(find.byKey(const Key('lcd_dropdown_more_up')), findsNothing);
      expect(find.byKey(const Key('lcd_dropdown_scrollbar')), findsOneWidget);
    });

    testWidgets('D-Pad abajo hace scroll automatico hasta la ultima opcion', (t) async {
      final ctrl = LcdDropdownController();
      final bounds = GlobalKey();
      int? chosen;
      await t.pumpWidget(
          host(items: many(12), onChanged: (v) => chosen = v, ctrl: ctrl, bounds: bounds));
      await t.tap(find.byKey(const Key('dd')));
      await t.pumpAndSettle();
      for (int i = 0; i < 11; i++) {
        expect(ctrl.handleDpad('down'), isTrue);
        await t.pumpAndSettle();
      }
      final panel = t.getRect(find.byKey(const Key('lcd_dropdown_panel')));
      final last = t.getRect(find.byKey(const Key('it_11')));
      expect(last.bottom, lessThanOrEqualTo(panel.bottom + 0.5));
      expect(last.top, greaterThanOrEqualTo(panel.top - 0.5));
      expect(find.byKey(const Key('lcd_dropdown_more_up')), findsOneWidget);
      expect(find.byKey(const Key('lcd_dropdown_more_down')), findsNothing);
      expect(ctrl.handleKey('='), isTrue);
      await t.pumpAndSettle();
      expect(chosen, 11);
      expect(ctrl.isOpen, isFalse);
    });

    testWidgets('teclas 1-9 eligen al instante y AC cierra', (t) async {
      final ctrl = LcdDropdownController();
      int? chosen;
      await t.pumpWidget(host(items: many(12), onChanged: (v) => chosen = v, ctrl: ctrl));
      await t.tap(find.byKey(const Key('dd')));
      await t.pumpAndSettle();
      expect(ctrl.handleKey('5'), isTrue);
      await t.pumpAndSettle();
      expect(chosen, 4);
      expect(ctrl.isOpen, isFalse);
      await t.tap(find.byKey(const Key('dd')));
      await t.pumpAndSettle();
      expect(ctrl.handleKey('AC'), isTrue);
      await t.pumpAndSettle();
      expect(ctrl.isOpen, isFalse);
      expect(chosen, 4);
    });

    testWidgets('2 columnas automaticas para signos y navegacion', (t) async {
      final ctrl = LcdDropdownController();
      int? chosen;
      final signs = [
        for (final e in ['<', '≤', '>', '≥'].asMap().entries)
          LcdDropdownItem(value: e.key, label: e.value, key: Key('s_${e.key}')),
      ];
      await t.pumpWidget(host(items: signs, onChanged: (v) => chosen = v, ctrl: ctrl));
      await t.tap(find.byKey(const Key('dd')));
      await t.pumpAndSettle();
      expect(t.getRect(find.byKey(const Key('s_0'))).top,
          t.getRect(find.byKey(const Key('s_1'))).top);
      ctrl.handleDpad('right');
      ctrl.handleDpad('down');
      await t.pumpAndSettle();
      ctrl.handleKey('=');
      await t.pumpAndSettle();
      expect(chosen, 3);
    });

    testWidgets('tocar un item elige y cierra', (t) async {
      final ctrl = LcdDropdownController();
      int? chosen;
      await t.pumpWidget(
          host(items: many(4), onChanged: (v) => chosen = v, ctrl: ctrl, columns: 1));
      await t.tap(find.byKey(const Key('dd')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('it_2')));
      await t.pumpAndSettle();
      expect(chosen, 2);
      expect(find.byKey(const Key('lcd_dropdown_panel')), findsNothing);
    });
  });

  group('Integracion en la calculadora', () {
    testWidgets('M6: flecha arriba NO enfoca la cabecera; el desplegable se abre con el puntero', (t) async {
      await boot(t, size: const Size(360, 800));
      await tapF(t, find.text('MODE'));
      for (var g = 0; g < 4 && find.byKey(const Key('menu_mode_6')).evaluate().isEmpty; g++) {
        await tapF(t, find.byKey(const Key('menu_page_next')));
      }
      await tapF(t, find.byKey(const Key('menu_mode_6')));
      await pad(t, 'up');
      await pad(t, 'left');
      expect(find.byKey(const Key('lcd_dropdown_panel')), findsNothing);
      expect(find.textContaining('2.º Grado'), findsNothing);
      await pickHeader(t, 'hdr_ineq_kind', 'ineq_deg_2');
      expect(find.byKey(const Key('lcd_dropdown_panel')), findsNothing);
      expect(find.textContaining('2.º Grado'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('pickHeader sigue funcionando con el overlay', (t) async {
      await boot(t);
      await tapF(t, find.text('MODE'));
      await tapF(t, find.byKey(const Key('menu_mode_2')));
      await pickHeader(t, 'hdr_eq_kind', 'eq_kind_1');
      expect(t.takeException(), isNull);
    });
  });
}
