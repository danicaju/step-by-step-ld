import 'package:casio_tutor_calc/core/editor/lcd_cursor_tokens.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/blinking_cursor_builder.dart';
import 'package:casio_tutor_calc/presentation/widgets/safe_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cursor de ancho cero: ni parpadear ni moverlo desplaza un solo pixel a los digitos.
const double _fs = 30;

Future<List<double>> _glyphXs(WidgetTester t, String tex) async {
  await t.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SafeMath.tex(tex, textStyle: const TextStyle(fontSize: _fs)),
    ),
  ));
  expect(t.takeException(), isNull, reason: tex);
  final xs = <double>[];
  void visit(RenderObject r) {
    if (r is RenderBox && r.hasSize && r.size.width > 3) {
      xs.add(double.parse(r.localToGlobal(Offset.zero).dx.toStringAsFixed(3)));
    }
    r.visitChildren(visit);
  }

  visit(t.renderObject(find.byType(Math)));
  return xs;
}

void main() {
  const digits = ['1', '2', '3', '4'];
  String withCursor(int pos, String c) =>
      digits.sublist(0, pos).join() + c + digits.sublist(pos).join();

  testWidgets('la barra mide 0 px: el ancho total no cambia en ninguna posicion', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: SafeMath.tex('1234')),
    ));
    final base = t.getSize(find.byType(Math)).width;
    for (var pos = 0; pos <= 4; pos++) {
      for (final c in [LcdCursor.bar, LcdCursor.barOff]) {
        await t.pumpWidget(MaterialApp(
          home: Align(alignment: Alignment.topLeft, child: SafeMath.tex(withCursor(pos, c))),
        ));
        expect(t.getSize(find.byType(Math)).width, closeTo(base, 0.001), reason: 'pos $pos');
      }
    }
  });

  testWidgets('dx de todos los digitos: parpadeo y movimiento varian exactamente 0.0 px',
      (t) async {
    final base = await _glyphXs(t, '1234');
    expect(base.length, greaterThanOrEqualTo(4));
    for (var pos = 0; pos <= 4; pos++) {
      final on = await _glyphXs(t, withCursor(pos, LcdCursor.bar));
      final off = await _glyphXs(t, withCursor(pos, LcdCursor.barOff));
      // El cursor (barra de 2.7 px) no cuenta: solo los digitos.
      expect(on, base, reason: 'cursor visible en pos $pos desplaza digitos');
      expect(off, base, reason: 'cursor oculto en pos $pos desplaza digitos');
    }
  });

  testWidgets('cursor dentro de fraccion, raiz y exponente: ancho identico al sin cursor',
      (t) async {
    const forms = [
      (r'\frac{12}{34}', r'\frac{1CUR2}{34}'),
      (r'\sqrt{12}', r'\sqrt{1CUR2}'),
      (r'x^{12}', r'x^{1CUR2}'),
      (r'12+34', r'12+CUR34'),
    ];
    for (final (plain, cur) in forms) {
      await t.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: SafeMath.tex(plain)),
      ));
      final w0 = t.getSize(find.byType(Math)).width;
      for (final c in [LcdCursor.bar, LcdCursor.barOff]) {
        await t.pumpWidget(MaterialApp(
          home: Align(
              alignment: Alignment.topLeft, child: SafeMath.tex(cur.replaceAll('CUR', c))),
        ));
        expect(t.takeException(), isNull);
        expect(t.getSize(find.byType(Math)).width, closeTo(w0, 0.001), reason: cur);
      }
    }
  });

  test('LcdBlink.apply: nunca emite \\mid y el cursor apagado conserva el comando', () {
    final on = LcdBlink.apply('1${LcdCursor.bar}2', on: true, dark: false);
    final off = LcdBlink.apply('1${LcdCursor.bar}2', on: false, dark: false);
    expect(on.contains(r'\mid'), isFalse);
    expect(off, r'1\phantom{\lcdcursor}2');
    expect(LcdBlink.apply('1${LcdCursor.bar}2', on: true, dark: true),
        r'1\textcolor{#C8D6CD}{\lcdcursor}2');
  });
}
