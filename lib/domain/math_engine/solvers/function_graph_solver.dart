import 'dart:math' as math;
import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

enum PointType {
  vertex('Vértice'),
  xIntercept('Corte Eje X'),
  yIntercept('Corte Eje Y'),
  systemIntersection('Intersección');

  final String displayName;
  const PointType(this.displayName);
}

class NotablePoint {
  final String label;
  final double x;
  final double y;
  final String latexCoords;
  final PointType type;

  const NotablePoint({
    required this.label,
    required this.x,
    required this.y,
    required this.latexCoords,
    required this.type,
  });
}

class TableValueRow {
  final double x;
  final double y;
  final String xLatex;
  final String yLatex;

  const TableValueRow({
    required this.x,
    required this.y,
    required this.xLatex,
    required this.yLatex,
  });
}

class FunctionAnalysisResult {
  final StepByStepResolution resolution;
  final List<NotablePoint> notablePoints;
  final double a;
  final double b;
  final double c;
  final bool isQuadratic;
  final double? vertexX;
  final double? vertexY;
  final List<TableValueRow> samplePoints;

  const FunctionAnalysisResult({
    required this.resolution,
    required this.notablePoints,
    required this.a,
    required this.b,
    required this.c,
    required this.isQuadratic,
    this.vertexX,
    this.vertexY,
    required this.samplePoints,
  });

  /// Evalúa la función para cualquier x
  double evaluate(double x) {
    if (isQuadratic) {
      return a * x * x + b * x + c;
    } else {
      return b * x + c; // y = mx + n con m=b, n=c
    }
  }
}

