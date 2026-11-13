import 'dart:math' as math;

import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

/// Operaciones disponibles en el Modo 12 (Vectores 2D / 3D).
enum VectorOperation {
  modulus('|u| Módulo'),
  dotAndAngle('u·v y Ángulo'),
  crossAndArea('u×v y Área'),
  add('u + v'),
  subtract('u - v');

  final String shortLabel;
  const VectorOperation(this.shortLabel);

  bool get needsSecondVector => this != VectorOperation.modulus;
}

/// Vector exacto en 2D o 3D con componentes racionales ([Rational]).
class RationalVector {
  final int dimension; // 2 o 3
  final Rational x;
  final Rational y;
  final Rational z;

  RationalVector._({
    required this.dimension,
    required this.x,
    required this.y,
    required this.z,
  });

  factory RationalVector.d2(Rational x, Rational y) =>
      RationalVector._(dimension: 2, x: x, y: y, z: Rational(0));

  factory RationalVector.d3(Rational x, Rational y, Rational z) =>
      RationalVector._(dimension: 3, x: x, y: y, z: z);

  factory RationalVector.fromInts(List<int> coords) {
    if (coords.length == 2) {
      return RationalVector.d2(Rational(coords[0]), Rational(coords[1]));
    }
    if (coords.length == 3) {
      return RationalVector.d3(
        Rational(coords[0]),
        Rational(coords[1]),
        Rational(coords[2]),
      );
    }
    throw const FormatException('Un vector debe tener 2 o 3 coordenadas.');
  }

  factory RationalVector.fromRationals(List<Rational> coords) {
    if (coords.length == 2) {
      return RationalVector.d2(coords[0], coords[1]);
    }
    if (coords.length == 3) {
      return RationalVector.d3(coords[0], coords[1], coords[2]);
    }
    throw const FormatException('Un vector debe tener 2 o 3 coordenadas.');
  }

  bool get isZero => x.isZero && y.isZero && (dimension == 2 || z.isZero);

  Rational normSquared() => x * x + y * y + (dimension == 3 ? z * z : Rational(0));

  double normDouble() => math.sqrt(normSquared().toDouble());

  Rational dot(RationalVector other) =>
      x * other.x + y * other.y + z * other.z;

  RationalVector cross(RationalVector other) => RationalVector.d3(
        y * other.z - z * other.y,
        -(x * other.z - z * other.x),
        x * other.y - y * other.x,
      );

  RationalVector operator +(RationalVector other) {
    final dim = math.max(dimension, other.dimension);
    return dim == 2
        ? RationalVector.d2(x + other.x, y + other.y)
        : RationalVector.d3(x + other.x, y + other.y, z + other.z);
  }

  RationalVector operator -(RationalVector other) {
    final dim = math.max(dimension, other.dimension);
    return dim == 2
        ? RationalVector.d2(x - other.x, y - other.y)
        : RationalVector.d3(x - other.x, y - other.y, z - other.z);
  }

  String toLatex() {
    if (dimension == 2) {
      return '\\left(${x.toLatex()},\\; ${y.toLatex()}\\right)';
    }
    return '\\left(${x.toLatex()},\\; ${y.toLatex()},\\; ${z.toLatex()}\\right)';
  }

  /// Notación compacta `(x, y, z)` sin delimitadores altos para comparaciones y resúmenes.
  String toCompactLatex() {
    if (dimension == 2) {
      return '(${x.toLatex()}, ${y.toLatex()})';
    }
    return '(${x.toLatex()}, ${y.toLatex()}, ${z.toLatex()})';
  }

  @override
  bool operator ==(Object other) =>
      other is RationalVector &&
      other.dimension == dimension &&
      other.x == x &&
      other.y == y &&
      other.z == z;

  @override
  int get hashCode => Object.hash(dimension, x, y, z);
}

/// Resultado estructurado de operaciones vectoriales para facilitar aserciones y tutoría.
class VectorAnalysisResult {
  final Rational? dotValue;
  final RationalVector? resultVector;
  final double? angleDegrees;
  final String exactNormLatex;
  final StepByStepResolution resolution;

  const VectorAnalysisResult({
    this.dotValue,
    this.resultVector,
    this.angleDegrees,
    this.exactNormLatex = '',
    required this.resolution,
  });
}

