import 'dart:math' as math;

import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../models/vector_models.dart';
import 'vectors/vector_cross_product_solver.dart';
import 'vectors/vector_mixed_product_solver.dart';

export '../models/vector_models.dart';
export 'vectors/vector_cross_product_solver.dart';

/// Solver paso a paso de Geometría Vectorial 2D y 3D para 1.º y 2.º de Bachillerato.
class VectorSolver {
  static StepByStepResolution solve({
    required VectorOperation operation,
    required RationalVector u,
    RationalVector? v,
    RationalVector? w,
  }) {
    return switch (operation) {
      VectorOperation.modulus => modulus(u),
      VectorOperation.dotAndAngle => dotProductAndAngle(
          u,
          v ?? RationalVector.fromInts(u.dimension == 2 ? [1, 0] : [1, 0, 0]),
        ),
      VectorOperation.crossAndArea => crossProductAndArea(
          u,
          v ?? RationalVector.fromInts([0, 1, 0]),
        ),
      VectorOperation.add => add(
          u,
          v ?? RationalVector.fromInts(u.dimension == 2 ? [0, 0] : [0, 0, 0]),
        ),
      VectorOperation.mixedProduct => mixedProduct(
          u,
          v ?? RationalVector.fromInts([0, 1, 0]),
          w ?? RationalVector.fromInts([0, 0, 1]),
        ),
      VectorOperation.subtract => subtract(
          u,
          v ?? RationalVector.fromInts(u.dimension == 2 ? [0, 0] : [0, 0, 0]),
        ),
    };
  }

