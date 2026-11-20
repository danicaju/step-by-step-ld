import '../../domain/math_engine/geometry/geometry_triangle_solver.dart';
import '../../domain/math_engine/geometry/line_equations_solver.dart';
import '../../domain/math_engine/polynomials/spanish_box_division_solver.dart';
import '../../domain/math_engine/statistics/probability_distribution_solver.dart';
import '../widgets/m10/line_equations_visual_editor.dart';
import '../widgets/m10/triangle_visual_editor.dart';
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
    selectorLabels: LineEquationsVisualEditor.forms,
    cols: 2,
    layouts: [
      [ModeField('x1', scalar: true), ModeField('y1', scalar: true), ModeField('x2', scalar: true), ModeField('y2', scalar: true)],
      [ModeField('x0', scalar: true), ModeField('y0', scalar: true), ModeField('v1', scalar: true), ModeField('v2', scalar: true)],
      [ModeField('x0', scalar: true), ModeField('y0', scalar: true), ModeField('m', scalar: true)],
      [ModeField('m', scalar: true), ModeField('n', scalar: true)],
      [ModeField('A', scalar: true), ModeField('B', scalar: true), ModeField('C', scalar: true)],
      [ModeField('x0', scalar: true), ModeField('y0', scalar: true), ModeField('v1', scalar: true), ModeField('v2', scalar: true)],
    ],
  );

  /// M10 triangulos: 0 = rectangulo (C = 90° fijo, 5 casillas), 1 = cualquier triangulo (6 casillas).
  /// Casillas de expresion (fracciones y raices); en blanco = incognita.
  final ModeFormState tri = ModeFormState(
    selectorLabels: TriangleVisualEditor.kinds,
    cols: 3,
    layouts: [
      [for (final l in ['a', 'b', 'c', 'A°', 'B°']) ModeField(l, expr: true)],
      [for (final l in ['a', 'b', 'c', 'A°', 'B°', 'C°']) ModeField(l, expr: true)],
    ],
  );

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

  /// M3: `true` = entrada libre (`miembro = miembro`); `false` = casillas de coeficientes.
  bool sysFree = true;

  /// M3 libre: 2 ecuaciones (layout 0) o 3 (layout 1); cada ecuacion son dos casillas (izq, der).
  final ModeFormState sysForm = ModeFormState(cols: 2, layouts: [
    [for (var i = 1; i <= 2; i++) ...[ModeField('Ec. $i izq', expr: true), ModeField('Ec. $i der', expr: true)]],
    [for (var i = 1; i <= 3; i++) ...[ModeField('Ec. $i izq', expr: true), ModeField('Ec. $i der', expr: true)]],
    [for (var i = 1; i <= 4; i++) ...[ModeField('Ec. $i izq', expr: true), ModeField('Ec. $i der', expr: true)]],
  ]);

  /// Celdas de coeficientes (Ruffini...): la fraccion `a/b` abierta edita el numerador.
  bool cellNumEdit = false;

  BoxDivisionResult? boxResult;
  NormalResult? normalResult;
  TriangleResult? triResult;
  LineEquationsResult? lineResult;

  void clearResults() {
    boxResult = null;
    normalResult = null;
    triResult = null;
    lineResult = null;
  }

  void reset() {
    m4View = 0;
    m8View = 0;
    m10View = 0;
    cellNumEdit = false;
    sysFree = true;
    for (final f in [box, frac, line, tri, normal, bin, sysForm]) {
      f.clear();
    }
    clearResults();
  }
}
