import 'dart:io';

import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/inequality_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/systems_free/free_system_solver.dart';
import 'package:casio_tutor_calc/presentation/theme/calculator_themes.dart';
import 'package:casio_tutor_calc/presentation/theme/theme_contrast.dart';
import 'package:casio_tutor_calc/presentation/theme/theme_controller.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_complex_editor_view.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_error_palette.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_input_box.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_error_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/blinking_cursor_builder.dart';
import 'package:casio_tutor_calc/presentation/widgets/number_line_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';

const _gt = 'pick:hdr_ineq_sign:ineq_sign_greater';

String _sol(String raw) => InequalitySolver.solveString(raw).exactResultLatex;

const ValueKey<String> _on = ValueKey('lcd_cursor_on');
const ValueKey<String> _off = ValueKey('lcd_cursor_off');

/// Activa el parpadeo real (la suite lo apaga) y lo restaura al terminar.
void _blinkTest(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    LcdBlink.enabled = true;
    addTearDown(() => LcdBlink.enabled = false);
    await boot(t, size: kDesktop);
    await body(t);
    await t.pumpWidget(const SizedBox());
  });
}

Future<void> _expectBlinks(WidgetTester t) async {
  expect(find.byKey(_on).evaluate().length + find.byKey(_off).evaluate().length, 1, reason: 'un cursor activo');
  final seen = <bool>{};
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 550));
    seen.add(find.byKey(_on).evaluate().isNotEmpty);
  }
  expect(seen, {true, false}, reason: 'el cursor debe alternar');
}

/// Lleva la LCD al paso [target] con el D-Pad.
Future<void> _goStep(WidgetTester t, int target) async {
  while (lcd(t).activeStepIndex > 0) {
    await pad(t, 'left');
  }
  for (var i = 0; i < target; i++) {
    await pad(t, 'right');
  }
}

