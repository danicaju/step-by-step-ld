import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';

String live(String raw, [int? c]) =>
    ExpressionParser.rawToLiveLatex(raw, cursorPos: c).replaceAll(' ', '');

bool balanced(String s) {
  var d = 0;
  for (final ch in s.split('')) {
    if (ch == '{') d++;
    if (ch == '}') d--;
    if (d < 0) return false;
  }
  return d == 0;
}

String eval(String raw) {
  final ast = ExpressionParser().parse(ExpressionParser.finalizeForEvaluation(raw));
  return StepEvaluator().evaluate(ast).exactResultLatex;
}

void main() {
  group('Motor: plantilla (num)/(den)', () {
    test('insert en vacio y envolviendo operando', () {
      expect(FractionTemplate.insert('0', 1), ('()/()', 1));
      expect(FractionTemplate.insert('3', 1), ('(3)/()', 5));
      expect(FractionTemplate.insert('2+3', 3), ('2+(3)/()', 7));
      expect(FractionTemplate.insert('2+', 2), ('2+()/()', 3));
    });

    test('llaves balanceadas en estados intermedios', () {
      for (final r in ['()/()', '(2)/()', '(2+4)/(3', '(2+)/(x-1)+5', '((1)/(2)+)/(2)']) {
        expect(balanced(live(r, 1)), isTrue, reason: r);
        expect(balanced(live(r)), isTrue, reason: r);
      }
      expect(live('()/()', 1), contains(r'\frac'));
    });

    test('multi-termino queda dentro de la fraccion', () {
      expect(live('(2+4)/(3)+5'), contains(r'\frac{2+4}{3}'));
      expect(live('(2x+3)/(x-1)'), contains(r'\frac{2x+3}{x-1}'));
    });

    test('navegacion numerador <-> denominador <-> fuera', () {
      const raw = '(2+4)/(3)';
      expect(FractionTemplate.handleRight(raw, 4), (raw, 7)); // ▶ fin num -> den
      expect(ExpressionParser.jumpFractionUpDown(raw, 2, isUp: false), 8); // ▼
      expect(ExpressionParser.stepCursorRight(raw, 8), 9); // ▶ sale
      expect(ExpressionParser.stepCursorLeft(raw, 9), 8); // ◀ entra al den
      expect(ExpressionParser.jumpFractionUpDown(raw, 8, isUp: true), 4); // ▲
      expect(ExpressionParser.handleTwoSlotLeftArrow(raw, 7), (raw, 4)); // ◀ ini den
      expect(ExpressionParser.handleTwoSlotLeftArrow(raw, 1), (raw, 0)); // ◀ ini num
    });

    test('anidada: profundidad', () {
      const raw = '((1)/(2)+(3)/(2))/(2)+1';
      expect(live(raw), contains(r'\frac{\frac{1}{2}+\frac{3}{2}}{2}+1'));
      expect(eval(raw), '2');
      // ▶ al final del numerador externo salta al denominador externo
      expect(FractionTemplate.handleRight(raw, 16)?.$2, 19);
    });

    test('backspace no deja parentesis huerfanos', () {
      expect(ExpressionParser.deleteAtCursor('()/()', 1).$1, '0');
      expect(ExpressionParser.deleteAtCursor('(2)/()', 5).$1, '(2)');
    });

    test('precedencia: fraccion seguida de operaciones', () {
      expect(eval('(2+4)/(3)+5'), '7');
      expect(
        LinearEquationSolver.solveEquationString('(2x+4)/(2)+1=5').exactResultLatex,
        'x = 2',
      );
      expect(
        LinearEquationSolver.solveEquationString('(x+1)/(2)=4').exactResultLatex,
        'x = 7',
      );
    });
  });

  group('Widget: pulsaciones reales', () {
    Future<void> tap(WidgetTester t, Finder f) async {
      await t.tap(f);
      await t.pumpAndSettle();
    }

    Future<void> txt(WidgetTester t, String s) =>
        tap(t, s == '=' ? find.text(s).last : find.text(s).first); // '=' tambien es leyenda ALPHA de CALC
    Future<void> frac(WidgetTester t) => tap(t, find.byKey(const Key('fraction_key_icon')));
    Future<void> pad(WidgetTester t, String k) => tap(t, find.byKey(Key('replay_$k')));

    Future<void> boot(WidgetTester t) async {
      await t.pumpWidget(const ProviderScope(child: MaterialApp(home: CalculatorScreen())));
      await t.pumpAndSettle();
    }

    CasioLcdScreen lcd(WidgetTester t) => t.widget<CasioLcdScreen>(find.byType(CasioLcdScreen));

    testWidgets('2+4 / 3, salir con ▶, +5, = -> 7', (t) async {
      await boot(t);
      await frac(t);
      await txt(t, '2');
      await txt(t, '+');
      await txt(t, '4');
      await pad(t, 'down');
      await txt(t, '3');
      await pad(t, 'right');
      await txt(t, '+');
      await txt(t, '5');
      expect(lcd(t).currentInputLatex.replaceAll(' ', ''), contains(r'\frac{2+4}{3}'));
      await txt(t, '=');
      expect(lcd(t).currentResolution?.exactResultLatex, '7');
    });

    testWidgets('volver con ◀ al numerador, editar y recalcular', (t) async {
      await boot(t);
      await frac(t);
      await txt(t, '2');
      await txt(t, '+');
      await txt(t, '4');
      await pad(t, 'right'); // fin num -> den
      await txt(t, '3');
      await pad(t, 'right'); // fuera
      await pad(t, 'left'); // fin den
      await pad(t, 'up'); // num
      await txt(t, '2'); // 2+42
      await pad(t, 'down');
      await pad(t, 'right');
      await txt(t, '=');
      expect(lcd(t).currentResolution?.exactResultLatex, r'\frac{44}{3}');
    });

    testWidgets('fraccion anidada en numerador', (t) async {
      await boot(t);
      await frac(t);
      await frac(t);
      await txt(t, '1');
      await pad(t, 'down');
      await txt(t, '2');
      await pad(t, 'right'); // sale de la interna
      await txt(t, '+');
      await frac(t);
      await txt(t, '3');
      await pad(t, 'down');
      await txt(t, '2');
      await pad(t, 'right');
      await pad(t, 'down');
      await txt(t, '2');
      await pad(t, 'right');
      await txt(t, '+');
      await txt(t, '1');
      expect(lcd(t).currentInputLatex.replaceAll(' ', ''), contains(r'\frac{\frac{1}{2}+\frac{3}{2}}{2}+1'));
      await txt(t, '=');
      expect(lcd(t).currentResolution?.exactResultLatex, '2');
    });
  });
}
