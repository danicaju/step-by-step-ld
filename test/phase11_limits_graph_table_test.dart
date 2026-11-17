import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/calculus/function_table.dart';
import 'package:casio_tutor_calc/presentation/painters/universal_function_painter.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/expr_key_input.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/function_table_widget.dart';
import 'package:casio_tutor_calc/domain/math_engine/calculus/limits_asymptotes_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'support/e2e_helpers.dart';
import 'support/header_select.dart';

String _tex(StepByStepResolution r) =>
    '${r.originalInputLatex}${r.steps.map((s) => s.latexExpression).join()}${r.exactResultLatex}';

void _clean(StepByStepResolution r) {
  final t = _tex(r);
  expect(RegExp(r'\\(text|mathrm)\{[^}]*[áéíóúñ¿¡][^}]*\}').hasMatch(t), isFalse, reason: t);
  var d = 0;
  for (final c in t.split('')) {
    if (c == '{') d++;
    if (c == '}') d--;
    expect(d >= 0, isTrue, reason: t);
  }
  expect(d, 0, reason: t);
}

String _dom(String f) => DomainSolver.of(FunctionModel.parse(f)).latex;
LimitValue _lim(String f, LimitPoint p) => LimitsAsymptotesSolver.limit(f, p).$1;
LimitPoint _at(int n, {int d = 1, LimSide side = LimSide.both}) => LimitPoint.at(Rational(n, d), side: side);

