import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../../models/vector_models.dart';

/// Producto mixto [u, v, w] = u . (v x w) = det(u, v, w) y volumen del paralelepipedo.
class VectorMixedProductSolver {
  static StepByStepResolution mixedProduct(
    RationalVector u,
    RationalVector v,
    RationalVector w,
  ) {
    RationalVector as3(RationalVector a) =>
        a.dimension == 3 ? a : RationalVector.d3(a.x, a.y, Rational(0));
    final a = as3(u);
    final b = as3(v);
    final c = as3(w);
    final cross = b.cross(c);
    final value = a.dot(cross);
    final volume = value.abs();
    String row(RationalVector p) => '${p.x.toLatex()} & ${p.y.toLatex()} & ${p.z.toLatex()}';
    final detLatex = '\\left|\\begin{array}{ccc}${row(a)} \\\\ ${row(b)} \\\\ ${row(c)}\\end{array}\\right|';

    return StepByStepResolution(
      originalInputLatex: '[\\vec{u}, \\vec{v}, \\vec{w}]',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Paso 1: Determinante de las tres filas',
          latexExpression: '[\\vec{u}, \\vec{v}, \\vec{w}] = $detLatex',
          pedagogicalNote:
              'El producto mixto es el determinante 3x3 cuyas filas son las coordenadas de u, v y w.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Paso 2: Producto vectorial v x w y producto escalar',
          latexExpression: '\\vec{v} \\times \\vec{w} = (${cross.x.toLatex()}, ${cross.y.toLatex()}, ${cross.z.toLatex()})'
              '\\;\\Rightarrow\\; \\vec{u} \\cdot (\\vec{v} \\times \\vec{w}) = ${value.toLatex()}',
          pedagogicalNote: 'Calculamos v x w y lo multiplicamos escalarmente por u.',
        ),
        MathStep(
          index: 3,
          shortTitle: 'Paso 3: Volumen del paralelepipedo',
          latexExpression: 'V = \\left|${value.toLatex()}\\right| = ${volume.toLatex()}\\;u^{3}',
          pedagogicalNote: value.isZero
              ? 'Producto mixto 0: los tres vectores son coplanarios (volumen nulo).'
              : 'El volumen del paralelepípedo es el valor absoluto del producto mixto.',
        ),
        MathStep(
          index: 4,
          shortTitle: 'Paso 4: Volumen del tetraedro',
          latexExpression:
              'V_{tetraedro} = \\frac{|[u,v,w]|}{6} = \\frac{${volume.toLatex()}}{6} = ${(volume / Rational(6)).toLatex()}\\;u^{3}',
          pedagogicalNote: 'El tetraedro que forman los tres vectores es la sexta parte del paralelepípedo.',
        ),
      ],
      exactResultLatex: '[\\vec{u}, \\vec{v}, \\vec{w}] = ${value.toLatex()}',
      decimalApproxLatex: '',
    );
  }
}