class FunctionGraphSolver {
  /// Analiza paso a paso una función cuadrática: y = ax² + bx + c
  static FunctionAnalysisResult analyzeQuadratic({
    required int a,
    required int b,
    required int c,
  }) {
    if (a == 0) {
      throw ArgumentError('En una parábola, el coeficiente "a" no puede ser 0.');
    }

    final originalLatex = 'y = ${_formatQuadraticEquation(a, b, c)}';
    final List<MathStep> steps = [];
    final List<NotablePoint> notablePoints = [];

    // Paso 1: Ramas y Concavidad
    final bool opensUp = a > 0;
    final String branchSymbol = opensUp ? r'\cup' : r'\cap';

    steps.add(
      MathStep(
        index: 1,
        shortTitle: '1. Ramas y Concavidad de la parábola',
        latexExpression:
            'a = $a ${opensUp ? '> 0' : '< 0'} \\implies $branchSymbol',
        pedagogicalNote: opensUp
            ? 'Como el coeficiente a es positivo (a = $a), las ramas apuntan hacia arriba y el vértice es el punto más bajo (mínimo absoluto).'
            : 'Como el coeficiente a es negativo (a = $a), las ramas apuntan hacia abajo y el vértice es el punto más alto (máximo absoluto).',
      ),
    );

    // Paso 2: Vértice V(xv, yv) y Eje de Simetría
    final Rational xvRational = Rational.raw(-b, 2 * a).simplify();
    final double xv = xvRational.toDouble();

    // yv = a*(xv)^2 + b*xv + c
    final Rational yvTerm1 = Rational(a) * xvRational.pow(2);
    final Rational yvTerm2 = Rational(b) * xvRational;
    final Rational yvTerm3 = Rational(c);
    final Rational yvRational = (yvTerm1 + yvTerm2 + yvTerm3).simplify();
    final double yv = yvRational.toDouble();

    final String vertexCoordsLatex =
        '\\left(${xvRational.toLatex()}, \\; ${yvRational.toLatex()}\\right)';

    notablePoints.add(
      NotablePoint(
        label: 'Vértice V',
        x: xv,
        y: yv,
        latexCoords: vertexCoordsLatex,
        type: PointType.vertex,
      ),
    );

    final xvLatex = xvRational.toLatex();
    final yvStr1 = a == 1
        ? '\\left($xvLatex\\right)^2'
        : (a == -1
            ? '-\\left($xvLatex\\right)^2'
            : '$a \\cdot \\left($xvLatex\\right)^2');
    final yvStr2 = b == 0
        ? ''
        : (b == 1
            ? ' + \\left($xvLatex\\right)'
            : (b == -1
                ? ' - \\left($xvLatex\\right)'
                : (b > 0
                    ? ' + $b \\cdot \\left($xvLatex\\right)'
                    : ' - ${b.abs()} \\cdot \\left($xvLatex\\right)')));
    final yvStr3 = AlgebraicLatexFormatter.constantTerm(c, isFirst: false);

    steps.add(
      MathStep(
        index: 2,
        shortTitle: '2. Cálculo del Vértice y Eje de Simetría',
        latexExpression:
            '\\begin{aligned} '
            'x_v &= \\frac{-b}{2a} = \\frac{-${AlgebraicLatexFormatter.parenIfNegative(b)}}{2 \\cdot ${AlgebraicLatexFormatter.parenIfNegative(a)}} = $xvLatex \\\\[6pt] '
            'y_v &= f(x_v) = $yvStr1$yvStr2$yvStr3 = ${yvRational.toLatex()} \\\\[6pt] '
            'V &= $vertexCoordsLatex \\quad \\left(x = $xvLatex\\right) '
            '\\end{aligned}',
        pedagogicalNote:
            'Calculamos la coordenada x del vértice con x = -b/(2a). '
            'Sustituimos ese valor en la función para hallar yᵥ. El eje de simetría es la recta vertical x = xᵥ.',
      ),
    );

    // Paso 3: Puntos de Corte con los ejes
    // Corte Eje Y: (0, c)
    final yInterceptPoint = NotablePoint(
      label: 'Corte Eje Y',
      x: 0,
      y: c.toDouble(),
      latexCoords: '(0, $c)',
      type: PointType.yIntercept,
    );
    notablePoints.add(yInterceptPoint);

    // Corte Eje X: ax² + bx + c = 0
    final int disc = b * b - 4 * a * c;
    final List<String> xInterceptsLatex = [];

    if (disc > 0) {
      final sqrtDisc = math.sqrt(disc);
      if (sqrtDisc == sqrtDisc.toInt()) {
        final sInt = sqrtDisc.toInt();
        final x1Rational = Rational.raw(-b + sInt, 2 * a).simplify();
        final x2Rational = Rational.raw(-b - sInt, 2 * a).simplify();

        final p1 = NotablePoint(
          label: 'Corte Eje X (x₁)',
          x: x1Rational.toDouble(),
          y: 0,
          latexCoords: '\\left(${x1Rational.toLatex()}, \\; 0\\right)',
          type: PointType.xIntercept,
        );
        final p2 = NotablePoint(
          label: 'Corte Eje X (x₂)',
          x: x2Rational.toDouble(),
          y: 0,
          latexCoords: '\\left(${x2Rational.toLatex()}, \\; 0\\right)',
          type: PointType.xIntercept,
        );
        notablePoints.add(p1);
        notablePoints.add(p2);
        xInterceptsLatex.add(p1.latexCoords);
        xInterceptsLatex.add(p2.latexCoords);
      } else {
        final double x1 = (-b + sqrtDisc) / (2 * a);
        final double x2 = (-b - sqrtDisc) / (2 * a);
        final p1 = NotablePoint(
          label: 'Corte Eje X (x₁)',
          x: x1,
          y: 0,
          latexCoords: '(${x1.toStringAsFixed(2)}, 0)',
          type: PointType.xIntercept,
        );
        final p2 = NotablePoint(
          label: 'Corte Eje X (x₂)',
          x: x2,
          y: 0,
          latexCoords: '(${x2.toStringAsFixed(2)}, 0)',
          type: PointType.xIntercept,
        );
        notablePoints.add(p1);
        notablePoints.add(p2);
        xInterceptsLatex.add(p1.latexCoords);
        xInterceptsLatex.add(p2.latexCoords);
      }
    } else if (disc == 0) {
      final pTang = NotablePoint(
        label: 'Corte Eje X (Tangente)',
        x: xv,
        y: 0,
        latexCoords: '\\left(${xvRational.toLatex()}, \\; 0\\right)',
        type: PointType.xIntercept,
      );
      notablePoints.add(pTang);
      xInterceptsLatex.add(pTang.latexCoords);
    }

    final String xCutLatex = disc > 0
        ? 'y = 0 \\implies ${xInterceptsLatex.join(r", \; ")}'
        : (disc == 0
            ? 'y = 0 \\implies (${xvRational.toLatex()}, 0)'
            : 'b^2 - 4ac = $disc < 0 \\implies \\text{No corta al eje X}');

    steps.add(
      MathStep(
        index: 3,
        shortTitle: '3. Puntos de corte con los ejes de coordenadas',
        latexExpression:
            '\\begin{aligned} '
            'x &= 0 \\implies (0, $c) \\\\[4pt] '
            '$xCutLatex '
            '\\end{aligned}',
        pedagogicalNote: disc > 0
            ? 'Corte con el eje Y evaluando f(0) = $c: (0, $c). Para el eje X resolvemos la ecuación de 2.º grado, obteniendo dos cortes.'
            : (disc == 0
                ? 'Corte con el eje Y en (0, $c). Para el eje X la parábola toca justo en el vértice.'
                : 'Corte con el eje Y en (0, $c). Para el eje X, como dentro de la raíz queda b² - 4ac = $disc (negativo), la parábola no corta al eje X.'),
        warningTrick: disc < 0
            ? 'Si b² - 4ac es negativo ($disc < 0), no hay solución real y la parábola no corta al eje X.'
            : null,
      ),
    );

    // Paso 4: Tabla de valores simétrica alrededor del vértice
    final List<TableValueRow> samplePoints = [];
    final int centerInt = xv.round();
    final List<int> xValues = [
      centerInt - 2,
      centerInt - 1,
      centerInt,
      centerInt + 1,
      centerInt + 2
    ];

    final List<String> tableXHeaders = [];
    final List<String> tableYValues = [];

    for (final xVal in xValues) {
      final yVal = a * xVal * xVal + b * xVal + c;
      samplePoints.add(TableValueRow(
        x: xVal.toDouble(),
        y: yVal.toDouble(),
        xLatex: '$xVal',
        yLatex: '$yVal',
      ));
      tableXHeaders.add('$xVal');
      tableYValues.add('$yVal');
    }

    final String tableLatex =
        '\\begin{array}{c|ccccc}\n'
        'x & ${tableXHeaders.join(" & ")} \\\\\n'
        '\\hline\n'
        'y & ${tableYValues.join(" & ")}\n'
        '\\end{array}';

    steps.add(
      MathStep(
        index: 4,
        shortTitle: '4. Tabla de valores simétrica respecto al vértice',
        latexExpression: tableLatex,
        pedagogicalNote:
            'Colocamos el vértice en el centro y tomamos dos valores a la izquierda y dos a la derecha. '
            'Observa cómo los valores de y son perfectamente simétricos equidistantes del vértice.',
      ),
    );

    final resolution = StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'V = $vertexCoordsLatex, \\; x = ${xvRational.toLatex()}',
      decimalApproxLatex: 'V = (${xv.toStringAsFixed(2)}, ${yv.toStringAsFixed(2)})',
    );