  /// Módulo de un vector `|u|` con simplificación exacta de radicales (ej. `\sqrt{18} = 3\sqrt{2}`).
  static StepByStepResolution modulus(RationalVector u) {
    final normSq = u.normSquared();
    final exactNorm = AlgebraicLatexFormatter.rationalSqrtLatex(normSq);
    final sqParts = _squareTermsLatex(u);
    final evalParts = _evaluatedSquareTermsLatex(u);

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Suma de cuadrados de las componentes',
        latexExpression:
            '\\left|\\vec{u}\\right| = \\sqrt{$sqParts} = \\sqrt{$evalParts} = \\sqrt{${normSq.toLatex()}}',
        pedagogicalNote:
            'Aplicamos el Teorema de Pitágoras en ${u.dimension}D elevando cada componente al cuadrado y sumando los resultados.',
        warningTrick: (u.x.isNegative || u.y.isNegative || (u.dimension == 3 && u.z.isNegative))
            ? 'Al elevar al cuadrado una componente negativa, el resultado siempre es positivo: (-a)² = +a².'
            : null,
      ),
    ];

    if (normSq.isInteger && !normSq.isZero) {
      final n = normSq.numerator;
      final decomp = AlgebraicLatexFormatter.decomposeIntSqrt(n);
      if (decomp.isExactSquare) {
        steps.add(
          MathStep(
            index: 2,
            shortTitle: 'Raíz cuadrada exacta',
            latexExpression:
                '\\left|\\vec{u}\\right| = \\sqrt{$n} = $exactNorm',
            pedagogicalNote:
                '$n es un cuadrado perfecto, por lo que el módulo del vector es un valor exacto entero.',
          ),
        );
      } else if (decomp.outside > 1) {
        steps.add(
          MathStep(
            index: 2,
            shortTitle: 'Extracción de factores del radical',
            latexExpression:
                '\\left|\\vec{u}\\right| = \\sqrt{${decomp.groupedLatex}} = $exactNorm',
            pedagogicalNote:
                'Factorizamos $n en primos y extraemos fuera de la raíz los factores elevados al cuadrado para dejar el radical simplificado.',
          ),
        );
      } else {
        steps.add(
          MathStep(
            index: 2,
            shortTitle: 'Radical irreducible',
            latexExpression: '\\left|\\vec{u}\\right| = $exactNorm',
            pedagogicalNote:
                '$n no contiene factores cuadrados repetidos, así que $exactNorm ya es su expresión radical exacta.',
          ),
        );
      }
    } else if (!normSq.isZero) {
      steps.add(
        MathStep(
          index: 2,
          shortTitle: 'Simplificación racional del módulo',
          latexExpression: '\\left|\\vec{u}\\right| = $exactNorm',
          pedagogicalNote:
              'Calculamos la raíz de la fracción racionalizando el denominador en su forma exacta irreducible.',
        ),
      );
    }

    final dec = u.normDouble();
    final decStr = _formatDecimal(dec);
    return StepByStepResolution(
      originalInputLatex: '\\left|${u.toCompactLatex()}\\right|',
      steps: steps,
      exactResultLatex: '\\left|\\vec{u}\\right| = $exactNorm',
      decimalApproxLatex: decStr,
    );
  }

  /// Producto escalar `u · v` y ángulo `α` entre ambos vectores en grados.
  static VectorAnalysisResult analyzeDotAndAngle(
    RationalVector u,
    RationalVector v,
  ) {
    final dim = math.max(u.dimension, v.dimension);
    final uu = dim == 2 ? u : RationalVector.d3(u.x, u.y, u.z);
    final vv = dim == 2 ? v : RationalVector.d3(v.x, v.y, v.z);

    final dotVal = uu.dot(vv);
    final termProd = [
      '${_wrapNeg(uu.x)} \\cdot ${_wrapNeg(vv.x)}',
      '${_wrapNeg(uu.y)} \\cdot ${_wrapNeg(vv.y)}',
      if (dim == 3) '${_wrapNeg(uu.z)} \\cdot ${_wrapNeg(vv.z)}',
    ].join(' + ');

    final partialTerms = [
      uu.x * vv.x,
      uu.y * vv.y,
      if (dim == 3) uu.z * vv.z,
    ];
    final partialSumLatex = _signedSum(partialTerms);

    final bool isOrthogonal =
        dotVal.isZero && !uu.isZero && !vv.isZero;

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Paso 1: Producto escalar u · v',
        latexExpression:
            '\\vec{u} \\cdot \\vec{v} = $termProd = $partialSumLatex = ${dotVal.toLatex()}',
        pedagogicalNote: isOrthogonal
            ? 'Multiplicamos componente a componente y sumamos. Como u · v = 0 y ninguno es el vector nulo, los vectores son ORTOGONALES (perpendiculares, 90°).'
            : 'Multiplicamos las componentes homólogas y sumamos algebraicamente. Un producto escalar siempre devuelve un número real (escalar), no un vector.',
        warningTrick: isOrthogonal
            ? 'Dos vectores no nulos son perpendiculares (90°) si y solo si u · v = 0.'
            : null,
      ),
    ];

    if (uu.isZero || vv.isZero) {
      steps.add(
        const MathStep(
          index: 2,
          shortTitle: 'Paso 2: Ángulo no definido con vector nulo',
          latexExpression: '\\left|\\vec{u}\\right| = 0 \\lor \\left|\\vec{v}\\right| = 0',
          pedagogicalNote:
              'Al ser uno de los vectores el vector nulo (0), su dirección está indeterminada y no se puede calcular el coseno del ángulo.',
        ),
      );
      return VectorAnalysisResult(
        dotValue: dotVal,
        angleDegrees: null,
        resolution: StepByStepResolution(
          originalInputLatex: '${uu.toCompactLatex()} \\cdot ${vv.toCompactLatex()}',
          steps: steps,
          exactResultLatex: '\\vec{u} \\cdot \\vec{v} = 0',
          decimalApproxLatex: '0',
        ),
      );
    }

    final normSqU = uu.normSquared();
    final normSqV = vv.normSquared();
    final normULatex = AlgebraicLatexFormatter.rationalSqrtLatex(normSqU);
    final normVLatex = AlgebraicLatexFormatter.rationalSqrtLatex(normSqV);
    final prodNormSq = normSqU * normSqV;
    final denomExactLatex = AlgebraicLatexFormatter.rationalSqrtLatex(prodNormSq);

    // Determinamos si |u|*|v| es racional exacto (prodNormSq es cuadrado racional)
    final cosExactFraction = _exactCosineRatioIfRational(dotVal, prodNormSq);
    final cosVal = dotVal.toDouble() / (uu.normDouble() * vv.normDouble());
    final clampedCos = cosVal.clamp(-1.0, 1.0);
    final angleRad = math.acos(clampedCos);
    final angleDeg = angleRad * 180.0 / math.pi;

    final notableAngle = _detectNotableAngleDeg(dotVal, prodNormSq);
    final degRounded = notableAngle != null ? '$notableAngle' : _formatDecimal(angleDeg, decimals: 2);

    final cosExpr = cosExactFraction != null
        ? '\\cos(\\alpha) = \\frac{${dotVal.toLatex()}}{$denomExactLatex} = ${cosExactFraction.toLatex()}'
        : '\\cos(\\alpha) = \\frac{${dotVal.toLatex()}}{$normULatex \\cdot $normVLatex} = \\frac{${dotVal.toLatex()}}{$denomExactLatex}';

    final angleExpr = notableAngle != null
        ? '$cosExpr \\implies \\alpha = $notableAngle^{\\circ}'
        : '$cosExpr \\implies \\alpha = \\arccos\\left(${_formatDecimal(clampedCos, decimals: 4)}\\right) \\approx ${_formatLatexDec(angleDeg, decimals: 2)}^{\\circ}';

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Paso 2: Módulos y ángulo con el coseno',
        latexExpression: angleExpr,
        pedagogicalNote: notableAngle != null
            ? 'Con |u| = $normULatex y |v| = $normVLatex, el coseno corresponde al ángulo notable exacto α = $notableAngle°.'
            : 'Con |u| = $normULatex y |v| = $normVLatex, aplicamos cos(α) = (u · v) / (|u| · |v|) y despejamos α = arccos(...).',
      ),
    );

    final exactResult = notableAngle != null
        ? '\\vec{u} \\cdot \\vec{v} = ${dotVal.toLatex()},\\; \\alpha = $notableAngle^{\\circ}'
        : '\\vec{u} \\cdot \\vec{v} = ${dotVal.toLatex()},\\; \\cos(\\alpha) = \\frac{${dotVal.toLatex()}}{$denomExactLatex}';

    return VectorAnalysisResult(
      dotValue: dotVal,
      angleDegrees: notableAngle?.toDouble() ?? angleDeg,
      exactNormLatex: denomExactLatex,
      resolution: StepByStepResolution(
        originalInputLatex: '${uu.toCompactLatex()} \\cdot ${vv.toCompactLatex()}',
        steps: steps,
        exactResultLatex: exactResult,
        decimalApproxLatex: notableAngle != null
            ? 'u \\cdot v = ${dotVal.toDecimalLatex()},\\; \\alpha = $notableAngle^{\\circ}'
            : 'u \\cdot v = ${dotVal.toDecimalLatex()},\\; \\alpha \\approx $degRounded^{\\circ}',
      ),
    );
  }

  static StepByStepResolution dotProductAndAngle(
    RationalVector u,
    RationalVector v,
  ) =>
      analyzeDotAndAngle(u, v).resolution;

  static VectorAnalysisResult analyzeCrossProductAndArea(
    RationalVector u,
    RationalVector v,
  ) =>
      VectorCrossProductSolver.analyzeCrossProductAndArea(u, v);

  static StepByStepResolution crossProductAndArea(
    RationalVector u,
    RationalVector v,
  ) =>
      VectorCrossProductSolver.crossProductAndArea(u, v);

  static StepByStepResolution mixedProduct(
    RationalVector u,
    RationalVector v,
    RationalVector w,
  ) =>
      VectorMixedProductSolver.mixedProduct(u, v, w);

  static StepByStepResolution add(RationalVector u, RationalVector v) {
    final dim = math.max(u.dimension, v.dimension);
    final uu = dim == 2 ? u : RationalVector.d3(u.x, u.y, u.z);
    final vv = dim == 2 ? v : RationalVector.d3(v.x, v.y, v.z);
    final res = uu + vv;

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Suma componente a componente',
        latexExpression:
            '\\vec{u} + \\vec{v} = \\left(${uu.x.toLatex()} ${_signedTail(vv.x)},\\; '
            '${uu.y.toLatex()} ${_signedTail(vv.y)}'
            '${dim == 3 ? ',\\; ${uu.z.toLatex()} ${_signedTail(vv.z)}' : ''}\\right) = '
            '${res.toLatex()}',
        pedagogicalNote:
            'Sumamos las coordenadas correspondientes (x₁+x₂, y₁+y₂, z₁+z₂).',
      ),
    ];

    return StepByStepResolution(
      originalInputLatex: '${uu.toCompactLatex()} + ${vv.toCompactLatex()}',
      steps: steps,
      exactResultLatex: '\\vec{u} + \\vec{v} = ${res.toCompactLatex()}',
      decimalApproxLatex: res.toCompactLatex(),
    );
  }

  static StepByStepResolution subtract(RationalVector u, RationalVector v) {
    final dim = math.max(u.dimension, v.dimension);
    final uu = dim == 2 ? u : RationalVector.d3(u.x, u.y, u.z);
    final vv = dim == 2 ? v : RationalVector.d3(v.x, v.y, v.z);
    final res = uu - vv;

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Resta componente a componente',
        latexExpression:
            '\\vec{u} - \\vec{v} = \\left(${uu.x.toLatex()} ${_signedTail(-vv.x)},\\; '
            '${uu.y.toLatex()} ${_signedTail(-vv.y)}'
            '${dim == 3 ? ',\\; ${uu.z.toLatex()} ${_signedTail(-vv.z)}' : ''}\\right) = '
            '${res.toLatex()}',
        pedagogicalNote:
            'Restamos cada componente del segundo vector a la del primero (x₁-x₂, y₁-y₂, z₁-z₂).',
      ),
    ];

    return StepByStepResolution(
      originalInputLatex: '${uu.toCompactLatex()} - ${vv.toCompactLatex()}',
      steps: steps,
      exactResultLatex: '\\vec{u} - \\vec{v} = ${res.toCompactLatex()}',
      decimalApproxLatex: res.toCompactLatex(),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers privados
  // ---------------------------------------------------------------------------
  static String _wrapNeg(Rational r) =>
      r.isNegative ? '\\left(${r.toLatex()}\\right)' : r.toLatex();

  static String _signedTail(Rational r) {
    if (r.isNegative) return '- ${r.abs().toLatex()}';
    return '+ ${r.toLatex()}';
  }

  static String _squareTermsLatex(RationalVector u) {
    final parts = [
      '${_wrapNeg(u.x)}^2',
      '${_wrapNeg(u.y)}^2',
      if (u.dimension == 3) '${_wrapNeg(u.z)}^2',
    ];
    return parts.join(' + ');
  }

  static String _evaluatedSquareTermsLatex(RationalVector u) {
    final parts = [
      (u.x * u.x).toLatex(),
      (u.y * u.y).toLatex(),
      if (u.dimension == 3) (u.z * u.z).toLatex(),
    ];
    return parts.join(' + ');
  }

  static String _signedSum(List<Rational> vals) {
    final buf = StringBuffer();
    for (int i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (i == 0) {
        buf.write(v.toLatex());
      } else if (v.isNegative) {
        buf.write(' - ${v.abs().toLatex()}');
      } else {
        buf.write(' + ${v.toLatex()}');
      }
    }
    return buf.toString();
  }

  static Rational? _exactCosineRatioIfRational(Rational dot, Rational prodNormSq) {
    if (dot.isZero) return Rational(0);
    if (!prodNormSq.isInteger) return null;
    final int val = prodNormSq.numerator;
    final int s = math.sqrt(val).round();
    if (s * s == val) {
      return (dot / Rational(s)).simplify();
    }
    return null;
  }

  static int? _detectNotableAngleDeg(Rational dot, Rational prodNormSq) {
    if (dot.isZero) return 90;
    final p = prodNormSq.toDouble();
    if (p <= 0) return null;
    final cosVal = dot.toDouble() / math.sqrt(p);
    final clamped = cosVal.clamp(-1.0, 1.0);
    const tol = 1e-6;

    final candidates = [
      (1.0, 0),
      (math.sqrt(3) / 2.0, 30),
      (math.sqrt(2) / 2.0, 45),
      (0.5, 60),
      (0.0, 90),
      (-0.5, 120),
      (-math.sqrt(2) / 2.0, 135),
      (-math.sqrt(3) / 2.0, 150),
      (-1.0, 180),
    ];

    for (final (c, deg) in candidates) {
      if ((clamped - c).abs() < tol) return deg;
    }
    return null;
  }

  static String _formatDecimal(double val, {int decimals = 4}) {
    if ((val - val.roundToDouble()).abs() < 1e-9) {
      return '${val.round()}';
    }
    String s = val.toStringAsFixed(decimals);
    while (s.contains('.') && s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
    return s.replaceAll('.', ',');
  }

  static String _formatLatexDec(double val, {int decimals = 2}) =>
      _formatDecimal(val, decimals: decimals);
}
