import 'package:casio_tutor_calc/core/editor/ghost_parentheses_helper.dart';
import 'package:casio_tutor_calc/core/editor/latex_render_sanitizer.dart';
import 'package:casio_tutor_calc/core/editor/lcd_cursor.dart';
import 'package:casio_tutor_calc/core/editor/lcd_cursor_tokens.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/presentation/widgets/safe_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';

final RegExp _leak = RegExp(r'extcolor|\\textcolor|\\left|\\right|\\mid|\\lcdcursor|[\t\f\x07]');

void _parses(String tex, {String? label}) {
  final s = LatexRenderSanitizer.sanitize(tex);
  try {
    final ast = SyntaxTree(greenRoot: TexParser(s, const TexParserSettings()).parse());
    ast.buildWidget(MathOptions(style: MathStyle.display, fontSize: 20));
  } catch (e) {
    fail('${label ?? tex} -> "$s" no parsea: $e');
  }
}

void main() {
  setUpAll(LcdCursorTex.ensureRegistered);

  group('LatexRenderSanitizer', () {
    final broken = <String, String>{
      'TAB + extcolor': '\textcolor{#929F9C}{)}',
      'FF + rac': '\frac{1}{2}',
      'CR + ight': '\\left(x+1\right)',
      'left sin right': r'\left(x+1',
      'right sin left': r'x+1\right)',
      'right al final de inecuacion': r'x + 1 > 0\right)',
      'left sin delimitador': r'\left',
      'right sin delimitador': r'\left( x \right',
      'llaves abiertas': r'\frac{1}{2',
      'llaves sobrantes': r'x}}+1',
      'left dentro de llave': r'\frac{\left(x}{2}',
      'right dentro de llave': r'\frac{x\right)}{2}',
      'textcolor sin args': r'\textcolor',
      'textcolor sin segundo grupo': r'\textcolor{#1A2530}',
      'barra final': r'x+1\',
      'porcentaje': r'50% + 1',
      'almohadilla': r'#x + 1',
      'begin sin end': r'\begin{array}{c} 1 \\ 2',
      'end sin begin': r'1 \end{array}',
      'tildes en text': r'\text{Solución ¿está?}',
      'salto de fila suelto': r'a \\ b',
      'vacio': '',
      'solo cursor': LcdCursor.bar,
    };
    for (final e in broken.entries) {
      test('parsea: ${e.key}', () => _parses(e.value, label: e.key));
    }

    test('restaura comandos comidos por escapes', () {
      expect(LatexRenderSanitizer.sanitize('\textcolor{#929F9C}{)}'),
          r'\textcolor{#929F9C}{)}');
      expect(LatexRenderSanitizer.sanitize('\frac{1}{2}'), r'\frac{1}{2}');
      expect(LatexRenderSanitizer.sanitize('a\times b'), r'a\times b');
    });

    test('balancea left/right con delimitador invisible', () {
      expect(LatexRenderSanitizer.sanitize(r'\left(x+1'), r'\left(x+1\right.');
      expect(LatexRenderSanitizer.sanitize(r'x\right)'), r'\left.x\right)');
      expect(LatexRenderSanitizer.sanitize(r'\left( \frac{1}{2} \right)').replaceAll(' ', ''),
          r'\left(\frac{1}{2}\right)');
    });

    test('sin tildes dentro de \\text y sin CR', () {
      final s = LatexRenderSanitizer.sanitize('\\text{Solución con ñ}\r + 5');
      expect(s, isNot(contains('ó')));
      expect(s, isNot(contains('ñ')));
      expect(s, isNot(contains('\r')));
    });
  });

  group('SafeMath nunca muestra LaTeX crudo', () {
    final inputs = <String>[
      '\textcolor{#929F9C}{)}',
      r'\left(\unknowncmd{x}',
      r'\frac{1}{',
      r'\sqrt[',
      r'x^{',
      r'\begin{array}{c}',
      r'\mid \left \right \textcolor',
    ];
    for (final tex in inputs) {
      testWidgets('render de "${tex.replaceAll('\t', '<TAB>')}"', (t) async {
        await t.pumpWidget(MaterialApp(home: Scaffold(body: SafeMath.tex(tex))));
        expect(t.takeException(), isNull);
        for (final w in t.widgetList<Text>(find.byType(Text))) {
          expect(w.data ?? '', isNot(matches(_leak)), reason: tex);
        }
        for (final w in t.widgetList<SelectableText>(find.byType(SelectableText))) {
          expect(w.data ?? '', isNot(matches(_leak)), reason: tex);
        }
      });
    }

    test('plain() no contiene comandos', () {
      for (final tex in ['\textcolor{#1}{)}', r'\left(x\right)', r'a \mid b', LcdCursor.bar]) {
        expect(SafeMath.plain(tex), isNot(matches(_leak)), reason: tex);
      }
    });
  });

  group('paréntesis, DEL y fantasma', () {
    test('ghostLatex genera LaTeX valido (sin TAB)', () {
      final g = GhostParenthesesHelper.ghostLatex('sin(30',
          ink: const Color(0xFF1A2530), background: const Color(0xFFC8D6CD));
      expect(g, startsWith(r'\textcolor{#'));
      expect(g, isNot(contains('\t')));
      _parses(g);
    });

    // (raw con cursor al final tras `)`, esperado tras DEL: no debe romper el render)
    final cases = <String>['ln(5)', 'sin(x)', '(x+1)', 'sin(ln(√(x))', '(1)/(2)', '√(x+1)'];
    for (final raw in cases) {
      test('DEL repetido sobre "$raw" produce LaTeX valido en cada paso', () {
        var r = raw;
        var pos = r.length;
        for (var i = 0; i < raw.length + 3; i++) {
          final latex = ExpressionParser.rawToLiveLatex(r, cursorPos: pos);
          _parses(latex, label: 'raw="$r" pos=$pos');
          final ghost = GhostParenthesesHelper.ghostLatex(r,
              ink: const Color(0xFF1A2530), background: const Color(0xFFC8D6CD));
          if (ghost.isNotEmpty) _parses('$latex$ghost', label: 'ghost "$r"');
          final res = ExpressionParser.deleteAtCursor(r, pos);
          r = res.$1;
          pos = res.$2;
        }
      });
    }

    test('con parentesis fantasma, sin ")" escrito solo hay UN cierre visible', () {
      final live = ExpressionParser.rawToLiveLatex('sin(7', cursorPos: 6, ghostClosers: true);
      expect(live, contains(r'\right.'));
      expect(live, isNot(contains(r'\right)')));
      final plain = ExpressionParser.rawToLiveLatex('sin(7');
      expect(plain, contains(r'\right)'), reason: 'sin ghostClosers se cierra visualmente (M2, M5...)');
      _parses(live);
    });

    test('el pi no genera doble barra invertida', () {
      final l = ExpressionParser.rawToLiveLatex('2π+π');
      expect(l, isNot(contains(r'\\pi')), reason: l);
      _parses(l);
    });

    test('inecuacion M6 con parentesis abierto no deja right huerfano', () {
      final l = ExpressionParser.rawToLiveLatex('(x+1', cursorPos: 4);
      final s = LatexRenderSanitizer.sanitize('$l > 0');
      final lefts = RegExp(r'\\left').allMatches(s).length;
      final rights = RegExp(r'\\right').allMatches(s).length;
      expect(lefts, rights, reason: s);
      _parses('$l > 0');
    });
  });
}
