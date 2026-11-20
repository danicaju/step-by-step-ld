import 'dart:math' as math;

import 'package:casio_tutor_calc/domain/math_engine/arithmetic/casio_iberia_arsenal.dart';
import 'package:casio_tutor_calc/domain/math_engine/geometry/geometry_triangle_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/geometry/line_equations_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/geometry/triangle_summary.dart';
import 'package:casio_tutor_calc/domain/math_engine/geometry/triangle_value_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/proportion/proportion_conversion_solver.dart';
import 'package:casio_tutor_calc/presentation/screens/forms_state.dart';
import 'package:casio_tutor_calc/presentation/theme/calculator_themes.dart';
import 'package:casio_tutor_calc/presentation/theme/theme_contrast.dart';
import 'package:casio_tutor_calc/presentation/theme/theme_controller.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_palette.dart';
import 'package:casio_tutor_calc/presentation/widgets/m10/line_equations_visual_editor.dart';
import 'package:casio_tutor_calc/presentation/widgets/m10/line_graph_painter.dart';
import 'package:casio_tutor_calc/presentation/widgets/m10/triangle_slot_layout.dart';
import 'package:casio_tutor_calc/presentation/widgets/m10/triangle_visual_editor.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/geometry_mode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';
import 'support/header_select.dart';

final _tildes = RegExp(r'[áéíóúÁÉÍÓÚñÑ¿¡]');
final _textArg = RegExp(r'\\(?:text|mathrm)\{([^}]+)\}');

void _render(String label, String latex) {
  final sanitized = CasioLcdScreen.sanitizeForMathTex(latex);
  final inText = _textArg.allMatches(sanitized).map((m) => m.group(1)!).join();
  expect(_tildes.hasMatch(inText), isFalse, reason: 'tildes en \\text [$label]');
  try {
    final ast = SyntaxTree(greenRoot: TexParser(sanitized, const TexParserSettings()).parse());
    ast.buildWidget(MathOptions(style: MathStyle.display, fontSize: 18));
  } catch (e) {
    fail('LaTeX invalido en [$label]: $latex\n$e');
  }
}

void _allRender(String label, StepByStepResolution r) {
  _render('$label.original', r.originalInputLatex);
  _render('$label.exact', r.exactResultLatex);
  for (var i = 0; i < r.steps.length; i++) {
    _render('$label.step$i', r.steps[i].latexExpression);
  }
  expectCleanNotes(r);
}

dynamic q(String s) => ProportionSolver.parseQuantity(s);

TriangleResult tri({List<double?> s = const [null, null, null], List<double?> a = const [null, null, null]}) =>
    TriangleSolver.solve(sides: s, angles: a);

void near(double a, double b, [double eps = 1e-3]) => expect((a - b).abs() < eps, isTrue, reason: '$a vs $b');

String _msg(void Function() f) {
  try {
    f();
  } on ArsenalException catch (e) {
    return e.message;
  }
  fail('se esperaba ArsenalException');
}

LcdTheme _theme(WidgetTester t) {
  final l = lcd(t);
  return l.lcdTheme ?? (l.isOledDark ? LcdTheme.night : LcdTheme.classic);
}

/// Revisa que ningun Math visible de la pantalla tenga error de parseo KaTeX.
void _noKatexErrors(WidgetTester t) {
  for (final m in t.widgetList<Math>(find.byType(Math))) {
    expect(m.parseError, isNull, reason: 'KaTeX: ${m.parseError}');
  }
}

