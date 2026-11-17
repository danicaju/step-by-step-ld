import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../exact/exact_number.dart';
import '../exact/ext_evaluator.dart';
import '../exact/ext_expr.dart';
import '../exact/ext_parser.dart';
import '../trig_and_angles_solver.dart';
import 'eq_poly.dart';

/// Contexto comun de un solver de ecuaciones en x: lados parseados,
/// comprobacion exacta de soluciones y construccion de pasos/resultado.
class EqCtx {
  final String raw;
  final XNode left;
  final XNode right;
  final AngleUnit angle;
  final List<MathStep> steps = [];

  EqCtx._(this.raw, this.left, this.right, this.angle);

  factory EqCtx.parse(String raw, {AngleUnit angle = AngleUnit.deg}) {
    final parts = raw.split('=');
    if (parts.length != 2 || parts[0].trim().isEmpty || parts[1].trim().isEmpty) {
      throw const FormatException(
        'La ecuación debe tener exactamente dos miembros separados por "=".',
      );
    }
    final l = ExtParser().parse(parts[0]);
    final r = ExtParser().parse(parts[1]);
    return EqCtx._(raw, l, r, angle);
  }

  XNode get diff => XBin(left, '-', right);
  String get originalLatex => '${left.latex()} = ${right.latex()}';

  void add(String title, String latex, String note, {String? warn}) {
    steps.add(MathStep(
      index: steps.length + 1,
      shortTitle: title,
      latexExpression: latex,
      pedagogicalNote: note,
      warningTrick: warn,
    ));
  }

  /// Evalua un nodo en x = [v]; `null` si no esta definido en ese punto.
  ExNum? evalAt(XNode n, ExNum v) {
    try {
      return ExtEvaluator(angle: angle, xValue: v).eval(n);
    } on FormatException {
      return null;
    }
  }

  /// Comprueba la solucion en la ecuacion ORIGINAL (lado a lado).
  ({bool ok, ExNum? l, ExNum? r}) check(ExNum v) {
    final l = evalAt(left, v);
    final r = evalAt(right, v);
    if (l == null || r == null) return (ok: false, l: l, r: r);
    final tol = 1e-9 * (1 + l.approx.abs() + r.approx.abs());
    return (ok: (l.approx - r.approx).abs() <= tol, l: l, r: r);
  }

  /// Lineas `x = v` con la verificacion de cada candidata (sin tildes en \text).
  ({List<ExNum> valid, String latex}) verify(List<ExNum> candidates) {
    final valid = <ExNum>[];
    final lines = <String>[];
    for (final c in candidates) {
      final res = check(c);
      final xs = c.toLatex();
      if (res.ok) {
        valid.add(c);
        lines.add(
          'x = $xs: \\; ${res.l!.toLatex()} = ${res.r!.toLatex()} \\implies \\text{Valida } (\\checkmark)',
        );
      } else if (res.l == null || res.r == null) {
        lines.add('x = $xs: \\; \\text{No esta en el dominio } \\implies \\text{Descartada}');
      } else {
        lines.add(
          'x = $xs: \\; ${res.l!.toLatex()} \\neq ${res.r!.toLatex()} \\implies \\text{Solucion extrana, Descartada}',
        );
      }
    }
    return (valid: valid, latex: lines.join(' \\\\ '));
  }

  static String solutionsLatex(List<ExNum> sols) => sols.isEmpty
      ? '\\text{Sin solucion real}'
      : sols.map((s) => 'x = ${s.toLatex()}').join(', \\quad ');

  static String decimalsLatex(List<ExNum> sols) {
    if (sols.isEmpty) return '\\text{Sin solucion real}';
    return sols.map((s) {
      final d = s.decimalLatex();
      return s.isRational ? 'x = ${s.toLatex()}' : 'x \\approx $d';
    }).join(', \\quad ');
  }

  StepByStepResolution finish(List<ExNum> sols,
      {String? exactOverride, String? decimalOverride}) {
    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: List.unmodifiable(steps),
      exactResultLatex: exactOverride ?? solutionsLatex(sols),
      decimalApproxLatex: decimalOverride ?? decimalsLatex(sols),
    );
  }

  /// Ecuacion `P(x) = 0` en LaTeX.
  static String polyEq(Poly p) => '${PolyOps.latex(p)} = 0';

  /// Texto "pasos de la formula general" para un polinomio resultante.
  void addPolynomialSolveStep(Poly p, List<ExNum> roots,
      {String title = 'Resolver la ecuación resultante'}) {
    final d = PolyOps.degree(p);
    var note = 'Resolvemos la ecuación polinómica de grado $d.';
    var latex = '${EqCtx.polyEq(p)} \\implies ${roots.isEmpty ? '\\text{Sin solucion real}' : roots.map((r) => 'x = ${r.toLatex()}').join(', \\; ')}';
    if (d == 2) {
      final a = PolyOps.coeff(p, 2);
      final b = PolyOps.coeff(p, 1);
      final c = PolyOps.coeff(p, 0);
      final disc = b * b - Rational(4) * a * c;
      note =
          'Ecuación de 2.º grado: calculamos el discriminante Δ = b² - 4ac = ${disc.numerator}${disc.isInteger ? '' : '/${disc.denominator}'}. ${disc.isNegative ? 'Como Δ < 0 no hay soluciones reales.' : (disc.isZero ? 'Como Δ = 0 hay una solución doble.' : 'Como Δ > 0 hay dos soluciones reales.')}';
      latex =
          '\\Delta = (${b.toLatex()})^{2} - 4 \\cdot (${a.toLatex()}) \\cdot (${c.toLatex()}) = ${disc.toLatex()} \\implies ${roots.isEmpty ? '\\text{Sin solucion real}' : roots.map((r) => 'x = ${r.toLatex()}').join(', \\; ')}';
    } else if (d >= 3) {
      note =
          'Buscamos raíces enteras o racionales con la regla de Ruffini (divisores del término independiente) y resolvemos el polinomio restante.';
    }
    add(title, latex, note);
  }
}