    return FunctionAnalysisResult(
      resolution: resolution,
      notablePoints: notablePoints,
      a: a.toDouble(),
      b: b.toDouble(),
      c: c.toDouble(),
      isQuadratic: true,
      vertexX: xv,
      vertexY: yv,
      samplePoints: samplePoints,
    );
  }

  /// Analiza paso a paso una función afín o lineal: y = mx + n
  static FunctionAnalysisResult analyzeLinear({
    required int m,
    required int n,
  }) {
    final originalLatex = 'y = ${_formatLinearEquation(m, n)}';
    final List<MathStep> steps = [];
    final List<NotablePoint> notablePoints = [];

    // Paso 1: Pendiente y Ordenada
    final String slopeType = m > 0
        ? r'\text{Creciente}'
        : (m < 0 ? r'\text{Decreciente}' : r'\text{Constante}');

    steps.add(
      MathStep(
        index: 1,
        shortTitle: '1. Pendiente y Ordenada en el origen',
        latexExpression:
            '\\begin{aligned} '
            'm &= $m \\implies $slopeType \\\\[4pt] '
            'n &= $n \\implies (0, $n) '
            '\\end{aligned}',
        pedagogicalNote:
            'La pendiente m indica la inclinación: por cada unidad que avanzamos a la derecha, la gráfica sube o baja m unidades. '
            'La ordenada n es la altura donde la recta cruza el eje vertical.',
      ),
    );

    // Corte Eje Y: (0, n)
    final yIntercept = NotablePoint(
      label: 'Corte Eje Y',
      x: 0,
      y: n.toDouble(),
      latexCoords: '(0, $n)',
      type: PointType.yIntercept,
    );
    notablePoints.add(yIntercept);

    // Corte Eje X: mx + n = 0 => x = -n/m
    String xCutLatex;
    if (m != 0) {
      final xInterceptRational = Rational.raw(-n, m).simplify();
      final pX = NotablePoint(
        label: 'Corte Eje X',
        x: xInterceptRational.toDouble(),
        y: 0,
        latexCoords: '\\left(${xInterceptRational.toLatex()}, \\; 0\\right)',
        type: PointType.xIntercept,
      );
      notablePoints.add(pX);
      xCutLatex =
          'mx + n = 0 \\implies ${AlgebraicLatexFormatter.linearExpression(m, n)} = 0 \\implies x = ${xInterceptRational.toLatex()} \\implies ${pX.latexCoords}';
    } else {
      xCutLatex = n == 0
          ? r'y = 0 \implies \text{Todo el eje X}'
          : r'y = 0 \implies \text{No corta al eje X}';
    }

    steps.add(
      MathStep(
        index: 2,
        shortTitle: '2. Puntos de corte con los ejes',
        latexExpression:
            '\\begin{aligned} '
            'x &= 0 \\implies (0, $n) \\\\[4pt] '
            'y &= 0 \\implies $xCutLatex '
            '\\end{aligned}',
        pedagogicalNote:
            'Para hallar el corte con el eje X igualamos y = 0 y despejamos x.',
        warningTrick: m == 0 && n != 0
            ? 'Una recta horizontal con n ≠ 0 es paralela al eje X y no tiene puntos de corte con él.'
            : null,
      ),
    );

    // Paso 3: Tabla de valores
    final List<TableValueRow> samplePoints = [];
    final List<int> xValues = [-2, -1, 0, 1, 2];
    final List<String> tableXHeaders = [];
    final List<String> tableYValues = [];

    for (final xVal in xValues) {
      final yVal = m * xVal + n;
      samplePoints.add(TableValueRow(
        x: xVal.toDouble(),
        y: yVal.toDouble(),
        xLatex: '$xVal',
        yLatex: '$yVal',
      ));
      tableXHeaders.add('$xVal');
      tableYValues.add('$yVal');
    }

    final String tableLatex =
        '\\begin{array}{c|ccccc}\n'
        'x & ${tableXHeaders.join(" & ")} \\\\\n'
        '\\hline\n'
        'y & ${tableYValues.join(" & ")}\n'
        '\\end{array}';

    steps.add(
      MathStep(
        index: 3,
        shortTitle: '3. Tabla de valores de la recta',
        latexExpression: tableLatex,
        pedagogicalNote:
            'Para dibujar una recta basta con dos puntos, pero calculamos varios para garantizar que no haya errores de cálculo.',
      ),
    );

    final resolution = StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'm = $m, \\; n = $n',
      decimalApproxLatex: 'm = $m, \\; n = $n',
    );

    return FunctionAnalysisResult(
      resolution: resolution,
      notablePoints: notablePoints,
      a: 0,
      b: m.toDouble(),
      c: n.toDouble(),
      isQuadratic: false,
      samplePoints: samplePoints,
    );
  }

  static String _formatQuadraticEquation(int a, int b, int c) {
    return AlgebraicLatexFormatter.quadraticExpression(a, b, c);
  }

  static String _formatLinearEquation(int m, int n) {
    return AlgebraicLatexFormatter.linearExpression(m, n);
  }
}
