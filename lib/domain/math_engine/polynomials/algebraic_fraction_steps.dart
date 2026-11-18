import '../models/step_resolution.dart';
import '../solvers/equations/eq_poly.dart';
import 'algebraic_fraction_solver.dart';

/// Pasos didacticos de factorizacion para las fracciones algebraicas.
class AlgebraicFractionSteps {
  const AlgebraicFractionSteps._();

  static double _d(Poly p, int n) {
    final r = PolyOps.coeff(p, n);
    return r.numerator / r.denominator;
  }

  /// Metodo de factorizacion que se usaria en clase para [p] (texto con tildes, fuera de LaTeX).
  static String method(Poly p) {
    final deg = PolyOps.degree(p);
    if (deg <= 0) return 'es una constante';
    if (deg == 1) return 'es de primer grado: ya es irreducible';
    final terms = p.keys.where((k) => !PolyOps.coeff(p, k).isZero).length;
    if (PolyOps.coeff(p, 0).isZero) return 'sacamos factor común x';
    if (deg == 2) {
      final a = _d(p, 2), b = _d(p, 1), c = _d(p, 0);
      if (terms == 2 && a * c < 0) return 'diferencia de cuadrados: a² - b² = (a + b)(a - b)';
      final disc = b * b - 4 * a * c;
      if (disc.abs() < 1e-9) return 'cuadrado perfecto: (a ± b)²';
      return 'ecuación de 2.º grado (discriminante ${disc.toStringAsFixed(disc == disc.roundToDouble() ? 0 : 2)})';
    }
    return 'buscamos raíces enteras o racionales con Ruffini';
  }

  /// Paso 1 de clase: factoriza cada polinomio y explica el metodo usado.
  static MathStep factorization(int index, List<(String, Poly)> polys) {
    final lines = <String>[];
    final notes = <String>[];
    for (final (name, p) in polys) {
      final f = AlgebraicFractionSolver.factor(p);
      lines.add('${PolyOps.latex(p)} = ${f.latex()}');
      notes.add('$name: ${method(p)}');
    }
    return MathStep(
      index: index,
      shortTitle: 'Factorizar cada polinomio',
      latexExpression: lines.join(r'\quad;\quad '),
      pedagogicalNote:
          'Factorizamos antes de operar. ${notes.join('. ')}. Si no hay raíces racionales, el factor queda tal cual.',
    );
  }
}
