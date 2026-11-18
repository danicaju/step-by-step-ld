import '../../domain/math_engine/geometry/geometry_triangle_solver.dart';
import '../../domain/math_engine/polynomials/spanish_box_division_solver.dart';
import '../../domain/math_engine/statistics/probability_distribution_solver.dart';
import '../widgets/modes/mode_form.dart';

/// Estado de las vistas nuevas de M4 (caja y fracciones), M8 (Normal/Binomial/2 variables)
/// y M10 (rectas y triangulos).
class ExtraViewsState {
  /// M4: 0/1 = Ruffini/Notables (indicador heredado), 2 = Division Caja, 3 = Fracciones Algebraicas.
  int m4View = 0;

  /// M8: 0 = 1 variable, 1 = 2 variables / regresion, 2 = Normal, 3 = Binomial.
  int m8View = 0;

  /// M10: 0 = Vectores, 1 = 6 ecuaciones de la recta, 2 = Triangulos.
  int m10View = 0;

  final ModeFormState box = ModeFormState(layouts: [
    [ModeField('P(x)', expr: true), ModeField('Q(x)', expr: true)],
  ]);

  final ModeFormState frac = ModeFormState(
    selectorLabels: const ['Simplificar', 'Suma', 'Resta', 'Producto', 'Cociente'],
    cols: 2,
    fractionStyle: true,
    layouts: [
      [ModeField('P(x)', expr: true), ModeField('Q(x)', expr: true)],
      for (var i = 0; i < 4; i++)
        [
          ModeField('P1(x)', expr: true),
          ModeField('Q1(x)', expr: true),
          ModeField('P2(x)', expr: true),
          ModeField('Q2(x)', expr: true),
        ],
    ],
  );

  final ModeFormState line = ModeFormState(
    selectorLabels: const ['2 puntos A, B', 'Punto y vector', 'Punto y pendiente'],
    cols: 2,
    layouts: [
      [ModeField('x1'), ModeField('y1'), ModeField('x2'), ModeField('y2')],
      [ModeField('x0'), ModeField('y0'), ModeField('v1'), ModeField('v2')],
      [ModeField('x0'), ModeField('y0'), ModeField('m')],
    ],
  );

  final ModeFormState tri = ModeFormState(cols: 3, layouts: [
    [ModeField('a'), ModeField('b'), ModeField('c'), ModeField('A°'), ModeField('B°'), ModeField('C°')],
  ]);

  final ModeFormState normal = ModeFormState(
    selectorLabels: const ['P(X ≤ a)', 'P(X ≥ a)', 'P(a ≤ X ≤ b)'],
    cols: 1,
    layouts: [
      for (var i = 0; i < 3; i++)
        [ModeField('μ'), ModeField('σ'), ModeField('a'), if (i == 2) ModeField('b')],
    ],
  );

  final ModeFormState bin = ModeFormState(
    selectorLabels: const ['P(X = k)', 'P(X ≤ k)', 'P(X ≥ k)'],
    cols: 1,
    layouts: [
      for (var i = 0; i < 3; i++) [ModeField('n'), ModeField('p'), ModeField('k')],
    ],
  );

  /// Celdas de coeficientes (Ruffini...): la fraccion `a/b` abierta edita el numerador.
  bool cellNumEdit = false;

  BoxDivisionResult? boxResult;
  NormalResult? normalResult;
  TriangleResult? triResult;

  void clearResults() {
    boxResult = null;
    normalResult = null;
    triResult = null;
  }

  void reset() {
    m4View = 0;
    m8View = 0;
    m10View = 0;
    cellNumEdit = false;
    for (final f in [box, frac, line, tri, normal, bin]) {
      f.clear();
    }
    clearResults();
  }
}
