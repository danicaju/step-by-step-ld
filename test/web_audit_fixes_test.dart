import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/ast/ast_nodes.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus/calculus_step_texts.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/ext_parser.dart';
import 'package:casio_tutor_calc/main.dart';

import 'support/e2e_helpers.dart';

/// Regresiones halladas en la auditoria visual en navegador (Flutter web + Playwright).
void main() {
  group('Simbolo de grado en trigonometria', () {
    test('sin((2 + 1)°) lleva parentesis y el grado afecta a todo el argumento', () {
      const node = TrigNode(
        TrigFunction.sin,
        BinaryOpNode(IntNode(2), BinaryOperator.add, IntNode(1)),
        showDegSymbol: true,
      );
      expect(node.toLatex(), r'\sin\left(\left(2 + 1\right)^\circ\right)');
    });

    test('un numero solo conserva el grado pegado: sin(30°)', () {
      const node = TrigNode(TrigFunction.sin, IntNode(30), showDegSymbol: true);
      expect(node.toLatex(), r'\sin\left(30^\circ\right)');
    });

    test('un argumento ya entre parentesis no se duplica', () {
      const node = TrigNode(
        TrigFunction.cos,
        BinaryOpNode(IntNode(2), BinaryOperator.add, IntNode(1), parenthesized: true),
        showDegSymbol: true,
      );
      expect(node.toLatex(), r'\cos\left(\left(2 + 1\right)^\circ\right)');
    });
  });

  test('derivadas: el paso 1 pone una regla por linea (no una fila ilegible)', () {
    final step = CalculusStepTexts.identifyRule(ExtParser().parse('sin(x^2)'));
    final tex = step.latexExpression;
    expect(tex, startsWith(r'\begin{array}{l}'));
    expect(tex, endsWith(r'\end{array}'));
    expect(RegExp(r'\\').allMatches(tex).length, greaterThanOrEqualTo(3));
    expect(balanced(tex), isTrue);
  });

  group('Tema Casio (sin violeta/azul por defecto)', () {
    test('acento ambar, tinta Casio y sin tintes de superficie', () {
      final t = casioTheme();
      expect(t.colorScheme.primary, const Color(0xFFE5A93C));
      expect(t.colorScheme.onPrimary, const Color(0xFF1A2530));
      expect(t.colorScheme.surface, const Color(0xFF181E29));
      expect(t.snackBarTheme.backgroundColor, const Color(0xFF1A2530));
      expect(t.colorScheme.surfaceTint, Colors.transparent);
      for (final c in [t.colorScheme.primary, t.colorScheme.secondary, t.colorScheme.tertiary]) {
        final h = HSVColor.fromColor(c).hue;
        expect(h < 200 || h > 330 || HSVColor.fromColor(c).saturation < 0.2, isTrue, reason: '$c');
      }
    });
  });

  testWidgets('con pasos, el titulo del paso va en su propia linea legible', (t) async {
    await boot(t);
    await keys(t, ['2', '+', '3', '=']);
    final title = find.byKey(const Key('lcd_step_title'));
    expect(title, findsOneWidget);
    expect(t.widget<Text>(title).style!.fontSize, greaterThanOrEqualTo(11));
    expect(t.takeException(), isNull);
  });
}
