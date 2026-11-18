import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_calculus_editor_view.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/function_table_widget.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/inequality_system_editor_view.dart';

import 'support/e2e_helpers.dart';
import 'support/header_select.dart';

Future<void> _openMode(WidgetTester t, int mode) async {
  await tapF(t, find.text('MODE'));
  for (var g = 0; g < 4 && find.byKey(Key('menu_mode_$mode')).evaluate().isEmpty; g++) {
    await tapF(t, find.byKey(const Key('menu_page_next')));
  }
  await tapF(t, find.byKey(Key('menu_mode_$mode')));
}

Future<void> _frac(WidgetTester t) => key(t, 'a/b');

/// Latex en vivo con el marcador del cursor intacto.
String _liveWithCursor(WidgetTester t) => lcd(t).currentInputLatex.replaceAll(' ', '');

/// `(1)/(2)` con el cursor fuera, tecleado como en la calculadora: a/b, 1, ▼, 2, ▶.
Future<void> _oneHalfExit(WidgetTester t) async {
  await _frac(t);
  await key(t, '1');
  await pad(t, 'down');
  await key(t, '2');
  await pad(t, 'right');
}

void main() {
  group('Dominio: raw + cursor', () {
    const half = '(1)/(2)';

    test('▶ al final del numerador entra al inicio del denominador', () {
      expect(FractionTemplate.handleRight(half, 2), (half, 5));
    });

    test('▶ al final del denominador sale a la derecha y ◀ vuelve a entrar', () {
      expect(ExpressionParser.handleFractionRightArrow(half, 6), isNull);
      expect(ExpressionParser.stepCursorRight(half, 6), 7);
      expect(ExpressionParser.stepCursorLeft(half, 7), 6);
    });

    test('anidada: la primera ▶ sale de la interior, la segunda de la exterior', () {
      const raw = '(1)/(2+(3)/(4))';
      expect(ExpressionParser.stepCursorRight(raw, 13), 14); // sigue dentro del den exterior
      expect(ExpressionParser.stepCursorRight(raw, 14), 15); // fuera de la exterior
    });

    test('lo que se escribe fuera queda fuera de las llaves', () {
      for (final tok in ['+', '-', '*', ':', '(', 'x', '3', 'sin(']) {
        final (raw, pos) = ExpressionParser.insertAtCursor(half, 7, tok);
        expect(raw.startsWith(half), isTrue, reason: tok);
        expect(pos, greaterThan(half.length), reason: tok);
        final latex = ExpressionParser.rawToLiveLatex(raw, cursorPos: pos).replaceAll(' ', '');
        expect(balanced(latex), isTrue, reason: '$tok -> $latex');
        expect(latex, startsWith(r'\frac{1}{2}'), reason: '$tok -> $latex');
      }
    });

    test('una potencia sigue unida al denominador, lo demas no', () {
      String l(String raw, int c) =>
          ExpressionParser.rawToLiveLatex(raw, cursorPos: c).replaceAll(' ', '');
      expect(l('(1)/(2)^2', 9), startsWith(r'\frac{1}{(2)^{2}}'));
      expect(l('(1)/(2)3', 8), startsWith(r'\frac{1}{2}3'));
      expect(l('(1)/(2)x', 8), startsWith(r'\frac{1}{2}x'));
    });

    test('el cursor justo tras la fraccion se pinta fuera de su ultima llave', () {
      final latex = ExpressionParser.rawToLiveLatex(half, cursorPos: 7).replaceAll(' ', '');
      expect(latex, startsWith(r'\frac{1}{2}'));
      expect(latex, contains(r'\frac{1}{2}\textcolor'));
      expect(balanced(latex), isTrue);
    });
  });

  group('M1: pulsaciones reales', () {
    testWidgets('a/b 1 ▼ 2 ▶ + 3 = -> \\frac{1}{2}+3 = 7/2', (t) async {
      await boot(t);
      await _oneHalfExit(t);
      await keys(t, ['+', '3']);
      expect(live(t), r'\frac{1}{2}+3');
      await key(t, '=');
      expect(result(t), r'\frac{7}{2}');
    });

    testWidgets('a/b 1 ▶ 2 ▶ × 4 = -> \\frac{1}{2}\\cdot4 = 2', (t) async {
      await boot(t);
      await _frac(t);
      await key(t, '1');
      await pad(t, 'right'); // numerador -> denominador
      await key(t, '2');
      await pad(t, 'right'); // fuera
      await keys(t, ['×', '4']);
      expect(live(t), r'\frac{1}{2}\cdot4');
      await key(t, '=');
      expect(result(t), '2');
    });

    testWidgets('anidada \\frac{1}{2+\\frac{3}{4}}+1 saliendo de ambos niveles', (t) async {
      await boot(t);
      await _frac(t);
      await key(t, '1');
      await pad(t, 'down');
      await keys(t, ['2', '+']);
      await _frac(t);
      await key(t, '3');
      await pad(t, 'down');
      await key(t, '4');
      expect(live(t), r'\frac{1}{2+\frac{3}{4}}');
      await pad(t, 'right'); // sale de la interior, aun dentro del den exterior
      await key(t, '+');
      expect(live(t), contains(r'\frac{3}{4}+'), reason: 'el + queda dentro del den exterior');
      await key(t, 'DEL');
      await pad(t, 'right'); // sale de la exterior
      await keys(t, ['+', '1']);
      expect(live(t), r'\frac{1}{2+\frac{3}{4}}+1');
      await key(t, '=');
      expect(result(t), r'\frac{15}{11}');
    });

    testWidgets('◀ desde \\frac{1}{2}| vuelve al final del denominador', (t) async {
      await boot(t);
      await _oneHalfExit(t);
      await pad(t, 'left');
      await key(t, '5');
      expect(live(t), r'\frac{1}{25}');
    });

    testWidgets('volver con ◀ desde \\frac{1}{2}+3, cambiar el 2 por 5 y recalcular', (t) async {
      await boot(t);
      await _oneHalfExit(t);
      await keys(t, ['+', '3']);
      // ◀ x3 (3 -> + -> ) ) deja el cursor al final del denominador, tras el 2.
      await pad(t, 'left');
      await pad(t, 'left');
      await pad(t, 'left');
      await key(t, 'DEL');
      await key(t, '5');
      expect(live(t), r'\frac{1}{5}+3');
      await key(t, '=');
      expect(result(t), r'\frac{16}{5}');
    });

    testWidgets('operadores y funciones tras salir quedan fuera de la fraccion', (t) async {
      for (final tok in ['+', '-', '×', '÷']) {
        await boot(t);
        await _oneHalfExit(t);
        await keys(t, [tok, '3']);
        expect(live(t), startsWith(r'\frac{1}{2}'), reason: tok);
        expect(balanced(_liveWithCursor(t)), isTrue, reason: tok);
      }
    });
  });

  group('Otros modos con editor de fraccion', () {
    testWidgets('M2: 1/2 + x = 4 saliendo de la fraccion con ▶ -> x = 7/2', (t) async {
      await boot(t);
      await _openMode(t, 2);
      await _oneHalfExit(t);
      await key(t, '+');
      await alphaKey(t, ')');
      await alphaCalc(t);
      await key(t, '4');
      await key(t, '=');
      expect(result(t), r'x = \frac{7}{2}');
    });

    testWidgets('M6: salir de la fraccion y seguir escribiendo', (t) async {
      await boot(t);
      await _openMode(t, 6);
      await _oneHalfExit(t);
      await keys(t, ['+', '3']);
      expect(live(t), contains(r'\frac{1}{2}+3'));
      expect(balanced(_liveWithCursor(t)), isTrue);
    });

    testWidgets('M7: salir de la fraccion en una fila del sistema', (t) async {
      await boot(t);
      await _openMode(t, 7);
      // En M7 ▼ cambia de fila: se entra al denominador con ▶.
      await _frac(t);
      await key(t, '1');
      await pad(t, 'right');
      await key(t, '2');
      await pad(t, 'right');
      await keys(t, ['+', '3']);
      final view = t.widget<InequalitySystemEditorView>(find.byType(InequalitySystemEditorView));
      expect(view.ineqSysRowInputs[view.ineqSysActiveRow], '(1)/(2)+3');
    });

    testWidgets('M12: salir de la fraccion en la expresion', (t) async {
      await boot(t);
      await _openMode(t, 12);
      await _oneHalfExit(t);
      await keys(t, ['+', '3']);
      final view = t.widget<CasioCalculusEditorView>(find.byType(CasioCalculusEditorView));
      expect(view.expressionRaw, '(1)/(2)+3');
    });

    test('M5: los formularios son texto lineal (sin plantilla): "/" y "+" se encadenan', () {
      final f = FunctionTableFormState();
      for (final k in ['x', '/', '2', '+', '3']) {
        f.key(k);
      }
      expect(f.cells[0], 'x/2+3');
    });
  });
}
