import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';

Future<void> _x(WidgetTester t) async {
  await tapF(t, find.text('ALPHA'));
  await key(t, ')');
}

Future<void> _power(WidgetTester t) async {
  await _x(t);
  await shiftKey(t, 'x²');
}

void main() {
  group('Exponente ^{...}: todo se escribe dentro', () {
    testWidgets('x^{52}', (t) async {
      await boot(t);
      await _power(t);
      await keys(t, ['5', '2']);
      expect(live(t), contains('x^{52'));
    });

    testWidgets('x^{5+1}: signo y digito dentro', (t) async {
      await boot(t);
      await _power(t);
      await keys(t, ['5', '+', '1']);
      expect(live(t), contains('x^{5+1'));
    });

    testWidgets('2^{-3}', (t) async {
      await boot(t);
      await key(t, '2');
      await shiftKey(t, 'x²');
      await keys(t, ['-', '3']);
      expect(live(t), contains('2^{-3'));
    });

    testWidgets('x^{5*2-1} con multiplicacion y resta', (t) async {
      await boot(t);
      await _power(t);
      await keys(t, ['5', '×', '2', '-', '1']);
      expect(live(t), contains(r'x^{5\cdot2-1'));
    });

    testWidgets('variable y parentesis dentro del exponente', (t) async {
      await boot(t);
      await _power(t);
      await key(t, '5');
      await _x(t);
      expect(live(t), contains('x^{5x'));
      await key(t, ')'); // un ) suelto no cierra el exponente
      await keys(t, ['+', '1']);
      expect(live(t), contains('x^{5x+1'));
    });

    testWidgets('solo ▶ saca el cursor del exponente', (t) async {
      await boot(t);
      await _power(t);
      await key(t, '5');
      await pad(t, 'right');
      await keys(t, ['+', '1']);
      expect(live(t), contains('x^{5}+1'));
    });

    testWidgets('▼ saca el cursor del exponente a la linea base', (t) async {
      await boot(t);
      await _power(t);
      await key(t, '5');
      await pad(t, 'down');
      await keys(t, ['+', '1']);
      expect(live(t), contains('x^{5}+1'));
    });

    testWidgets('◀ a la derecha del exponente vuelve a entrar y se sigue editando', (t) async {
      await boot(t);
      await _power(t);
      await key(t, '5');
      await pad(t, 'right');
      await pad(t, 'left');
      await key(t, '2');
      expect(live(t), contains('x^{52'));
    });
  });

  group('Fraccion: operadores dentro del denominador', () {
    Future<void> frac(WidgetTester t) => key(t, 'a/b');

    testWidgets('\frac{1}{2+3}', (t) async {
      await boot(t);
      await key(t, '1');
      await frac(t);
      await key(t, '2');
      await keys(t, ['+', '3']);
      expect(live(t), contains(r'\frac{1}{2+3'));
    });

    testWidgets('todos los operadores se quedan en el denominador', (t) async {
      await boot(t);
      await key(t, '1');
      await frac(t);
      await keys(t, ['2', '-', '3', '×', '4', '÷', '5']);
      expect(live(t), contains(r'\frac{1}{2-3\cdot4:5'));
    });
  });
}
