import 'package:casio_tutor_calc/presentation/widgets/modes/mode_form.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/probability_distribution_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/header_select.dart';

Future<void> _goMode(WidgetTester t, int n) async {
  await tapF(t, find.text('MODE'));
  if (n > 4) await tapF(t, find.byKey(const Key('menu_page_next')));
  if (n > 8) await tapF(t, find.byKey(const Key('menu_page_next')));
  await tapF(t, find.byKey(Key('menu_mode_$n')));
}

Finder _k(String k) => find.byKey(Key(k));

void main() {
  group('M5: conmutador Pasos/Grafica solo tras =', () {
    testWidgets('oculto al editar, visible con resultado y oculto otra vez con AC', (t) async {
      await boot(t);
      await _goMode(t, 5);
      expect(_k('hdr_graph_kind'), findsOneWidget);
      expect(_k('mode5_view_toggle'), findsNothing);
      expect(find.text('Ver Pasos'), findsNothing);
      expect(find.text('Ver Gráfica'), findsNothing);
      await keys(t, ['5', '=']);
      expect(_k('mode5_view_toggle'), findsOneWidget);
      await key(t, 'AC');
      expect(_k('mode5_view_toggle'), findsNothing);
      expect(_k('hdr_graph_kind'), findsOneWidget);
    });

    testWidgets('el desplegable Vista sigue disponible (Limites y Tabla)', (t) async {
      await boot(t);
      await _goMode(t, 5);
      expect(_k('hdr_graph_view'), findsOneWidget);
    });
  });

  group('M8: sin OPTN y + Añadir fila dentro de la tabla', () {
    testWidgets('no hay boton OPTN ni + Fila en la barra inferior', (t) async {
      await boot(t);
      await _goMode(t, 8);
      expect(_k('stat_optn_btn'), findsNothing);
      expect(_k('stat_add_row_btn'), findsNothing);
      expect(_k('stat_add_row_inline'), findsOneWidget);
    });

    testWidgets('anadir y quitar filas con el pie de la tabla (quitar solo con mas de 2)', (t) async {
      await boot(t);
      await _goMode(t, 8);
      expect(_k('stat_cell_1_0'), findsNothing);
      await tapF(t, _k('stat_add_row_inline'));
      expect(_k('stat_cell_1_0'), findsOneWidget);
      expect(_k('stat_remove_row_inline'), findsNothing);
      await tapF(t, _k('stat_add_row_inline'));
      expect(_k('stat_cell_2_0'), findsOneWidget);
      expect(_k('stat_remove_row_inline'), findsOneWidget);
      await tapF(t, _k('stat_remove_row_inline'));
      expect(_k('stat_cell_2_0'), findsNothing);
      expect(_k('stat_remove_row_inline'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('▼ desde la ultima fila rellena anade otra', (t) async {
      await boot(t);
      await _goMode(t, 8);
      await key(t, '5');
      await pad(t, 'down');
      expect(_k('stat_cell_1_0'), findsOneWidget);
    });

    testWidgets('tambien en 2 variables', (t) async {
      await boot(t);
      await _goMode(t, 8);
      await pickHeader(t, 'hdr_stat_kind', 'stat_kind_1');
      expect(_k('stat_add_row_inline'), findsOneWidget);
      expect(_k('stat_optn_btn'), findsNothing);
    });
  });

  group('Normal y Binomial: ficha y fracciones', () {
    testWidgets('Binomial con p = 1/6 tecleado con a/b: B(6, 1/6), P(X = 1)', (t) async {
      await boot(t);
      await _goMode(t, 8);
      await pickHeader(t, 'hdr_stat_kind', 'stat_kind_3');
      expect(_k('xform_badge'), findsOneWidget);
      expect(_k('xform_params'), findsOneWidget);
      expect(_k('xform_calc'), findsOneWidget);
      await keys(t, ['=', '6', '=']);
      // p: a/b con el campo vacio, 1, ▶ al denominador, 6
      await keys(t, ['a/b', '1']);
      await pad(t, 'right');
      await key(t, '6');
      expect(find.descendant(of: _k('xform_cell_1'), matching: find.byType(Math)), findsOneWidget);
      await keys(t, ['=', '1', '=']);
      expect(result(t), contains('3125'));
      expect(t.takeException(), isNull);
    });

    for (final (name, seq) in [
      ('p = 1', ['=', '6', '=', '1', '=', '1', '=']),
      ('p = 0', ['=', '6', '=', '0', '=', '1', '=']),
      ('n no entero (2.5)', ['=', '2', '.', '5', '=', '0', '.', '5', '=', '1', '=']),
    ]) {
      testWidgets('Binomial con $name da LcdErrorScreen', (t) async {
        await boot(t);
        await _goMode(t, 8);
        await pickHeader(t, 'hdr_stat_kind', 'stat_kind_3');
        await keys(t, seq);
        expect(_k('lcd_error_screen'), findsOneWidget);
      });
    }

    testWidgets('Normal con mu = 3/2: P(X <= 2) en N(3/2, 1)', (t) async {
      await boot(t);
      await _goMode(t, 8);
      await pickHeader(t, 'hdr_stat_kind', 'stat_kind_2');
      await keys(t, ['=', 'a/b', '3']);
      await pad(t, 'right');
      await keys(t, ['2', '=', '1', '=', '2', '=']);
      expect(result(t), '0{,}6915');
    });

    testWidgets('sigma = 0 da LcdErrorScreen en Normal', (t) async {
      await boot(t);
      await _goMode(t, 8);
      await pickHeader(t, 'hdr_stat_kind', 'stat_kind_2');
      await keys(t, ['=', '0', '=', '0', '=', '1', '=']);
      expect(_k('lcd_error_screen'), findsOneWidget);
    });

    testWidgets('navegacion ◀ ▶ ▲ ▼ recorre selector y campos sin overflow', (t) async {
      await boot(t, size: const Size(360, 700));
      await _goMode(t, 8);
      await pickHeader(t, 'hdr_stat_kind', 'stat_kind_2');
      await pad(t, 'right'); // selector: P(X >= a)
      await pad(t, 'down');
      await pad(t, 'down');
      await pad(t, 'down');
      await pad(t, 'up');
      expect(find.byKey(const Key('xform_cell_2')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    test('expresiones de calculo segun el tipo de probabilidad', () {
      expect(ProbabilityDistributionWidget.expressionParts(false, 2), ['P(', 2, '≤ X ≤', 3, ')']);
      expect(ProbabilityDistributionWidget.expressionParts(false, 0), ['P(X ≤', 2, ')']);
      expect(ProbabilityDistributionWidget.expressionParts(true, 0), ['P(X =', 2, ')']);
      expect(ProbabilityDistributionWidget.expressionParts(true, 2), ['P(X ≥', 2, ')']);
    });
  });

  group('ModeFormState con fracciones', () {
    test('a/b con el campo vacio, ▶ al denominador, ◀ al numerador y DEL por partes', () {
      final f = ModeFormState(layouts: [
        [ModeField('p'), ModeField('q')],
      ]);
      expect(f.key('/'), isTrue);
      expect(f.fracNum, isTrue);
      f.key('1');
      f.dpad('right');
      expect(f.focus, 0, reason: 'primero pasa al denominador, no cambia de campo');
      expect(f.fracNum, isFalse);
      f.key('6');
      expect(f.text(0), '1/6');
      f.dpad('left');
      expect(f.fracNum, isTrue);
      f.key('-');
      expect(f.text(0), '-1/6');
      f.dpad('right');
      f.key('DEL');
      f.key('DEL');
      expect(f.text(0), '-1');
      f.dpad('right');
      expect(f.focus, 1, reason: 'sin fraccion, ▶ cambia de campo');
    });
  });
}
