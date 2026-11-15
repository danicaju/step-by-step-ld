import 'dart:math' as math;

import '../models/inequality_models.dart';
import '../models/step_resolution.dart';
import 'inequality_solver.dart';

/// Solver de Sistemas de Inecuaciones Lineales de 2 Incógnitas (Programación Lineal / Región Factible).
class LinearInequality2DSolver {
  /// Resuelve un sistema de inecuaciones lineales en 2 variables (x, y).
  ///
  /// Ejemplos:
  /// - `['x + y <= 4', '2x - y >= 1', 'x >= 0', 'y >= 0']`
  /// - `['2x + 3y <= 12', 'x - y <= 1', 'x >= 0', 'y >= 0']`
  static ({StepByStepResolution resolution, FeasibleRegion2DVisualData visualData}) solveSystem2D(
    List<String> rawInequalities,
  ) {
    if (rawInequalities.isEmpty) {
      throw const FormatException('Introduce al menos una inecuacion lineal.');
    }

    final parsedList = <LinearInequality2D>[];
    for (final raw in rawInequalities) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      parsedList.add(_parse2DInequality(trimmed));
    }

    if (parsedList.isEmpty) {
      throw const FormatException('No se encontraron inecuaciones validas.');
    }

    final steps = <MathStep>[];

