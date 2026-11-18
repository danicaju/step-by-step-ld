import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/calculus/limits_asymptotes_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/polynomials/algebraic_fraction_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/rational_hyperbola_study.dart';
import 'package:casio_tutor_calc/presentation/painters/universal_function_painter.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/inequality_system_editor_view.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/mode_form.dart';
import 'support/e2e_helpers.dart';
import 'support/header_select.dart';

Future<void> _openMode(WidgetTester tester, int mode) async {
  await tester.tap(find.text('MODE'));
  await tester.pumpAndSettle();
  for (var g = 0; g < 4 && find.byKey(Key('menu_mode_$mode')).evaluate().isEmpty; g++) {
    await tester.tap(find.byKey(const Key('menu_page_next')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(Key('menu_mode_$mode')));
  await tester.pumpAndSettle();
}

void _noAccentsInText(StepByStepResolution r) {
  for (final s in r.steps) {
    for (final m in RegExp(r'\\(?:text|mathrm)\{([^}]*)\}').allMatches(s.latexExpression)) {
      expect(RegExp(r'[áéíóúñ¿¡]').hasMatch(m.group(1)!), isFalse, reason: '${s.shortTitle}: ${m.group(0)}');
    }
    expect(s.latexExpression.contains('\r'), isFalse);
  }
}

void main() {
  group('1. Exponentes multi-digito', () {
    test('^( mantiene el cursor dentro del exponente mientras se teclea', () {
      var (raw, pos) = ExpressionParser.insertAtCursor('x', 1, '^(');
      for (final ch in ['1', '2']) {
        (raw, pos) = ExpressionParser.insertAtCursor(raw, pos, ch);
      }
      expect(raw, 'x^(12)');
      expect(pos, 5);
      expect(ExpressionParser.rawToLiveLatex(raw), contains('^{12}'));
      (raw, pos) = ExpressionParser.insertAtCursor(raw, pos, '-');
      (raw, pos) = ExpressionParser.insertAtCursor(raw, pos, '3');
      expect(raw, 'x^(12-3)');
    });

    test('negativos y expresiones dentro del exponente', () {
      var (raw, pos) = ExpressionParser.insertAtCursor('2', 1, '^(');
      (raw, pos) = ExpressionParser.insertAtCursor(raw, pos, '-');
      (raw, pos) = ExpressionParser.insertAtCursor(raw, pos, '3');
      expect(ExpressionParser.rawToLiveLatex(raw), contains('^{-3}'));
    });

    testWidgets('SHIFT + x² y dos digitos escriben x^{12}; solo ▶ sale del exponente', (t) async {
      await boot(t);
      await alphaKey(t, ')');
      await shiftKey(t, 'x²');
      await keys(t, ['1', '2']);
      expect(live(t), contains('^{12'));
      await pad(t, 'right');
      await keys(t, ['+', '1']);
      expect(live(t), contains('^{12}'));
      expect(live(t), contains('+1'));
    });
  });

  group('5. M7 entra directo al editor', () {
    testWidgets('sin pantalla intermedia: desplegables y editor visibles', (t) async {
      await boot(t);
      await _openMode(t, 7);
      expect(find.byType(InequalitySystemEditorView), findsOneWidget);
      expect(find.byKey(const Key('hdr_ineqsys_unknowns')), findsOneWidget);
      expect(find.byKey(const Key('hdr_ineqsys_rows')), findsOneWidget);
      expect(find.byKey(const Key('hdr_ineqsys_sign')), findsOneWidget);
      await pickHeader(t, 'hdr_ineqsys_unknowns', 'ineqsys_unk_2');
      expect(find.byType(InequalitySystemEditorView), findsOneWidget);
      await pickHeader(t, 'hdr_ineqsys_rows', 'ineqsys_rows_3');
      expect(find.byType(InequalitySystemEditorView), findsOneWidget);
    });

    testWidgets('ALPHA + ) escribe x y ALPHA + ( escribe y en las filas', (t) async {
      await boot(t);
      await _openMode(t, 7);
      await keys(t, ['2']);
      await alphaKey(t, ')');
      await keys(t, ['+']);
      await alphaKey(t, '(');
      final view = t.widget<InequalitySystemEditorView>(find.byType(InequalitySystemEditorView));
      final row = view.ineqSysRowInputs[view.ineqSysActiveRow];
      expect(row, contains('x'));
      expect(row, contains('y'));
    });
  });

  group('2/3. M4 entrada visual', () {
    testWidgets('caja espanola: insignia, cajas y raya vertical', (t) async {
      await boot(t);
      await _openMode(t, 4);
      await pickHeader(t, 'hdr_poly_kind', 'poly_tab_box');
      expect(find.text('M4: POLINOMIOS'), findsOneWidget);
      expect(find.byKey(const Key('box_input_vline')), findsOneWidget);
      expect(find.byKey(const Key('box_input_hline')), findsOneWidget);
      expect(find.byKey(const Key('box_input_quotient_label')), findsOneWidget);
      expect(find.byKey(const Key('xform_cell_0')), findsOneWidget);
      expect(find.byKey(const Key('xform_cell_1')), findsOneWidget);
      expect(find.textContaining('Escribe dividendo P(x)'), findsWidgets);
    });

    testWidgets('fracciones: una fraccion al simplificar', (t) async {
      await boot(t);
      await _openMode(t, 4);
      await pickHeader(t, 'hdr_poly_kind', 'poly_tab_frac');
      expect(find.text('M4: POLINOMIOS'), findsOneWidget);
      expect(find.byKey(const Key('xform_bar_0')), findsOneWidget);
      expect(find.byKey(const Key('xform_cell_2')), findsNothing);
    });

    test('navegacion D-pad de fracciones verticales', () {
      final f = ModeFormState(
        selectorLabels: const ['Simplificar', 'Suma', 'Resta'],
        fractionStyle: true,
        layouts: [
          [ModeField('P', expr: true), ModeField('Q', expr: true)],
          for (var i = 0; i < 2; i++)
            [ModeField('P1', expr: true), ModeField('Q1', expr: true), ModeField('P2', expr: true), ModeField('Q2', expr: true)],
        ],
      );
      f.selector = 1;
      f.focus = 1; // P1
      f.dpad('down');
      expect(f.focus, 2); // Q1
      f.dpad('up');
      expect(f.focus, 1);
      f.dpad('right');
      expect(f.focus, 0); // operador
      f.dpad('right');
      expect(f.focus, 3); // P2
      f.dpad('down');
      expect(f.focus, 4); // Q2
      f.dpad('left');
      expect(f.focus, 0);
      f.dpad('down'); // en el operador, ▲▼ cambian la operacion
      expect(f.selector, 2);
      f.dpad('left');
      expect(f.focus, 1);
    });

    test('fracciones algebraicas: factorizacion, m.c.m., reduccion y simplificacion', () {
      final r = AlgebraicFractionSolver.operate(FractionOp.add, '1', 'x-1', '1', 'x+1').resolution;
      final titles = r.steps.map((s) => s.shortTitle).join('|');
      expect(titles, contains('Factorizar cada polinomio'));
      expect(titles, contains('m.c.m.'));
      expect(titles, contains('Desarrollar y reducir'));
      expect(r.exactResultLatex, contains('2x'));
      _noAccentsInText(r);
      final s = AlgebraicFractionSolver.operate(FractionOp.simplify, 'x^2-1', 'x^2-x', '', '').resolution;
      expect(s.steps.map((e) => e.shortTitle).join('|'), contains('Simplificar'));
      _noAccentsInText(s);
    });
  });

  group('4. M5 racional y libre', () {
    testWidgets('plantilla racional con fraccion vertical y 4 celdas', (t) async {
      await boot(t);
      await _openMode(t, 5);
      await pickHeader(t, 'hdr_graph_kind', 'graph_kind_1');
      expect(find.byKey(const Key('m5_rational_template')), findsOneWidget);
      expect(find.byKey(const Key('m5_rational_bar')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('coeff_cell_$i')), findsOneWidget);
      }
      expect(find.text('M5: RACIONAL'), findsOneWidget);
    });

    testWidgets('funcion libre muestra el prefijo f(x) =', (t) async {
      await boot(t);
      await _openMode(t, 5);
      await pickHeader(t, 'hdr_graph_kind', 'graph_kind_2');
      expect(lcd(t).currentInputLatex, contains('f(x)'));
    });

    test('ventana centrada en (-s/r, p/r) y dos ramas separadas', () {
      final st = LimitsAsymptotesSolver.study('(2*x+1)/(x-3)');
      final w = UniversalFunctionPainter.autoWindow(st.model, st.asymptotes);
      expect((w.xMin + w.xMax) / 2, closeTo(3, 1e-9));
      expect((w.yMin + w.yMax) / 2, closeTo(2, 1e-9));
      expect(w.xMin < 0 && w.xMax > 3, isTrue); // se ve el corte con OY
      expect(w.xMin < -0.5 && w.xMax > -0.5, isTrue); // se ve el corte con OX
      final branches = UniversalFunctionPainter.branchesFor(st.model, st.asymptotes, w);
      expect(branches.length, 2);
      for (final b in branches) {
        final left = b.every((p) => p.$1 < 3);
        final right = b.every((p) => p.$1 > 3);
        expect(left || right, isTrue);
      }
      final roots = UniversalFunctionPainter.roots(st.model, w.xMin, w.xMax);
      expect(roots.single, closeTo(-0.5, 1e-6));
    });

    test('estudio paso a paso: dominio, AV con laterales, AH y cortes', () {
      final r = RationalHyperbolaStudy.analyze(2, 1, 1, -3);
      expect(r.steps.length, 4);
      expect(r.steps[1].latexExpression, contains('-\\infty'));
      expect(r.steps[1].latexExpression, contains('+\\infty'));
      expect(r.steps[2].latexExpression, contains('y = 2'));
      expect(r.steps[3].latexExpression, contains('OX'));
      expect(r.steps[3].latexExpression, contains('OY'));
      _noAccentsInText(r);
    });
  });

  group('6. M12 pasos de pizarra', () {
    StepByStepResolution solve(CalculusOperation op, String f, {int? a, int? b}) => CalculusSolver.solve(
          operation: op,
          expressionRaw: f,
          integralLowerA: a == null ? null : Rational(a),
          integralUpperB: b == null ? null : Rational(b),
        );

    test('derivada: regla, piezas, formula y simplificacion (4-5 pasos)', () {
      for (final f in ['x^3+2x', 'x*sin(x)', '(x^2+1)/(x-1)', 'sin(3x)', 'e^(2x)']) {
        final r = solve(CalculusOperation.derivative, f);
        expect(r.steps.length, inInclusiveRange(4, 6), reason: f);
        expect(r.steps.first.shortTitle, contains('Identificar la regla'));
        expect(r.steps[1].shortTitle, contains('Desglose'));
        expect(r.steps.last.shortTitle, contains('Simplificación'));
        _noAccentsInText(r);
      }
      final prod = solve(CalculusOperation.derivative, 'x*sin(x)');
      expect(prod.steps.first.latexExpression, contains('Producto'));
      expect(prod.steps[1].latexExpression, contains("u'"));
    });

    test('integral indefinida: preparacion, metodo, primitiva y + C', () {
      for (final f in ['3x^2+2x', 'sqrt(x)', '2x*e^(x^2)', 'x*e^x']) {
        final r = solve(CalculusOperation.indefiniteIntegral, f);
        expect(r.steps.length, greaterThanOrEqualTo(4), reason: f);
        expect(r.steps.first.shortTitle, contains('Preparación'));
        expect(r.steps[1].shortTitle, contains('Elección del método'));
        expect(r.steps.last.shortTitle, contains('+ C'));
        _noAccentsInText(r);
      }
      final parts = solve(CalculusOperation.indefiniteIntegral, 'x*e^x');
      expect(parts.steps[1].shortTitle, contains('partes'));
      final sqrt = solve(CalculusOperation.indefiniteIntegral, 'sqrt(x)');
      expect(sqrt.steps.first.latexExpression, contains('^{\\frac{1}{2}}'));
    });

    test('integral definida: Barrow con [F(x)] y valores sustituidos', () {
      final r = solve(CalculusOperation.definiteIntegral, '3x^2+2x', a: 0, b: 2);
      expect(r.steps.length, greaterThanOrEqualTo(5));
      final barrow = r.steps.firstWhere((s) => s.shortTitle.contains('Barrow'));
      expect(barrow.latexExpression, contains('F(2) - F(0)'));
      expect(barrow.latexExpression, contains('_{0}^{2} = F(2)'));
      expect(r.exactResultLatex, '12');
      _noAccentsInText(r);
    });
  });
}
