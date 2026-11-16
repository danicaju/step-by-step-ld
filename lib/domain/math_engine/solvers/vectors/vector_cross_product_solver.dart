import '../../core/algebraic_latex_formatter.dart';
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../../models/vector_models.dart';

class VectorCrossProductSolver {
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
            'La segunda componente del producto vectorial lleva un signo menos delante de su determinante 2x2: -(u_{x} \\cdot v_{z} - u_{z} \\cdot v_{x})j.',
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

  static String _halfLatex(Rational areaSq, String areaParallelogram) {
    if (areaSq.isZero) return '0';
    if (areaParallelogram.contains(r'\frac')) {
      return '\\frac{1}{2}\\left($areaParallelogram\\right)';
    }
    return '\\frac{$areaParallelogram}{2}';
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
}