/// Solver paso a paso de Geometría Vectorial 2D y 3D para 1.º y 2.º de Bachillerato.
class VectorSolver {
  static StepByStepResolution solve({
    required VectorOperation operation,
    required RationalVector u,
    RationalVector? v,
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

  /// Producto vectorial `u × v` en 3D y área del paralelogramo y del triángulo.
  static VectorAnalysisResult analyzeCrossProductAndArea(
    RationalVector u,
    RationalVector v,
  ) {
    final u3 = u.dimension == 3
        ? u
        : RationalVector.d3(u.x, u.y, Rational(0));
    final v3 = v.dimension == 3
        ? v
        : RationalVector.d3(v.x, v.y, Rational(0));

    final w = u3.cross(v3);

    // Determinante 3x3 simbólico i, j, k
    final det3Latex =
        '\\vec{u} \\times \\vec{v} = \\left|\\begin{array}{ccc}\n'
        '\\vec{i} & \\vec{j} & \\vec{k} \\\\\n'
        '${u3.x.toLatex()} & ${u3.y.toLatex()} & ${u3.z.toLatex()} \\\\\n'
        '${v3.x.toLatex()} & ${v3.y.toLatex()} & ${v3.z.toLatex()}\n'
        '\\end{array}\\right|';

    // Desarrollo por adjuntos con signo MENOS explícito delante de j
    final minorILatex =
        '\\left|\\begin{array}{cc}\n${u3.y.toLatex()} & ${u3.z.toLatex()} \\\\\n${v3.y.toLatex()} & ${v3.z.toLatex()}\n\\end{array}\\right|';
    final minorJLatex =
        '\\left|\\begin{array}{cc}\n${u3.x.toLatex()} & ${u3.z.toLatex()} \\\\\n${v3.x.toLatex()} & ${v3.z.toLatex()}\n\\end{array}\\right|';
    final minorKLatex =
        '\\left|\\begin{array}{cc}\n${u3.x.toLatex()} & ${u3.y.toLatex()} \\\\\n${v3.x.toLatex()} & ${v3.y.toLatex()}\n\\end{array}\\right|';

    final detJVal = u3.x * v3.z - u3.z * v3.x;
    final adjStepLatex =
        '$minorILatex\\vec{i} - $minorJLatex\\vec{j} + $minorKLatex\\vec{k} = '
        '\\left(${w.x.toLatex()}\\right)\\vec{i} - \\left(${detJVal.toLatex()}\\right)\\vec{j} + \\left(${w.z.toLatex()}\\right)\\vec{k}';

    final areaSq = w.normSquared();
    final areaParallelogram = AlgebraicLatexFormatter.rationalSqrtLatex(areaSq);
    final areaTriangle = _halfLatex(areaSq, areaParallelogram);
    final areaDec = _formatDecimal(w.normDouble(), decimals: 4);

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Paso 1: Plantear determinante simbólico 3×3',
        latexExpression: det3Latex,
        pedagogicalNote:
            (u.dimension == 2 || v.dimension == 2)
                ? 'Como el producto vectorial solo existe en 3D, completamos con z = 0 y colocamos i, j, k en la primera fila.'
                : 'Colocamos los vectores de la base (i, j, k) en la fila superior, u en la segunda y v en la tercera.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Paso 2: Desarrollar adjuntos (cuidado signo en j)',
        latexExpression: adjStepLatex,
        pedagogicalNote:
            'Calculamos cada determinante 2×2 multiplicando en cruz y alternando los signos (+, -, +).',
        warningTrick:
            'La segunda componente del producto vectorial lleva un signo menos delante de su determinante 2x2: -(uₓ·v_z - u_z·vₓ)j.',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Paso 3: Vector perpendicular y área geométrica',
        latexExpression:
            '\\vec{u} \\times \\vec{v} = ${w.toCompactLatex()},\\; \\left|\\vec{u} \\times \\vec{v}\\right| = $areaParallelogram',
        pedagogicalNote: w.isZero
            ? 'El producto vectorial es el vector nulo (0, 0, 0): los vectores u y v son paralelos / linealmente dependientes (área = 0).'
            : 'El vector resultante es perpendicular tanto a u como a v. Su módulo |$areaParallelogram| es el área del paralelogramo y la mitad es el área del triángulo.',
      ),
    ];

    return VectorAnalysisResult(
      resultVector: w,
      exactNormLatex: areaParallelogram,
      resolution: StepByStepResolution(
        originalInputLatex: '${u3.toCompactLatex()} \\times ${v3.toCompactLatex()}',
        steps: steps,
        exactResultLatex: '\\vec{u} \\times \\vec{v} = ${w.toCompactLatex()}',
        decimalApproxLatex:
            '${w.toCompactLatex()},\\; A_{\\text{paralelogramo}} \\approx $areaDec,\\; A_{\\triangle} = $areaTriangle',
      ),
    );
  }

  static StepByStepResolution crossProductAndArea(
    RationalVector u,
    RationalVector v,
  ) =>
      analyzeCrossProductAndArea(u, v).resolution;

