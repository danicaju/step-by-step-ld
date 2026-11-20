@Tags(['slow'])
library;

import 'dart:io';

import 'package:casio_tutor_calc/core/editor/cell_expression_input.dart';
import 'package:casio_tutor_calc/core/editor/scalar_cell_evaluator.dart';
import 'package:casio_tutor_calc/core/input/physical_key_translator.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/complex_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/exact_number.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/extended_calc_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/trig_and_angles_solver.dart';
import 'package:flutter/material.dart' show Key;
import 'package:flutter/services.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_input_box.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';

StepByStepResolution ext(String s, {AngleUnit angle = AngleUnit.deg}) =>
    ExtendedCalcSolver.solve(s, angle: angle);

String exact(String s, {AngleUnit angle = AngleUnit.deg}) => norm(ext(s, angle: angle).exactResultLatex);

/// Decimal de una resolucion con punto (la app usa coma o llaves segun el ajuste).
String dec(StepByStepResolution r) => r.decimalApproxLatex.replaceAll('{,}', '.').replaceAll(',', '.');

/// `true` si algun LaTeX pintado en pantalla contiene [text] (editores sin `currentInputLatex`).
bool shows(WidgetTester t, String text) => find
    .byWidgetPredicate((w) =>
        (w is LcdInputBox && (w.latex ?? '').contains(text)) ||
        (w is CasioLcdScreen && w.currentInputLatex.contains(text)))
    .evaluate()
    .isNotEmpty;

/// Mensaje del `ExMathError` que lanza [body]; falla si no lanza.
String domainError(void Function() body) {
  try {
    body();
  } on ExMathError catch (e) {
    return e.message;
  }
  fail('Debia lanzar un error de dominio');
}

void expectCapital(String msg) {
  expect(msg, isNotEmpty);
  expect(msg[0], msg[0].toUpperCase(), reason: 'El error debe empezar por mayuscula: $msg');
  expect(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true).hasMatch(msg), isFalse);
}

