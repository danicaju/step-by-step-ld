import 'dart:io';

import 'package:casio_tutor_calc/presentation/widgets/lcd/blinking_cursor_builder.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_input_box.dart';
import 'package:casio_tutor_calc/presentation/widgets/matrix/matrix_cell_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';

const Key _panel = Key('lcd_dropdown_panel');
const ValueKey<String> _on = ValueKey('lcd_cursor_on');
const ValueKey<String> _off = ValueKey('lcd_cursor_off');

LcdInputBox _box(WidgetTester t, String key) => t.widget<LcdInputBox>(find.byKey(Key(key)));

bool _hasPhantom(GreenNode? n) => n is PhantomNode || (n?.children.any(_hasPhantom) ?? false);

/// El cursor de la LCD principal esta oculto cuando algun `Math` lo sustituye por `\phantom{...}`.
bool _lcdCursorVisible(WidgetTester t) {
  final maths = find.byType(Math).evaluate().map((e) => e.widget as Math).toList();
  return !maths.any((m) => m.ast != null && _hasPhantom(m.ast!.greenRoot));
}

/// Activa el parpadeo real (la suite lo apaga) y lo restaura al terminar.
void _blinkTest(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    LcdBlink.enabled = true;
    addTearDown(() => LcdBlink.enabled = false);
    await boot(t, size: kDesktop);
    await body(t);
    // Desmontar cancela los Timer: el test no puede acabar con temporizadores colgando.
    await t.pumpWidget(const SizedBox());
  });
}

/// El cursor de la casilla activa alterna visible/oculto cada ~530 ms.
Future<void> _expectBlinks(WidgetTester t) async {
  expect(find.byKey(_on).evaluate().length + find.byKey(_off).evaluate().length, 1, reason: 'hay un cursor activo');
  final seen = <bool>{};
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 550));
    seen.add(find.byKey(_on).evaluate().isNotEmpty);
    expect(find.byKey(_on).evaluate().length + find.byKey(_off).evaluate().length, 1);
  }
  expect(seen, {true, false}, reason: 'el cursor debe alternar');
}