void main() {
  group('Cabecera dinamica de M10', () {
    for (final night in [false, true]) {
      testWidgets('subtitulo segun la vista (${night ? 'LCD oscuro' : 'LCD claro'})', (t) async {
        await boot(t);
        await goMode(t, 10);
        if (night) await tapF(t, find.byKey(const Key('lcd_theme_toggle')));
        expect(find.textContaining('VECTORES 3D'), findsWidgets);
        await pickHeader(t, 'hdr_vector_view', 'vector_view_1');
        expect(find.text('6 ECUACIONES DE LA RECTA'), findsWidgets);
        expect(find.textContaining('VECTORES 3D'), findsNothing);
        await pickHeader(t, 'hdr_vector_view', 'vector_view_2');
        expect(find.text('RESOLUCIÓN DE TRIÁNGULOS'), findsWidgets);
        expect(find.textContaining('VECTORES 3D'), findsNothing);
        // Contraste del subtitulo sobre el fondo de la LCD (>= 4.5:1).
        final style = t.widget<Text>(find.text('RESOLUCIÓN DE TRIÁNGULOS').first).style;
        final bg = LcdPalette.of(_theme(t)).background;
        expect(_theme(t) == LcdTheme.night, night);
        expect(ThemeContrast.ratio(style?.color ?? Colors.black, bg), greaterThanOrEqualTo(4.5));
        await pickHeader(t, 'hdr_vector_view', 'vector_view_0');
        expect(find.textContaining('VECTORES 3D'), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('Triangulos: motor', () {
    test('rectangulo a=3, b=4: Pitagoras c=5, A=36,87, B=53,13, area 6', () {
      final r = tri(s: [3, 4, null], a: [null, null, 90]);
      final s = r.solutions.first;
      near(s.sides[2], 5);
      near(s.angles[0], 36.8699, 1e-3);
      near(s.angles[1], 53.1301, 1e-3);
      expect(TriangleSummary.of(s).area, closeTo(6, 1e-9));
      expect(TriangleSummary.of(s).bySides, 'escaleno');
      expect(TriangleSummary.of(s).byAngles, 'rectángulo');
      expect(r.kind, 'pitagoras');
      final text = lessonText(r.resolution);
      expect(text, contains(r'c^{2} = a^{2} + b^{2}'));
      expect(text, contains(r'\sqrt{3^{2} + 4^{2}} = \sqrt{25} = 5'));
      _allRender('3-4', r.resolution);
    });

    test('rectangulo c=10, A=30: trigonometria a=5, b=5√3, B=60', () {
      final r = tri(s: [null, null, 10], a: [30, null, 90]);
      final s = r.solutions.first;
      near(s.sides[0], 5);
      near(s.sides[1], 8.66025);
      near(s.angles[1], 60);
      final text = lessonText(r.resolution);
      expect(text, contains(r'5\sqrt{3}'));
      expect(text, contains(r'\sin 30^{\circ}'));
      _allRender('c10', r.resolution);
    });

    test('radicales simplificados: catetos 5 y 5 -> 5√2; catetos 1 y 1 -> √2', () {
      expect(lessonText(tri(s: [5, 5, null], a: [null, null, 90]).resolution), contains(r'5\sqrt{2}'));
      expect(lessonText(tri(s: [1, 1, null], a: [null, null, 90]).resolution), contains(r'\sqrt{2}'));
    });

    test('LLL (5, 7, 8): angulos con el coseno que suman 180', () {
      final r = tri(s: [5, 7, 8]);
      near(r.solutions.first.angles.fold<double>(0, (p, v) => p + v), 180, 1e-9);
      near(r.solutions.first.angles[1], 60);
      expect(r.kind, 'coseno');
      expect(lessonText(r.resolution), contains(r'\cos A = \frac{b^{2} + c^{2} - a^{2}}{2\,b\,c}'));
      expect(TriangleSummary.of(r.solutions.first).area, closeTo(10 * math.sqrt(3), 1e-9));
      _allRender('lll', r.resolution);
    });

    test('LAL (a=5, b=8, C=60): c=7 exacto y lados/angulos coherentes', () {
      final r = tri(s: [5, 8, null], a: [null, null, 60]);
      near(r.solutions.first.sides[2], 7, 1e-9);
      expect(lessonText(r.resolution), contains(r'c = \sqrt{49} = 7'));
      near(r.solutions.first.angles.fold<double>(0, (p, v) => p + v), 180, 1e-9);
      _allRender('lal', r.resolution);
      final r2 = tri(s: [7, 8, null], a: [null, null, 60]);
      expect(lessonText(r2.resolution), contains(r'\sqrt{57}'));
    });

    test('ALA y AAL con el teorema del seno', () {
      final ala = tri(s: [null, null, 10], a: [40, 60, null]);
      near(ala.solutions.first.angles[2], 80);
      near(ala.solutions.first.sides[0], 6.527, 1e-3);
      _allRender('ala', ala.resolution);
      final aal = tri(s: [10, null, null], a: [40, 60, null]);
      near(aal.solutions.first.sides[1], 10 * math.sin(60 * math.pi / 180) / math.sin(40 * math.pi / 180), 1e-9);
    });

    test('LLA ambiguo: dos soluciones validas con sus dos triangulos', () {
      final r = tri(s: [5, 8, null], a: [30, null, null]);
      expect(r.isAmbiguous, isTrue);
      expect(r.solutions.length, 2);
      near(r.solutions[0].angles[1], 53.1301, 1e-3);
      near(r.solutions[1].angles[1], 126.8699, 1e-3);
      final text = lessonText(r.resolution);
      expect(text, contains('Caso ambiguo: triángulo 1'));
      expect(text, contains('Caso ambiguo: triángulo 2'));
      _allRender('lla', r.resolution);
      expect(tri(s: [8, 5, null], a: [30, null, null]).isAmbiguous, isFalse);
    });

    test('equilatero e isosceles se clasifican', () {
      expect(TriangleSummary.of(tri(s: [4, 4, 4]).solutions.first).bySides, 'equilátero');
      expect(TriangleSummary.of(tri(s: [5, 5, 8]).solutions.first).bySides, 'isósceles');
      expect(TriangleSummary.of(tri(s: [3, 4, 6]).solutions.first).byAngles, 'obtusángulo');
      expect(TriangleSummary.of(tri(s: [4, 4, 4]).solutions.first).byAngles, 'acutángulo');
    });

    test('validacion con mensajes en MAYUSCULAS', () {
      final imposible = _msg(() => tri(s: [1, 2, 10]));
      expect(imposible, contains('NO ES UN TRIÁNGULO'));
      expect(imposible.replaceFirst('Math ERROR: ', ''), imposible.replaceFirst('Math ERROR: ', '').toUpperCase());
      expect(_msg(() => tri(s: [3, 4, null])), contains('FALTAN DATOS'));
      expect(_msg(() => tri(a: [30, 60, 90])), contains('FALTAN DATOS'));
      expect(_msg(() => tri(s: [3, 4, 5], a: [30, null, null])), contains('SOBRAN DATOS'));
      expect(_msg(() => tri(s: [5, null, null], a: [100, 90, null])), contains('ÁNGULOS'));
      expect(_msg(() => tri(s: [null, null, 5], a: [30, 150, null])), contains('180'));
      expect(_msg(() => tri(s: [null, 10, 5], a: [null, null, 90])), contains('HIPOTENUSA'));
      expect(_msg(() => tri(s: [3, 8, null], a: [30, null, null])), contains('SENO'));
      expect(_msg(() => tri(s: [-3, 4, 5])), contains('POSITIVOS'));
    });

    test('valores de casilla: fracciones, raices y vacio', () {
      expect(TriangleValueParser.parseOrNull(''), isNull);
      expect(TriangleValueParser.parseOrNull('(3)/(4)'), closeTo(0.75, 1e-12));
      expect(TriangleValueParser.parseOrNull('√(2)'), closeTo(math.sqrt(2), 1e-12));
      expect(TriangleValueParser.parseOrNull('2√(3)'), closeTo(2 * math.sqrt(3), 1e-12));
      expect(TriangleValueParser.parseOrNull('-1.5+2'), closeTo(0.5, 1e-12));
      expect(() => TriangleValueParser.parseOrNull('3+'), throwsA(isA<ArsenalException>()));
    });
  });

  group('Triangulos: geometria del editor', () {
    for (final right in [true, false]) {
      test('casillas dentro del lienzo, sin solapes y sin cruzar lados (${right ? 'rectangulo' : 'general'})', () {
        final l = TriangleSlotLayout.of(right: right);
        final canvas = Offset.zero & TriangleSlotLayout.canvas;
        final rects = l.allRects;
        expect(rects.length, right ? 5 : 6);
        for (final r in rects) {
          expect(canvas.contains(r.topLeft) && canvas.contains(r.bottomRight), isTrue, reason: '$r fuera de $canvas');
        }
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(rects[i].overlaps(rects[j]), isFalse, reason: '${rects[i]} solapa ${rects[j]}');
          }
        }
        bool hit(Rect r, Offset p, Offset q) {
          for (var k = 0; k <= 60; k++) {
            final pt = Offset.lerp(p, q, k / 60)!;
            if (r.inflate(1).contains(pt)) return true;
          }
          return false;
        }

        for (final r in rects) {
          for (var e = 0; e < 3; e++) {
            expect(hit(r, l.v[e], l.v[(e + 1) % 3]), isFalse, reason: '$r cruza el lado $e');
          }
        }
      });
    }
  });

  group('Triangulos: pantalla', () {
    bothSizes('rectangulo 3-4: hipotenusa 5, croquis a escala y resumen', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_2 = 3 = 4 = = = =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('c=5,'));
      expectLesson(r, minSteps: 4);
      for (var i = 0; i < r.steps.length; i++) {
        _noKatexErrors(t);
        if (i < r.steps.length - 1) await key(t, '=');
      }
      expect(find.byKey(const Key('triangle_sketch_clip')), findsOneWidget);
      _noKatexErrors(t);
    });

    bothSizes('rectangulo con hipotenusa 10 y angulo A=30', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_2 = > > 1 0 = 3 0 = =');
      final r = res(t);
      expect(norm(lessonText(r)), contains(r'5\sqrt{3}'));
    });

    bothSizes('LLL 5, 7, 8 con el D-Pad (sin overflow)', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_2 pick:xform_selector_dropdown:tri_form_1 = 5 > 7 > 8 = = = =');
      final r = res(t);
      expect(norm(r.exactResultLatex), allOf(contains('a=5'), contains('b=7'), contains('c=8')));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('LAL a=5, b=8, C=60 -> c=7', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_2 pick:xform_selector_dropdown:tri_form_1 = 5 = 8 = = = = 6 0 =');
      expect(norm(res(t).exactResultLatex), contains('c=7,'));
    });

    bothSizes('fracciones y raices en las casillas: catetos √(2) y 1', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_2 = sqrt 2 = 1 = = = =');
      expect(norm(res(t).exactResultLatex), contains('c=1{,}7321'));
    });

    for (final night in [false, true]) {
      testWidgets('triangulo imposible: error en MAYUSCULAS visible (${night ? 'LCD oscuro' : 'LCD claro'})', (t) async {
        await boot(t);
        await goMode(t, 10);
        if (night) await tapF(t, find.byKey(const Key('lcd_theme_toggle')));
        await seq(t, 'pick:hdr_vector_view:vector_view_2 pick:xform_selector_dropdown:tri_form_1 = 1 = 2 = 1 0 = = = =');
        expect(find.byKey(const Key('lcd_error_screen')), findsOneWidget);
        final f = find.textContaining('NO ES UN TRIÁNGULO');
        expect(f, findsWidgets);
        final color = t.widget<Text>(f.first).style?.color;
        if (color != null) {
          expect(ThemeContrast.ratio(color, LcdPalette.of(night ? LcdTheme.night : LcdTheme.classic).background),
              greaterThanOrEqualTo(4.5));
        }
        expect(t.takeException(), isNull);
      });
    }
  });

  group('Rectas: motor', () {
    test('A(1,2) y B(3,6): v=(2,4), m=2, y=2x y 2x - y = 0 sin signos dobles', () {
      final r = LineEquationsSolver.fromPoints(q('1'), q('2'), q('3'), q('6'));
      expect(r.v1, q('2'));
      expect(r.v2, q('4'));
      expect(r.slope, q('2'));
      expect(r.resolution.exactResultLatex, '2x - y = 0');
      final text = lessonText(r.resolution);
      expect(text, contains(r'\vec{v} = \overrightarrow{AB}'));
      expect(text, contains('(2,\\; 4)'));
      expect(text, contains('y = 2x'));
      expect(r.resolution.steps.length, 8);
      _noSignMess(r.resolution);
      _allRender('AB', r.resolution);
    });

    test('las 6 formas de entrada dan la misma recta y2x+3', () {
      final fs = [
        LineEquationsSolver.fromPoints(q('0'), q('3'), q('1'), q('5')),
        LineEquationsSolver.fromPointVector(q('0'), q('3'), q('1'), q('2')),
        LineEquationsSolver.fromPointSlope(q('0'), q('3'), q('2')),
        LineEquationsSolver.fromExplicit(q('2'), q('3')),
        LineEquationsSolver.fromGeneral(q('2'), q('-1'), q('3')),
        LineEquationsSolver.fromContinuous(q('0'), q('1'), q('3'), q('2')),
      ];
      for (final r in fs) {
        expect(r.resolution.exactResultLatex, '2x - y + 3 = 0');
        _noSignMess(r.resolution);
        _allRender('forma', r.resolution);
      }
      final neg = LineEquationsSolver.fromPoints(q('-2'), q('-3'), q('1'), q('3'));
      _noSignMess(neg.resolution);
      _allRender('neg', neg.resolution);
      final frac = LineEquationsSolver.fromPointSlope(q('1/2'), q('-3/4'), q('-2/3'));
      _noSignMess(frac.resolution);
      _allRender('frac', frac.resolution);
    });

    test('vertical y horizontal sin dividir entre 0', () {
      final v = LineEquationsSolver.fromPoints(q('2'), q('1'), q('2'), q('5'));
      expect(v.isVertical, isTrue);
      expect(v.resolution.exactResultLatex, 'x - 2 = 0');
      expect(lessonText(v.resolution), contains('no se puede dividir entre 0'));
      final h = LineEquationsSolver.fromPoints(q('1'), q('3'), q('4'), q('3'));
      expect(h.isHorizontal, isTrue);
      expect(h.resolution.exactResultLatex, 'y - 3 = 0');
      for (final r in [v, h]) {
        _noSignMess(r.resolution);
        _allRender('vh', r.resolution);
      }
      expect(() => LineEquationsSolver.fromContinuous(q('1'), q('0'), q('2'), q('3')), throwsA(isA<ArsenalException>()));
    });
  });

  group('Rectas: pantalla', () {
    testWidgets('desplegable Datos con las 6 formas (sin la barra ◀ ▶ antigua)', (t) async {
      await boot(t);
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_1');
      expect(find.byKey(const Key('xform_selector_dropdown')), findsOneWidget);
      expect(find.textContaining('2 puntos A, B'), findsNothing);
      expect(find.textContaining('2 puntos A y B'), findsWidgets);
      await tapF(t, find.byKey(const Key('xform_selector_dropdown')));
      expect(find.byKey(const Key('line_form_0')), findsOneWidget);
      await tapF(t, find.byKey(const Key('line_form_0')));
      const cells = [4, 4, 3, 2, 3, 4];
      for (var i = 0; i < cells.length; i++) {
        await pickHeader(t, 'xform_selector_dropdown', 'line_form_$i');
        for (var c = 0; c < cells[i]; c++) {
          expect(find.byKey(Key('xform_cell_$c')), findsOneWidget, reason: 'forma $i, hueco $c');
        }
        expect(find.byKey(Key('xform_cell_${cells[i]}')), findsNothing, reason: 'forma $i');
      }
      expect(t.takeException(), isNull);
    });

    bothSizes('A(1,2) y B(3,6): 8 pasos, general 2x - y = 0 y grafica final', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_1 = 1 = 2 = 3 = 6 =');
      final r = res(t);
      expect(result(t), '2x - y = 0');
      expectLesson(r, minSteps: 8);
      _noSignMess(r);
      for (var i = 0; i < r.steps.length; i++) {
        _noKatexErrors(t);
        if (i < r.steps.length - 1) await key(t, '=');
      }
      expect(find.byKey(const Key('line_graph_clip')), findsOneWidget);
      expect(find.byKey(const Key('line_graph_paint')), findsOneWidget);
    });

    bothSizes('vertical A(2,1) B(2,5) sin errores', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_1 = 2 = 1 = 2 = 5 =');
      for (var i = 0; i < res(t).steps.length; i++) {
        _noKatexErrors(t);
        if (i < res(t).steps.length - 1) await key(t, '=');
      }
      expect(result(t), 'x - 2 = 0');
    });

    bothSizes('horizontal A(1,3) B(4,3) sin errores', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_1 = 1 = 3 = 4 = 3 =');
      for (var i = 0; i < res(t).steps.length; i++) {
        _noKatexErrors(t);
        if (i < res(t).steps.length - 1) await key(t, '=');
      }
      expect(result(t), 'y - 3 = 0');
    });

    bothSizes('forma explicita y = 2x + 3 desde los huecos y fraccion 1/2', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_1 pick:xform_selector_dropdown:line_form_3 = 2 = 3 =');
      expect(result(t), '2x - y + 3 = 0');
      await seq(t, 'AC pick:xform_selector_dropdown:line_form_2 = 1 = 2 = 1 frac 2 =');
      expect(result(t), 'x - 2y + 3 = 0');
    });
  });

  group('Temas y contraste', () {
    test('tinta, acento y fondo de la grafica cumplen contraste en las 3 LCD', () {
      for (final theme in LcdTheme.values) {
        final pal = LcdPalette.of(theme);
        final r = LineEquationsSolver.fromPoints(q('1'), q('2'), q('3'), q('6'));
        final painter = LineGraphPainter(r, pal, night: theme == LcdTheme.night);
        expect(ThemeContrast.ratio(pal.formula, pal.background), greaterThanOrEqualTo(4.5), reason: '$theme tinta');
        expect(ThemeContrast.ratio(painter.accent, pal.background), greaterThanOrEqualTo(3.0), reason: '$theme acento');
        expect(ThemeContrast.ratio(pal.original, pal.background), greaterThanOrEqualTo(4.5), reason: '$theme ejes');
      }
    });

    for (final hw in HardwareThemes.all) {
      testWidgets('editores y dibujos sin errores con el tema ${hw.id} en las 3 LCD', (t) async {
        ThemeController.instance.select(hw, persist: false);
        addTearDown(ThemeController.instance.resetForTests);
        final x = ExtraViewsState();
        final r = LineEquationsSolver.fromPoints(q('1'), q('2'), q('3'), q('6'));
        final tr = tri(s: [5, 8, null], a: [30, null, null]);
        for (final theme in LcdTheme.values) {
          for (final size in [const Size(390, 220), const Size(1000, 360)]) {
            for (var kind = 0; kind < 2; kind++) {
              x.tri.selector = kind;
              x.line.selector = kind * 5;
              for (final w in <Widget>[
                TriangleVisualEditor(form: x.tri, theme: theme, onFocus: (_) {}, onSelector: (_) {}),
                LineEquationsVisualEditor(form: x.line, theme: theme, onFocus: (_) {}, onSelector: (_) {}),
                LineGraphView(result: r, theme: theme),
                TriangleSketchView(solution: tr.solutions.first, others: tr.solutions.skip(1).toList(), theme: theme),
              ]) {
                await t.pumpWidget(MaterialApp(
                  home: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: size.width, height: size.height, child: w))),
                ));
                expect(t.takeException(), isNull, reason: '${hw.id} $theme $size');
              }
            }
          }
        }
      });
    }
  });
}

/// Sin `+ -`, `- -`, `1x`, `1y` ni `x - -2` en ninguna formula de la leccion.
void _noSignMess(StepByStepResolution r) {
  final all = [r.originalInputLatex, r.exactResultLatex, ...r.steps.map((s) => s.latexExpression)];
  for (final tex in all) {
    final n = tex.replaceAll(RegExp(r'\s+'), '');
    expect(n.contains('+-'), isFalse, reason: tex);
    expect(n.contains('--'), isFalse, reason: tex);
    expect(RegExp(r'(?<![0-9.])1[xyt](?![a-zA-Z_])').hasMatch(n), isFalse, reason: tex);
  }
}