  static StepByStepResolution add(RationalVector u, RationalVector v) {
    final dim = math.max(u.dimension, v.dimension);
    final uu = dim == 2 ? u : RationalVector.d3(u.x, u.y, u.z);
    final vv = dim == 2 ? v : RationalVector.d3(v.x, v.y, v.z);
    final res = uu + vv;
    final opParts = [
      '${uu.x.toLatex()} ${_signedTail(vv.x)}',
      '${uu.y.toLatex()} ${_signedTail(vv.y)}',
      if (dim == 3) '${uu.z.toLatex()} ${_signedTail(vv.z)}',
    ].join(',\\; ');

    return StepByStepResolution(
      originalInputLatex: '${uu.toCompactLatex()} + ${vv.toCompactLatex()}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Sumar coordenada a coordenada',
          latexExpression: '\\vec{u} + \\vec{v} = \\left($opParts\\right) = ${res.toCompactLatex()}',
          pedagogicalNote:
              'Para sumar vectores operamos cada componente homóloga por separado.',
        ),
      ],
      exactResultLatex: '\\vec{u} + \\vec{v} = ${res.toCompactLatex()}',
      decimalApproxLatex: res.toCompactLatex(),
    );
  }

  static StepByStepResolution subtract(RationalVector u, RationalVector v) {
    final dim = math.max(u.dimension, v.dimension);
    final uu = dim == 2 ? u : RationalVector.d3(u.x, u.y, u.z);
    final vv = dim == 2 ? v : RationalVector.d3(v.x, v.y, v.z);
    final res = uu - vv;
    final opParts = [
      '${uu.x.toLatex()} - ${_wrapNeg(vv.x)}',
      '${uu.y.toLatex()} - ${_wrapNeg(vv.y)}',
      if (dim == 3) '${uu.z.toLatex()} - ${_wrapNeg(vv.z)}',
    ].join(',\\; ');

    return StepByStepResolution(
      originalInputLatex: '${uu.toCompactLatex()} - ${vv.toCompactLatex()}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Restar coordenada a coordenada',
          latexExpression: '\\vec{u} - \\vec{v} = \\left($opParts\\right) = ${res.toCompactLatex()}',
          pedagogicalNote:
              'Restamos cada componente de v a la correspondiente de u.',
          warningTrick:
              'Restar una componente negativa equivale a sumarla: a - (-b) = a + b.',
        ),
      ],
      exactResultLatex: '\\vec{u} - \\vec{v} = ${res.toCompactLatex()}',
      decimalApproxLatex: res.toCompactLatex(),
    );
  }

  static String _wrapNeg(Rational r) {
    if (r.isNegative || !r.isInteger) {
      return '\\left(${r.toLatex()}\\right)';
    }
    return r.toLatex();
  }

  static String _signedTail(Rational r) {
    if (r.isNegative) {
      return '- ${(-r).toLatex()}';
    }
    return '+ ${r.toLatex()}';
  }

  static String _squareTermsLatex(RationalVector u) {
    final items = [
      '${_wrapNeg(u.x)}^{2}',
      '${_wrapNeg(u.y)}^{2}',
      if (u.dimension == 3) '${_wrapNeg(u.z)}^{2}',
    ];
    return items.join(' + ');
  }

  static String _evaluatedSquareTermsLatex(RationalVector u) {
    final items = [
      (u.x * u.x).toLatex(),
      (u.y * u.y).toLatex(),
      if (u.dimension == 3) (u.z * u.z).toLatex(),
    ];
    return items.join(' + ');
  }

  static String _signedSum(List<Rational> vals) {
    final buf = StringBuffer();
    for (int i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (i == 0) {
        buf.write(v.toLatex());
      } else if (v.isNegative) {
        buf.write(' - ${(-v).toLatex()}');
      } else {
        buf.write(' + ${v.toLatex()}');
      }
    }
    return buf.toString();
  }

  static Rational? _exactCosineRatioIfRational(Rational dot, Rational prodNormSq) {
    if (dot.isZero) return Rational(0);
    if (!prodNormSq.isInteger) {
      // Comprobamos si numerador y denominador son cuadrados perfectos
      final n = prodNormSq.numerator;
      final d = prodNormSq.denominator;
      final rn = math.sqrt(n).round();
      final rd = math.sqrt(d).round();
      if (rn * rn == n && rd * rd == d) {
        return dot / Rational(rn, rd);
      }
      return null;
    }
    final s = prodNormSq.numerator;
    final r = math.sqrt(s).round();
    if (r * r == s) {
      return dot / Rational(r);
    }
    return null;
  }

  static int? _detectNotableAngleDeg(Rational dot, Rational prodNormSq) {
    if (dot.isZero) return 90;
    // cos^2(alpha) = dot^2 / prodNormSq
    final cosSq = (dot * dot) / prodNormSq;
    final isPos = dot.isPositive;
    if (cosSq == Rational(1)) return isPos ? 0 : 180;
    if (cosSq == Rational(3, 4)) return isPos ? 30 : 150;
    if (cosSq == Rational(1, 2)) return isPos ? 45 : 135;
    if (cosSq == Rational(1, 4)) return isPos ? 60 : 120;
    return null;
  }

  static String _halfLatex(Rational areaSq, String areaParallelogram) {
    final halfSq = areaSq / Rational(4);
    if (areaParallelogram == '0') return '0';
    return AlgebraicLatexFormatter.rationalSqrtLatex(halfSq);
  }

  static String _formatDecimal(double val, {int decimals = 4}) {
    final s = val.toStringAsFixed(decimals)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', ',');
  }

  static String _formatLatexDec(double val, {int decimals = 2}) {
    final s = val.toStringAsFixed(decimals)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', '{,}');
  }
}