void main() {
  group('Recta real en su propio paso (UI)', () {
    bothSizes('5x^2 - 4 > 5: la recta solo aparece en el penultimo paso', (t) async {
      await seq(t, 'mode:6 pick:hdr_ineq_kind:ineq_deg_2 5 x sq - 4 $_gt 5 =');
      final r = res(t);
      final lineIdx = r.steps.indexWhere((s) => s.showsNumberLine);
      expect(lineIdx, r.steps.length - 2);
      expect(r.steps[lineIdx].shortTitle, 'Estudio de signos en la recta real');
      await _goStep(t, lineIdx);
      expect(find.byType(NumberLineWidget), findsOneWidget);
      expect(find.text('RECTA REAL DE SIGNOS'), findsOneWidget);
      await _goStep(t, 0);
      expect(find.byType(NumberLineWidget), findsNothing);
      await _goStep(t, r.steps.length - 1);
      expect(find.byType(NumberLineWidget), findsNothing);
      expect(r.steps.last.latexExpression, startsWith(r'x \in'));
    });

    testWidgets('escritorio: el panel DESGLOSE muestra la recta integra', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:6 pick:hdr_ineq_kind:ineq_deg_2 5 x sq - 4 $_gt 5 =');
      await tapF(t, find.text('DESGLOSE PASO A PASO'));
      final list = find.ancestor(of: find.byKey(const ValueKey('step_tile_0')), matching: find.byType(ListView));
      await t.dragUntilVisible(find.byKey(const Key('step_number_line')), list.first, const Offset(0, -150));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('step_number_line')), findsOneWidget);
      expect(find.byType(NumberLineWidget), findsWidgets);
      expect(t.takeException(), isNull);
    });

    for (final dark in [false, true]) {
      for (final points in [0, 1, 3, 6]) {
        testWidgets('NumberLineWidget sin recortes: $points puntos, oscuro=$dark', (t) async {
          final data = _fakeData(points);
          for (final size in [const Size(390, 844), const Size(1280, 800)]) {
            await t.binding.setSurfaceSize(size);
            await t.pumpWidget(MaterialApp(
              home: Scaffold(body: Center(child: SizedBox(width: size.width - 20, child: NumberLineWidget(data: data, isOledDark: dark)))),
            ));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull, reason: '$size');
            final box = t.getRect(find.byType(NumberLineWidget));
            expect(box.height, greaterThanOrEqualTo(NumberLineWidget.naturalHeight - 0.5), reason: '$size');
          }
          addTearDown(() => t.binding.setSurfaceSize(null));
        });
      }
    }

    test('la recta real no usa azul, cian ni morado', () {
      final re = RegExp(r'0x[Ff][Ff]([0-9A-Fa-f]{6})');
      for (final f in [
        'lib/presentation/painters/number_line_painter.dart',
        'lib/presentation/painters/number_line_palette.dart',
        'lib/presentation/painters/number_line_layout.dart',
        'lib/presentation/widgets/number_line_painter.dart',
      ]) {
        for (final m in re.allMatches(File(f).readAsStringSync())) {
          final c = Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
          final hsv = HSVColor.fromColor(c);
          final cool = hsv.hue >= 160 && hsv.hue <= 300 && hsv.saturation > 0.25;
          expect(cool, isFalse, reason: '$f ${m.group(0)}');
        }
      }
    });
  });

  group('M7 cursor parpadeante en Sistemas de Inecuaciones', () {
    _blinkTest('LCD claro y oscuro: la fila activa parpadea esperando entrada', (t) async {
      await seq(t, 'mode:7');
      expect(find.byKey(const Key('ineq_sys_row_0')), findsOneWidget);
      await _expectBlinks(t);
      await seq(t, 'x');
      await _expectBlinks(t);
      await tapF(t, find.byKey(const Key('lcd_theme_toggle')));
      await _expectBlinks(t);
      await seq(t, 'v');
      await _expectBlinks(t);
    });
  });

  group('M10 y M11: fraccion vacia primero (a/b)', () {
    bothSizes('M11 1/2 + 3/4 i: a/b, 1, abajo, 2 en la parte real y a/b, 3, abajo, 4 en la imaginaria', (t) async {
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_add frac 1 v 2 = frac 3 v 4 = frac 1 v 4 = frac 1 v 4 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains(r'\frac{3}{4}'));
      expect(norm(r.exactResultLatex), contains('i'));
      expectLesson(r);
    });

    bothSizes('M11: a/b con la celda vacia abre la fraccion y DEL la elimina sin dejar barras', (t) async {
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_add frac');
      final cell = t.widget<CasioComplexEditorView>(find.byType(CasioComplexEditorView));
      expect(cell.cells[0], '/');
      expect(cell.fractionNumeratorActive, isTrue, reason: 'el cursor empieza en el numerador');
      await seq(t, 'DEL');
      expect(t.widget<CasioComplexEditorView>(find.byType(CasioComplexEditorView)).cells[0], '');
      await seq(t, '3 frac');
      expect(t.widget<CasioComplexEditorView>(find.byType(CasioComplexEditorView)).cells[0], '3/');
      expect(t.widget<CasioComplexEditorView>(find.byType(CasioComplexEditorView)).fractionNumeratorActive, isFalse);
      await seq(t, 'DEL');
      expect(t.widget<CasioComplexEditorView>(find.byType(CasioComplexEditorView)).cells[0], '3');
    });

    bothSizes('M11: navegacion ▲ ▼ ◀ ▶ entre numerador y denominador', (t) async {
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_add - 3 frac 5');
      var v = t.widget<CasioComplexEditorView>(find.byType(CasioComplexEditorView));
      expect(v.cells[0], '-3/5');
      expect(v.fractionNumeratorActive, isFalse);
      await seq(t, '^');
      v = t.widget<CasioComplexEditorView>(find.byType(CasioComplexEditorView));
      expect(v.fractionNumeratorActive, isTrue);
      expect(v.activeIndex, 0);
      await seq(t, '>');
      v = t.widget<CasioComplexEditorView>(find.byType(CasioComplexEditorView));
      expect(v.fractionNumeratorActive, isFalse);
      expect(v.activeIndex, 0);
    });

    bothSizes('M10: a/b con la celda vacia tambien abre la fraccion', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_op:vector_op_modulus frac 3 v 2 = 1 = 1 =');
      final r = res(t);
      expect(norm(r.originalInputLatex), contains(r'\frac{3}{2}'));
      expectLesson(r);
    });
  });

  group('Errores: mayuscula inicial y legibilidad en LCD claro y oscuro', () {
    test('LcdErrorText capitaliza cualquier mensaje', () {
      for (final raw in [
        'Math ERROR: el divisor no puede ser 0.',
        'Error en Matrices: matriz no cuadrada',
        'Exception: FormatException: algo raro',
        'Sintaxis incompleta: escribe el dividendo.',
        'fraccion',
      ]) {
        final msg = LcdErrorText.info(raw, syntax: false).message;
        expect(msg[0], msg[0].toUpperCase(), reason: raw);
        expect(RegExp(r'^[a-z]').hasMatch(msg), isFalse, reason: raw);
      }
    });

    test('ningun literal de error de lib/ empieza en minuscula', () {
      final bad = <String>[];
      final re = RegExp(r"(?:Math ERROR|Sintaxis incompleta|Syntax ERROR): [a-z]|"
          r"(?:FormatException|ArgumentError|ArsenalException|StateError)\(\s*(?:const )?'[a-z]");
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (re.hasMatch(lines[i])) bad.add('${f.path}:${i + 1}');
        }
      }
      expect(bad, isEmpty, reason: bad.join(', '));
    });

    for (final hw in HardwareThemes.all) {
      for (final dark in [false, true]) {
        test('contraste WCAG tema ${hw.name} LCD ${dark ? "oscuro" : "claro"}', () {
          final p = LcdErrorPalette.of(hw, dark: dark);
          expect(ThemeContrast.ratio(p.title, p.header), greaterThanOrEqualTo(7.0), reason: 'titulo');
          expect(ThemeContrast.ratio(p.body, p.card), greaterThanOrEqualTo(7.0), reason: 'cuerpo');
          expect(ThemeContrast.ratio(p.hint, p.card), greaterThanOrEqualTo(4.5), reason: 'sugerencia');
          expect(ThemeContrast.ratio(p.icon, p.header), greaterThanOrEqualTo(4.5), reason: 'icono');
          expect(ThemeContrast.ratio(p.hintIcon, p.card), greaterThanOrEqualTo(4.5), reason: 'icono pista');
          expect(p.card != p.bg, isTrue, reason: 'la tarjeta se distingue del fondo');
        });
      }
    }

    testWidgets('LcdErrorScreen en LCD oscuro: titulo, cuerpo y sugerencia claros y legibles', (t) async {
      for (final hw in HardwareThemes.all) {
        ThemeController.instance.select(hw, persist: false);
        for (final dark in [false, true]) {
          await t.pumpWidget(MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 380,
                height: 300,
                child: LcdErrorScreen(kind: LcdErrorKind.math, message: 'el divisor no puede ser 0.', isOledDark: dark),
              ),
            ),
          ));
          await t.pump();
          Color colorOf(String key) => t.widget<Text>(find.byKey(Key(key))).style!.color!;
          final p = LcdErrorPalette.of(hw, dark: dark);
          expect(colorOf('lcd_error_title'), p.title);
          expect(colorOf('lcd_error_message'), p.body);
          expect(colorOf('lcd_error_hint'), p.hint);
          expect(t.widget<Text>(find.byKey(const Key('lcd_error_message'))).data, startsWith('E'));
          if (dark) expect(colorOf('lcd_error_title').computeLuminance(), greaterThan(0.4));
        }
      }
      ThemeController.instance.resetForTests();
    });
  });

  group('M3 sistemas libres (dominio)', () {
    StepByStepResolution sys(List<String> l, List<String> r) => FreeSystemSolver.solve(l, r);

    test('lineal desordenado 2(x+1) - y = 7 y x + 2y = 5 -> (3, 1)', () {
      final r = sys(['2(x+1)-y', 'x+2y'], ['7', '5']);
      expect(norm(r.exactResultLatex), 'x=3,y=1');
      expect(r.steps.first.shortTitle, contains('ordenar'));
      expectLesson(r, minSteps: 3);
    });

    test('lineal con fracciones x/2 + y/3 = 5, x - y = 1', () {
      final r = sys([r'\frac{x}{2}+\frac{y}{3}', 'x-y'], ['5', '1']);
      expect(norm(r.exactResultLatex), contains(r'x=\frac{32}{5}'));
      expectLesson(r, minSteps: 3);
    });

    test('lineal 3x3 x+y+z=6, 2x-y+z=3, x+2y-z=2 -> (1, 2, 3)', () {
      final r = sys(['x+y+z', '2x-y+z', 'x+2y-z'], ['6', '3', '2']);
      expect(norm(r.exactResultLatex), 'x=1,y=2,z=3');
      expectLesson(r, minSteps: 3);
    });

    test('lineal + cuadratico x + y = 7, x^2 + y^2 = 25 -> (3,4) y (4,3)', () {
      final r = sys(['x+y', 'x^2+y^2'], ['7', '25']);
      final t = norm(r.exactResultLatex);
      expect(t, contains(r'(3,4)'));
      expect(t, contains(r'(4,3)'));
      expectLesson(r, minSteps: 5);
    });

    test('hiperbola x*y = 12, x + y = 7', () {
      final t = norm(sys(['x*y', 'x+y'], ['12', '7']).exactResultLatex);
      expect(t, contains('(3,4)'));
      expect(t, contains('(4,3)'));
    });

    test('dos cuadraticas x^2 + y^2 = 25, x^2 - y^2 = 7 -> cuatro pares (+-4, +-3)', () {
      final r = sys(['x^2+y^2', 'x^2-y^2'], ['25', '7']);
      final t = norm(r.exactResultLatex);
      for (final pair in ['(-4,-3)', '(-4,3)', '(4,-3)', '(4,3)']) {
        expect(t, contains(pair));
      }
      expectLesson(r, minSteps: 4);
    });

    for (final lg in ['log(x)+log(y)', 'log_10(x)+log_10(y)']) {
      test('logaritmico $lg = 2, x - y = 15 -> (20, 5) y se descarta la extrana', () {
        final r = sys([lg, 'x-y'], ['2', '15']);
        expect(norm(r.exactResultLatex), contains('(20,5)'));
        expect(norm(r.exactResultLatex), isNot(contains('(-5,-20)')));
        expect(lessonText(r), contains('descartada'));
        expectLesson(r, minSteps: 5);
      });
    }

    test('exponencial 2^x * 2^y = 32, x - y = 1 -> (3, 2)', () {
      expect(norm(sys(['2^x*2^y', 'x-y'], ['32', '1']).exactResultLatex), 'x=3,y=2');
    });

    test('racional 1/x + 1/y = 5/6, x + y = 5 -> (2,3) y (3,2) con ceros del denominador excluidos', () {
      final r = sys(['1/x+1/y', 'x+y'], ['5/6', '5']);
      final t = norm(r.exactResultLatex);
      expect(t, contains('(2,3)'));
      expect(t, contains('(3,2)'));
      expect(lessonText(r), contains(r'x \ne 0'));
      expectLesson(r, minSteps: 5);
    });

    test('sistemas incompatibles y errores claros', () {
      expect(() => sys(['x+y', 'x+y'], ['1', '2']), returnsNormally);
      expect(() => sys(['x+w', 'x-y'], ['1', '2']), throwsFormatException);
      expect(() => sys(['', ''], ['', '']), throwsFormatException);
      // 3x3 y 4x4 no lineales se resuelven por cascada; el 2x2 sin receta cae a Newton (sin excepcion).
      expect(() => sys(['x+y+z', 'x^2', 'y'], ['1', '2', '3']), returnsNormally);
      expect(() => sys(['x^3+y', 'x*y'], ['1', '2']), returnsNormally);
      expect(() => sys(['x+y+z+w', 'x-y', 'z', 'q'], ['1', '2', '3', '4']), throwsFormatException);
    });
  });

  group('M3 entrada libre con = explicito (UI)', () {
    LcdInputBox cell(WidgetTester t, int i) => t.widget<LcdInputBox>(find.byKey(Key('sys_free_cell_$i')));

    bothSizes('estructura 2x2: dos casillas por ecuacion separadas por =', (t) async {
      await seq(t, 'mode:3');
      expect(find.byKey(const Key('sys_free_editor')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('sys_free_cell_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('sys_free_cell_4')), findsNothing);
      expect(find.byKey(const Key('sys_free_eq_0')), findsOneWidget);
      expect(find.byKey(const Key('sys_free_eq_1')), findsOneWidget);
      expect(find.text('='), findsWidgets);
      expect(cell(t, 0).active, isTrue);
    });

    bothSizes('D-Pad: ► pasa al miembro derecho, ▼ a la ecuacion siguiente, ▲ y ◄ vuelven', (t) async {
      await seq(t, 'mode:3 >');
      expect(cell(t, 1).active, isTrue);
      await seq(t, 'v');
      expect(cell(t, 3).active, isTrue);
      await seq(t, '<');
      expect(cell(t, 2).active, isTrue);
      await seq(t, '^');
      expect(cell(t, 0).active, isTrue);
    });

    bothSizes('lineal desordenado 2(x+1) - y = 7 y x + 2y = 5 -> x = 3, y = 1', (t) async {
      await seq(t, 'mode:3 2 ( x + 1 ) - y = 7 = x + 2 y = 5 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), 'x=3,y=1');
      expect(r.steps.first.shortTitle, contains('ordenar'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('3x3 con z (ALPHA + 3): x+y+z=6, 2x-y+z=3, x+2y-z=2', (t) async {
      await seq(t, 'mode:3 pick:hdr_sys_size:sys_dim_3 x + y + A:3 = 6 = 2 x - y + A:3 = 3 = x + 2 y - A:3 = 2 =');
      expect(find.byKey(const Key('sys_free_cell_5')), findsNothing);
      final r = res(t);
      expect(norm(r.exactResultLatex), 'x=1,y=2,z=3');
      expectLesson(r, minSteps: 3);
    });

    bothSizes('lineal + cuadratico x + y = 7, x^2 + y^2 = 25', (t) async {
      await seq(t, 'mode:3 x + y = 7 = x sq + y sq = 2 5 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('(3,4)'));
      expect(norm(r.exactResultLatex), contains('(4,3)'));
      expectLesson(r, minSteps: 5);
    });

    bothSizes('logaritmico log_10(x) + log_10(y) = 2, x - y = 15 -> (20, 5)', (t) async {
      await seq(t, 'mode:3 log 1 0 > x > + log 1 0 > y > = 2 = x - y = 1 5 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('(20,5)'));
      expect(lessonText(r), contains('descartada'));
    });

    bothSizes('racional 1/x + 1/y = 5/6, x + y = 5 con fracciones verticales', (t) async {
      await seq(t, 'mode:3 frac 1 v x > + frac 1 v y > = frac 5 v 6 > = x + y = 5 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('(2,3)'));
      expect(norm(r.exactResultLatex), contains('(3,2)'));
    });

    bothSizes('el selector Coeficientes conserva la entrada clasica ax+by=c', (t) async {
      await seq(t, 'mode:3 pick:hdr_sys_input:sys_input_coef');
      expect(find.byKey(const Key('sys_free_editor')), findsNothing);
      expect(find.byKey(const Key('coeff_cell_0')), findsOneWidget);
    });

    bothSizes('un error de entrada se muestra en la LCD con mayuscula inicial', (t) async {
      await seq(t, 'mode:3 x + A:3 = 1 = x - y = 2 =');
      expect(find.byKey(const Key('lcd_error_screen')), findsOneWidget);
      final msg = t.widget<Text>(find.byKey(const Key('lcd_error_message'))).data!;
      expect(msg[0], msg[0].toUpperCase());
    });

    _blinkTest('M3 libre: el cursor parpadea en LCD claro y oscuro', (t) async {
      await seq(t, 'mode:3');
      await _expectBlinks(t);
      await tapF(t, find.byKey(const Key('lcd_theme_toggle')));
      await _expectBlinks(t);
    });
  });

  group('M6 inecuaciones universales', () {
    test('racional (x-1)/(x+2) >= 0', () {
      final s = _sol('(x-1)/(x+2)>=0');
      expect(s, contains(r'(-\infty, -2)'));
      expect(s, contains(r'[1, +\infty)'));
    });

    test('radical sqrt(x+3) > 2', () {
      expect(_sol('sqrt(x+3)>2'), r'(1, +\infty)');
    });

    test('radical con dos casos sqrt(x+3) > x+1', () {
      expect(_sol('sqrt(x+3)>x+1'), r'[-3, 1)');
    });

    test('logaritmica ln(x-2) <= 0', () {
      expect(_sol('ln(x-2)<=0'), r'(2, 3]');
    });

    test('exponencial 2^(x+1) > 8', () {
      expect(_sol('2^(x+1)>8'), r'(2, +\infty)');
    });

    test('valor absoluto compuesto |x-1|+|x+2| < 5', () {
      expect(_sol('|x-1|+|x+2|<5'), r'(-3, 2)');
    });

    test('polinomio de grado 3 x^3 - x > 0', () {
      final s = _sol('x^3-x>0');
      expect(s, contains(r'(-1, 0)'));
      expect(s, contains(r'(1, +\infty)'));
    });

    test('fallback continuo e^x - x - 2 > 0', () {
      final s = _sol('e^x-x-2>0');
      expect(s, contains(r'\cup'));
    });

    test('cada resolucion trae el paso exclusivo de la recta real', () {
      for (final raw in ['5x^2-4>5', 'sqrt(x+3)>2', 'ln(x-2)<=0', '(x-1)/(x+2)>=0', '2x-3<7']) {
        final res = InequalitySolver.solveString(raw);
        final idx = res.steps.indexWhere((s) => s.showsNumberLine);
        expect(idx, isNonNegative, reason: raw);
        expect(idx, res.steps.length - 2, reason: 'penultimo paso: $raw');
        expect(res.steps.last.showsNumberLine, isFalse, reason: raw);
        expect(InequalitySolver.getVisualData(res), isNotNull, reason: raw);
      }
    });

    test('sistema 1D mixto ln(x-1) > 0 con x^2 - 9 <= 0 -> (2, 3]', () {
      final r = InequalitySolver.solveSystem1D(['ln(x-1)>0', 'x^2-9<=0']);
      expect(r.resolution.exactResultLatex, contains(r'(2, 3]'));
      final idx = r.resolution.steps.indexWhere((s) => s.showsNumberLine);
      expect(idx, r.resolution.steps.length - 2);
      expect(r.resolution.steps[idx].shortTitle, 'Intersección en la recta real');
      expect(r.resolution.steps.last.latexExpression, contains(r'(2, 3]'));
    });

    test('sistema 1D de 3 filas intersecta todas', () {
      final r = InequalitySolver.solveSystem1D(['x>0', 'x<10', 'sqrt(x)>2']);
      expect(r.resolution.exactResultLatex, contains('(4, 10)'));
    });

    test('5x^2 - 4 > 5 tiene raices +-3 sqrt5 / 5 en la recta', () {
      final res = InequalitySolver.solveString('5x^2-4>5');
      final v = InequalitySolver.getVisualData(res)!;
      expect(v.criticalPoints.map((p) => p.label).join(' '), contains(r'\sqrt{5}'));
      expect(res.steps.last.latexExpression, startsWith('x'));
      expectNoLeak(res);
    });
  });
}

Inequality1DVisualData _fakeData(int n) => Inequality1DVisualData(
      criticalPoints: [
        for (var i = 0; i < n; i++)
          CriticalPoint(value: i * 1.5 - 2, label: i.isEven ? r'-\frac{3\sqrt{5}}{5}' : r'\frac{3\sqrt{5}}{5}', isClosed: i.isEven),
      ],
      primaryIntervals: [const InequalityInterval(start: double.negativeInfinity, end: -2)],
      signTestIntervals: [
        for (var i = 0; i <= n; i++)
          InequalityInterval(
            start: i == 0 ? double.negativeInfinity : (i - 1) * 1.5 - 2,
            end: i == n ? double.infinity : i * 1.5 - 2,
            isSatisfied: i.isEven,
          ),
      ],
      solutionLatex: r'(-\infty, -2)',
    );

void expectNoLeak(StepByStepResolution res) {
  for (final s in res.steps) {
    expect(s.pedagogicalNote.contains(r'\'), isFalse, reason: s.shortTitle);
  }
}
