import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_menu_navigation.dart';
import 'support/e2e_helpers.dart';

void main() {
  group('E2E editor: parentesis, funciones y castillos', () {
    testWidgets('(2+3 y = evalua 5 sin cerrar parentesis', (t) async {
      await boot(t);
      await keys(t, ['(', '2', '+', '3', '=']);
      expect(result(t), '5');
      expect(find.textContaining('Syntax'), findsNothing);
    });

    testWidgets('sin(cos(0)) con teclas reales', (t) async {
      await boot(t);
      await keys(t, ['sin', 'cos', '0']);
      expect(balanced(live(t)), isTrue, reason: live(t));
      expect(live(t), isNot(contains(r'\\')));
      await key(t, '=');
      expect(result(t), isNotNull);
      expect(find.textContaining('Syntax'), findsNothing);
    });

    testWidgets('sin(sqrt(cos(0))) con teclas reales', (t) async {
      await boot(t);
      await keys(t, ['sin', '√■', 'cos', '0']);
      expect(balanced(live(t)), isTrue, reason: live(t));
      await key(t, '=');
      expect(result(t), isNotNull);
      expect(find.textContaining('Syntax'), findsNothing);
    });

    testWidgets('frac (2+4)/3 + 5 = 7 usando ▼ y ▶', (t) async {
      await boot(t);
      await key(t, 'a/b');
      await keys(t, ['2', '+', '4']);
      await pad(t, 'down');
      await key(t, '3');
      await pad(t, 'right');
      await keys(t, ['+', '5']);
      expect(live(t), contains(r'\frac{2+4}{3}+5'));
      await key(t, '=');
      expect(result(t), '7');
    });

    testWidgets('fraccion dentro del denominador: ▼ y ▲ navegan', (t) async {
      await boot(t);
      await key(t, 'a/b');
      await key(t, '1');
      await pad(t, 'down');
      await keys(t, ['2', '+']);
      await key(t, 'a/b');
      await key(t, '3');
      await pad(t, 'down');
      await key(t, '4');
      expect(live(t), contains(r'\frac{1}{2+\frac{3}{4}}'));
      await pad(t, 'up');
      await key(t, '9');
      expect(live(t), contains(r'\frac{39}{4}'));
      await pad(t, 'up');
      await key(t, '8');
      expect(live(t), contains(r'\frac{18}{2+'));
      expect(balanced(live(t)), isTrue);
      for (var i = 0; i < 3; i++) {
        await pad(t, 'down');
      }
      await key(t, '7');
      expect(live(t), contains(r'\frac{39}{47}'));
    });

    testWidgets('sin(log_2(5)+1): ▶ sale del log hacia el interior del seno', (t) async {
      await boot(t);
      await keys(t, ['sin', 'log■□', '2']);
      await pad(t, 'right');
      await key(t, '5');
      await pad(t, 'right');
      await keys(t, ['+', '1']);
      expect(live(t), contains(r'\sin\left(\log_{2}\left(5\right)+1\right)'));
      await key(t, '=');
      expect(result(t), isNotNull);
      expect(find.textContaining('Syntax'), findsNothing);
    });

    testWidgets('x^2 con el 0 inicial no deja exponente flotante', (t) async {
      await boot(t);
      await key(t, 'x²');
      expect(live(t), isNot(startsWith('^')));
      expect(live(t), isNot(contains('{}^')));
      expect(balanced(live(t)), isTrue, reason: live(t));
      await key(t, '=');
      expect(find.textContaining('Syntax'), findsNothing);
    });
  });

  group('E2E M1: teclas y jerarquia', () {
    testWidgets('-3^2 = -9 y (-3)^2 = 9', (t) async {
      await boot(t);
      await keys(t, ['-', '3', 'x²', '=']);
      expect(result(t), '-9');
      await key(t, 'AC');
      await keys(t, ['(', '-', '3', ')', 'x²', '=']);
      expect(result(t), '9');
    });

    testWidgets('6/sqrt(3) = 2 sqrt 3 con fraccion', (t) async {
      await boot(t);
      await key(t, 'a/b');
      await key(t, '6');
      await pad(t, 'down');
      await keys(t, ['√■', '3']);
      await key(t, '=');
      expect(result(t), r'2\sqrt{3}');
    });

    testWidgets('log_2(8) + 2 = 5 con teclas reales (log con base)', (t) async {
      await boot(t);
      await keys(t, ['log■□', '2']);
      await pad(t, 'right');
      await key(t, '8');
      await pad(t, 'right');
      await keys(t, ['+', '2', '=']);
      expect(result(t), '5');
    });

    testWidgets('ALPHA + log inserta ln y ln(1) = 0', (t) async {
      await boot(t);
      await tapF(t, find.text('ALPHA'));
      await key(t, 'log■□');
      expect(live(t), contains(r'\ln'));
      await key(t, '1');
      await key(t, '=');
      expect(result(t), '0');
    });

    testWidgets('SHIFT + = aproxima, SHIFT + AC apaga y AC enciende', (t) async {
      await boot(t);
      await keys(t, ['1', '÷', '3']);
      await shiftKey(t, '=');
      expect(lcd(t).showDecimalApprox, isTrue);
      await shiftKey(t, 'AC');
      expect(find.byKey(const Key('lcd_powered_off')), findsOneWidget);
      await key(t, 'AC');
      expect(find.byKey(const Key('lcd_powered_off')), findsNothing);
    });

    testWidgets('DEL y D-Pad completo no rompen el editor', (t) async {
      await boot(t);
      await keys(t, ['1', '2', '3', 'DEL']);
      for (final d in ['left', 'right', 'up', 'down']) {
        await pad(t, d);
      }
      expect(t.takeException(), isNull);
      await key(t, '=');
      expect(result(t), '12');
    });

    test('menuMove sigue siendo total', () {
      expect(menuMove(0, 'right'), 1);
    });
  });
}