void main() {
  group('1. D-Pad no salta a los desplegables', () {
    testWidgets('M9: ▲ y ◀ en la primera celda se quedan en la matriz', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:9 ^ < ^ <');
      expect(find.byKey(_panel), findsNothing);
      expect(t.widget<MatrixCellBox>(find.byKey(const Key('matrix_A_cell_0_0'))).active, isTrue);
    });

    testWidgets('M9: ▲ sube de fila y no entra en Op/F/C', (t) async {
      await boot(t, size: kPhone);
      await seq(t, 'mode:9 pick:hdr_matrix_op:matrix_op_add v ^');
      expect(find.byKey(_panel), findsNothing);
      expect(t.widget<MatrixCellBox>(find.byKey(const Key('matrix_A_cell_0_0'))).active, isTrue);
    });

    testWidgets('M4 Ruffini: ▲ y ◀ no salen de la casilla', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:4 pick:hdr_poly_degree:ruffini_tab_3 ^ < ^');
      expect(find.byKey(_panel), findsNothing);
      expect(_box(t, 'coeff_cell_0').active, isTrue);
    });

    testWidgets('M4 Caja: ▲ y ◀ en P(x) no abren ni enfocan el desplegable', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_box ^ < ^');
      expect(find.byKey(_panel), findsNothing);
      expect(_box(t, 'xform_cell_0').active, isTrue);
    });

    testWidgets('M4 Fracciones: ▲ y ◀ no abren ningun desplegable', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_frac = ^ < ^ < ^');
      expect(find.byKey(_panel), findsNothing);
    });

    testWidgets('M11 y M12: ▲ no abre la cabecera', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:11 ^ < ^');
      expect(find.byKey(_panel), findsNothing);
      expect(_box(t, 'complex_cell_0').active, isTrue);
    });

    testWidgets('M12: ▲ y ◀ se quedan en f(x)', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:12 ^ < ^');
      expect(find.byKey(_panel), findsNothing);
      expect(_box(t, 'calculus_expr_box').active, isTrue);
    });
  });

  group('2. M9 con fracciones exactas', () {
    bothSizes('det [[1/2,0],[0,1/3]] = 1/6', (t) async {
      await seq(
        t,
        'mode:9 pick:hdr_matrix_op:matrix_op_determinant pick:hdr_matrix_rows:matrix_r_2 pick:hdr_matrix_cols:matrix_c_2 '
        'frac 1 > 2 > > > frac 1 > 3 =',
      );
      expect(norm(res(t).exactResultLatex), contains(r'\frac{1}{6}'));
    });

    bothSizes('inversa de [[1/2,0],[0,1/3]] = [[2,0],[0,3]]', (t) async {
      await seq(
        t,
        'mode:9 pick:hdr_matrix_op:matrix_op_inverse pick:hdr_matrix_rows:matrix_r_2 pick:hdr_matrix_cols:matrix_c_2 '
        'frac 1 > 2 > > > frac 1 > 3 =',
      );
      expect(norm(res(t).exactResultLatex), contains(r'2&0\\0&3'));
    });

    bothSizes('producto (1/2)·(1/3) = 1/6', (t) async {
      await seq(
        t,
        'mode:9 pick:hdr_matrix_op:matrix_op_multiply pick:hdr_matrix_rows:matrix_r_1 pick:hdr_matrix_cols:matrix_c_1 '
        'frac 1 > 2 tabB pick:hdr_matrix_rows:matrix_r_1 pick:hdr_matrix_cols:matrix_c_1 frac 1 > 3 =',
      );
      expect(norm(res(t).exactResultLatex), contains(r'\frac{1}{6}'));
    });

    bothSizes('suma (1/2)+(1/3) = 5/6', (t) async {
      await seq(
        t,
        'mode:9 pick:hdr_matrix_op:matrix_op_add pick:hdr_matrix_rows:matrix_r_1 pick:hdr_matrix_cols:matrix_c_1 '
        'frac 1 > 2 tabB pick:hdr_matrix_rows:matrix_r_1 pick:hdr_matrix_cols:matrix_c_1 frac 1 > 3 =',
      );
      expect(norm(res(t).exactResultLatex), contains(r'\frac{5}{6}'));
    });

    testWidgets('celdas grandes (>= 68 x 46) y navegacion ▲▼ dentro de la fraccion', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:9 frac 3 > 7');
      final size = t.getSize(find.byKey(const Key('matrix_A_cell_0_0')));
      expect(size.width, greaterThanOrEqualTo(68));
      expect(size.height, greaterThanOrEqualTo(46));
      // Denominador activo; ▲ lleva al numerador sin salir de la celda.
      await seq(t, '^ 5');
      final cell = t.widget<MatrixCellBox>(find.byKey(const Key('matrix_A_cell_0_0')));
      expect(cell.active, isTrue);
      expect(cell.value, '35/7');
      expect(cell.numeratorActive, isTrue);
      await seq(t, 'v 1');
      expect(t.widget<MatrixCellBox>(find.byKey(const Key('matrix_A_cell_0_0'))).value, '35/71');
    });
  });

  group('3-4. Navegacion interna en P(x) y Q(x)', () {
    testWidgets('Caja: ▼/▲ recorren la fraccion interna antes de cambiar de casilla', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_box frac x v 2');
      expect(_box(t, 'xform_cell_0').active, isTrue);
      expect(_box(t, 'xform_cell_0').latex, contains(r'\frac'));
      expect(_box(t, 'xform_cell_1').active, isFalse);
      // Sin movimiento interno disponible, ▼ pasa a Q(x); ▲ vuelve a P(x).
      await seq(t, 'v');
      expect(_box(t, 'xform_cell_1').active, isTrue);
      await seq(t, '^');
      expect(_box(t, 'xform_cell_0').active, isTrue);
      // ▲ dentro de P(x): el numerador de la fraccion interna, sin cambiar de casilla.
      await seq(t, '^ 3');
      expect(_box(t, 'xform_cell_0').active, isTrue);
      expect(_box(t, 'xform_cell_0').latex, contains(r'\frac'));
    });

    testWidgets('Caja: ◀ ▶ navegan por la expresion y solo cambian de casilla en los extremos', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_box 1 2 <');
      expect(_box(t, 'xform_cell_0').active, isTrue);
      await seq(t, '< <');
      expect(_box(t, 'xform_cell_0').active, isTrue, reason: '◀ en el borde izquierdo no sale hacia la cabecera');
      await seq(t, '> > >');
      expect(_box(t, 'xform_cell_1').active, isTrue);
    });

    testWidgets('Fracciones algebraicas: ▲▼ dentro de una fraccion en P(x)', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_frac = frac x v 2');
      expect(_box(t, 'xform_cell_0').active, isTrue);
      expect(_box(t, 'xform_cell_0').latex, contains(r'\frac'));
      await seq(t, '^');
      expect(_box(t, 'xform_cell_0').active, isTrue, reason: 'sube al numerador interno, no a otra casilla');
      await seq(t, 'v v');
      expect(_box(t, 'xform_cell_1').active, isTrue, reason: 'sin movimiento interno se pasa a Q(x)');
    });

    testWidgets('selector compacto de 36 px en Fracciones algebraicas', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_frac');
      final sel = find.byKey(const Key('xform_selector_dropdown'));
      expect(sel, findsOneWidget);
      expect(t.getSize(sel).height, 36);
      expect(t.getSize(find.byKey(const Key('xform_cell_0'))).width, greaterThanOrEqualTo(190));
    });
  });

  group('5. Cursor parpadeante real', () {
    _blinkTest('M4 Ruffini: P(x) y casilla de raiz', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_degree:ruffini_tab_3');
      await _expectBlinks(t);
      await seq(t, '2 > > > >');
      expect(_box(t, 'coeff_cell_4').active, isTrue);
      await _expectBlinks(t);
    });

    _blinkTest('M4 Division en caja', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_box');
      await _expectBlinks(t);
      await seq(t, '> ');
      expect(_box(t, 'xform_cell_1').active, isTrue);
      await _expectBlinks(t);
    });

    _blinkTest('M4 Fracciones algebraicas', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_frac =');
      await _expectBlinks(t);
    });

    _blinkTest('M4 Notables (LCD principal)', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_notables');
      final seen = <bool>{};
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 550));
        seen.add(_lcdCursorVisible(t));
      }
      expect(seen, {true, false}, reason: 'el cursor de las notables debe alternar');
    });

    _blinkTest('M12 Derivada y Recta tangente', (t) async {
      await seq(t, 'mode:12');
      expect(_box(t, 'calculus_expr_box').active, isTrue);
      await _expectBlinks(t);
      await seq(t, 'pick:hdr_calculus_op:calculus_op_tangentLine x v');
      expect(_box(t, 'calculus_x0_box').active, isTrue);
      await _expectBlinks(t);
    });

    _blinkTest('M12 Integral indefinida', (t) async {
      await seq(t, 'mode:12 pick:hdr_calculus_op:calculus_op_indefiniteIntegral');
      await _expectBlinks(t);
      await seq(t, 'x');
      await _expectBlinks(t);
    });

    _blinkTest('M12 Integral definida: a, b y f(x)', (t) async {
      await seq(t, 'mode:12 pick:hdr_calculus_op:calculus_op_definiteIntegral');
      await _expectBlinks(t);
      await seq(t, 'v');
      expect(_box(t, 'calculus_a_box').active, isTrue);
      await _expectBlinks(t);
      await seq(t, '>');
      expect(_box(t, 'calculus_b_box').active, isTrue);
      await _expectBlinks(t);
    });

    _blinkTest('una tecla reinicia el ciclo a visible', (t) async {
      await seq(t, 'mode:12');
      await t.pump(const Duration(milliseconds: 540));
      expect(find.byKey(_off), findsOneWidget);
      await key(t, '5');
      expect(find.byKey(_on), findsOneWidget);
    });
  });

  group('6. M11: boton Editar', () {
    testWidgets('oculto antes de = y visible tras calcular', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_toPolar - 1');
      expect(find.byKey(const Key('complex_edit_btn')), findsNothing);
      await seq(t, '= sqrt 3 =');
      expect(find.byKey(const Key('complex_edit_btn')), findsOneWidget);
      await tapF(t, find.byKey(const Key('complex_edit_btn')));
      expect(find.byKey(const Key('complex_edit_btn')), findsNothing);
    });
  });

  group('7. Limite de lineas', () {
    test('ningun .dart de lib/ supera las 500 lineas', () {
      final tooLong = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final n = f.readAsLinesSync().length;
        if (n >= 500) tooLong.add('${f.path}: $n');
      }
      expect(tooLong, isEmpty);
    });
  });
}
