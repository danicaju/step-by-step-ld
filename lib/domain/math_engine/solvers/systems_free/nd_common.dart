import 'dart:math' as math;

import '../../models/step_resolution.dart';
import '../exact/ext_expr.dart';
import '../inequalities/universal/numeric_function.dart';
import '../trig_and_angles_solver.dart' show AngleUnit;

/// Contexto comun de un sistema N x N en entrada libre (N = 2, 3 o 4; x, y, z, w).
class NdSystem {
  final int n;
  final List<(XNode, XNode)> sides;
  final AngleUnit unit;
  final String originalLatex;

  const NdSystem(this.n, this.sides, this.unit, this.originalLatex);

  static const List<String> vars = ['X', 'Y', 'Z', 'W'];
  static const List<String> names = ['x', 'y', 'z', 'w'];

  Map<String, double> env(List<double> v) => {for (var i = 0; i < n; i++) vars[i]: v[i]};

  /// `lhs - rhs` de la ecuacion [i]; `null` fuera de dominio.
  double? residual(int i, List<double> v) {
    final e = env(v);
    final a = NumFn.evalEnv(sides[i].$1, e, unit: unit), b = NumFn.evalEnv(sides[i].$2, e, unit: unit);
    if (a == null || b == null) return null;
    return a - b;
  }

  /// `true` si [v] cumple todas las ecuaciones originales (residuo relativo pequeno).
  bool satisfies(List<double> v, {double tol = 1e-6}) {
    final e = env(v);
    for (final (l, r) in sides) {
      final a = NumFn.evalEnv(l, e, unit: unit), b = NumFn.evalEnv(r, e, unit: unit);
      if (a == null || b == null || a.isInfinite || b.isInfinite) return false;
      if ((a - b).abs() > tol * (1 + a.abs() + b.abs())) return false;
    }
    return true;
  }
}

/// Formato de numeros y pasos de los modulos N x N.
abstract final class NdFmt {
  /// Fraccion `p/q` (q <= 1000) si [v] es racional con precision de 1e-9; `null` si no.
  static (int, int)? asFraction(double v) {
    if (!v.isFinite || v.abs() > 1e9) return null;
    for (var q = 1; q <= 1000; q++) {
      final p = (v * q).roundToDouble();
      if ((v * q - p).abs() < 1e-9 * q) return (p.toInt(), q);
    }
    return null;
  }

  /// LaTeX de [v]: entero o fraccion exactos si lo son; si no, decimal a 4 cifras.
  static String num(double v) {
    if (v.abs() < 1e-10) return '0';
    final f = asFraction(v);
    if (f != null) {
      final (p, q) = f;
      if (q == 1) return '$p';
      return '${p < 0 ? '-' : ''}\\frac{${p.abs()}}{$q}';
    }
    return dec(v);
  }

  static bool isExact(double v) => v.abs() < 1e-10 || asFraction(v) != null;

  /// Decimal a 4 cifras sin ceros finales y con coma decimal LaTeX.
  static String dec(double v) {
    var s = v.toStringAsFixed(4);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    if (s == '-0') s = '0';
    return s.replaceAll('.', '{,}');
  }

  /// `x = 3,\; y = 4` para una solucion.
  static String point(List<double> v, int n, {bool decimal = false}) =>
      [for (var i = 0; i < n; i++) '${NdSystem.names[i]} = ${decimal ? dec(v[i]) : num(v[i])}'].join(r',\; ');

  static String tuple(List<double> v, int n) => '\\left(${[for (var i = 0; i < n; i++) num(v[i])].join(r',\, ')}\\right)';

  static String tupleVars(int n) => '(${NdSystem.names.take(n).join(', ')})';

  /// Termino `c v` con signo para construir expresiones lineales.
  static String term(double c, String v, {required bool first}) {
    final a = c.abs();
    final body = (a - 1).abs() < 1e-12 ? v : '${num(a)}$v';
    if (first) return c < 0 ? '-$body' : body;
    return c < 0 ? ' - $body' : ' + $body';
  }

  static MathStep step(String title, String latex, String note, [String? warn]) =>
      MathStep(index: 0, shortTitle: title, latexExpression: latex, pedagogicalNote: note, warningTrick: warn);

  static List<MathStep> renumber(List<MathStep> steps) => [
        for (var i = 0; i < steps.length; i++)
          MathStep(
            index: i + 1,
            shortTitle: steps[i].shortTitle,
            latexExpression: steps[i].latexExpression,
            pedagogicalNote: steps[i].pedagogicalNote,
            warningTrick: steps[i].warningTrick,
          ),
      ];

  /// Sistema como `\begin{cases} ... \end{cases}`.
  static String cases(List<String> rows) => '\\begin{cases} ${rows.join(' \\\\ ')} \\end{cases}';

  /// Soluciones ordenadas y sin duplicados (tolerancia 1e-5).
  static List<List<double>> dedupe(List<List<double>> sols) {
    final out = <List<double>>[];
    for (final s in sols) {
      final dup = out.any((o) {
        for (var i = 0; i < s.length; i++) {
          if ((o[i] - s[i]).abs() > 1e-5 * (1 + o[i].abs())) return false;
        }
        return true;
      });
      if (!dup) out.add(s);
    }
    out.sort((a, b) {
      for (var i = 0; i < a.length; i++) {
        final c = a[i].compareTo(b[i]);
        if (c != 0) return c;
      }
      return 0;
    });
    return out;
  }

  /// Resolucion final comun: lista de soluciones validadas.
  static StepByStepResolution finish(
    NdSystem sys,
    List<MathStep> steps,
    List<List<double>> sols, {
    String? noSolutionNote,
    bool approximate = false,
  }) {
    final n = sys.n;
    final exactAll = sols.every((s) => s.take(n).every(isExact));
    final shown = [for (final s in sols) '\\left(${[for (var i = 0; i < n; i++) approximate || !exactAll ? dec(s[i]) : num(s[i])].join(r',\, ')}\\right)'];
    final result = sols.isEmpty ? r'\text{Sin solucion real}' : '\\left\\{${shown.join(r',\; ')}\\right\\}';
    final all = [
      ...steps,
      step(
        'Soluciones del sistema',
        sols.isEmpty ? result : '${tupleVars(n)} \\in $result',
        sols.isEmpty
            ? (noSolutionNote ?? 'Ninguna combinación real de ${NdSystem.names.take(n).join(', ')} cumple a la vez todas las ecuaciones.')
            : 'El sistema tiene ${sols.length} ${sols.length == 1 ? 'solución' : 'soluciones'} ${approximate || !exactAll ? 'aproximadas (4 decimales)' : 'exactas'}; cada una cumple todas las ecuaciones originales.',
      ),
    ];
    return StepByStepResolution(
      originalInputLatex: sys.originalLatex,
      steps: renumber(all),
      exactResultLatex: result,
      decimalApproxLatex: result,
    );
  }

  /// Valor mod periodo en `[0, period)`.
  static double wrap(double v, double period) {
    final r = v % period;
    return r < 0 ? r + period : r;
  }

  static double fullTurn(AngleUnit u) => switch (u) {
        AngleUnit.deg => 360.0,
        AngleUnit.grad => 400.0,
        _ => 2 * math.pi,
      };
}
