import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../../parser/expression_parser.dart';
import '../exact/ext_expr.dart';
import '../exact/ext_parser.dart';
import '../inequalities/universal/inequality_family_detector.dart';
import '../linear_system_solver.dart';
import '../trig_and_angles_solver.dart' show AngleUnit;
import '../systems_2x2/system_2x2_fractions.dart';
import 'free_system_rewrite.dart';
import 'nd_common.dart';
import 'nonlinear_algebraic_and_trig_systems.dart';
import 'nonlinear_numeric_nd_solver.dart';
import 'nonlinear_substitution_nd_solver.dart';
import 'nonlinear_system_solver.dart';

/// Sistemas 2x2, 3x3 y 4x4 en entrada libre (`miembro izquierdo = miembro derecho` por ecuacion):
/// lineales desordenados (parentesis, fracciones) y no lineales: lineal + cuadratica, dos cuadraticas,
/// exponenciales, logaritmicas, racionales (motor exacto 2x2) y, para cualquier N, cambios de
/// variable, sustitucion en cascada, radicales y Newton-Raphson N-D (ver `nonlinear_*_nd_*`).
class FreeSystemSolver {
  const FreeSystemSolver._();

  static XNode _parse(String side) {
    final text = side.trim().isEmpty ? '0' : side.trim();
    try {
      return ExtParser().parse(ExpressionParser.finalizeForEvaluation(text));
    } on ExtUnsupported catch (e) {
      throw FormatException('Ecuación no soportada: ${e.message}');
    }
  }

  static String _term(Rational c, String v, {required bool first}) {
    final abs = c.abs();
    final body = abs == Rational(1) ? v : '${abs.toLatex()}$v';
    if (first) return c.isNegative ? '-$body' : body;
    return c.isNegative ? ' - $body' : ' + $body';
  }

  /// `a x + b y + c z = d` con fracciones verticales y sin terminos nulos.
  static String _lin(List<Rational> row, List<String> vars) {
    final buf = StringBuffer();
    var first = true;
    for (var i = 0; i < vars.length; i++) {
      if (row[i].isZero) continue;
      buf.write(_term(row[i], vars[i], first: first));
      first = false;
    }
    if (first) buf.write('0');
    return '$buf = ${row.last.toLatex()}';
  }

  /// Resuelve el sistema de [lhs] = [rhs] (2, 3 o 4 ecuaciones). [unit] es la unidad angular
  /// (DEG/RAD) para sin, cos y tan.
  static StepByStepResolution solve(
    List<String> lhs,
    List<String> rhs, {
    SystemResolutionMethod method = SystemResolutionMethod.sustitucion,
    AngleUnit unit = AngleUnit.rad,
  }) {
    final n = lhs.length;
    if (n < 2 || n > 4 || rhs.length != n) throw const FormatException('Un sistema libre tiene 2, 3 o 4 ecuaciones.');
    for (var i = 0; i < n; i++) {
      if (lhs[i].trim().isEmpty && rhs[i].trim().isEmpty) {
        throw const FormatException('Completa todas las ecuaciones del sistema.');
      }
    }
    final sides = [for (var i = 0; i < n; i++) (_parse(lhs[i]), _parse(rhs[i]))];
    _checkVariables(sides, n);
    final original = '\\begin{cases} ${[for (final (l, r) in sides) '${l.latex()} = ${r.latex()}'].join(' \\\\ ')} \\end{cases}';
    final sys = NdSystem(n, sides, unit, original);

    try {
      final exact = _solveExact(sides, n, original, method);
      if (exact != null) return exact;
    } on FormatException catch (e) {
      if (e.message.contains('indeterminado') || e.message.contains('Completa')) rethrow;
    }
    return NonlinearSubstitutionNdSolver.solve(sys) ?? NonlinearAlgebraicSystems.solve(sys) ?? NonlinearNumericNdSolver.solve(sys);
  }

