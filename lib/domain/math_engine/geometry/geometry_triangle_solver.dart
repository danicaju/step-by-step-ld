import '../models/step_resolution.dart';
import 'triangle_exact.dart';
import 'triangle_input_validator.dart';
import 'triangle_models.dart';
import 'triangle_steps_oblique.dart';
import 'triangle_steps_right.dart';
import 'triangle_summary.dart';
import 'triangle_tex.dart';

export 'triangle_models.dart';

/// Resolucion de triangulos "como en clase": rectangulos (Pitagoras y razones) y
/// cualesquiera (coseno, seno y suma de angulos), con radicales exactos y resumen final.
class TriangleSolver {
  const TriangleSolver._();

  static const double _eps = 1e-9;

  /// Decimal con coma y sin ceros sobrantes.
  static String n(double v, [int d = 4]) => Val(v).dec(d);
  static String ang(double v) => triAng(v);

  /// Resuelve con exactamente tres datos (al menos un lado). Angulos en grados.
  static TriangleResult solve({
    List<double?> sides = const [null, null, null],
    List<double?> angles = const [null, null, null],
  }) {
    final s = [...sides], a = [...angles];
    TriangleInputValidator.check(s, a);
    final ctx = TriCtx();
    final right = a.indexWhere((v) => v != null && (v - 90).abs() < _eps);
    final ns = s.whereType<double>().length, na = a.whereType<double>().length;

    final String caseName;
    final String kind;
    if (right >= 0) {
      caseName = 'Triángulo rectángulo: el ángulo recto es ${kTriAngles[right]}, la hipotenusa es ${kTriSides[right]} '
          '(el lado opuesto al recto) y los otros dos lados son los catetos. Usaremos Pitágoras y las razones sen, cos y tan.';
      kind = 'pitagoras';
    } else if (ns == 3) {
      caseName = 'Caso LLL (tres lados): el teorema del coseno da los ángulos.';
      kind = 'coseno';
    } else if (ns == 2 && na == 1) {
      final ai = a.indexWhere((v) => v != null);
      final opposite = s[ai] != null;
      caseName = opposite
          ? 'Caso LLA (dos lados y el ángulo opuesto a uno de ellos): el teorema del seno, con posible caso ambiguo.'
          : 'Caso LAL (dos lados y el ángulo que forman): el teorema del coseno da el tercer lado.';
      kind = opposite ? 'seno' : 'coseno';
    } else {
      final ks = s.indexWhere((v) => v != null);
      final between = a[ks] == null;
      caseName = between
          ? 'Caso ALA (dos ángulos y el lado entre ellos): suma de ángulos y teorema del seno.'
          : 'Caso AAL (dos ángulos y un lado no comprendido): suma de ángulos y teorema del seno.';
      kind = 'seno';
    }

    final given = [
      for (var i = 0; i < 3; i++)
        if (s[i] != null) '${kTriSides[i]} = ${n(s[i]!)}',
      for (var i = 0; i < 3; i++)
        if (a[i] != null) '${kTriAngles[i]} = ${ang(a[i]!)}',
    ].join(r',\; ');
    final unknown = [
      for (var i = 0; i < 3; i++)
        if (s[i] == null) kTriSides[i],
      for (var i = 0; i < 3; i++)
        if (a[i] == null) kTriAngles[i],
    ].join(r',\; ');
    ctx.card(
      'Clasificación y datos',
      ['\\text{Datos:}\\;\\; $given', '\\text{Calcular:}\\;\\; $unknown'],
      caseName,
    );

    final List<TriangleSolution> sols;
    if (right >= 0) {
      sols = [TriangleStepsRight.solve(ctx, s, a, right)];
    } else if (ns == 3) {
      sols = [TriangleStepsOblique.sss(ctx, s)];
    } else if (ns == 2 && na == 1) {
      final ai = a.indexWhere((v) => v != null);
      sols = s[ai] != null
          ? TriangleStepsOblique.ssa(ctx, s, a, ai)
          : [TriangleStepsOblique.sas(ctx, s, a, ai)];
    } else {
      sols = [TriangleStepsOblique.asa(ctx, s, a)];
    }
    TriangleSummary.addStep(ctx, sols);

    final ambiguous = sols.length > 1;
    final result = [
      for (var k = 0; k < sols.length; k++)
        '${ambiguous ? 'S_{${k + 1}}:\\; ' : ''}'
            '${[for (var i = 0; i < 3; i++) '${kTriSides[i]} = ${n(sols[k].sides[i])}'].join(r',\; ')}'
            r',\; '
            '${[for (var i = 0; i < 3; i++) '${kTriAngles[i]} = ${ang(sols[k].angles[i])}'].join(r',\; ')}',
    ].join(r'\quad ');
    return TriangleResult(
      sols,
      ambiguous ? 'ambiguo' : kind,
      StepByStepResolution(
        originalInputLatex: given,
        steps: ctx.steps,
        exactResultLatex: result,
        decimalApproxLatex: '',
      ),
    );
  }
}
