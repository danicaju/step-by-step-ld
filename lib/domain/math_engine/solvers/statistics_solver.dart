import 'dart:math' as math;

import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

/// Par estadístico `(x_i, f_i)` para el cálculo de 1 variable.
class StatDataPoint {
  final Rational xi;
  final int fi;

  const StatDataPoint(this.xi, [this.fi = 1]);
}

/// Resultado completo del análisis estadístico unidimensional.
class StatisticsResult {
  final int nTotal;
  final Rational mean;
  final Rational variance;
  final double stdDevDouble;
  final String stdDevLatex;
  final List<Rational> modes;
  final Rational median;
  final Rational q1;
  final Rational q3;
  final StepByStepResolution resolution;

  const StatisticsResult({
    required this.nTotal,
    required this.mean,
    required this.variance,
    required this.stdDevDouble,
    required this.stdDevLatex,
    required this.modes,
    required this.median,
    required this.q1,
    required this.q3,
    required this.resolution,
  });
}

class _GroupedStatRow {
  final Rational xi;
  final int fi;
  final int cumulativeFi;
  final Rational xiFi;
  final Rational xi2Fi;

  const _GroupedStatRow({
    required this.xi,
    required this.fi,
    required this.cumulativeFi,
    required this.xiFi,
    required this.xi2Fi,
  });
}

class StatisticsOneVarSolver {
  /// Resuelve una tabla o lista de datos `(x_i, f_i)` devolviendo el `StepByStepResolution`.
  static StepByStepResolution solve(List<StatDataPoint> data) {
    return analyze(data).resolution;
  }

  /// Variante ergonómica que acepta pares posicionales de Dart 3 `[(Rational xi, int fi)]`.
  static StepByStepResolution solvePairs(List<(Rational, int)> pairs) {
    final converted = [
      for (final (xi, fi) in pairs) StatDataPoint(xi, fi),
    ];
    return analyze(converted).resolution;
  }