  /// Motor exacto: lineales (Gauss/sustitucion/igualacion/reduccion) y no lineales polinomicos,
  /// exponenciales y logaritmicos 2x2. `null` si el sistema es no lineal de 3 o 4 ecuaciones.
  static StepByStepResolution? _solveExact(List<(XNode, XNode)> sides, int n, String original, SystemResolutionMethod method) {
    final forms = [for (final (l, r) in sides) FreeSystemRewrite.rewrite(l, r)];
    final conditions = {for (final f in forms) ...f.conditions}.toList();
    final linear = forms.every((f) => f.poly.degree <= 1);
    final notes = [for (final f in forms) if (f.note != null) f.note!];
    final rewritten = [for (final f in forms) if (f.rewrite != null) f.rewrite!];
    if (!linear) {
      if (n > 2) return null;
      return NonlinearSystemSolver.solve(
        forms: forms,
        originals: sides,
        originalLatex: original,
        conditions: conditions,
        orderStep: MathStep(
          index: 0,
          shortTitle: 'Reescribir el sistema como polinomios',
          latexExpression: rewritten.isNotEmpty
              ? rewritten.join(r' \quad ')
              : '\\begin{cases} ${[for (final f in forms) '${f.poly.latex()} = 0'].join(' \\\\ ')} \\end{cases}',
          pedagogicalNote: notes.isNotEmpty
              ? notes.join(' ')
              : 'Pasamos todo a un miembro de cada ecuación para ver su grado y elegir el método.',
        ),
      );
    }

    final vars = ['x', 'y', 'z', 'w'].sublist(0, n);
    final rows = <List<Rational>>[
      for (final f in forms)
        [
          for (var i = 0; i < n; i++) f.poly.coef([for (var k = 0; k < 4; k++) k == i ? 1 : 0]),
          -f.poly.constantTerm,
        ],
    ];
    final ordered = '\\begin{cases} ${[for (final r in rows) _lin(r, vars)].join(' \\\\ ')} \\end{cases}';
    final first = MathStep(
      index: 1,
      shortTitle: 'Expandir, quitar denominadores y ordenar',
      latexExpression: '$original \\;\\Longrightarrow\\; $ordered',
      pedagogicalNote:
          'Quitamos paréntesis, pasamos las incógnitas al primer miembro y los números al segundo, y las ordenamos como a·x + b·y${n >= 3 ? ' + c·z' : ''}${n == 4 ? ' + d·w' : ''} = e.',
      warningTrick: 'Al pasar un término al otro miembro cambia de signo.',
    );
    final inner = n == 2
        ? System2x2Fractions.solve(row1: rows[0], row2: rows[1], method: method)
        : LinearSystemSolver.solveNxN(augmentedRows: rows, method: method);
    final all = [first, ...inner.steps];
    return StepByStepResolution(
      originalInputLatex: original,
      steps: [
        for (var i = 0; i < all.length; i++)
          MathStep(
            index: i + 1,
            shortTitle: all[i].shortTitle,
            latexExpression: all[i].latexExpression,
            pedagogicalNote: all[i].pedagogicalNote,
            warningTrick: all[i].warningTrick,
          ),
      ],
      exactResultLatex: inner.exactResultLatex,
      decimalApproxLatex: inner.decimalApproxLatex,
    );
  }

  static void _checkVariables(List<(XNode, XNode)> sides, int n) {
    final allowed = NdSystem.vars.sublist(0, n);
    final bad = <String>{};
    for (final (l, r) in sides) {
      for (final node in [l, r]) {
        InequalityFamilyDetector.walk(node, (v) {
          if (v is XVar && !allowed.contains(v.name)) bad.add(v.name.toLowerCase());
        });
      }
    }
    if (bad.isNotEmpty) {
      final names = NdSystem.names.sublist(0, n);
      throw FormatException(
          'Un sistema de $n ecuaciones solo usa las incógnitas ${names.sublist(0, n - 1).join(', ')} y ${names.last}.');
    }
  }
}
