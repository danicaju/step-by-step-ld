import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:casio_tutor_calc/domain/math_engine/arithmetic/classwiz_key_actions.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/calculator_settings.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/presentation/widgets/calculator_bezel_widgets.dart';

import 'support/e2e_helpers.dart';

Future<void> alpha(WidgetTester t, String label) async {
  await tapF(t, find.text('ALPHA'));
  await key(t, label);
}

Future<void> calcKey(WidgetTester t) => tapF(
      t,
      find.byWidgetPredicate((w) => w is CompactControlKey && w.label == 'CALC'),
    );

String? override(WidgetTester t) => lcd(t).resultOverrideLatex;

void main() {
  setUp(CalculatorSettings.reset);

  group('Dominio ClassWiz', () {
    test('FACT: 360 = 2^3 * 3^2 * 5 y no aplica a 1 ni a fracciones', () {
      expect(ClassWizKeyActions.factorLatex(Rational(360)), r'2^{3} \cdot 3^{2} \cdot 5');
      expect(ClassWizKeyActions.factorLatex(Rational(1)), isNull);
      expect(ClassWizKeyActions.factorLatex(Rational(1, 2)), isNull);
    });

    test('DMS: 2.5 -> 2 30 0 y negativos', () {
      expect(ClassWizKeyActions.dmsLatex(2.5), r"2^{\circ} 30' 0''");
      expect(ClassWizKeyActions.dmsLatex(35.3375), r"35^{\circ} 20' 15''");
      expect(ClassWizKeyActions.dmsLatex(-0.5), r"-0^{\circ} 30' 0''");
    });

    test('a b/c <-> d/c', () {
      expect(ClassWizKeyActions.fractionLatex(Rational(7, 2), mixed: true), r'3\frac{1}{2}');
      expect(ClassWizKeyActions.fractionLatex(Rational(7, 2), mixed: false), r'\frac{7}{2}');
      expect(ClassWizKeyActions.fractionLatex(Rational(-7, 2), mixed: true), r'-3\frac{1}{2}');
      expect(ClassWizKeyActions.fractionLatex(Rational(4), mixed: true), isNull);
      expect(ClassWizKeyActions.rationalFromLatex(r'3\frac{1}{2}'), Rational(7, 2));
    });

    test('ENG: exponentes multiplos de 3 hacia delante y hacia atras', () {
      expect(ClassWizKeyActions.engBaseExponent(1234567), 6);
      expect(ClassWizKeyActions.engBaseExponent(0.0042), -3);
      expect(ClassWizKeyActions.engBaseExponent(1000), 3);
      expect(ClassWizKeyActions.engLatex(1000, 3), r'1 \times 10^{3}');
      expect(ClassWizKeyActions.engLatex(1000, 6), r'0,001 \times 10^{6}');
      expect(ClassWizKeyActions.engLatex(1000, 0), r'1000 \times 10^{0}');
      expect(ClassWizKeyActions.engLatex(0.0042, -6), r'4200 \times 10^{-6}');
    });

    test('Ran# en [0,1) y RanInt#(a,b) acotado', () {
      final rnd = Random(7);
      for (var i = 0; i < 200; i++) {
        final v = ClassWizKeyActions.ranHash(rnd);
        expect(v >= 0 && v < 1, isTrue);
        final n = ClassWizKeyActions.ranInt(3, 6, rnd);
        expect(n >= 3 && n <= 6, isTrue);
      }
      expect(ClassWizKeyActions.ranInt(5, 5, rnd), 5);
      expect(ClassWizKeyActions.substituteRandoms('RanInt#(5,5)+2', rnd), '(5)+2');
      expect(
        RegExp(r'^\(0\.\d{3}\)\*2$').hasMatch(ClassWizKeyActions.substituteRandoms('Ran#*2', rnd)),
        isTrue,
      );
    });
  });

  group('CW-2.3 FACT', () {
    testWidgets('360 alterna factores primos y vuelve a 360', (t) async {
      await boot(t);
      await keys(t, ['3', '6', '0', '=']);
      expect(result(t), '360');
      await shiftKey(t, '÷');
      expect(override(t), r'2^{3} \cdot 3^{2} \cdot 5');
      await shiftKey(t, '÷');
      expect(override(t), isNull);
      expect(result(t), '360');
    });
  });

  group('CW-2.4 sexagesimal', () {
    testWidgets('2.5 <-> 2 30 0 con SHIFT + .', (t) async {
      await boot(t);
      await keys(t, ['2', '.', '5', '=']);
      await shiftKey(t, '.');
      expect(override(t), r"2^{\circ} 30' 0''");
      await shiftKey(t, '.');
      expect(override(t), isNull);
    });

    testWidgets('35 20 15 se escribe y evalua sin error', (t) async {
      await boot(t);
      await keys(t, ['3', '5']);
      await shiftKey(t, '.');
      await keys(t, ['2', '0']);
      await shiftKey(t, '.');
      await keys(t, ['1', '5']);
      await shiftKey(t, '.');
      await key(t, '=');
      expect(result(t), isNotNull);
      expect(find.textContaining('Syntax'), findsNothing);
    });
  });

  group('CW-2.5 a b/c', () {
    testWidgets('7/2 alterna impropia y mixta con SHIFT + S<=>D', (t) async {
      await boot(t);
      await keys(t, ['7', '÷', '2', '=']);
      expect(result(t), r'\frac{7}{2}');
      await shiftKey(t, 'S⬄D');
      expect(override(t), r'3\frac{1}{2}');
      await shiftKey(t, 'S⬄D');
      expect(override(t), isNull);
    });
  });

  group('CW-2.6 ENG y Ran#', () {
    testWidgets('ENG sube de 3 en 3 y ◀ baja', (t) async {
      await boot(t);
      await keys(t, ['1', '2', '3', '4', '5', '6', '7', '=']);
      await shiftKey(t, '3');
      expect(override(t), r'1,234567 \times 10^{6}');
      await shiftKey(t, '3');
      expect(override(t), r'0,001234567 \times 10^{9}');
      await pad(t, 'left');
      expect(override(t), r'1,234567 \times 10^{6}');
      await pad(t, 'left');
      expect(override(t), r'1234,567 \times 10^{3}');
    });

    testWidgets('Ran# desde OPTN da un decimal en [0,1)', (t) async {
      await boot(t);
      await tapF(t, find.text('SHIFT'));
      await calcKey(t);
      await key(t, '4'); // Otras funciones
      await pad(t, 'right');
      await key(t, '2'); // Ran#
      await key(t, '=');
      final r = ClassWizKeyActions.rationalFromLatex(result(t)!);
      expect(r, isNotNull);
      final v = r!.toDouble();
      expect(v >= 0 && v < 1, isTrue);
    });

    testWidgets('RanInt#(4,4) da 4', (t) async {
      await boot(t);
      await tapF(t, find.text('SHIFT'));
      await calcKey(t);
      await key(t, '4'); // Otras funciones
      await pad(t, 'right');
      await key(t, '3'); // RanInt#(
      await key(t, '4');
      await pad(t, 'right');
      await key(t, '4');
      await key(t, '=');
      expect(result(t), '4');
    });
  });

  group('CW-2.1 STO', () {
    testWidgets('STO guarda Ans en A sin ALPHA y muestra Ans -> A', (t) async {
      await boot(t);
      await keys(t, ['5', '+', '3', '=']);
      await tapF(t, find.text('SHIFT'));
      await key(t, '(');
      expect(lcd(t).showSto, isTrue);
      await key(t, '7');
      expect(lcd(t).showSto, isFalse);
      expect(override(t), r'\text{Ans} \rightarrow A');
      await key(t, 'AC');
      await alpha(t, '7');
      await keys(t, ['+', '1', '=']);
      expect(result(t), '9');
    });

    testWidgets('AC cancela STO', (t) async {
      await boot(t);
      await tapF(t, find.text('SHIFT'));
      await key(t, '(');
      await key(t, 'AC');
      expect(lcd(t).showSto, isFalse);
    });
  });

  group('CW-2.2 CALC', () {
    testWidgets('2x^2-3x+1 en x=2 y vuelve a pedir x?', (t) async {
      await boot(t);
      await key(t, '2');
      await alpha(t, ')');
      await key(t, 'x²');
      await key(t, '-');
      await key(t, '3');
      await alpha(t, ')');
      await keys(t, ['+', '1']);
      await calcKey(t);
      expect(find.text('x? '), findsOneWidget);
      await keys(t, ['2', '=']);
      expect(result(t), '3');
      await key(t, '=');
      expect(find.text('x? '), findsOneWidget);
      await keys(t, ['0', '=']);
      expect(result(t), '1');
    });

    testWidgets('x+y pregunta x? y luego y?', (t) async {
      await boot(t);
      await alpha(t, ')');
      await key(t, '+');
      await alpha(t, '(');
      await calcKey(t);
      expect(find.text('x? '), findsOneWidget);
      await keys(t, ['1', '=']);
      expect(find.text('y? '), findsOneWidget);
      await keys(t, ['2', '=']);
      expect(result(t), '3');
    });

    testWidgets('sin(30 no abre el prompt de variables', (t) async {
      await boot(t);
      await keys(t, ['sin', '3', '0']);
      await calcKey(t);
      expect(find.text('x? '), findsNothing);
    });
  });

  group('CW-2.7 RESET', () {
    testWidgets('SHIFT + 9 abre RESET con menu y confirmacion', (t) async {
      await boot(t);
      await shiftKey(t, '9');
      expect(find.byKey(const Key('lcd_reset_view')), findsOneWidget);
      expect(find.text('1: Setup'), findsOneWidget);
      expect(find.text('2: Memoria'), findsOneWidget);
      expect(find.text('3: Inicializar todo'), findsOneWidget);
      await key(t, '3');
      expect(find.text('[ = ] : Sí   |   [ AC ] : Cancelar'), findsOneWidget);
    });

    testWidgets('= confirma y restaura la configuracion', (t) async {
      await boot(t);
      CalculatorSettings.mathOutput = MathOutputMode.decimalO;
      await shiftKey(t, '9');
      await keys(t, ['1', '=']);
      expect(find.byKey(const Key('lcd_reset_view')), findsNothing);
      expect(CalculatorSettings.mathOutput, MathOutputMode.mathO);
    });

    testWidgets('AC cancela sin tocar nada', (t) async {
      await boot(t);
      CalculatorSettings.mathOutput = MathOutputMode.decimalO;
      await shiftKey(t, '9');
      await keys(t, ['1', 'AC']);
      expect(find.byKey(const Key('lcd_reset_view')), findsNothing);
      expect(CalculatorSettings.mathOutput, MathOutputMode.decimalO);
    });

    testWidgets('Memoria borra A pero no la configuracion', (t) async {
      await boot(t);
      CalculatorSettings.mathOutput = MathOutputMode.decimalO;
      await keys(t, ['5', '=']);
      await tapF(t, find.text('SHIFT'));
      await key(t, '(');
      await key(t, '7');
      await shiftKey(t, '9');
      await keys(t, ['2', '=']);
      expect(CalculatorSettings.mathOutput, MathOutputMode.decimalO);
      await key(t, 'AC');
      await alpha(t, '7');
      await keys(t, ['+', '1', '=']);
      expect(result(t), '1');
    });
  });
}