void main() {
  group('Dominio', () {
    test('polinomio, racional, raiz, logaritmo', () {
      expect(_dom('x^2+3x'), r'\mathbb{R}');
      expect(_dom('1/(x-2)'), r'(-\infty,\,2) \cup (2,\,+\infty)');
      expect(_dom('sqrt(x-1)'), r'[1,\,+\infty)');
      expect(_dom('ln(x+3)'), r'(-3,\,+\infty)');
    });
    test('combinadas', () {
      expect(_dom('sqrt(x)/(x-4)'), r'[0,\,4) \cup (4,\,+\infty)');
      expect(_dom('sqrt(x^2-4)'), r'(-\infty,\,-2] \cup [2,\,+\infty)');
      expect(_dom('1/sqrt(x-1)'), r'(1,\,+\infty)');
    });
  });

  group('Limites e indeterminaciones', () {
    test('sustitucion directa', () {
      expect(_lim('x^2+1', _at(3)).latex, '10');
      expect(_lim('(x+1)/(x-2)', _at(0)).latex, r'-\frac{1}{2}');
    });
    test('0/0 por factorizacion (Ruffini)', () {
      final (v, r) = LimitsAsymptotesSolver.limit('(x^2-1)/(x-1)', _at(1));
      expect(v.latex, '2');
      expect(_tex(r), contains(r'\frac{0}{0}'));
      _clean(r);
      expect(_lim('(x^2-5x+6)/(x-2)', _at(2)).latex, '-1');
      expect(_lim('(x^3-8)/(x-2)', _at(2)).latex, '12');
    });
    test('0/0 con raiz: conjugado', () {
      final (v, r) = LimitsAsymptotesSolver.limit('(sqrt(x+2)-2)/(x-2)', _at(2));
      expect(v.latex, r'\frac{1}{4}');
      expect(v.estimated, isFalse);
      expect(_tex(r), contains('conjugado'.isEmpty ? '' : r'\sqrt{'));
      _clean(r);
      expect(_lim('(x-4)/(sqrt(x)-2)', _at(4)).latex, '4');
    });
    test('infinito/infinito', () {
      const inf = LimitPoint.plusInfinity();
      expect(_lim('(3x^2+1)/(x^2-5)', inf).latex, '3');
      expect(_lim('(x+1)/(x^2-5)', inf).latex, '0');
      expect(_lim('(x^3+1)/(x^2-5)', inf).latex, r'+\infty');
      expect(_lim('(x^3+1)/(x^2-5)', const LimitPoint.minusInfinity()).latex, r'-\infty');
      final r = LimitsAsymptotesSolver.limit('(3x^2+1)/(x^2-5)', inf).$2;
      expect(_tex(r), contains(r'\frac{\infty}{\infty}'));
      _clean(r);
    });
    test('laterales', () {
      expect(_lim('1/x', _at(0, side: LimSide.right)).latex, r'+\infty');
      expect(_lim('1/x', _at(0, side: LimSide.left)).latex, r'-\infty');
      expect(_lim('1/x', _at(0)).exists, isFalse);
      expect(_lim('1/x^2', _at(0)).latex, r'+\infty');
    });
    test('no racionales: estimacion marcada', () {
      final v = _lim('ln(x)', _at(0, side: LimSide.right));
      expect(v.latex, r'-\infty');
      expect(v.estimated, isTrue);
      expect(_lim('sin(x)/x', _at(0)).latex, '1');
    });
  });

  group('Asintotas', () {
    StudyResult st(String f) => LimitsAsymptotesSolver.study(f);
    test('vertical y horizontal', () {
      final s = st('(2x+1)/(x-3)');
      expect(s.asymptotes.vertical.map((a) => a.latex), ['x = 3']);
      expect(s.asymptotes.horizontal.map((a) => a.latex), ['y = 2']);
      expect(s.asymptotes.oblique, isEmpty);
      _clean(s.resolution);
    });
    test('oblicua por division', () {
      final s = st('(x^2+1)/(x-1)');
      expect(s.asymptotes.vertical.map((a) => a.latex), ['x = 1']);
      expect(s.asymptotes.oblique.map((a) => a.latex), ['y = x + 1']);
      expect(s.asymptotes.horizontal, isEmpty);
      _clean(s.resolution);
    });
    test('hueco: sin asintota vertical', () {
      final s = st('(x^2-1)/(x-1)');
      expect(s.asymptotes.vertical, isEmpty);
    });
    test('logaritmica: AV en 0 (estimada)', () {
      final s = st('ln(x)');
      expect(s.asymptotes.vertical.map((a) => a.latex), ['x = 0']);
      expect(s.asymptotes.vertical.first.estimated, isTrue);
    });
  });

  group('Visor universal', () {
    test('1/(x-2): ninguna rama cruza la asintota x = 2', () {
      final st = LimitsAsymptotesSolver.study('1/(x-2)');
      final w = UniversalFunctionPainter.autoWindow(st.model, st.asymptotes);
      final br = UniversalFunctionPainter.branchesFor(st.model, st.asymptotes, w);
      expect(br.length, greaterThanOrEqualTo(2));
      for (final b in br) {
        expect(b.any((p) => p.$1 < 2) && b.any((p) => p.$1 > 2), isFalse);
      }
    });
    test('tan(x): salto de signo corta la rama (sin AV conocida)', () {
      final f = FunctionModel.parse('tan(x)');
      final br = FunctionSampler.branches(f.at, -6, 6, n: 600, jump: 20);
      for (final b in br) {
        for (var i = 1; i < b.length; i++) {
          expect(((b[i].$2 - b[i - 1].$2).abs() > 20) && ((b[i].$2 < 0) != (b[i - 1].$2 < 0)), isFalse);
        }
      }
      expect(br.length, greaterThan(2));
    });
    test('sqrt solo pinta dentro del dominio', () {
      final f = FunctionModel.parse('sqrt(x)');
      final br = FunctionSampler.branches(f.at, -5, 5);
      expect(br.every((b) => b.every((p) => p.$1 >= 0)), isTrue);
    });
    test('etiquetas legibles de las asintotas', () {
      expect(UniversalFunctionPainter.plainLabel(r'x = \frac{1}{2}'), 'x = 1/2');
      expect(UniversalFunctionPainter.plainLabel('y = x + 1'), 'y = x + 1');
    });
    testWidgets('renderiza en tamanos pequenos con ClipRRect y sin overflow', (t) async {
      for (final f in ['(x^2+1)/(x-1)', 'ln(x)', 'tan(x)', 'sqrt(x-1)', 'sin(x)/x']) {
        final st = LimitsAsymptotesSolver.study(f);
        for (final size in [const Size(120, 80), const Size(320, 200)]) {
          await t.pumpWidget(MaterialApp(
            home: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: UniversalGraphView(model: st.model, asymptotes: st.asymptotes),
              ),
            ),
          ));
          expect(find.byKey(const Key('universal_graph_clip')), findsOneWidget);
          expect(t.takeException(), isNull, reason: f);
        }
      }
    });
  });

  group('TABLE', () {
    List<TableRowData> tbl(String f, String a, String b, String st, {String? g}) => FunctionTable.build(
          f: FunctionModel.parse(f),
          g: g == null ? null : FunctionModel.parse(g),
          start: FunctionTable.parseNumber(a, 'Inicio'),
          end: FunctionTable.parseNumber(b, 'Fin'),
          step: FunctionTable.parseNumber(st, 'Paso'),
        );
    test('1/(x-2) marca Error / AV en la asintota sin lanzar', () {
      final rows = tbl('1/(x-2)', '0', '4', '1');
      expect(rows.length, 5);
      expect(FunctionTable.cell(rows[2].f), 'Error / AV');
      expect(FunctionTable.cell(rows[3].f), '1');
      expect(FunctionTable.cell(rows[0].f), '-0,5');
    });
    test('f y g comparativas; fuera de dominio solo en la que corresponde', () {
      final rows = tbl('sqrt(x)', '-2', '2', '1', g: 'x^2');
      expect(FunctionTable.cell(rows[0].f), 'Error / AV');
      expect(FunctionTable.cell(rows[0].g), '4');
      expect(FunctionTable.cell(rows[4].f), '1,41421');
    });
    test('paso con fracciones y decimales', () {
      final rows = tbl('x', '0', '1', '1/4');
      expect(rows.length, 5);
      expect(FunctionTable.xText(rows[1].x), '0,25');
    });
    test('errores de configuracion', () {
      expect(() => tbl('x', '0', '5', '0'), throwsA(isA<TableConfigException>()));
      expect(() => tbl('x', '0', '5', '-1'), throwsA(isA<TableConfigException>()));
      expect(() => tbl('x', '0', '100', '1'), throwsA(isA<TableConfigException>()));
      expect(() => FunctionTable.parseNumber('', 'Inicio'), throwsA(isA<TableConfigException>()));
    });
    test('estado del formulario y teclas', () {
      final f = FunctionTableFormState();
      expect(f.key('x'), isTrue);
      f.key(')', alpha: true);
      f.key('^2');
      expect(f.cells[0], 'xx^2');
      f.dpad('down');
      f.dpad('down');
      expect(f.focus, 2);
      expect(f.key('7'), isTrue);
      expect(f.key('sin'), isFalse);
      f.dpad('right');
      f.dpad('right');
      expect(f.focus, 4);
      f.dpad('up');
      expect(f.focus, 1);
      expect(ExprKeyInput.apply('sin(', 'DEL'), '');
      expect(ExprKeyInput.apply('x', '^('), 'x^(');
    });
  });

  group('E2E M5', () {
    Future<void> goM5(WidgetTester t) async {
      await tapF(t, find.text('MODE'));
      await tapF(t, find.byKey(const Key('menu_page_next')));
      await tapF(t, find.byKey(const Key('menu_mode_5')));
    }

    testWidgets('cabecera ofrece las tres vistas y mantiene las claves previas', (t) async {
      await boot(t);
      await goM5(t);
      expect(find.byKey(const Key('hdr_graph_kind')), findsOneWidget);
      expect(find.byKey(const Key('hdr_graph_view')), findsOneWidget);
      await pickHeader(t, 'hdr_graph_view', 'graph_view_2');
      expect(find.byKey(const Key('function_table_widget')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('TABLE con teclado: 1/(x-2) en [0,4]', (t) async {
      await boot(t);
      await goM5(t);
      await pickHeader(t, 'hdr_graph_view', 'graph_view_2');
      await keys(t, ['1', 'a/b', '(']);
      await alphaKey(t, ')');
      await keys(t, ['-', '2', ')', '=']);
      await key(t, '=');
      await keys(t, ['0', '=', '4', '=', '1', '=']);
      expect(find.byKey(const Key('table_rows')), findsOneWidget);
      expect(find.text('Error / AV'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Limites: (x^2-1)/(x-1) en 1 = 2 con 0/0', (t) async {
      await boot(t);
      await goM5(t);
      await pickHeader(t, 'hdr_graph_view', 'graph_view_1');
      expect(find.byKey(const Key('limit_form_widget')), findsOneWidget);
      await key(t, '(');
      await alphaKey(t, ')');
      await keys(t, ['x²', '-', '1', ')', 'a/b', '(']);
      await alphaKey(t, ')');
      await keys(t, ['-', '1', ')', '=', '1', '=']);
      expect(result(t), '2');
      expect(t.takeException(), isNull);
    });

    testWidgets('Limites: formulario vacio muestra LcdErrorScreen', (t) async {
      await boot(t);
      await goM5(t);
      await pickHeader(t, 'hdr_graph_view', 'graph_view_1');
      await keys(t, ['=', '=']);
      expect(find.byKey(const Key('lcd_error_screen')), findsOneWidget);
    });

    testWidgets('f(x) libre: estudio con visor universal', (t) async {
      await boot(t);
      await goM5(t);
      await pickHeader(t, 'hdr_graph_kind', 'graph_kind_2');
      await keys(t, ['1', 'a/b', '(']);
      await alphaKey(t, ')');
      await keys(t, ['-', '3', ')', '=']);
      expect(find.byKey(const Key('universal_graph_clip')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
