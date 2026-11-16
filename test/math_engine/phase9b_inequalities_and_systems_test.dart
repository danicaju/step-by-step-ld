import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/inequality_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_inequality_2d_solver.dart';

void main() {
  group('Actualización 9B: Inecuaciones Desordenadas, Valor Absoluto y Recta Real', () {
    test('1. Inecuación lineal con términos desordenados y agrupación', () {
      final res = InequalitySolver.solveString('3x - 5 + 2x > 7 - x');
      expect(res.steps.isNotEmpty, isTrue);
      // 5x - 5 > 7 - x => 6x > 12 => x > 2 => (2, +\infty)
      expect(res.exactResultLatex, contains('x > 2'));
      expect(res.exactResultLatex, contains('(2, +\\infty)'));

      final visual = InequalitySolver.getVisualData(res);
      expect(visual, isNotNull);
      expect(visual!.criticalPoints.length, equals(1));
      expect(visual.criticalPoints.first.value, closeTo(2.0, 1e-4));
      expect(visual.criticalPoints.first.isClosed, isFalse); // > es estricto
      expect(visual.primaryIntervals.first.start, closeTo(2.0, 1e-4));
      expect(visual.primaryIntervals.first.end, equals(double.infinity));
    });

    test('2. Inecuación con paréntesis y multiplicación distributiva desordenada', () {
      // 2(x - 1) + 4 <= 5x - 3 => 2x - 2 + 4 <= 5x - 3 => 2x + 2 <= 5x - 3 => -3x <= -5 => x >= 5/3
      final res = InequalitySolver.solveString(r'2(x - 1) + 4 \le 5x - 3');
      expect(res.exactResultLatex, contains(r'\ge'));
      expect(res.exactResultLatex, contains(r'\frac{5}{3}'));

      final visual = InequalitySolver.getVisualData(res);
      expect(visual, isNotNull);
      expect(visual!.criticalPoints.first.isClosed, isTrue); // \le es cerrado
    });

    test('3. Inecuación con valor absoluto acotado |x - 5| < 3', () {
      // |x - 5| < 3 <=> -3 < x - 5 < 3 <=> 2 < x < 8 => (2, 8)
      final res = InequalitySolver.solveString('|x - 5| < 3');
      expect(res.exactResultLatex, contains('(2, 8)'));

      final visual = InequalitySolver.getVisualData(res);
      expect(visual, isNotNull);
      expect(visual!.criticalPoints.length, equals(2));
      expect(visual.criticalPoints[0].value, closeTo(2.0, 1e-4));
      expect(visual.criticalPoints[1].value, closeTo(8.0, 1e-4));
      expect(visual.criticalPoints[0].isClosed, isFalse);
      expect(visual.criticalPoints[1].isClosed, isFalse);
      expect(visual.primaryIntervals.first.isBounded, isTrue);
    });

    test('4. Inecuación con valor absoluto disjunto |2x - 8| >= 4', () {
      // |2x - 8| >= 4 <=> 2x - 8 <= -4 o 2x - 8 >= 4
      // 2x <= 4 => x <= 2  o  2x >= 12 => x >= 6
      // S: (-\infty, 2] U [6, +\infty)
      final res = InequalitySolver.solveString(r'|2x - 8| \ge 4');
      expect(res.exactResultLatex, contains(r'(-\infty, 2]'));
      expect(res.exactResultLatex, contains(r'[6, +\infty)'));

      final visual = InequalitySolver.getVisualData(res);
      expect(visual, isNotNull);
      expect(visual!.criticalPoints.length, equals(2));
      expect(visual.criticalPoints[0].value, closeTo(2.0, 1e-4));
      expect(visual.criticalPoints[1].value, closeTo(6.0, 1e-4));
      expect(visual.criticalPoints[0].isClosed, isTrue);
      expect(visual.criticalPoints[1].isClosed, isTrue);
      expect(visual.primaryIntervals.length, equals(2));
    });

    test('5. Inecuación de 2.º grado con carteles SÍ / NO en la recta real', () {
      // x^2 - 4x + 3 <= 0 => raíces 1 y 3 => P(x) <= 0 en [1, 3]
      final res = InequalitySolver.solveQuadratic(
        a: 1,
        b: -4,
        c: 3,
        sign: InequalitySign.lessOrEqual,
      );
      expect(res.exactResultLatex, equals('[1, 3]'));

      final visual = InequalitySolver.getVisualData(res);
      expect(visual, isNotNull);
      expect(visual!.signTestIntervals, isNotNull);
      expect(visual.signTestIntervals!.length, equals(3));
      // Intervalo 1: (-inf, 1) -> NO cumple
      expect(visual.signTestIntervals![0].isSatisfied, isFalse);
      // Intervalo 2: (1, 3) -> SÍ cumple
      expect(visual.signTestIntervals![1].isSatisfied, isTrue);
      // Intervalo 3: (3, +inf) -> NO cumple
      expect(visual.signTestIntervals![2].isSatisfied, isFalse);
    });

    test('6. Sistema de inecuaciones 1D con rayados cruzados (/// y \\\\\\ -> XXX)', () {
      // Inecuación 1: 2x - 4 <= 6 => 2x <= 10 => x <= 5  => (-inf, 5]
      // Inecuación 2: -3x + 9 < 3 => -3x < -6 => x > 2   => (2, +inf)
      // Intersección: (2, 5]
      final outcome = InequalitySolver.solveSystem1D([
        r'2x - 4 \le 6',
        '-3x + 9 < 3',
      ]);

      expect(outcome.resolution.exactResultLatex, contains(r'(2, 5]'));
      final visual = outcome.visualData;
      expect(visual.isSystem, isTrue);
      expect(visual.primaryIntervals.isNotEmpty, isTrue);
      expect(visual.secondaryIntervals!.isNotEmpty, isTrue);
      expect(visual.intersectionIntervals!.isNotEmpty, isTrue);
      expect(visual.intersectionIntervals!.first.start, closeTo(2.0, 1e-4));
      expect(visual.intersectionIntervals!.first.end, closeTo(5.0, 1e-4));
      expect(visual.intersectionIntervals!.first.includeStart, isFalse);
      expect(visual.intersectionIntervals!.first.includeEnd, isTrue);
    });

    test('7. Sistema de inecuaciones lineales 2D (Región Factible en el Plano)', () {
      // x + y <= 4,  2x - y >= 1,  x >= 0,  y >= 0
      final outcome = LinearInequality2DSolver.solveSystem2D([
        r'x + y \le 4',
        r'2x - y \ge 1',
        r'x \ge 0',
        r'y \ge 0',
      ]);

      expect(outcome.resolution.steps.length, greaterThanOrEqualTo(3));
      expect(outcome.visualData.isBounded, isTrue);
      expect(outcome.visualData.isEmpty, isFalse);
      expect(outcome.visualData.vertices.length, greaterThanOrEqualTo(3));

      // Comprobar punto de intersección de x + y = 4 y 2x - y = 1 => 3x = 5 => x = 5/3, y = 7/3
      final hasIntersect = outcome.visualData.vertices.any(
        (v) => (v.x - 5.0 / 3.0).abs() < 1e-3 && (v.y - 7.0 / 3.0).abs() < 1e-3,
      );
      expect(hasIntersect, isTrue);

      // Comprobar estilos de frontera continuas
      for (final ineq in outcome.visualData.inequalities) {
        expect(ineq.isBoundarySolid, isTrue);
      }
    });

    test('8. Blindaje de LaTeX: CERO tildes o eñes dentro de \\text{...}', () {
      final testCases = [
        '3x - 5 + 2x > 7 - x',
        r'2(x - 1) + 4 \le 5x - 3',
        '|x - 5| < 3',
        r'|2x - 8| \ge 4',
        'x^2 - 4x + 3 <= 0',
      ];

      for (final tc in testCases) {
        final res = InequalitySolver.solveString(tc);
        for (final step in res.steps) {
          final matches = RegExp(r'\\text\{([^}]+)\}').allMatches(step.latexExpression);
          for (final m in matches) {
            final textContent = m.group(1)!;
            expect(
              RegExp(r'[áéíóúÁÉÍÓÚñÑ]').hasMatch(textContent),
              isFalse,
              reason: 'Tilde encontrada en \\text{$textContent} de paso "${step.shortTitle}"',
            );
          }
        }
      }
    });

    test('9. Inecuación de 2.º grado desordenada desde string y sin tabla de signos antigua', () {
      // 2x^2 + 5x > 4 => 2x^2 + 5x - 4 > 0
      final res = InequalitySolver.solveString('2x^2 + 5x > 4');
      expect(res.steps.isNotEmpty, isTrue);
      // Comprobar que el paso 1 transpone e iguala a 0
      expect(res.steps.first.shortTitle, contains('igualar a cero'));
      expect(res.steps.first.latexExpression, contains('2x^{2} + 5x - 4 > 0'));

      // Verificar que NO hay tabla antigua \begin{array}
      for (final step in res.steps) {
        expect(step.latexExpression.contains(r'\begin{array}'), isFalse,
            reason: 'Se detectó tabla antigua array en lugar de la recta visual');
      }

      // Comprobar que genera visualización con carteles SÍ / NO
      final visual = InequalitySolver.getVisualData(res);
      expect(visual, isNotNull);
      expect(visual!.signTestIntervals, isNotNull);
      expect(visual.signTestIntervals!.length, equals(3));
    });

    test('10. Sistema de 3 inecuaciones 1D con intersección visual', () {
      final outcome = InequalitySolver.solveSystem1D([
        'x > 1',
        r'x \le 6',
        '2x + 1 >= 5', // 2x >= 4 => x >= 2
      ]);

      expect(outcome.resolution.exactResultLatex, contains('[2, 6]'));
      final visual = outcome.visualData;
      expect(visual.isSystem, isTrue);
      expect(visual.primaryIntervals.isNotEmpty, isTrue);
      expect(visual.secondaryIntervals?.isNotEmpty, isTrue);
      expect(visual.intersectionIntervals?.isNotEmpty, isTrue);
      expect(visual.intersectionIntervals!.first.start, closeTo(2.0, 1e-4));
      expect(visual.intersectionIntervals!.first.end, closeTo(6.0, 1e-4));
    });
  });
}
