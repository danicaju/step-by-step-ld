import 'package:casio_tutor_calc/domain/math_engine/solvers/ruffini_solver.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _trim(List<int> c) {
  final l = List<int>.from(c);
  while (l.isNotEmpty && l.first == 0) {
    l.removeAt(0);
  }
  return l;
}

/// Sin tildes/enes dentro de \text{} o \mathrm{}, llaves balanceadas y sin \r suelto.
void _clean(RuffiniOutcome o) {
  final all = '${o.resolution.originalInputLatex}${o.resolution.steps.map((s) => s.latexExpression).join()}'
      '${o.resolution.exactResultLatex}${o.resolution.decimalApproxLatex}';
  expect(RegExp(r'\\(text|mathrm)\{[^}]*[áéíóúñ¿¡][^}]*\}').hasMatch(all), isFalse, reason: all);
  expect(RegExp(r'\\r(?![a-zA-Z])').hasMatch(all), isFalse, reason: all);
  var d = 0;
  for (final c in all.replaceAll(r'\{', '').replaceAll(r'\}', '').split('')) {
    if (c == '{') d++;
    if (c == '}') d--;
    expect(d >= 0, isTrue, reason: all);
  }
  expect(d, 0, reason: all);
}

RuffiniOutcome _run(List<int> c) {
  final o = RuffiniSolver.factorizeFull(c);
  expect(o.factorization.expand(), _trim(c), reason: 'el producto desarrollado debe coincidir con $c');
  _clean(o);
  return o;
}

