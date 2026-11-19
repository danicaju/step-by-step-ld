import 'dart:io';

import 'package:casio_tutor_calc/core/formatting/step_note_formatter.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/ruffini_solver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/exercise_dsl.dart';

void main() {
  group('StepNoteFormatter.toPlain', () {
    String p(String s) => StepNoteFormatter.toPlain(s);

    test('exponentes: digitos a superindices, compuestos a ^(expr), nunca ^\$1', () {
      expect(p(r'x^{2}'), 'x²');
      expect(p(r'x^{3}+1'), 'x³+1');
      expect(p(r'x^{-1}'), 'x⁻¹');
      expect(p(r'2^{10}'), '2¹⁰');
      expect(p(r'2^{3+4}'), '2^(3+4)');
      expect(p(r'e^{-x+2}'), 'e^(-x+2)');
      expect(p(r'2^{2^{3}}'), '2^(2³)');
      expect(p(r'8^{\frac{1}{3}}'), '8^(1/3)');
      expect(p(r'x^{}'), 'x');
      expect(p(r'x_{10}'), 'x₁₀');
      for (final s in [r'x^{2}', r'x^{2x-1}', r'e^{-x+2}', r'z_{1}', r'r_{\alpha}']) {
        expect(p(s), isNot(contains(r'$')), reason: s);
        expect(p(s), isNot(contains('{')), reason: s);
      }
    });

    test('comandos y operadores', () {
      expect(p(r'a \cdot b \times c \div d'), 'a · b × c ÷ d');
      expect(p(r'\pm 1 \le 2 \ge 3 \neq 4 \infty \pi'), '± 1 ≤ 2 ≥ 3 ≠ 4 ∞ π');
      expect(p(r'\sqrt{x+1}'), '√(x+1)');
      expect(p(r'\sqrt[3]{8}'), '³√(8)');
      expect(p(r'\frac{a}{b}'), 'a/b');
      expect(p(r'\frac{x+1}{x-1}'), '(x+1)/(x-1)');
      expect(p(r'\left( x \right) \mid y'), '( x ) | y');
      expect(p(r'\text{si } x \mathrm{ok}'), 'si x ok');
      expect(p(r'\textcolor{#2563EB}{x}'), 'x');
      expect(p(r'\begin{array}{cc}1 & 2 \\ 3 & 4\end{array}'), '[1 2; 3 4]');
    });

    test('rescata comandos cuyo backslash se perdio en un literal Dart no crudo', () {
      // '\textcolor' -> TAB + 'extcolor'; '\times' -> TAB + 'imes'; '\frac' -> FF + 'rac'.
      expect(p('\textcolor{#000}{x}'), 'x');
      expect(p('2 \times 3'), '2 × 3');
      expect(p('\frac{1}{2}'), '1/2');
    });

    test('llaves desbalanceadas no rompen ni dejan restos', () {
      expect(p(r'x^{2'), 'x²');
      expect(p(r'\frac{1}{'), '1/');
      expect(p('}{'), '');
    });

    test('findLeak detecta grupos regex literales, valores corruptos y LaTeX crudo', () {
      for (final s in [r'x^$1', r'$2', r'a\1', 'null', 'NaN', 'Infinity', 'Instance of Foo']) {
        expect(StepNoteFormatter.findLeak(s, raw: true), isNotNull, reason: s);
      }
      for (final s in [r'\frac{1}{2}', r'\left(', r'\cdot', r'\sqrt{2}', 'extcolor', r'\mid', r'\text{a}', r'x^{2}', r'x_{1}']) {
        expect(StepNoteFormatter.findLeak(s), isNotNull, reason: s);
      }
      expect(StepNoteFormatter.findLeak('x² + 2x + 1 = (x+1)²'), isNull);
      expect(StepNoteFormatter.findLeak('nulo y nada'), isNull);
    });
  });

  test('ningun .dart de lib/ supera las 500 lineas', () {
    final over = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final n = f.readAsLinesSync().length;
      if (n >= 500) over.add('${f.path}: $n');
    }
    expect(over, isEmpty);
  });

  test('ningun replaceAll/replaceFirst de lib/ usa grupos de captura literales', () {
    final bad = <String>[];
    final re = RegExp(r'replace(All|First)\(.*(\$[1-9]|\\[1-9])');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (re.hasMatch(lines[i])) bad.add('${f.path}:${i + 1}');
      }
    }
    expect(bad, isEmpty, reason: 'usa replaceAllMapped en vez de \$1');
  });

  group('Regresion x^\$1 en notas de Ruffini (M4)', () {
    test('factor irreducible de grado >= 3 se imprime con superindices', () {
      final r = RuffiniSolver.factorize([1, 0, 0, 0, 1]); // x^4 + 1: sin raices racionales
      final text = [for (final s in r.steps) '${s.shortTitle}\n${s.pedagogicalNote}\n${s.warningTrick ?? ''}'].join('\n');
      expect(text, isNot(contains(r'$1')));
      expect(text, contains('x⁴'));
      expectCleanNotes(r);
    });

    test('x^3 + 2x^2 + 3x + 15 -> sin x^\$1 en ninguna nota', () {
      final r = RuffiniSolver.factorize([1, 2, 3, 15]);
      for (final s in r.steps) {
        expect(StepNoteFormatter.findLeak(s.pedagogicalNote, raw: true), isNull, reason: s.pedagogicalNote);
      }
      expectCleanNotes(r);
    });
  });
}