void main() {
  group('1. Raices n-esimas reales', () {
    test('indice impar con radicando negativo', () {
      expect(exact('root(3,-8)'), '-2');
      expect(exact(r'\sqrt[3]{-8}'), '-2');
      expect(exact('root(3,-27)+5'), '2');
      expect(exact(r'\sqrt[3]{-27}+5'), '2');
      expect(exact('root(5,-32)'), '-2');
    });

    test('motor clasico: la raiz cubica y n-esima negativa ya no da NaN', () {
      final r = StepEvaluator().evaluate(ExpressionParser().parse('root(3,-8)'));
      expect(norm(r.exactResultLatex), '-2');
      final r5 = StepEvaluator().evaluate(ExpressionParser().parse('root(5,-32)'));
      expect(norm(r5.exactResultLatex), '-2');
    });

    test('indice par con radicando negativo: error de dominio en mayuscula', () {
      final m = domainError(() => ext('root(4,-16)'));
      expectCapital(m);
      expect(m, contains('negativo'));
      expectCapital(domainError(() => ext('√(-4)')));
      expectCapital(domainError(() => StepEvaluator().evaluate(ExpressionParser().parse('root(4,-16)'))));
    });

    test('raiz irracional impar negativa conserva el signo', () {
      final r = ext(r'\sqrt[3]{-2}');
      expect(dec(r), startsWith('-1.2599'));
    });
  });

  group('2. Trigonometricas inversas', () {
    test('DEG', () {
      expect(exact('asin(0.5)'), contains('30'));
      expect(exact('acos(0)'), contains('90'));
      expect(exact('atan(1)'), contains('45'));
      expect(exact('arcsin(0.5)'), contains('30'));
      expect(exact('arctan(1)'), contains('45'));
      expect(exact('sin⁻¹(0.5)'), contains('30'));
    });

    test('RAD', () {
      expect(exact('asin(0.5)', angle: AngleUnit.rad), r'\frac{\pi}{6}');
      expect(exact('acos(0)', angle: AngleUnit.rad), r'\frac{\pi}{2}');
      expect(exact('atan(1)', angle: AngleUnit.rad), r'\frac{\pi}{4}');
    });

    test('alias LaTeX', () {
      expect(exact(r'\sin^{-1}(0.5)'), contains('30'));
      expect(exact(r'\arcsin(0.5)'), contains('30'));
      expect(exact(r'\arccos(0)'), contains('90'));
      expect(exact(r'\cos^{-1}(0)', angle: AngleUnit.rad), r'\frac{\pi}{2}');
      expect(exact(r'\tan^{-1}(1)', angle: AngleUnit.rad), r'\frac{\pi}{4}');
    });

    test('dominio estricto [-1, 1]', () {
      for (final s in ['asin(2)', 'acos(-1.5)', r'\arcsin(2)']) {
        final m = domainError(() => ext(s));
        expectCapital(m);
        expect(m, contains('[-1, 1]'));
      }
      expect(exact('asin(1)', angle: AngleUnit.rad), r'\frac{\pi}{2}');
    });
  });

  group('3. Hiperbolicas', () {
    test('valores en 0', () {
      expect(exact('sinh(0)'), '0');
      expect(exact('cosh(0)'), '1');
      expect(exact('tanh(0)'), '0');
      expect(exact('asinh(0)'), '0');
      expect(exact('acosh(1)'), '0');
      expect(exact('atanh(0)'), '0');
    });

    test('cosh^2(2) - sinh^2(2) = 1 en DEG y en RAD', () {
      for (final unit in [AngleUnit.deg, AngleUnit.rad]) {
        final r = ext('cosh^2(2)-sinh^2(2)', angle: unit);
        expect(norm(r.exactResultLatex), '1');
        expect(double.parse(dec(r)), closeTo(1, 1e-9));
      }
      expect(ScalarCellEvaluator.toDouble('cosh(2)^2-sinh(2)^2'), closeTo(1, 1e-9));
    });

    test('sinh/cosh no dependen de la unidad angular', () {
      for (final f in ['sinh(1)', 'cosh(1)', 'tanh(1)']) {
        final d = ext(f).decimalApproxLatex;
        expect(ext(f, angle: AngleUnit.rad).decimalApproxLatex, d);
        expect(ext(f, angle: AngleUnit.grad).decimalApproxLatex, d);
      }
      expect(ScalarCellEvaluator.toDouble('sinh(1)'), closeTo(1.1752011936, 1e-9));
      expect(ScalarCellEvaluator.toDouble('tanh(1)'), closeTo(0.7615941559, 1e-9));
    });

    test('dominios de las inversas', () {
      expectCapital(domainError(() => ext('acosh(0.5)')));
      expectCapital(domainError(() => ext('atanh(1)')));
      expect(ScalarCellEvaluator.toDouble('asinh(1)'), closeTo(0.8813735870, 1e-9));
    });

    test('renderizado LaTeX en vivo', () {
      expect(ExpressionParser.rawToLiveLatex('sinh(2)'), contains(r'\sinh'));
      expect(ExpressionParser.rawToLiveLatex('acosh(2)'), contains(r'\cosh^{-1}'));
      expect(ExpressionParser.rawToLiveLatex('ℯ^(2)'), isNot(contains('ℯ')));
    });
  });

  group('4. Identidades fundamentales', () {
    test('sin^2 + cos^2 = 1 y cosh^2 - sinh^2 = 1', () {
      final r = ext('sin^2(30)+cos^2(30)');
      expect(norm(r.exactResultLatex), '1');
      expect(r.steps.first.shortTitle, 'Identidad fundamental');
      expect(exact('cos^2(7)+sin^2(7)'), '1');
      expect(exact('cosh^2(3)-sinh^2(3)'), '1');
      expect(exact('3+sin^2(20)+cos^2(20)'), '4');
    });

    test('ln(e^a) = a y e^(ln a) = a', () {
      expect(exact('ln(ℯ^(3))'), '3');
      expect(exact('ℯ^(ln(5))'), '5');
      expect(exact('ln(ℯ^(1/2))'), contains('frac'));
    });

    test('arctan(tan t) = t solo en rango principal', () {
      final r = ext('atan(tan(30))');
      expect(norm(r.exactResultLatex), contains('30'));
      expect(r.steps.first.shortTitle, 'Identidad fundamental');
      expect(dec(ext('atan(tan(100))')), startsWith('-80'));
      expect(exact('asin(sin(150))'), contains('30'));
      expect(exact('acos(cos(40))'), contains('40'));
    });
  });

  group('5. Evaluador compartido de celdas (M9, M10, M11)', () {
    test('expresiones de las 8 familias', () {
      expect(ScalarCellEvaluator.rational(r'\sqrt[3]{8}'), Rational(2));
      expect(ScalarCellEvaluator.rational(r'\cosh(0)'), Rational(1));
      expect(ScalarCellEvaluator.rational(r'\ln(e^3)'), Rational(3));
      expect(ScalarCellEvaluator.rational(r'\log_{2}(8)'), Rational(3));
      expect(ScalarCellEvaluator.rational('root(3,8)'), Rational(2));
      expect(ScalarCellEvaluator.rational('cosh(0)'), Rational(1));
      expect(ScalarCellEvaluator.rational('ln(ℯ^(3))'), Rational(3));
      expect(ScalarCellEvaluator.rational('log_(2,8)'), Rational(3));
      expect(ScalarCellEvaluator.rational(r'\arctan(1)'), Rational(45));
      expect(ScalarCellEvaluator.rational(r'\arctan(1)', angle: AngleUnit.rad), isNot(Rational(45)));
    });

    test('valores irracionales', () {
      expect(ScalarCellEvaluator.toDouble(r'\frac{\sqrt{2}}{2}'), closeTo(0.70710678, 1e-8));
      expect(ScalarCellEvaluator.toDouble(r'\pi/4'), closeTo(0.78539816, 1e-8));
      expect(ScalarCellEvaluator.toDouble(r'e^2'), closeTo(7.3890561, 1e-7));
      expect(ScalarCellEvaluator.eval('√(2)/2').toLatex(), r'\frac{\sqrt{2}}{2}');
      expect(ScalarCellEvaluator.isExactRational('π/4'), isFalse);
    });

    test('enteros, decimales y fracciones simples conservan el racional exacto', () {
      expect(ScalarCellEvaluator.rational('-3/4'), Rational(-3, 4));
      expect(ScalarCellEvaluator.rational('7'), Rational(7));
      expect(ScalarCellEvaluator.rational('0.25'), Rational(1, 4));
      expect(ScalarCellEvaluator.rational('.5'), Rational(1, 2));
      expect(ScalarCellEvaluator.rational('3.'), Rational(3));
      expect(ScalarCellEvaluator.isExactRational('-3/4'), isTrue);
      expect(ScalarCellEvaluator.tryEval('  '), isNull);
    });

    test('parentesis pendientes se cierran y los errores son validos', () {
      expect(ScalarCellEvaluator.rational('ln(ℯ^(3'), Rational(3));
      expect(() => ScalarCellEvaluator.eval('1/0'), throwsA(isA<ExMathError>()));
      expectCapital(domainError(() => ScalarCellEvaluator.eval('ln(0)')));
      expectCapital(domainError(() => ScalarCellEvaluator.eval('root(4,-16)')));
    });

    test('edicion lineal de celdas con expresion', () {
      expect(CellExpressionInput.isExpression('3/4'), isFalse);
      expect(CellExpressionInput.isExpression('sinh(0)'), isTrue);
      var c = CellExpressionInput.append('', 'root(');
      c = CellExpressionInput.append(c, '3');
      c = CellExpressionInput.dpadRight(c)!;
      expect(c, 'root(3,');
      c = CellExpressionInput.append(c, '8');
      c = CellExpressionInput.dpadRight(c)!;
      expect(c, 'root(3,8)');
      expect(CellExpressionInput.dpadRight(c), isNull);
      expect(ScalarCellEvaluator.rational(c), Rational(2));
      expect(CellExpressionInput.dpadLeft(c), 'root(3,8');
      expect(CellExpressionInput.backspace('2+sinh('), '2+');
      expect(CellExpressionInput.backspace('root(3,'), 'root(3');
      expect(CellExpressionInput.append('ln(1)', ')'), 'ln(1)');
    });

    test('DEL no fusiona los slots de root( y log_(', () {
      final (raw, cur) = ExpressionParser.deleteAtCursor('root(3,8)', 7);
      expect(raw, 'root(3,8)');
      expect(cur, 6);
      final (raw2, cur2) = ExpressionParser.deleteAtCursor('log_(2,8)', 7);
      expect(raw2, 'log_(2,8)');
      expect(cur2, 6);
    });
  });

  group('6. M11: e^z y Ln z', () {
    test('e^(0 + pi i) = -1 (identidad de Euler)', () {
      final r = ComplexSolver.exp(ExNum.integer(0), ExNum.pi());
      expect(norm(r.resolution.exactResultLatex), '-1');
      expect(double.parse(dec(r.resolution)), closeTo(-1, 1e-9));
      expect(r.resolution.steps.length, 3);
      expectLesson(r.resolution, minSteps: 3);
    });

    test('e^(1 + 0i) y e^(0 + (pi/2) i)', () {
      expect(norm(ComplexSolver.exp(ExNum.integer(1), ExNum.integer(0)).resolution.exactResultLatex), 'e');
      final i = ComplexSolver.exp(ExNum.integer(0), ScalarCellEvaluator.eval(r'\pi/2')).resolution;
      expect(norm(i.exactResultLatex), 'i');
    });

    test('e^z con a != 0 reparte e^a en parte real e imaginaria', () {
      final r = ComplexSolver.exp(ExNum.integer(1), ExNum.pi()).resolution;
      expect(norm(r.exactResultLatex), '-e');
    });

    test('Ln(1 + i) = ln(sqrt 2) + (pi/4) i', () {
      final r = ComplexSolver.ln(ExNum.integer(1), ExNum.integer(1)).resolution;
      final tex = norm(r.exactResultLatex);
      expect(tex, contains(r'\ln'));
      expect(tex, contains(r'\sqrt{2}'));
      expect(tex, contains(r'\frac{\pi}{4}i'));
      expect(dec(r), startsWith('0.34657'));
      expectLesson(r, minSteps: 3);
    });

    test('argumento principal en (-pi, pi]', () {
      String ln(int a, int b) =>
          norm(ComplexSolver.ln(ExNum.integer(a), ExNum.integer(b)).resolution.exactResultLatex);
      expect(ln(-1, 0), r'\pii');
      expect(ln(-1, 1), contains(r'\frac{3\pi}{4}'));
      expect(ln(-1, -1), contains(r'-\frac{3\pi}{4}i'));
      expect(ln(0, 2), contains(r'\frac{\pi}{2}'));
      expect(ln(0, -2), contains(r'-\frac{\pi}{2}i'));
      expect(ln(1, 0), '0');
    });

    test('Ln(0) da un error limpio', () {
      final m = domainError(() => ComplexSolver.ln(ExNum.integer(0), ExNum.integer(0)));
      expectCapital(m);
      expect(m, contains('Ln(0)'));
    });

    test('las operaciones nuevas estan en el selector de M11', () {
      expect(ComplexOperation.values, containsAll([ComplexOperation.expZ, ComplexOperation.lnZ]));
      expect(ComplexOperation.expZ.needsSecondComplex, isFalse);
      expect(ComplexOperation.lnZ.lastCellIndex, 1);
      final viaFacade = ComplexSolver.solve(
        operation: ComplexOperation.lnZ,
        z1: RationalComplex.fromInts(1, 1),
      );
      expect(viaFacade.steps.length, 3);
    });
  });

  group('7. Teclado fisico', () {
    List<String> type(String text) {
      final t = PhysicalKeyTranslator();
      final out = <String>[];
      for (final ch in text.split('')) {
        final acts = t.translate(logical: LogicalKeyboardKey.keyA, character: ch);
        if (acts != null) out.addAll(acts.map((a) => a.value));
      }
      return out;
    }

    test('funciones con tecla propia siguen igual', () {
      expect(type('sin('), ['sin']);
      expect(type('cos('), ['cos']);
      expect(type('ln('), ['ALPHA', 'LOG']);
      expect(type('log('), ['LOG']);
      expect(type('sqrt('), ['√']);
    });

    test('hiperbolicas, inversas y cbrt', () {
      expect(type('sinh('), ['tok:sinh(']);
      expect(type('cosh('), ['tok:cosh(']);
      expect(type('tanh('), ['tok:tanh(']);
      expect(type('arcsin('), ['tok:arcsin(']);
      expect(type('arccos('), ['tok:arccos(']);
      expect(type('arctan('), ['tok:arctan(']);
      expect(type('asin('), ['tok:arcsin(']);
      expect(type('acos('), ['tok:arccos(']);
      expect(type('atan('), ['tok:arctan(']);
      expect(type('cbrt('), ['ALPHA', '√']);
    });

    test('pi y e', () {
      expect(type('pi+'), ['PI', '+']);
      expect(type('2pi+1'), ['2', 'PI', '+', '1']);
      expect(type('e'), ['ALPHA', 'SCI10']);
    });
  });

  group('8. OPTN y teclado en pantalla', () {
    testWidgets('M1: la lista OPTN ofrece las secciones y inserta hiperbolicas e inversas', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'optn');
      for (final s in ['Hiperbólicas', 'Funciones']) {
        expect(find.textContaining(s), findsWidgets, reason: s);
      }
      await tapF(t, find.textContaining('Hiperbólicas'));
      await tapF(t, find.textContaining('cosh'));
      expect(live(t), contains(r'\cosh'));
      await seq(t, '0');
      await seq(t, 'optn');
      await pad(t, 'right');
      for (final s in ['Constantes', 'Trig. Inversas']) {
        expect(find.textContaining(s), findsWidgets, reason: s);
      }
      await tapF(t, find.textContaining('Trig. Inversas'));
      await tapF(t, find.textContaining('arcsin'));
      expect(live(t), contains(r'\sin^{-1}'));
    });

    for (final mode in [2, 6, 12]) {
      testWidgets('M$mode: OPTN rapido inserta cosh( y la constante e', (t) async {
        await boot(t, size: kDesktop);
        await seq(t, 'mode:$mode quickoptn');
        expect(find.byKey(const Key('optn_insert_cosh(')), findsOneWidget);
        expect(find.byKey(const Key('optn_insert_arcsin(')), findsOneWidget);
        expect(find.byKey(const Key('optn_insert_ℯ')), findsOneWidget);
        await seq(t, 'quick:cosh(');
        expect(shows(t, 'cosh'), isTrue);
      });
    }

    testWidgets('M5: OPTN rapido ofrece e y cosh(', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:5 quickoptn');
      expect(find.byKey(const Key('optn_insert_ℯ')), findsOneWidget);
      expect(find.byKey(const Key('optn_insert_cosh(')), findsOneWidget);
      await seq(t, 'quick:ℯ');
      await seq(t, 'quickoptn quick:cosh(');
      expect(shows(t, 'cosh'), isTrue);
    });

    testWidgets('M3: entrada libre acepta e y funciones desde OPTN', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:3 quickoptn');
      expect(find.byKey(const Key('optn_insert_ℯ')), findsOneWidget);
      expect(find.byKey(const Key('optn_insert_sinh(')), findsOneWidget);
      await seq(t, 'quick:sinh(');
      expect(shows(t, 'sinh'), isTrue);
    });

    testWidgets('M1: ALPHA + x10^x escribe e y se evalua como el numero e', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'A:×10ˣ');
      expect(live(t), contains('e'));
      await seq(t, '=');
      expect(norm(res(t).exactResultLatex), 'e');
    });

    testWidgets('M1: sinh y cosh^2 - sinh^2 desde OPTN dan 0 y 1', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'optn');
      await tapF(t, find.textContaining('Hiperbólicas'));
      await tapF(t, find.textContaining('sinh'));
      await seq(t, '0 =');
      expect(norm(res(t).exactResultLatex), '0');
    });
  });

  group('9. Celdas de M9, M10 y M11 con expresiones', () {
    testWidgets('M11 e^z: celdas con pi y el resultado -1', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_expZ');
      await seq(t, '0 =');
      await seq(t, 'S:pi');
      await seq(t, '=');
      expect(norm(res(t).exactResultLatex), '-1');
    });

    testWidgets('M11 Ln z con celdas 1 y 1', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_lnZ');
      await seq(t, '1 = 1 =');
      final tex = norm(res(t).exactResultLatex);
      expect(tex, contains(r'\ln'));
      expect(tex, contains(r'\frac{\pi}{4}i'));
    });

    testWidgets('M11 Ln 0 muestra el error', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_lnZ');
      await seq(t, '0 = 0 =');
      expect(find.byKey(const Key('lcd_error_screen')), findsOneWidget);
    });
  });

  test('ningun .dart de lib/ llega a 500 lineas', () {
    final over = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final n = f.readAsLinesSync().length;
      if (n >= 500) over.add('${f.path}: $n');
    }
    expect(over, isEmpty);
  });
}
