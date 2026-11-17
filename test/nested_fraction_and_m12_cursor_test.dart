import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/nested_fraction_navigator.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_calculus_editor_view.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';

bool balanced(String s) {
  var d = 0;
  for (final ch in s.split('')) {
    if (ch == '{') d++;
    if (ch == '}') d--;
    if (d < 0) return false;
  }
  return d == 0;
}

void main() {
  group('Motor: NestedFractionNavigator (castillo de 3 niveles)', () {
    // (1)/(2+(3)/(4+(5)/(6)))
    const raw = '(1)/(2+(3)/(4+(5)/(6)))';

    test('▼ baja hasta el denominador mas profundo y ▲ vuelve arriba', () {
      var c = 1; // numerador superior
      final visited = <int>[c];
      for (var i = 0; i < 10; i++) {
        final n = NestedFractionNavigator.down(raw, c);
        if (n == null) break;
        c = n;
        visited.add(c);
      }
      // Termina dentro del den de la fraccion mas profunda: tras "6".
      expect(raw.substring(0, c).endsWith('(6'), isTrue, reason: 'cursor=$c');
      for (var i = 0; i < 10; i++) {
        final n = NestedFractionNavigator.up(raw, c);
        if (n == null) break;
        c = n;
      }
      expect(c, 2, reason: 'debe acabar al final del numerador superior');
      for (final p in visited) {
        expect(balanced(ExpressionParser.rawToLiveLatex(raw, cursorPos: p)), isTrue);
      }
    });

    test('▲ desde num de hija en den del padre -> num del padre', () {
      expect(NestedFractionNavigator.up(raw, 8), 2);
    });
  });

  group('Widget: pulsaciones reales', () {
    Future<void> tap(WidgetTester t, Finder f) async {
      await t.tap(f);
      await t.pumpAndSettle();
    }

    Future<void> txt(WidgetTester t, String s) =>
        tap(t, s == '=' ? find.text(s).last : find.text(s).first);
    Future<void> frac(WidgetTester t) => tap(t, find.byKey(const Key('fraction_key_icon')));
    Future<void> pad(WidgetTester t, String k) => tap(t, find.byKey(Key('replay_$k')));

    Future<void> boot(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(const ProviderScope(child: MaterialApp(home: CalculatorScreen())));
      await t.pumpAndSettle();
    }

    CasioLcdScreen lcd(WidgetTester t) => t.widget<CasioLcdScreen>(find.byType(CasioLcdScreen));
    String live(WidgetTester t) => lcd(t)
        .currentInputLatex
        .replaceAll(' ', '')
        .replaceAll(r'\textcolor{#2E86DE}{\mid}', '');

    testWidgets('M12 arranca vacio sin fraccion fantasma y x^2 -> 2x', (t) async {
      await boot(t);
      await tap(t, find.text('MODE'));
      for (var g = 0; g < 4 && find.byKey(const Key('menu_mode_12')).evaluate().isEmpty; g++) {
        await tap(t, find.byKey(const Key('menu_page_next')));
      }
      await tap(t, find.byKey(const Key('menu_mode_12')));
      var view = t.widget<CasioCalculusEditorView>(find.byType(CasioCalculusEditorView));
      expect(view.expressionRaw, isEmpty);
      await tap(t, find.text('ALPHA'));
      await tap(
        t,
        find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == ')'),
      );
      await tap(
        t,
        find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == 'x²'),
      );
      view = t.widget<CasioCalculusEditorView>(find.byType(CasioCalculusEditorView));
      expect(view.expressionRaw.contains('/'), isFalse);
      expect(view.expressionRaw.replaceAll(' ', '').toLowerCase(), startsWith('x'), reason: view.expressionRaw);
      await txt(t, '=');
      expect(lcd(t).currentResolution?.exactResultLatex.replaceAll(' ', ''), contains('2x'));
    });

    testWidgets('fraccion dentro del denominador queda abajo y evalua 4/11', (t) async {
      await boot(t);
      await frac(t);
      await txt(t, '1');
      await pad(t, 'down');
      await txt(t, '2');
      await txt(t, '+');
      await frac(t);
      expect(live(t), contains(r'\frac{1}{2+\frac'));
      expect(balanced(live(t)), isTrue);
      await txt(t, '3');
      await pad(t, 'down');
      await txt(t, '4');
      await pad(t, 'right');
      await txt(t, '=');
      expect(lcd(t).currentResolution?.exactResultLatex, r'\frac{4}{11}');
    });

    testWidgets('castillo de 3 niveles: ▼ hasta el fondo y ▲ hasta arriba', (t) async {
      await boot(t);
      await frac(t);
      await txt(t, '1');
      await pad(t, 'down');
      await txt(t, '2');
      await txt(t, '+');
      await frac(t);
      await txt(t, '3');
      await pad(t, 'down');
      await txt(t, '4');
      await txt(t, '+');
      await frac(t);
      await txt(t, '5');
      await pad(t, 'down');
      await txt(t, '6');
      for (var i = 0; i < 4; i++) {
        await pad(t, 'up');
      }
      await txt(t, '9'); // escribe en el numerador superior
      expect(live(t), contains(r'\frac{19}{'));
      for (var i = 0; i < 5; i++) {
        await pad(t, 'down');
      }
      await txt(t, '7'); // escribe en el den mas profundo
      expect(live(t), contains(r'\frac{5}{67}'));
      expect(balanced(live(t)), isTrue);
    });
  });
}