  /// Realiza el cálculo completo con medidas de centralización, dispersión y posición.
  static StatisticsResult analyze(List<StatDataPoint> data) {
    if (data.isEmpty) {
      throw const FormatException('Introduce al menos un dato (xᵢ, fᵢ) en la tabla.');
    }

    // 1. Agrupar x_i repetidos sumando sus frecuencias y ordenar ascendentemente
    final Map<Rational, int> groupedMap = {};
    for (final point in data) {
      if (point.fi <= 0) {
        throw FormatException(
          'La frecuencia absoluta fᵢ debe ser un entero positivo (recibido ${point.fi}).',
        );
      }
      groupedMap[point.xi] = (groupedMap[point.xi] ?? 0) + point.fi;
    }

    final sortedKeys = groupedMap.keys.toList()
      ..sort((a, b) => (a.numerator * b.denominator).compareTo(b.numerator * a.denominator));
    final List<_GroupedStatRow> rows = [];
    int cumFi = 0;
    Rational sumXiFi = Rational(0);
    Rational sumXi2Fi = Rational(0);

    for (final xi in sortedKeys) {
      final fi = groupedMap[xi]!;
      cumFi += fi;
      final fiRat = Rational(fi);
      final xiFi = xi * fiRat;
      final xi2Fi = xi * xi * fiRat;
      sumXiFi += xiFi;
      sumXi2Fi += xi2Fi;

      rows.add(
        _GroupedStatRow(
          xi: xi,
          fi: fi,
          cumulativeFi: cumFi,
          xiFi: xiFi,
          xi2Fi: xi2Fi,
        ),
      );
    }

    final int nTotal = cumFi;
    final Rational nRat = Rational(nTotal);

    // 2. Media, Varianza y Desviación Típica (aritmética exacta con Rational)
    final Rational mean = sumXiFi / nRat;
    final Rational sumSqOverN = sumXi2Fi / nRat;
    final Rational meanSq = mean * mean;
    final Rational variance = sumSqOverN - meanSq;

    final double varDouble = variance.toDouble() < 0 ? 0.0 : variance.toDouble();
    final double stdDevDouble = math.sqrt(varDouble);
    final (:exactLatex, :isExactRational) = _simplifySquareRootRational(variance);
    final String stdDevDec = _formatDecimal(stdDevDouble);

    // 3. Moda, Mediana y Cuartiles Q1, Q3
    int maxFi = 0;
    for (final r in rows) {
      if (r.fi > maxFi) maxFi = r.fi;
    }
    final modeList = [
      for (final r in rows)
        if (r.fi == maxFi) r.xi,
    ];
    final bool isAmodal = rows.length > 1 && modeList.length == rows.length;

    final Rational median = _quantileFromCumulative(rows, nTotal, numFactor: 2, denFactor: 4);
    final Rational q1 = _quantileFromCumulative(rows, nTotal, numFactor: 1, denFactor: 4);
    final Rational q3 = _quantileFromCumulative(rows, nTotal, numFactor: 3, denFactor: 4);

    // -------------------------------------------------------------------------
    // Construcción de los 4 Pasos en LaTeX puro compatible con flutter_math_fork
    // -------------------------------------------------------------------------
    final List<MathStep> steps = [];

    // PASO 1: Tabla completa (xi | fi | Fi | xi*fi | xi^2*fi)
    final tableRowsLatex = rows.map((r) {
      return '${r.xi.toLatex()} & ${r.fi} & ${r.cumulativeFi} & ${r.xiFi.toLatex()} & ${r.xi2Fi.toLatex()}';
    }).join(' \\\\\n');

    final step1TableLatex =
        '\\begin{array}{c|c|c|c|c}\n'
        'x_i & f_i & F_i & x_i \\cdot f_i & x_i^2 \\cdot f_i \\\\\n'
        '\\hline\n'
        '$tableRowsLatex \\\\\n'
        '\\hline\n'
        '\\Sigma & N = $nTotal & - & ${sumXiFi.toLatex()} & ${sumXi2Fi.toLatex()}\n'
        '\\end{array}';

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Tabla de frecuencias y acumulados',
        latexExpression: step1TableLatex,
        pedagogicalNote:
            'Calculamos Fᵢ sumando las frecuencias absolutas fᵢ acumuladas hasta llegar a N = $nTotal. '
            'Después añadimos las columnas xᵢ·fᵢ y xᵢ²·fᵢ con sus sumas totales al pie de la tabla.',
      ),
    );

    // PASO 2: Media aritmética
    final meanSubst = _formatRationalOverN(sumXiFi, nTotal);
    final meanExpr = meanSubst == mean.toLatex()
        ? '\\bar{x} = \\frac{\\sum x_i \\cdot f_i}{N} = ${mean.toLatex()}'
        : '\\bar{x} = \\frac{\\sum x_i \\cdot f_i}{N} = $meanSubst = ${mean.toLatex()}';
    final meanFullLatex = mean.denominator == 1
        ? meanExpr
        : '$meanExpr \\approx ${mean.toDecimalLatex()}';

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Media aritmética (x̄)',
        latexExpression: meanFullLatex,
        pedagogicalNote:
            'Dividimos la suma total de la columna xᵢ·fᵢ (${sumXiFi.toLatex()}) entre el número total de datos N = $nTotal. '
            'Resultado: x̄ = ${mean.toLatex()}${mean.denominator == 1 ? '' : ' ≈ ${mean.toDecimalLatex()}'}.',
      ),
    );

    // PASO 3: Varianza y Desviación típica
    final meanBaseWrapped = _wrapBaseForSquare(mean);
    final sumSqSubst = _formatRationalOverN(sumXi2Fi, nTotal);
    final sigmaFinal = isExactRational
        ? exactLatex
        : '$exactLatex \\approx $stdDevDec';
    final varianceLine =
        '\\sigma^2 = \\frac{\\sum x_i^2 \\cdot f_i}{N} - \\bar{x}^2 = '
        '$sumSqSubst - $meanBaseWrapped^2 = '
        '${sumSqOverN.toLatex()} - ${meanSq.toLatex()} = ${variance.toLatex()}';
    final stdDevLine = variance.numerator == 0
        ? '\\sigma = \\sqrt{0} = 0'
        : '\\sigma = \\sqrt{${variance.toLatex()}} = $sigmaFinal';

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Varianza (σ²) y Desviación típica (σ)',
        latexExpression:
            '\\begin{aligned}\n$varianceLine \\\\\n$stdDevLine\n\\end{aligned}',
        pedagogicalNote:
            'Calculamos la varianza restando el cuadrado de la media a la media de los cuadrados (σ² = ${variance.toLatex()}). '
            'La desviación típica es su raíz cuadrada: σ = $stdDevDec.',
        warningTrick:
            'En σ² = (Σxᵢ²·fᵢ / N) - x̄², eleva cada xᵢ al cuadrado en la tabla antes de multiplicar por fᵢ, y extrae la raíz cuadrada al final para obtener σ.',
      ),
    );

    // PASO 4: Moda, Mediana y Cuartiles
    final String modeLatex = isAmodal
        ? r'\text{Amodal}'
        : modeList.map((m) => m.toLatex()).join(', \\; ');
    final nOver2Str = Rational.raw(nTotal, 2).simplify().toLatex();
    final nOver4Str = Rational.raw(nTotal, 4).simplify().toLatex();
    final threeNOver4Str = Rational.raw(3 * nTotal, 4).simplify().toLatex();

    final step4Latex =
        '\\begin{aligned}\n'
        'M_o &= $modeLatex \\\\\n'
        'M_e &= ${median.toLatex()} \\qquad \\left(\\frac{N}{2} = $nOver2Str\\right) \\\\\n'
        'Q_1 &= ${q1.toLatex()}, \\quad Q_3 = ${q3.toLatex()}\n'
        '\\end{aligned}';

    steps.add(
      MathStep(
        index: 4,
        shortTitle: 'Moda (Mo), Mediana (Me) y Cuartiles (Q₁, Q₃)',
        latexExpression: step4Latex,
        pedagogicalNote:
            'La Moda M_o es el valor con mayor frecuencia fᵢ ($maxFi). '
            'Para hallar la Mediana M_e buscamos N/2 = $nOver2Str en la columna de frecuencias acumuladas Fᵢ '
            '(el primer Fᵢ ≥ N/2; si coincide exacto con N/2, promediamos ese xᵢ y el siguiente). '
            'Del mismo modo hallamos Q₁ buscando N/4 = $nOver4Str y Q₃ buscando 3N/4 = $threeNOver4Str en Fᵢ.',
      ),
    );

    final origDesc = rows.length <= 5
        ? rows.map((r) => '(${r.xi.toLatex()}, ${r.fi})').join(', \\; ')
        : '${rows.length} \\text{ filas}, \\; N = $nTotal';

    final exactResult =
        '\\bar{x} = ${mean.toLatex()}, \\; \\sigma^2 = ${variance.toLatex()}, \\; \\sigma = $exactLatex';
    final decimalApprox =
        '\\bar{x} = ${mean.toDecimalLatex()}, \\; \\sigma^2 = ${variance.toDecimalLatex()}, \\; \\sigma = $stdDevDec';

    final resolution = StepByStepResolution(
      originalInputLatex: origDesc,
      steps: steps,
      exactResultLatex: exactResult,
      decimalApproxLatex: decimalApprox,
    );

    return StatisticsResult(
      nTotal: nTotal,
      mean: mean,
      variance: variance,
      stdDevDouble: stdDevDouble,
      stdDevLatex: exactLatex,
      modes: isAmodal ? const [] : modeList,
      median: median,
      q1: q1,
      q3: q3,
      resolution: resolution,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers privados
  // ---------------------------------------------------------------------------

  static Rational _quantileFromCumulative(
    List<_GroupedStatRow> rows,
    int nTotal, {
    required int numFactor,
    required int denFactor,
  }) {
    final int scaledTarget = numFactor * nTotal;
    for (int i = 0; i < rows.length; i++) {
      final int scaledCum = denFactor * rows[i].cumulativeFi;
      if (scaledCum == scaledTarget && i + 1 < rows.length) {
        return (rows[i].xi + rows[i + 1].xi) / Rational(2);
      }
      if (scaledCum >= scaledTarget) {
        return rows[i].xi;
      }
    }
    return rows.last.xi;
  }

  static String _formatRationalOverN(Rational sum, int n) {
    if (sum.denominator == 1) {
      return '\\frac{${sum.numerator}}{$n}';
    }
    return '\\frac{${sum.toLatex()}}{$n}';
  }

  static String _wrapBaseForSquare(Rational r) {
    if (r.denominator != 1 || r.isNegative) {
      return '\\left(${r.toLatex()}\\right)';
    }
    return r.toLatex();
  }

  static ({String exactLatex, bool isExactRational}) _simplifySquareRootRational(
    Rational r,
  ) {
    if (r.numerator <= 0) {
      return (exactLatex: '0', isExactRational: true);
    }
    final int p = r.numerator;
    final int q = r.denominator;
    final int product = p * q;

    int outFactor = 1;
    int radicand = product;
    for (int f = math.sqrt(product).toInt(); f >= 2; f--) {
      if (product % (f * f) == 0) {
        outFactor = f;
        radicand = product ~/ (f * f);
        break;
      }
    }

    final Rational coeff = Rational.raw(outFactor, q).simplify();
    if (radicand == 1) {
      return (exactLatex: coeff.toLatex(), isExactRational: true);
    }

    if (coeff.denominator == 1) {
      return (
        exactLatex: AlgebraicLatexFormatter.radical(coeff.numerator, radicand),
        isExactRational: false,
      );
    }

    final numCoeff = coeff.numerator == 1 ? '' : '${coeff.numerator}';
    return (
      exactLatex: '\\frac{$numCoeff\\sqrt{$radicand}}{${coeff.denominator}}',
      isExactRational: false,
    );
  }

  static String _formatDecimal(double val) {
    if ((val - val.roundToDouble()).abs() < 1e-9) {
      return '${val.round()}';
    }
    String s = val.toStringAsFixed(6);
    while (s.contains('.') && s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
    return s.replaceAll('.', ',');
  }
}
