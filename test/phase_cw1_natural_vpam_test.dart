import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/calculator_settings.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/unwrap_helper.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/number_formatter.dart';

import 'package:casio_tutor_calc/presentation/widgets/calculator_bezel_widgets.dart';

import 'support/e2e_helpers.dart';

void main() {
  setUp(CalculatorSettings.reset);

  group('CW-1.1 Ans tras =', () {
    testWidgets('operador binario encadena con Ans', (t) async {
      await boot(t);
      await keys(t, ['5', '+', '3', '=']);
      expect(result(t), '8');
      await keys(t, ['+', '2', '=']);
      expect(result(t), '10');
    });

    testWidgets('x2 tras = eleva Ans', (t) async {
      await boot(t);
      await keys(t, ['3', '+', '1', '=', 'x²', '=']);
      expect(result(t), '16');
    });

    testWidgets('numero tras = empieza expresion limpia', (t) async {
      await boot(t);
      await keys(t, ['5', '+', '3', '=', '7']);
      expect(live(t), '7');
      await key(t, '=');
      expect(result(t), '7');
    });

    testWidgets('funcion tras = empieza limpio', (t) async {
      await boot(t);
      await keys(t, ['5', '+', '3', '=', 'sin', '3', '0', '=']);
      expect(result(t), r'\frac{1}{2}');
    });
  });

  group('CW-1.2 Sin Replay por D-Pad', () {
    testWidgets('arriba/abajo ya no cargan calculos previos', (t) async {
      await boot(t);
      await keys(t, ['1', '+', '1', '=', 'AC', '2', '+', '2', '=', 'AC', '3', '+', '3', '=', 'AC']);
      final empty = live(t);
      for (var i = 0; i < 4; i++) {
        await pad(t, 'up');
        await pad(t, 'down');
      }
      expect(live(t), empty);
      expect(live(t).contains('3'), isFalse);
    });
  });

  group('CW-1.3 DEL desenvuelve', () {
    test('raiz: cursor tras apertura conserva operando', () {
      final r = UnwrapHelper.tryUnwrap('√(5)', 2);
      expect(r, ('5', 0));
    });
    test('raiz: cursor tras cierre conserva operando', () {
      final r = UnwrapHelper.tryUnwrap('√(5)', 4);
      expect(r, ('5', 1));
    });
    test('fraccion: quita la barra y conserva numerador y denominador', () {
      expect(UnwrapHelper.tryUnwrap('(3)/(4)', 5), ('34', 1));
      expect(UnwrapHelper.tryUnwrap('(3)/(4)', 1), ('34', 1));
      expect(UnwrapHelper.tryUnwrap('(3)/(4)', 7), ('34', 1));
    });
    test('estructuras vacias usan el borrado normal', () {
      expect(UnwrapHelper.tryUnwrap('√()', 2), isNull);
      expect(UnwrapHelper.tryUnwrap('()/()', 4), isNull);
    });
    test('deleteAtCursor integra el desenvuelto', () {
      expect(ExpressionParser.deleteAtCursor('2+√(9)', 4), ('2+9', 2));
    });
  });

  group('CW-1.4 cierre de parentesis y multiplicacion implicita', () {
    testWidgets('sin(30 se cierra al pulsar =', (t) async {
      await boot(t);
      await keys(t, ['sin', '3', '0', '=']);
      expect(result(t), r'\frac{1}{2}');
    });
    testWidgets('3(4+5) = 27', (t) async {
      await boot(t);
      await keys(t, ['3', '(', '4', '+', '5', ')', '=']);
      expect(result(t), '27');
    });
    testWidgets('2sin(30) = 1', (t) async {
      await boot(t);
      await keys(t, ['2', 'sin', '3', '0', '=']);
      expect(result(t), '1');
    });
    testWidgets('2√3 y 2π se evaluan sin error', (t) async {
      await boot(t);
      await keys(t, ['2', '√■', '3', '=']);
      expect(result(t), isNotNull);
      expect(find.textContaining('Syntax'), findsNothing);
      await key(t, 'AC');
      await shiftKey(t, '0');
      expect(live(t), isNot('0'));
    });
  });

  group('CW-1.5 multi-sentencia', () {
    testWidgets('A=5 : 2A+1 con Disp', (t) async {
      await boot(t);
      await tapF(t, find.text('ALPHA'));
      await key(t, '7'); // A
      await tapF(t, find.text('ALPHA'));
      await tapF(t, find.byWidgetPredicate((w) => w is CompactControlKey && w.label == 'CALC')); // =
      await key(t, '5');
      await tapF(t, find.text('ALPHA'));
      await key(t, '÷'); // separador
      await keys(t, ['2']);
      await tapF(t, find.text('ALPHA'));
      await key(t, '7');
      await keys(t, ['+', '1', '=']);
      expect(result(t), '5');
      expect(find.text('Disp'), findsOneWidget);
      await key(t, '=');
      expect(result(t), '11');
      expect(find.text('Disp'), findsNothing);
    });
  });

  group('CW-1.6 SETUP', () {
    testWidgets('DecimalO muestra decimal directo', (t) async {
      await boot(t);
      CalculatorSettings.mathOutput = MathOutputMode.decimalO;
      await keys(t, ['1', '÷', '4', '=']);
      expect(lcd(t).showDecimalApprox, isTrue);
    });

    testWidgets('el menu SETUP aplica Salida y Separador', (t) async {
      await boot(t);
      await tapF(t, find.text('SHIFT'));
      await tapF(t, find.text('MODE'));
      await key(t, '6'); // fila 6: Salida por Defecto
      await key(t, '2'); // MathI/DecimalO
      expect(CalculatorSettings.mathOutput, MathOutputMode.decimalO);
      await tapF(t, find.text('SHIFT'));
      await tapF(t, find.text('MODE'));
      await key(t, '7'); // fila 7: Separador Digitos
      await key(t, '2'); // Activado
      expect(CalculatorSettings.digitSeparator, isTrue);
    });

    test('separador de miles agrupa la parte entera', () {
      CalculatorSettings.digitSeparator = true;
      expect(NumberFormatter.decimal(1234567.89), r'1\,234\,567,89');
      expect(NumberFormatter.fraction(1234567, 1), r'1\,234\,567');
      CalculatorSettings.digitSeparator = false;
      expect(NumberFormatter.decimal(1234567.89), '1234567,89');
    });

    test('reset restaura salida y separador', () {
      CalculatorSettings.mathOutput = MathOutputMode.decimalO;
      CalculatorSettings.digitSeparator = true;
      CalculatorSettings.reset();
      expect(CalculatorSettings.mathOutput, MathOutputMode.mathO);
      expect(CalculatorSettings.digitSeparator, isFalse);
    });
  });
}
