import 'package:casio_tutor_calc/core/editor/exponent_navigation_helper.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';

Future<void> _type(WidgetTester t, String ch, LogicalKeyboardKey key) async {
  await t.sendKeyDownEvent(key, character: ch);
  await t.sendKeyUpEvent(key);
  await t.pump();
}

Future<void> _press(WidgetTester t, LogicalKeyboardKey key) async {
  await t.sendKeyDownEvent(key);
  await t.sendKeyUpEvent(key);
  await t.pump();
}

bool _balancedParens(String s) {
  var d = 0;
  for (final c in s.split('')) {
    if (c == '(') d++;
    if (c == ')') d--;
    if (d < 0) return false;
  }
  return d == 0;
}

void main() {
  group('Helper puro: DEL y bordes del exponente (buffer ^( ))', () {
    (String, int) del(String raw, int pos) => ExpressionParser.deleteAtCursor(raw, pos);

    test('DEL dentro borra el ultimo token interno y nunca el cierre', () {
      var s = ('x^(2x+1)', 7); // x^(2x+1|)
      final seen = <String>[];
      for (var i = 0; i < 5; i++) {
        s = del(s.$1, s.$2);
        seen.add(s.$1);
        expect(_balancedParens(s.$1), isTrue, reason: s.$1);
      }
      expect(seen.first, 'x^(2x+)');
      expect(seen.last, 'x');
    });

    test('DEL justo tras ^(2x+1)| entra y borra el ultimo token interno', () {
      final (raw, pos) = del('x^(2x+1)', 8);
      expect(raw, 'x^(2x+)');
      expect(pos, 6);
      expect(_balancedParens(raw), isTrue);
    });

    test('DEL tras ^()| borra el bloque entero', () {
      final (raw, _) = del('x^()', 4);
      expect(raw, 'x');
    });

    test('DEL al inicio de un exponente con contenido lo desenvuelve', () {
      final (raw, pos) = del('x^(23)', 3); // x^(|23)
      expect(raw, 'x23');
      expect(pos, 1);
    });

    test('exponentes anidados quedan balanceados al borrar', () {
      var s = ('2^(2^(3))', 9);
      for (var i = 0; i < 6; i++) {
        s = del(s.$1, s.$2);
        expect(_balancedParens(s.$1), isTrue, reason: s.$1);
      }
    });

    test('isInsideExponent / exitDown', () {
      expect(ExponentNavigationHelper.isInsideExponent('x^(2x+1)', 6), isTrue);
      expect(ExponentNavigationHelper.isInsideExponent('x^(2x+1)', 8), isFalse);
      expect(ExponentNavigationHelper.exitDown('x^(2x+1)', 5), 8);
    });
  });

  group('M1: exponentes multi-termino (teclas virtuales)', () {
    bothSizes('2^{3+4}+1 = 129', (t) async {
      await seq(t, '2 S:pow 3 + 4 > + 1 =');
      expect(norm(res(t).exactResultLatex), '129');
    });

    bothSizes('2^{3×2-1} = 32', (t) async {
      await seq(t, '2 S:pow 3 × 2 - 1 > =');
      expect(norm(res(t).exactResultLatex), '32');
    });

    bothSizes('8^{1/3}+2 = 4', (t) async {
      await seq(t, '8 S:pow frac 1 v 3 > > + 2 =');
      expect(norm(res(t).exactResultLatex), '4');
    });

    bothSizes('2^{2^{3}} = 256', (t) async {
      await seq(t, '2 S:pow 2 S:pow 3 > > =');
      expect(norm(res(t).exactResultLatex), '256');
    });
  });

  group('Edicion: permanencia, salida con ▶ y entrada con ◀', () {
    testWidgets('operadores, variables y parentesis se quedan dentro; ▶ sale', (t) async {
      await boot(t);
      await seq(t, 'x S:pow 2 x - 1 ( 2 ) × 3');
      expect(live(t), contains(r'x^{2x-1(2)\cdot3'));
      await seq(t, '> + 5');
      expect(live(t), contains(r'x^{2x-1(2)\cdot3}+5'));
      expect(balanced(live(t)), isTrue);
    });

    testWidgets('x² y x³ dejan el cursor tras } y ◀ entra a editar el exponente', (t) async {
      await boot(t);
      await seq(t, 'x sq');
      expect(live(t), contains('x^{2}'));
      await seq(t, '< 3 + 1');
      expect(live(t), contains('x^{23+1'));
      await seq(t, '> + 5');
      expect(live(t), contains('x^{23+1}+5'));
    });

    testWidgets('exponente anidado: primer ▶ sale al padre, segundo a la linea base', (t) async {
      await boot(t);
      await seq(t, '2 S:pow 2 S:pow 3 > + 1');
      expect(live(t), contains('2^{2^{3}+1'));
      await seq(t, '> + 1');
      expect(live(t), contains('2^{2^{3}+1}+1'));
    });

    testWidgets('DEL dentro y justo despues de ^{2x+1} mantiene llaves balanceadas', (t) async {
      await boot(t);
      await seq(t, 'x S:pow 2 x + 1');
      expect(live(t), contains('x^{2x+1'));
      await key(t, 'DEL');
      expect(live(t), contains('x^{2x+'));
      expect(live(t), isNot(contains('x^{2x+1')));
      expect(balanced(live(t)), isTrue);
      await seq(t, '1 >');
      await key(t, 'DEL'); // justo tras ^{2x+1}|: entra y borra el 1
      expect(live(t), contains('x^{2x+'));
      expect(live(t), isNot(contains('x^{2x+1')));
      expect(balanced(live(t)), isTrue);
      for (var i = 0; i < 4; i++) {
        await key(t, 'DEL');
        expect(balanced(live(t)), isTrue, reason: live(t));
      }
      expect(live(t), isNot(contains('^')));
    });

    testWidgets('pista ▶ salir del exponente solo con el cursor dentro', (t) async {
      await boot(t);
      await seq(t, 'x S:pow 2');
      expect(find.text('▶ salir del exponente'), findsOneWidget);
      await seq(t, '>');
      expect(find.text('▶ salir del exponente'), findsNothing);
    });
  });

  group('Otros modos', () {
    bothSizes('M2: 2^{x+1}=16 -> x = 3', (t) async {
      await seq(t, 'mode:2 2 S:pow x + 1 > > 1 6 =');
      expect(norm(res(t).exactResultLatex), anyOf('x=3', '3'));
    });

    bothSizes('M5: 2^{-x+2} + ▶ + - 1 sin expulsion prematura', (t) async {
      // M5 no tiene tecla de ℯ en OPTN: la base 2 ejercita la misma ruta del editor.
      await seq(t, 'mode:5 2 S:pow - x + 2 > - 1');
      expect(live(t), contains(r'^{-x+2}-1'));
      expect(balanced(live(t)), isTrue);
    });

    bothSizes('M12: d/dx e^{2x+1} = 2e^{2x+1}', (t) async {
      await seq(t, 'mode:12 quickoptn quick:ℯ S:pow 2 x + 1 > =');
      final out = norm(res(t).exactResultLatex);
      expect(out, contains('2'));
      expect(out, contains('e^{2x+1}'));
    });

    bothSizes('M12: d/dx e^{-2x+1} = -2e^{-2x+1}', (t) async {
      await seq(t, 'mode:12 quickoptn quick:ℯ S:pow - 2 x + 1 > =');
      final out = norm(res(t).exactResultLatex);
      expect(out, contains('-2'));
      expect(out, contains('e^{-2x+1}'));
    });
  });

  group('Teclado fisico', () {
    testWidgets('2 ^ 3 + 4 → + 1 Enter = 129', (t) async {
      await boot(t);
      await _type(t, '2', LogicalKeyboardKey.digit2);
      await _type(t, '^', LogicalKeyboardKey.digit6);
      await _type(t, '3', LogicalKeyboardKey.digit3);
      await _type(t, '+', LogicalKeyboardKey.numpadAdd);
      await _type(t, '4', LogicalKeyboardKey.digit4);
      expect(live(t), contains('2^{3+4'));
      await _press(t, LogicalKeyboardKey.arrowRight);
      await _type(t, '+', LogicalKeyboardKey.numpadAdd);
      await _type(t, '1', LogicalKeyboardKey.digit1);
      await _press(t, LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(norm(res(t).exactResultLatex), '129');
    });
  });
}