void main() {
  group('Coeficiente principal: nunca se duplica fuera y dentro de los factores', () {
    test('2x - 4 = 2(x - 2)', () {
      final o = _run([2, -4]);
      expect(o.resolution.exactResultLatex, '2(x - 2)');
    });

    test('2x^4 - 3x^3 + x^2 = x^2 (x - 1)(2x - 1)', () {
      final o = _run([2, -3, 1, 0, 0]);
      expect(o.resolution.exactResultLatex, r'x^{2}(x - 1)(2x - 1)');
      expect(o.resolution.exactResultLatex, isNot(contains('2x^{2}(2x')));
    });

    test('coeficiente negativo: -x^2 + 1 = -(x - 1)(x + 1)', () {
      final o = _run([-1, 0, 1]);
      expect(o.resolution.exactResultLatex, '-(x - 1)(x + 1)');
    });

    test('factor numerico y x comunes: 2x^3 - 8x = 2x(x - 2)(x + 2)', () {
      final o = _run([2, 0, -8, 0]);
      expect(o.resolution.exactResultLatex, '2x(x - 2)(x + 2)');
      expect(o.resolution.steps.first.shortTitle, contains('Sacar factor común 2x'));
    });

    test('los casos de siempre no cambian', () {
      expect(_run([1, 0, -7, 6]).resolution.exactResultLatex, '(x - 1)(x - 2)(x + 3)');
      expect(_run([1, 2, -5, -6]).resolution.exactResultLatex, '(x + 1)(x - 2)(x + 3)');
      expect(_run([1, 0, -4, 0]).resolution.exactResultLatex, 'x(x - 2)(x + 2)');
    });
  });

  group('Candidatos racionales ±p/q', () {
    test('con a_n != ±1 el paso de candidatos lista fracciones', () {
      final o = _run([2, -1, 2, -1]);
      final step = o.resolution.steps.firstWhere((s) => s.shortTitle.contains('racional'));
      expect(step.latexExpression, contains(r'\frac{1}{2}'));
      expect(step.latexExpression, contains(r'\text{divisores de } 2'));
      expect(step.pedagogicalNote, contains('±p/q'));
    });

    test('raiz racional 1/2 con tabla de Ruffini fraccionaria y factor primitivo (2x - 1)', () {
      final o = _run([2, -1, 2, -1]);
      expect(o.resolution.exactResultLatex, r'(2x - 1)(x^{2} + 1)');
      final table = o.resolution.steps.firstWhere((s) => s.shortTitle.contains('Tabla de Ruffini'));
      expect(table.shortTitle, contains('1/2'));
      expect(table.latexExpression, contains(r'\frac{1}{2}'));
      expect(table.latexExpression, contains(r'\boxed{0}'));
      expect(table.warningTrick, contains('(2x - 1)'));
    });

    test('dos raices racionales en grado 4', () {
      final o = _run([6, 1, 4, 1, -2]); // (2x - 1)(3x + 2)(x^2 + 1)
      final r = o.resolution.exactResultLatex;
      expect(r, contains('(2x - 1)'));
      expect(r, contains('(3x + 2)'));
      expect(r, contains(r'(x^{2} + 1)'));
    });

    test('monico: se mantiene el paso de divisores enteros', () {
      final o = _run([1, 0, -7, 6]);
      expect(o.resolution.steps.first.shortTitle, contains('a₀'));
      expect(o.resolution.steps.first.latexExpression, contains(r'\text{Divisores de } 6'));
    });
  });

  group('Remate en grado 2', () {
    test('x^2 - 2 => x = ±√2 con factorizacion exacta', () {
      final o = _run([1, 0, -2]);
      expect(o.resolution.exactResultLatex, r'\left(x - \sqrt{2}\right)\left(x + \sqrt{2}\right)');
      expect(o.resolution.decimalApproxLatex, r'x = \pm \sqrt{2}');
      expect(o.resolution.steps.any((s) => s.latexExpression.contains(r'\Delta = 8')), isTrue);
    });

    test('x^2 - 2x - 1 => x = 1 ± √2', () {
      final o = _run([1, -2, -1]);
      expect(o.resolution.exactResultLatex, r'\left(x - 1 - \sqrt{2}\right)\left(x - 1 + \sqrt{2}\right)');
      expect(o.resolution.steps.any((s) => s.latexExpression.contains(r'1 \pm \sqrt{2}')), isTrue);
    });

    test('2x^2 - 2x - 1 => a delante y raices (1 ± √3)/2', () {
      final o = _run([2, -2, -1]);
      expect(o.resolution.exactResultLatex,
          r'2\left(x - \frac{1 + \sqrt{3}}{2}\right)\left(x - \frac{1 - \sqrt{3}}{2}\right)');
    });

    test('raices racionales, doble y producto primitivo', () {
      expect(_run([6, -5, 1]).resolution.exactResultLatex, '(2x - 1)(3x - 1)');
      expect(_run([1, -4, 4]).resolution.exactResultLatex, '(x - 2)^{2}');
    });

    test('Δ < 0: x^2 + x + 1 queda sin descomponer, con nota y raices complejas', () {
      final o = _run([1, 1, 1]);
      expect(o.resolution.exactResultLatex, r'(x^{2} + x + 1)');
      final step = o.resolution.steps.firstWhere((s) => s.shortTitle.contains('irreducible'));
      expect(step.shortTitle, contains('ℝ'));
      expect(step.pedagogicalNote, contains('irreducible en ℝ'));
      expect(step.pedagogicalNote, contains('Δ = -3 < 0'));
      expect(step.pedagogicalNote, contains('complejas conjugadas'));
      expect(step.latexExpression, contains(r'\frac{-1 \pm i\sqrt{3}}{2}'));
      expect(step.latexExpression, contains(r'\Delta = -3 < 0'));
      expect(o.resolution.decimalApproxLatex, r'\text{Sin raices reales}');
    });

    test('Δ < 0 con raiz racional previa: (x - 2)(x^2 + x + 1)', () {
      final o = _run([1, -1, -1, -2]);
      expect(o.resolution.exactResultLatex, r'(x - 2)(x^{2} + x + 1)');
      expect(o.resolution.decimalApproxLatex, 'x = 2');
    });

    test('x^2 + 1: raices ±i', () {
      final o = _run([1, 0, 1]);
      expect(o.resolution.steps.last.pedagogicalNote, anyOf(contains('no se descompone más en ℝ'), contains('irreducible')));
    });
  });

  group('Sin mas raices racionales', () {
    test('x^3 - 2 se deja sin descomponer con aviso de raices irracionales', () {
      final o = _run([1, 0, 0, -2]);
      expect(o.resolution.exactResultLatex, r'(x^{3} - 2)');
      expect(o.resolution.decimalApproxLatex, r'\text{Sin raices racionales}');
      expect(o.resolution.steps.last.pedagogicalNote, contains('irracionales'));
    });
  });

  group('Barrido: el producto desarrollado siempre coincide con P(x)', () {
    test('todos los polinomios de grado 1 a 4 con coeficientes en -3..3', () {
      const vals = [-3, -2, -1, 0, 1, 2, 3];
      void rec(List<int> acc, int left) {
        if (left == 0) {
          if (acc.first == 0) return;
          final o = RuffiniSolver.factorizeFull(acc);
          expect(o.factorization.expand(), _trim(acc), reason: '$acc -> ${o.resolution.exactResultLatex}');
          return;
        }
        for (final v in vals) {
          rec([...acc, v], left - 1);
        }
      }

      for (var deg = 1; deg <= 4; deg++) {
        rec([], deg + 1);
      }
    });

    test('grados 5 y 6 representativos', () {
      for (final c in <List<int>>[
        [2, -3, -3, 2, 0, 0],
        [6, -5, 1, 0, 0, 0],
        [1, 0, 0, 0, 0, -1],
        [2, 0, 0, 0, 0, 0, -2],
        [1, 1, 1, 1, 1, 1, 1],
        [4, 0, -5, 0, 1],
        [3, -2, 3, -2],
      ]) {
        _run(c);
      }
    });
  });
}
