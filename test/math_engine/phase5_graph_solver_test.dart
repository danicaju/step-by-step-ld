import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/function_graph_solver.dart';
import 'package:casio_tutor_calc/domain/services/notebook_scanner_service.dart';

void main() {
  group('Fase 5 - FunctionGraphSolver: Funciones Cuadráticas (Parábolas)', () {
    test('Estudio analítico de parábola y = x² - 4x + 3 (a=1, b=-4, c=3)', () {
      final result = FunctionGraphSolver.analyzeQuadratic(a: 1, b: -4, c: 3);

      expect(result.isQuadratic, isTrue);
      expect(result.a, equals(1.0));
      expect(result.b, equals(-4.0));
      expect(result.c, equals(3.0));

      // 1. Vértice y eje
      expect(result.vertexX, equals(2.0));
      expect(result.vertexY, equals(-1.0));

      final vertex = result.notablePoints.firstWhere(
        (p) => p.type == PointType.vertex,
      );
      expect(vertex.x, equals(2.0));
      expect(vertex.y, equals(-1.0));
      expect(vertex.latexCoords, contains('2'));
      expect(vertex.latexCoords, contains('-1'));

      // 2. Cortes con los ejes
      final yIntercept = result.notablePoints.firstWhere(
        (p) => p.type == PointType.yIntercept,
      );
      expect(yIntercept.x, equals(0.0));
      expect(yIntercept.y, equals(3.0));

      final xIntercepts = result.notablePoints
          .where((p) => p.type == PointType.xIntercept)
          .toList();
      expect(xIntercepts.length, equals(2));
      final xValues = xIntercepts.map((p) => p.x).toList()..sort();
      expect(xValues[0], equals(1.0));
      expect(xValues[1], equals(3.0));

      // 3. Pasos pedagógicos
      expect(result.resolution.steps.length, equals(4));
      // Paso 1: Ramas hacia arriba
      expect(result.resolution.steps[0].latexExpression, contains('> 0'));
      expect(result.resolution.steps[0].pedagogicalNote, contains('mínimo'));

      // Paso 2: Vértice V(2, -1)
      expect(result.resolution.steps[1].latexExpression, contains('x_v'));
      expect(result.resolution.steps[1].latexExpression, contains('y_v'));

      // Paso 3: Cortes
      expect(result.resolution.steps[2].latexExpression, contains('(0, 3)'));

      // Paso 4: Tabla de valores simétrica alrededor de x = 2
      expect(result.samplePoints.length, equals(5));
      expect(result.samplePoints[0].x, equals(0.0));
      expect(result.samplePoints[0].y, equals(3.0));
      expect(result.samplePoints[1].x, equals(1.0));
      expect(result.samplePoints[1].y, equals(0.0));
      expect(result.samplePoints[2].x, equals(2.0));
      expect(result.samplePoints[2].y, equals(-1.0));
      expect(result.samplePoints[3].x, equals(3.0));
      expect(result.samplePoints[3].y, equals(0.0));
      expect(result.samplePoints[4].x, equals(4.0));
      expect(result.samplePoints[4].y, equals(3.0));

      // Simetría f(2 - k) == f(2 + k)
      expect(result.samplePoints[0].y, equals(result.samplePoints[4].y));
      expect(result.samplePoints[1].y, equals(result.samplePoints[3].y));

      // Evaluación general
      expect(result.evaluate(2.0), equals(-1.0));
      expect(result.evaluate(0.0), equals(3.0));
      expect(result.evaluate(5.0), equals(8.0)); // 25 - 20 + 3 = 8
    });

    test('Parábola con ramas hacia abajo y sin raíces reales: y = -x² + 2x - 5', () {
      final result = FunctionGraphSolver.analyzeQuadratic(a: -1, b: 2, c: -5);

      expect(result.isQuadratic, isTrue);
      // a = -1 < 0 -> Ramas hacia abajo, máximo
      expect(result.resolution.steps[0].latexExpression, contains('< 0'));
      expect(result.resolution.steps[0].pedagogicalNote, contains('máximo'));

      // Vértice: xv = -2 / (2 * -1) = 1, yv = -1 + 2 - 5 = -4
      expect(result.vertexX, equals(1.0));
      expect(result.vertexY, equals(-4.0));

      // Discriminante: b² - 4ac = 4 - 20 = -16 < 0
      final xIntercepts = result.notablePoints
          .where((p) => p.type == PointType.xIntercept)
          .toList();
      expect(xIntercepts, isEmpty);
      expect(result.resolution.steps[2].warningTrick, isNotNull);
      expect(result.resolution.steps[2].warningTrick, contains('b² - 4ac'));
      expect(
        result.resolution.steps[2].pedagogicalNote,
        contains('no corta al eje X'),
      );
    });

    test('Parábola lanza excepción si a == 0', () {
      expect(
        () => FunctionGraphSolver.analyzeQuadratic(a: 0, b: 2, c: 1),
        throwsArgumentError,
      );
    });
  });

  group('Fase 5 - FunctionGraphSolver: Funciones Lineales / Afines (Rectas)', () {
    test('Estudio analítico de recta creciente y = 2x - 4', () {
      final result = FunctionGraphSolver.analyzeLinear(m: 2, n: -4);

      expect(result.isQuadratic, isFalse);
      expect(result.b, equals(2.0)); // m
      expect(result.c, equals(-4.0)); // n

      // Pendiente positiva
      expect(result.resolution.steps[0].latexExpression, contains('Creciente'));
      expect(result.resolution.steps[0].pedagogicalNote, contains('pendiente'));

      // Cortes
      final yIntercept = result.notablePoints.firstWhere(
        (p) => p.type == PointType.yIntercept,
      );
      expect(yIntercept.x, equals(0.0));
      expect(yIntercept.y, equals(-4.0));

      final xIntercept = result.notablePoints.firstWhere(
        (p) => p.type == PointType.xIntercept,
      );
      expect(xIntercept.x, equals(2.0)); // 2x - 4 = 0 => x = 2
      expect(xIntercept.y, equals(0.0));

      // Tabla de valores
      expect(result.samplePoints.length, equals(5));
      expect(result.evaluate(0.0), equals(-4.0));
      expect(result.evaluate(2.0), equals(0.0));
      expect(result.evaluate(3.0), equals(2.0));
    });

    test('Recta horizontal constante: y = 5 (m=0, n=5)', () {
      final result = FunctionGraphSolver.analyzeLinear(m: 0, n: 5);

      expect(result.resolution.steps[0].latexExpression, contains('Constante'));
      // No corta al eje X
      final xIntercepts = result.notablePoints
          .where((p) => p.type == PointType.xIntercept)
          .toList();
      expect(xIntercepts, isEmpty);
      expect(result.resolution.steps[1].warningTrick, contains('paralela'));
    });
  });

  group('Fase 5 - NotebookScannerService: Ejercicios Demo con Errores de Examen', () {
    test('Catálogo demo contiene 4 casos realistas de examen con errores detectados', () {
      final demos = NotebookScannerService.getDemoExercises();

      expect(demos.length, equals(4));

      // Caso 1: Ecuación 1er grado con fracciones
      expect(demos[0].detectedCategory, equals('linear_eq'));
      expect(demos[0].targetMode, equals(2));
      expect(demos[0].handwrittenErrorDetected, contains('signo menos delante de la fracción'));

      // Caso 2: Parábola
      expect(demos[1].detectedCategory, equals('function_graph'));
      expect(demos[1].targetMode, equals(5));
      expect(demos[1].handwrittenErrorDetected, contains('doble signo'));

      // Caso 3: Ruffini
      expect(demos[2].detectedCategory, equals('ruffini'));
      expect(demos[2].targetMode, equals(4));
      expect(demos[2].handwrittenErrorDetected, contains('olvidando el 0'));

      // Caso 4: Identidad Notable
      expect(demos[3].detectedCategory, equals('notable'));
      expect(demos[3].targetMode, equals(4));
      expect(demos[3].handwrittenErrorDetected, contains('doble producto'));
    });

    test('Simulación offline devuelve un ejercicio demo válido', () async {
      final scanner = NotebookScannerService();
      final scanned = await scanner.offlineDemoScan(index: 1);

      expect(scanned.title, equals('Estudio y Gráfica de Parábola'));
      expect(scanned.targetMode, equals(5));
      expect(scanned.extractedExpressionRaw, equals('x^2 - 4x + 3'));
      expect(scanned.handwrittenErrorDetected, isNotNull);
    });
  });
}
