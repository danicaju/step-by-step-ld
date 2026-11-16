import 'dart:math' as math;

import '../models/step_resolution.dart';
import '../models/inequality_models.dart';
import 'inequalities/sutherland_hodgman_2d.dart';
import 'inequalities/inequality_sign.dart';

/// Solver de Sistemas de Inecuaciones Lineales de 2 Incógnitas (Región Factible 2D).
class LinearInequality2DSolver {
  /// Resuelve un sistema de inecuaciones lineales en 2 variables (x, y)
  /// produciendo 3 pasos pedagógicos claros y datos para el plano cartesiano.
  static ({StepByStepResolution resolution, FeasibleRegion2DVisualData visualData}) solveSystem2D(
    List<String> rawInequalities,
  ) {
    if (rawInequalities.isEmpty) {
      throw const FormatException('Introduce al menos una inecuación lineal.');
    }

    final parsedList = <LinearInequality2D>[];
    for (final raw in rawInequalities) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      parsedList.add(_parse2DInequality(trimmed));
    }

    if (parsedList.isEmpty) {
      throw const FormatException('No se encontraron inecuaciones válidas.');
    }

    final steps = <MathStep>[];

    // =========================================================================
    // PASO 1: Rectas frontera, estilo y 2 puntos de corte
    // =========================================================================
    final boundaryLinesDesc = <String>[];
    for (int i = 0; i < parsedList.length; i++) {
      final ineq = parsedList[i];
      final lineEq = _formatLineEquation(ineq.a, ineq.b, ineq.c);
      final styleStr = ineq.isBoundarySolid ? 'continua' : 'discontinua';
      final pts = _computeTwoPoints(ineq.a, ineq.b, ineq.c);
      final p1Str = pts.$1.toLatex();
      final p2Str = pts.$2.toLatex();

      boundaryLinesDesc.add(
        'r_{${i + 1}}: $lineEq \\quad (\\text{Linea $styleStr}) '
        '\\implies P_1$p1Str, \\; P_2$p2Str',
      );
    }

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Rectas frontera y puntos de corte',
        latexExpression: boundaryLinesDesc.join(r' \\ '),
        pedagogicalNote:
            'Sustituimos la desigualdad por un igual (=) para obtener las rectas frontera y calculamos dos puntos sencillos para representarlas. '
            'Las inecuaciones con ≤ o ≥ tienen línea continua (puntos incluidos); las de < o > tienen línea discontinua (puntos excluidos).',
      ),
    );

    // =========================================================================
    // PASO 2: Comprobación de semiplanos con punto de prueba
    // =========================================================================
    final testPointSteps = <String>[];
    for (int i = 0; i < parsedList.length; i++) {
      final ineq = parsedList[i];
      final lineLabel = 'r_{${i + 1}}';

      if (ineq.c.abs() < 1e-9) {
        // Pasa por el origen: usar (1,0) o (0,1)
        final altX = ineq.a.abs() > 1e-9 ? 1.0 : 0.0;
        final altY = ineq.a.abs() > 1e-9 ? 0.0 : 1.0;
        final testAlt = ineq.testPoint(altX, altY);
        final satText = testAlt.satisfied
            ? r'\text{SI se cumple (sombrear ese lado)}'
            : r'\text{NO se cumple (sombrear semiplano opuesto)}';
        testPointSteps.add(
          '$lineLabel: (${_fmt(altX)}, ${_fmt(altY)}) \\implies '
          '${_fmt(testAlt.value)} ${ineq.sign.latex} ${_fmt(ineq.c)} \\implies $satText',
        );
      } else {
        final test00 = ineq.testPoint(0, 0);
        final satText = test00.satisfied
            ? r'\text{SI se cumple (sombrear el lado del origen)}'
            : r'\text{NO se cumple (sombrear semiplano opuesto)}';
        testPointSteps.add(
          '$lineLabel: (0,0) \\implies '
          '${_fmt(test00.value)} ${ineq.sign.latex} ${_fmt(ineq.c)} \\implies $satText',
        );
      }
    }

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Comprobación de semiplanos (Punto de prueba)',
        latexExpression: testPointSteps.join(r' \\ '),
        pedagogicalNote:
            'Evaluamos el punto de prueba (0,0) en cada inecuación. Si satisface la desigualdad, sombreamos el semiplano que lo contiene; en caso contrario, sombreamos el lado opuesto.',
      ),
    );

    // =========================================================================
    // PASO 3: Cálculo de vértices y determinación de la región solución
    // =========================================================================
    final candidateVertices = <Point2D>[];
    final vertexExplanations = <String>[];

    for (int i = 0; i < parsedList.length; i++) {
      for (int j = i + 1; j < parsedList.length; j++) {
        final l1 = parsedList[i];
        final l2 = parsedList[j];

        // Resolver sistema 2x2 formado por las dos rectas frontera
        final det = l1.normA * l2.normB - l1.normB * l2.normA;
        if (det.abs() < 1e-9) continue; // Paralelas o coincidentes

        final px = (l1.normC * l2.normB - l1.normB * l2.normC) / det;
        final py = (l1.normA * l2.normC - l1.normC * l2.normA) / det;

        // Comprobar si cumple la clausura (<= c + eps) de TODAS las inecuaciones
        bool inClosure = true;
        for (final ineq in parsedList) {
          final val = ineq.normA * px + ineq.normB * py;
          if (val > ineq.normC + 1e-7) {
            inClosure = false;
            break;
          }
        }

        if (inClosure) {
          // Determinar si es vértice abierto (alguna de las rectas que pasan por él es estricta)
          bool isOpen = false;
          for (final ineq in parsedList) {
            final dist = (ineq.normA * px + ineq.normB * py - ineq.normC).abs();
            if (dist < 1e-5 && ineq.isStrict) {
              isOpen = true;
              break;
            }
          }

          final alreadyExists = candidateVertices.any(
            (v) => (v.x - px).abs() < 1e-4 && (v.y - py).abs() < 1e-4,
          );
          if (!alreadyExists) {
            final pt = Point2D(px, py, null, isOpen);
            candidateVertices.add(pt);
            final statusStr = isOpen ? r'\text{ (Vertice abierto } \circ)' : r'\text{ (Vertice cerrado } \bullet)';
            vertexExplanations.add(
              'r_{${i + 1}} \\cap r_{${j + 1}} \\implies ${pt.toLatex()} $statusStr',
            );
          }
        }
      }
    }

    // Análisis topológico de la región sobre caja de gran alcance [-1000, 1000]^2
    final regionAnalysis = SutherlandHodgman2D.analyzeFeasibleRegion(parsedList);
    final bool isEmpty = regionAnalysis.isEmpty;
    final bool isBounded = regionAnalysis.isBounded;

    final sortedVertices = _sortVerticesCounterClockwise(candidateVertices);
    final names = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final labeledVertices = <Point2D>[];
    final formattedVertices = <String>[];

    for (int k = 0; k < sortedVertices.length; k++) {
      final v = sortedVertices[k];
      final name = k < names.length ? names[k] : 'V_{${k + 1}}';
      labeledVertices.add(Point2D(v.x, v.y, name, v.isOpen));
      final mark = v.isOpen ? r'^\circ' : '';
      formattedVertices.add('$name$mark${v.toLatex()}');
    }

    final String verticesLatex = formattedVertices.isEmpty
        ? r'\text{Sin vertices de corte}'
        : formattedVertices.join(', \\; ');

    final String conclusionLatex;
    final String conclusionNote;
    final String summaryLatex;

    if (isEmpty) {
      conclusionLatex = r'\text{Region factible vacia: } \emptyset';
      conclusionNote =
          'Los semiplanos no tienen ninguna región en común. El sistema es incompatible y no tiene solución.';
      summaryLatex = r'S_{f} = \emptyset';
    } else if (isBounded) {
      conclusionLatex =
          '\\text{Region factible acotada con } ${labeledVertices.length} \\text{ vertices: } $verticesLatex';
      conclusionNote =
          'La intersección forma un polígono cerrado (región acotada). Los vértices calculados delimitan la región solución.';
      summaryLatex = 'S_{f} \\text{ acotada: } $verticesLatex';
    } else {
      conclusionLatex =
          '\\text{Region factible no acotada con vertices: } $verticesLatex';
      conclusionNote =
          'La región factible se extiende indefinidamente (no acotada). Los vértices calculados marcan los puntos de inflexión del contorno.';
      summaryLatex = 'S_{f} \\text{ no acotada: } $verticesLatex';
    }

    final String step3Latex;
    if (isEmpty) {
      step3Latex = conclusionLatex;
    } else if (vertexExplanations.isEmpty) {
      step3Latex = '$conclusionLatex \\\\[4pt] \\text{Pulsa "Ver Plano 2D" para ver la region sombreada.}';
    } else {
      step3Latex =
          '${vertexExplanations.join(r' \\ ')} \\\\[6pt] $conclusionLatex \\\\[4pt] '
          '\\text{Pulsa "Ver Plano 2D" para ver la region sombreada.}';
    }

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Vértices y región solución',
        latexExpression: step3Latex,
        pedagogicalNote: conclusionNote,
      ),
    );

    final resolution = StepByStepResolution(
      originalInputLatex:
          '\\begin{cases} ${parsedList.map((e) => e.rawInput).join(r' \\ ')} \\end{cases}',
      steps: steps,
      exactResultLatex: summaryLatex,
      decimalApproxLatex: summaryLatex,
    );

    final visualData = FeasibleRegion2DVisualData(
      inequalities: parsedList,
      vertices: labeledVertices,
      isBounded: isBounded,
      isEmpty: isEmpty,
      solutionSummaryLatex: summaryLatex,
    );

    return (resolution: resolution, visualData: visualData);
  }

  static (Point2D, Point2D) _computeTwoPoints(double a, double b, double c) {
    if (c.abs() < 1e-9) {
      if (a.abs() > 1e-9 && b.abs() > 1e-9) {
        return (const Point2D(0, 0), Point2D(b, -a));
      } else if (a.abs() > 1e-9) {
        return (const Point2D(0, 0), const Point2D(0, 1));
      } else {
        return (const Point2D(0, 0), const Point2D(1, 0));
      }
    }
    if (a.abs() > 1e-9 && b.abs() > 1e-9) {
      return (Point2D(0, c / b), Point2D(c / a, 0));
    } else if (a.abs() > 1e-9) {
      return (Point2D(c / a, 0), Point2D(c / a, 1));
    } else if (b.abs() > 1e-9) {
      return (Point2D(0, c / b), Point2D(1, c / b));
    }
    return (const Point2D(0, 0), const Point2D(1, 1));
  }

  static LinearInequality2D _parse2DInequality(String raw) {
    final cleaned = raw
        .replaceAll(' ', '')
        .replaceAll('X', 'x')
        .replaceAll('Y', 'y')
        .replaceAll(r'\cdot', '*')
        .replaceAll('·', '*');

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

    return LinearInequality2D.create(
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

  static String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    if ((v - v.roundToDouble()).abs() < 1e-6) return v.round().toString();
    return v.toStringAsFixed(2);
  }
}
