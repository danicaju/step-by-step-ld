import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/polynomials/spanish_box_division_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/ruffini_solver.dart';
import 'package:casio_tutor_calc/presentation/utils/cell_fraction_editor.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_error_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/spanish_box_division_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/header_select.dart';

Future<void> _goM4(WidgetTester t) async {
  await tapF(t, find.text('MODE'));
  await tapF(t, find.byKey(const Key('menu_mode_4')));
}

double _opacityOf(WidgetTester t, Finder f) => t.widget<Opacity>(f).opacity;

void main() {
  group('Celda de coeficientes con fraccion (a/b sin numero previo)', () {
    test('a/b en celda vacia abre el numerador; con texto abre el denominador', () {
      expect(CellFractionEditor.slash('', false), ('/', true));
      expect(CellFractionEditor.slash('-', false), ('-/', true));
      expect(CellFractionEditor.slash('3', true), ('3/', false));
    });

    test('teclas, signo y DEL por partes', () {
      var (text, num) = CellFractionEditor.slash('', false);
      text = CellFractionEditor.append(text, '1', num);
      text = CellFractionEditor.append(text, '2', num);
      expect(text, '12/');
      text = CellFractionEditor.append(text, '-', num);
      expect(text, '-12/');
      expect(CellFractionEditor.dpad(text, num, 'right'), false);
      num = false;
      text = CellFractionEditor.append(text, '5', num);
      expect(text, '-12/5');
      expect(CellFractionEditor.dpad(text, num, 'up'), true);
      expect(CellFractionEditor.dpad(text, num, 'right'), isNull);
      (text, num) = CellFractionEditor.backspace(text, num);
      expect(text, '-12/');
      (text, num) = CellFractionEditor.backspace(text, num);
      expect(text, '-12');
      expect(CellFractionEditor.dpad(text, false, 'right'), isNull);
    });
  });

  group('Ruffini con coeficientes racionales', () {
    test('x^3/2 - x^2/2 - 2x + 2 se escala por 2 y se vuelve a P(x)', () {
      final r = RuffiniSolver.factorizeRational([Rational(1, 2), Rational(-1, 2), Rational(-2), Rational(2)]);
      expect(r.steps.first.shortTitle, 'Quitar denominadores');
      expect(r.steps.last.shortTitle, 'Volver a P(x)');
      expect(r.exactResultLatex, startsWith(r'\frac{1}{2}'));
      expect(r.exactResultLatex, contains('x - 1'));
      expect(r.exactResultLatex, contains('x + 2'));
      for (var i = 0; i < r.steps.length; i++) {
        expect(r.steps[i].index, i + 1);
      }
      expect(RegExp(r'\\(text|mathrm)\{[^}]*[áéíóúñ][^}]*\}').hasMatch(r.steps.map((s) => s.latexExpression).join()), isFalse);
    });

    test('enteros siguen por el camino de siempre', () {
      final r = RuffiniSolver.factorizeRational([Rational(1), Rational(-6), Rational(11), Rational(-6)]);
      expect(r.steps.first.shortTitle, isNot('Quitar denominadores'));
    });

    testWidgets('E2E: a/b sin escribir un numero antes y D-Pad entre numerador y denominador', (t) async {
      await boot(t);
      await _goM4(t);
      // 1/2 · x^3 + (-1/2) · x^2 - 2x + 2
      await keys(t, ['a/b', '1']);
      await pad(t, 'right');
      await keys(t, ['2', '=']);
      await keys(t, ['-', 'a/b', '1']);
      await pad(t, 'right');
      await keys(t, ['2', '=']);
      await keys(t, ['-', '2', '=']);
      await keys(t, ['2', '=']);
      expect(result(t), isNotNull);
      expect(result(t), contains(r'\frac{1}{2}'));
      expect(t.takeException(), isNull);
    });

    testWidgets('fraccion incompleta no se redondea en silencio', (t) async {
      await boot(t);
      await _goM4(t);
      await keys(t, ['a/b', '1']);
      for (var i = 0; i < 3; i++) {
        await key(t, '=');
      }
      await key(t, '=');
      expect(find.byType(LcdErrorScreen), findsOneWidget, reason: 'una fraccion sin denominador es un error, no un 0');
    });
  });

  group('M4: celdas de caja y fracciones en LaTeX (nada de x^2 literal)', () {
    testWidgets('caja: el exponente se pinta con Math.tex', (t) async {
      await boot(t);
      await _goM4(t);
      await pickHeader(t, 'hdr_poly_kind', 'poly_tab_box');
      await alphaKey(t, ')');
      await keys(t, ['x²', '+', '5']);
      final cell = find.byKey(const Key('xform_cell_0'));
      expect(find.descendant(of: cell, matching: find.byType(Math)), findsOneWidget);
      expect(find.descendant(of: cell, matching: find.textContaining('^')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('fracciones algebraicas: numerador y denominador en LaTeX', (t) async {
      await boot(t);
      await _goM4(t);
      await pickHeader(t, 'hdr_poly_kind', 'poly_tab_frac');
      await key(t, '=');
      await alphaKey(t, ')');
      await keys(t, ['x²', '-', '1']);
      final cell = find.byKey(const Key('xform_cell_0'));
      expect(find.descendant(of: cell, matching: find.byType(Math)), findsOneWidget);
      expect(find.descendant(of: cell, matching: find.textContaining('^')), findsNothing);
    });
  });

  group('Division en caja: la caja es el grueso de los pasos', () {
    final box = SpanishBoxDivisionSolver.divideText('2x^3-3x^2-8x+12', 'x-2');

    test('un paso para ordenar, dos por termino del cociente y uno final', () {
      expect(box.steps.length, 3);
      expect(box.resolution.steps.length, 1 + 2 * box.steps.length + 1);
      expect(box.resolution.steps.first.shortTitle, 'Ordenar y completar');
      expect(box.resolution.steps[1].pedagogicalNote, contains('2x³'));
      expect(box.resolution.steps[2].latexExpression, contains('R_{1}(x)'));
    });

    testWidgets('el dibujo se construye por etapas sin cambiar de tamano', (t) async {
      final last = box.resolution.steps.length - 1;
      Future<Size> sizeAt(int stage) async {
        await t.pumpWidget(MaterialApp(
          home: Center(child: SizedBox(width: 420, height: 260, child: SpanishBoxDivisionView(result: box, stage: stage))),
        ));
        return t.getSize(find.byKey(const Key('box_left')));
      }

      final s0 = await sizeAt(0);
      final q = find.descendant(of: find.byKey(const Key('box_quotient')), matching: find.byType(Opacity));
      expect(q, findsNWidgets(3));
      expect([for (var i = 0; i < 3; i++) _opacityOf(t, q.at(i))], [0, 0, 0]);
      expect(_opacityOf(t, find.descendant(of: find.byKey(const Key('box_right')), matching: find.byType(Opacity)).last), 0);

      await sizeAt(1);
      expect([for (var i = 0; i < 3; i++) _opacityOf(t, q.at(i))], [1, 0, 0]);
      await sizeAt(4);
      expect([for (var i = 0; i < 3; i++) _opacityOf(t, q.at(i))], [1, 1, 0]);
      final sLast = await sizeAt(last);
      expect([for (var i = 0; i < 3; i++) _opacityOf(t, q.at(i))], [1, 1, 1]);
      expect(sLast, s0, reason: 'la caja reserva el hueco: no salta de tamano entre pasos');
      expect(find.text('R = 0'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('E2E: la caja se ve en el paso 1 y en los intermedios, no solo al final', (t) async {
      await boot(t);
      await _goM4(t);
      await pickHeader(t, 'hdr_poly_kind', 'poly_tab_box');
      await alphaKey(t, ')');
      await keys(t, ['x²', '-', '1', '=']);
      await alphaKey(t, ')');
      await keys(t, ['-', '1', '=']);
      expect(lcd(t).currentResolution!.steps.length, 6);
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(const Key('box_division_clip')), findsOneWidget, reason: 'paso ${i + 1}');
        await key(t, '=');
      }
      expect(t.takeException(), isNull);
    });
  });

  group('Caja espanola legible: 13 px fijos con scroll en vez de encoger', () {
    final box = SpanishBoxDivisionSolver.divideText('x^4-3x^2+2x-5', 'x^2-x+1');
    final last = box.resolution.steps.length - 1;
    final clip = find.byKey(const Key('box_division_clip'));

    Future<void> pumpBox(WidgetTester t, double w, double h, int? stage) => t.pumpWidget(MaterialApp(
          home: Center(child: SizedBox(width: w, height: h, child: SpanishBoxDivisionView(result: box, stage: stage))),
        ));

    double maxExtent(WidgetTester t, String key) {
      final s = t.state<ScrollableState>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Scrollable)).first);
      return s.position.maxScrollExtent;
    }

    testWidgets('no usa FittedBox y todo el texto mide al menos 13 px', (t) async {
      await pumpBox(t, 340, 110, null);
      expect(find.descendant(of: clip, matching: find.byType(FittedBox)), findsNothing);
      final texts = find.descendant(of: clip, matching: find.byType(Text));
      expect(texts, findsWidgets);
      for (final w in t.widgetList<Text>(texts)) {
        expect(w.style?.fontSize, greaterThanOrEqualTo(13), reason: 'texto "${w.data}"');
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('grado 4 en 340x110: desplaza en horizontal y vertical sin overflow', (t) async {
      await pumpBox(t, 340, 110, null);
      expect(maxExtent(t, 'box_scroll_v'), greaterThan(0));
      expect(maxExtent(t, 'box_scroll_h'), greaterThan(0));
      await t.drag(clip, const Offset(0, -60));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('en un espacio diminuto (140x90) tampoco falla', (t) async {
      await pumpBox(t, 140, 90, null);
      await t.drag(clip, const Offset(-80, -40));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('si cabe, no hay scroll y la caja queda centrada', (t) async {
      await pumpBox(t, 700, 400, null);
      expect(maxExtent(t, 'box_scroll_v'), 0);
      expect(maxExtent(t, 'box_scroll_h'), 0);
    });

    testWidgets('la fila del paso en curso queda a la vista y el bloque no cambia de tamano', (t) async {
      final n = box.steps.length;
      int active(int s) {
        if (s >= 2 * n + 1) return 2 * n;
        if (s == 0) return 0;
        final cur = s.isOdd ? (s - 1) ~/ 2 : (s - 2) ~/ 2;
        return s.isOdd ? (cur == 0 ? 0 : 2 * cur) : 2 + 2 * cur;
      }

      await pumpBox(t, 340, 110, 0);
      await t.pumpAndSettle();
      final size0 = t.getSize(find.byKey(const Key('box_left')));
      for (var s = 0; s <= last; s++) {
        await pumpBox(t, 340, 110, s);
        await t.pumpAndSettle();
        // Al final se enseña cociente y resto (arriba a la derecha); antes, la fila en curso.
        final target = s == last ? find.byKey(const Key('box_remainder')) : find.byKey(Key('box_row_${active(s)}'));
        final row = t.getRect(target);
        final view = t.getRect(clip);
        if (s == last) {
          final q = t.getRect(find.byKey(const Key('box_quotient')));
          expect(q.top, greaterThanOrEqualTo(view.top - 0.5), reason: 'cociente a la vista');
          expect(q.right, lessThanOrEqualTo(view.right + 0.5), reason: 'cociente a la vista');
        }
        expect(row.top, greaterThanOrEqualTo(view.top - 0.5), reason: 'paso ${s + 1}: fila por encima');
        expect(row.bottom, lessThanOrEqualTo(view.bottom + 0.5), reason: 'paso ${s + 1}: fila por debajo');
        expect(t.getSize(find.byKey(const Key('box_left'))), size0, reason: 'paso ${s + 1}: tamano estable');
      }
      expect(t.takeException(), isNull);
    });
  });
}
