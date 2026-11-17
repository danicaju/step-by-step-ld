import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_inequality_2d_solver.dart';

void main() {
  group('LinearInequality2DSolver Tests', () {
    test('Escenario 1: Región no acotada con recta estricta { x + y > 0 ; x - 2y <= 5 }', () {
      final res = LinearInequality2DSolver.solveSystem2D([
        'x + y > 0',
        'x - 2y <= 5',
      ]);

      expect(res.visualData.isEmpty, isFalse);
      expect(res.visualData.isBounded, isFalse);
      expect(res.visualData.vertices, hasLength(1));

      final v = res.visualData.vertices.first;
      expect(v.x, closeTo(5.0 / 3.0, 1e-4));
      expect(v.y, closeTo(-5.0 / 3.0, 1e-4));
      expect(v.isOpen, isTrue);

      // Verificación de puntos interiores válidos
      final ineqs = res.visualData.inequalities;
      bool allSatisfied(double px, double py) =>
          ineqs.every((ineq) => ineq.evaluatesTrue(px, py));

      expect(allSatisfied(2, 0), isTrue, reason: '(2, 0) debe pertenecer a la región');
      expect(allSatisfied(5, 2), isTrue, reason: '(5, 2) debe pertenecer a la región');

      // Verificación de puntos excluidos
      expect(allSatisfied(-3, 0), isFalse, reason: '(-3, 0) no cumple x + y > 0');
      expect(allSatisfied(0, -4), isFalse, reason: '(0, -4) no cumple x - 2y <= 5');
    });

    test('Escenario 2: Región acotada (triángulo) { x >= -2 ; y <= -1 ; x - 2y <= 6 }', () {
      final res = LinearInequality2DSolver.solveSystem2D([
        'x >= -2',
        'y <= -1',
        'x - 2y <= 6',
      ]);

      expect(res.visualData.isEmpty, isFalse);
      expect(res.visualData.isBounded, isTrue);
      expect(res.visualData.vertices, hasLength(3));

      // Comprobar que los 3 vértices esperados están presentes: (-2, -1), (4, -1), (-2, -4)
      final expectedPoints = [
        (-2.0, -1.0),
        (4.0, -1.0),
        (-2.0, -4.0),
      ];

      for (final exp in expectedPoints) {
        final match = res.visualData.vertices.any(
          (v) => (v.x - exp.$1).abs() < 1e-4 && (v.y - exp.$2).abs() < 1e-4,
        );
        expect(match, isTrue, reason: 'El vértice $exp debe estar presente');
      }

      // Todos los bordes son no estrictos -> vértices cerrados
      expect(res.visualData.vertices.every((v) => !v.isOpen), isTrue);
    });

    test('Escenario 3: Entrada desordenada y signos invertidos { 2y - x >= -5 ; y > -x }', () {
      final res = LinearInequality2DSolver.solveSystem2D([
        '2y - x >= -5',
        'y > -x',
      ]);

      expect(res.visualData.isEmpty, isFalse);
      expect(res.visualData.isBounded, isFalse);
      expect(res.visualData.vertices, hasLength(1));

      final v = res.visualData.vertices.first;
      expect(v.x, closeTo(5.0 / 3.0, 1e-4));
      expect(v.y, closeTo(-5.0 / 3.0, 1e-4));
      expect(v.isOpen, isTrue);

      final ineqs = res.visualData.inequalities;
      bool allSatisfied(double px, double py) =>
          ineqs.every((ineq) => ineq.evaluatesTrue(px, py));

      expect(allSatisfied(2, 0), isTrue);
      expect(allSatisfied(5, 2), isTrue);
      expect(allSatisfied(-3, 0), isFalse);
      expect(allSatisfied(0, -4), isFalse);
    });

    test('Escenario 4: Sistema incompatible real { x + y > 5 ; x + y < 2 }', () {
      final res = LinearInequality2DSolver.solveSystem2D([
        'x + y > 5',
        'x + y < 2',
      ]);

      expect(res.visualData.isEmpty, isTrue);
      expect(res.visualData.vertices, isEmpty);
      expect(res.resolution.exactResultLatex, contains(r'\emptyset'));
    });

    test('Degenerada (segmento) no es vacia: { x + y <= 2 ; x + y >= 2 }', () {
      final res = LinearInequality2DSolver.solveSystem2D(['x + y <= 2', 'x + y >= 2']);
      expect(res.visualData.isEmpty, isFalse);
      expect(res.resolution.exactResultLatex, isNot(contains(r'\emptyset')));
    });

    test('Estrictas contradictorias si son vacias: { x + y < 2 ; x + y > 2 }', () {
      final res = LinearInequality2DSolver.solveSystem2D(['x + y < 2', 'x + y > 2']);
      expect(res.visualData.isEmpty, isTrue);
    });

    test('Siempre 3 pasos, sin tildes en text ni texto Pulsa pegado', () {
      final res = LinearInequality2DSolver.solveSystem2D(['x + y > 0', 'x - 2y <= 5']);
      expect(res.resolution.steps, hasLength(3));
      for (final s in res.resolution.steps) {
        expect(s.latexExpression, isNot(contains('Pulsa')));
        expect(RegExp(r'\text\{[^}]*[áéíóúñ¿¡]').hasMatch(s.latexExpression), isFalse);
      }
    });
  });
}
