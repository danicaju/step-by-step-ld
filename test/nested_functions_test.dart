import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';

String live(String raw) => ExpressionParser.rawToLiveLatex(raw);

(String, int) right(String raw, int pos) {
  final r = ExpressionParser.handleFractionRightArrow(raw, pos) ??
      ExpressionParser.handlePowerRightArrow(raw, pos) ??
      ExpressionParser.handleMcmMcdRightArrow(raw, pos) ??
      ExpressionParser.handleTwoSlotRightArrow(raw, pos) ??
      ExpressionParser.handleStructuredBlockRightArrow(raw, pos);
  return r ?? (raw, ExpressionParser.stepCursorRight(raw, pos));
}

void main() {
  powerTests();
  group('Anidamiento trigonometrico abierto (sin saltos de linea)', () {
    test('sin(cos(tan( sin cerrar', () {
      final l = live('sin(cos(tan(5');
      expect(l, isNot(contains(r'\\')));
      expect(l, contains(r'\sin'));
      expect(l, contains(r'\cos'));
      expect(l, contains(r'\tan'));
      expect(RegExp(r'\\left\(').allMatches(l).length,
          RegExp(r'\\right[.)]').allMatches(l).length);
    });

    test('sin(log_(2,cos(30 sin cerrar', () {
      final l = live('sin(log_(2,cos(30');
      expect(l, isNot(contains(r'\\')));
      expect(l, isNot(contains(r'\right\right')));
      expect(RegExp(r'\\left\(').allMatches(l).length,
          RegExp(r'\\right[.)]').allMatches(l).length);
    });

    test('sin(log_(2,5)) cerrado', () {
      expect(live('sin(log_(2,5))'),
          contains(r'\sin\left(\log_{2}\left(5\right)\right)'));
    });

    test('inversas y ln anidadas abiertas', () {
      final l = live('arcsin(ln(arctan(1');
      expect(l, isNot(contains(r'\\')));
      expect(l, contains(r'\ln'));
    });
  });

  group('D-Pad: salir de log_ dentro de sin', () {
    test('▶ sale del log y luego del seno', () {
      const raw = 'sin(log_(2,5))';
      var pos = 'sin(log_(2,5'.length;
      (String, int) r = right(raw, pos);
      expect(r.$1, raw);
      expect(r.$2, 'sin(log_(2,5)'.length);
      r = right(r.$1, r.$2);
      expect(r.$1, raw);
      expect(r.$2, raw.length);
    });

    test('▶ con parentesis sin cerrar: sale del log y luego del seno', () {
      var r = right('sin(log_(2,5', 'sin(log_(2,5'.length);
      expect(r.$1, 'sin(log_(2,5)');
      r = right(r.$1, r.$2);
      expect(r.$2, r.$1.length);
      expect(r.$1, 'sin(log_(2,5))');
    });

    test('▶ en log dentro de potencia abierta no la cierra', () {
      final r = right('sin(2^(log_(3', 'sin(2^(log_(3'.length);
      expect(r.$1, 'sin(2^(log_(3,');
    });

    test('◀ recorre los mismos niveles hacia atras', () {
      const raw = 'sin(log_(2,5))';
      var pos = raw.length;
      pos = ExpressionParser.stepCursorLeft(raw, pos);
      expect(pos, 'sin(log_(2,5)'.length);
      pos = ExpressionParser.stepCursorLeft(raw, pos);
      expect(pos, 'sin(log_(2,5'.length);
    });
  });
}

void powerTests() {
  group('Potencia sin base', () {
    for (final t in ['^2', '^3', '^(']) {
      test('0 inicial + $t conserva 0 como base', () {
        final (raw, pos) = ExpressionParser.insertAtCursor('0', 1, t);
        expect(raw, '0$t');
        expect(pos, raw.length);
      });
      test('editor vacio + $t', () {
        final (raw, _) = ExpressionParser.insertAtCursor('', 0, t);
        expect(raw, '0$t');
      });
      test('tras operador + $t', () {
        final (raw, _) = ExpressionParser.insertAtCursor('2+', 2, t);
        expect(raw, '2+0$t');
      });
    }
    test('tras un operando no anade base', () {
      final (raw, _) = ExpressionParser.insertAtCursor('5', 1, '^2');
      expect(raw, '5^2');
    });
  });
}