    // -------------------------------------------------------------------------
    // PASO 1: Rectas frontera y estilo (continua o discontinua)
    // -------------------------------------------------------------------------
    final boundaryLinesDesc = <String>[];
    for (int i = 0; i < parsedList.length; i++) {
      final ineq = parsedList[i];
      final lineEq = _formatLineEquation(ineq.a, ineq.b, ineq.c);
      final styleStr = ineq.isBoundarySolid ? 'continua' : 'discontinua';
      final reasonStr = ineq.isBoundarySolid
          ? 'incluye el igual (${ineq.sign.symbol})'
          : 'desigualdad estricta (${ineq.sign.symbol})';
      boundaryLinesDesc.add(
        'r_{${i + 1}}: $lineEq \\quad (\\text{Linea } $styleStr \\text{ porque } $reasonStr)',
      );
    }

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Determinar las rectas frontera',
        latexExpression: boundaryLinesDesc.join(r' \\ '),
        pedagogicalNote:
            'Cambiamos cada desigualdad por un signo igual (=) para obtener las rectas frontera que limitan los semiplanos. '
            'Si la inecuación contiene ≤ o ≥, la recta se dibuja continua porque sus puntos pertenecen a la solución. '
            'Si contiene < o >, se dibuja discontinua porque sus puntos no están incluidos.',
      ),
    );

    // -------------------------------------------------------------------------
    // PASO 2: Prueba del punto (0,0) para determinar semiplanos
    // -------------------------------------------------------------------------
    final testPointSteps = <String>[];
    for (int i = 0; i < parsedList.length; i++) {
      final ineq = parsedList[i];
      final test00 = ineq.testPoint(0, 0);
      final val00 = test00.value;
      final satisfied = test00.satisfied;
      final lineLabel = 'r_{${i + 1}}';

      // Si la recta pasa por (0,0), usar (1,0) o (0,1)
      if (ineq.c.abs() < 1e-9) {
        final altX = ineq.a.abs() > 1e-9 ? 1.0 : 0.0;
        final altY = ineq.a.abs() > 1e-9 ? 0.0 : 1.0;
        final testAlt = ineq.testPoint(altX, altY);
        final valAlt = testAlt.value;
        final satAlt = testAlt.satisfied;
        final satText = satAlt ? r'\text{SI se cumple}' : r'\text{NO se cumple}';
        testPointSteps.add(
          '$lineLabel: (${_fmt(altX)}, ${_fmt(altY)}) \\implies '
          '${_fmt(valAlt)} ${ineq.sign.latex} ${_fmt(ineq.c)} \\implies $satText',
        );
      } else {
        final satText = satisfied ? r'\text{SI se cumple}' : r'\text{NO se cumple}';
        testPointSteps.add(
          '$lineLabel: (0,0) \\implies '
          '${_fmt(val00)} ${ineq.sign.latex} ${_fmt(ineq.c)} \\implies $satText',
        );
      }
    }

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Comprobación de semiplanos con punto de prueba',
        latexExpression: testPointSteps.join(r' \\ '),
        pedagogicalNote:
            'Sustituimos el punto de prueba (0,0) en cada inecuación. Si se cumple la desigualdad, sombreamos el semiplano que contiene al origen (0,0). '
            'Si no se cumple, sombreamos el semiplano contrario.',
      ),
    );

    // -------------------------------------------------------------------------
    // PASO 3: Cálculo de vértices (intersección de rectas frontera)
    // -------------------------------------------------------------------------
    final candidateVertices = <Point2D>[];
    final vertexExplanations = <String>[];

    for (int i = 0; i < parsedList.length; i++) {
      for (int j = i + 1; j < parsedList.length; j++) {
        final l1 = parsedList[i];
        final l2 = parsedList[j];

        final det = l1.a * l2.b - l1.b * l2.a;
        if (det.abs() < 1e-9) {
          // Rectas paralelas o coincidentes
          continue;
        }

        final detX = l1.c * l2.b - l1.b * l2.c;
        final detY = l1.a * l2.c - l1.c * l2.a;
        final px = detX / det;
        final py = detY / det;

        // Comprobar si este punto satisface TODAS las inecuaciones del sistema
        bool allSatisfied = true;
        for (final ineq in parsedList) {
          if (!ineq.evaluatesTrue(px, py)) {
            allSatisfied = false;
            break;
          }
        }

        if (allSatisfied) {
          // Evitar duplicados
          final alreadyExists = candidateVertices.any(
            (v) => (v.x - px).abs() < 1e-4 && (v.y - py).abs() < 1e-4,
          );
          if (!alreadyExists) {
            final pt = Point2D(px, py);
            candidateVertices.add(pt);
            vertexExplanations.add(
              'r_{${i + 1}} \\cap r_{${j + 1}} \\implies ${pt.toLatex()}',
            );
          }
        }
      }
    }

    // Ordenar vértices angularmente alrededor del centroide para dibujar el polígono
    final sortedVertices = _sortVerticesCounterClockwise(candidateVertices);

    final bool isEmpty = candidateVertices.isEmpty;
    final bool isBounded = _isRegionBounded(parsedList, sortedVertices);

    final String verticesLatex;
    if (isEmpty) {
      verticesLatex = r'\text{Sin vertices: region factible vacia } (\emptyset)';
    } else {
      final names = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
      final formatted = <String>[];
      for (int k = 0; k < sortedVertices.length; k++) {
        final name = k < names.length ? names[k] : 'V_{${k + 1}}';
        formatted.add('$name${sortedVertices[k].toLatex()}');
      }
      verticesLatex = formatted.join(', \\; ');
    }

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Cálculo de los vértices de la región factible',
        latexExpression: vertexExplanations.isEmpty
            ? verticesLatex
            : '${vertexExplanations.join(r' \\ ')} \\\\[6pt] \\text{Vertices validos: } $verticesLatex',
        pedagogicalNote:
            'Resolvemos los sistemas 2x2 formados por pares de rectas frontera para hallar los puntos de corte. '
            'Solo aquellos puntos que cumplen todas las inecuaciones a la vez forman los vértices de la región factible.',
      ),
    );

    // -------------------------------------------------------------------------
    // PASO 4: Conclusión de la región factible
    // -------------------------------------------------------------------------
    final String conclusionLatex;
    final String conclusionNote;
    if (isEmpty) {
      conclusionLatex = r'\text{Region factible vacia: } \emptyset';
      conclusionNote =
          'Los semiplanos no tienen ninguna zona en común. El sistema es incompatible y no existe solución real.';
    } else if (isBounded) {
      conclusionLatex =
          '\\text{Region factible acotada con } ${sortedVertices.length} \\text{ vertices: } $verticesLatex';
      conclusionNote =
          'La región factible es un polígono cerrado (acotado). En problemas de optimización lineal, los máximos y mínimos se alcanzan siempre en uno de estos vértices.';
    } else {
      conclusionLatex =
          '\\text{Region factible no acotada con vertices: } $verticesLatex';
      conclusionNote =
          'La región factible es abierta hacia el infinito (no acotada). Los vértices delimitan su frontera inferior/superior.';
    }

    steps.add(
      MathStep(
        index: 4,
        shortTitle: 'Conclusión de la región factible',
        latexExpression: conclusionLatex,
        pedagogicalNote: conclusionNote,
      ),
    );

    final originalLatex = parsedList.map((e) => e.rawInput).join(r' \quad ');

    final res = StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: verticesLatex,
      decimalApproxLatex: verticesLatex,
    );

    final visualData = FeasibleRegion2DVisualData(
      inequalities: parsedList,
      vertices: sortedVertices,
      isBounded: isBounded,
      isEmpty: isEmpty,
      solutionSummaryLatex: conclusionLatex,
    );

    return (resolution: res, visualData: visualData);
  }

  // ---------------------------------------------------------------------------
  // Parseo de inecuaciones 2D: ax + by <= c
  // ---------------------------------------------------------------------------
  static LinearInequality2D _parse2DInequality(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('\u2212', '-')
        .replaceAll('X', 'x')
        .replaceAll('Y', 'y')
        .replaceAll(r'\cdot', '*')
        .replaceAll('·', '*');

    // Detectar signo
    InequalitySign? sign;
    int signIdx = -1;
    int signLen = 0;

    const patterns = [
      '<=', '>=', '≤', '≥', r'\leq', r'\geq', r'\le', r'\ge', '<', '>'
    ];
    for (final pat in patterns) {
      final idx = cleaned.indexOf(pat);
      if (idx != -1) {
        sign = InequalitySign.tryParse(pat);
        signIdx = idx;
        signLen = pat.length;
        break;
      }
    }

    if (sign == null || signIdx == -1) {
      throw FormatException('Falta signo de desigualdad en: $raw');
    }

    final lhs = cleaned.substring(0, signIdx);
    final rhs = cleaned.substring(signIdx + signLen);

    final leftParsed = _parseSide2D(lhs);
    final rightParsed = _parseSide2D(rhs.isEmpty ? '0' : rhs);

    final netA = leftParsed.a - rightParsed.a;
    final netB = leftParsed.b - rightParsed.b;
    final netC = rightParsed.constant - leftParsed.constant;

    return LinearInequality2D(
      a: netA,
      b: netB,
      c: netC,
      sign: sign,
      rawInput: raw,
    );
  }

  static ({double a, double b, double constant}) _parseSide2D(String side) {
    if (side.isEmpty || side == '0') {
      return (a: 0.0, b: 0.0, constant: 0.0);
    }

    // Desglosar en términos aditivos con signos
    final terms = <String>[];
    int start = 0;
    for (int i = 0; i < side.length; i++) {
      final ch = side[i];
      if ((ch == '+' || ch == '-') && i > 0 && side[i - 1] != '(' && side[i - 1] != '/') {
        terms.add(side.substring(start, i));
        start = i;
      }
    }
    terms.add(side.substring(start));

    double totalA = 0.0;
    double totalB = 0.0;
    double totalC = 0.0;

    for (final rawTerm in terms) {
      final term = rawTerm.trim();
      if (term.isEmpty) continue;

      if (term.contains('x')) {
        totalA += _parseCoeff(term, 'x');
      } else if (term.contains('y')) {
        totalB += _parseCoeff(term, 'y');
      } else {
        totalC += _parseDouble(term);
      }
    }

    return (a: totalA, b: totalB, constant: totalC);
  }

  static double _parseCoeff(String term, String variable) {
    final clean = term.replaceAll('*', '');
    final idx = clean.indexOf(variable);
    final prefix = clean.substring(0, idx);
    if (prefix.isEmpty || prefix == '+') return 1.0;
    if (prefix == '-') return -1.0;
    return _parseDouble(prefix);
  }

  static double _parseDouble(String s) {
    if (s.contains('/')) {
      final parts = s.split('/');
      final num = double.parse(parts[0]);
      final den = double.parse(parts[1]);
      return num / den;
    }
    return double.parse(s);
  }

  static String _formatLineEquation(double a, double b, double c) {
    final buffer = StringBuffer();
    if (a != 0) {
      if (a == 1) {
        buffer.write('x');
      } else if (a == -1) {
        buffer.write('-x');
      } else {
        buffer.write('${_fmt(a)}x');
      }
    }

    if (b != 0) {
      if (buffer.isNotEmpty) {
        if (b > 0) {
          buffer.write(b == 1 ? ' + y' : ' + ${_fmt(b)}y');
        } else {
          buffer.write(b == -1 ? ' - y' : ' - ${_fmt(b.abs())}y');
        }
      } else {
        if (b == 1) {
          buffer.write('y');
        } else if (b == -1) {
          buffer.write('-y');
        } else {
          buffer.write('${_fmt(b)}y');
        }
      }
    }

    if (buffer.isEmpty) buffer.write('0');
    buffer.write(' = ${_fmt(c)}');
    return buffer.toString();
  }

  static List<Point2D> _sortVerticesCounterClockwise(List<Point2D> points) {
    if (points.length <= 2) return points;

    // Calcular centroide
    double cx = 0;
    double cy = 0;
    for (final p in points) {
      cx += p.x;
      cy += p.y;
    }
    cx /= points.length;
    cy /= points.length;

    final sorted = List<Point2D>.from(points);
    sorted.sort((a, b) {
      final angleA = math.atan2(a.y - cy, a.x - cx);
      final angleB = math.atan2(b.y - cy, b.x - cx);
      return angleA.compareTo(angleB);
    });
    return sorted;
  }

  static bool _isRegionBounded(List<LinearInequality2D> ineqs, List<Point2D> vertices) {
    if (vertices.length < 3) return false;
    // Comprobar si existen restricciones en las 4 direcciones principales
    bool hasPlusX = ineqs.any((e) => e.a > 0.1 && (e.sign == InequalitySign.less || e.sign == InequalitySign.lessOrEqual));
    bool hasMinusX = ineqs.any((e) => e.a > 0.1 && (e.sign == InequalitySign.greater || e.sign == InequalitySign.greaterOrEqual) || (e.a < -0.1 && (e.sign == InequalitySign.less || e.sign == InequalitySign.lessOrEqual)));
    bool hasPlusY = ineqs.any((e) => e.b > 0.1 && (e.sign == InequalitySign.less || e.sign == InequalitySign.lessOrEqual));
    bool hasMinusY = ineqs.any((e) => e.b > 0.1 && (e.sign == InequalitySign.greater || e.sign == InequalitySign.greaterOrEqual) || (e.b < -0.1 && (e.sign == InequalitySign.less || e.sign == InequalitySign.lessOrEqual)));

    return hasPlusX && hasMinusX && hasPlusY && hasMinusY;
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
