import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../../parser/expression_parser.dart';
import '../exact/ext_expr.dart';
import '../exact/ext_parser.dart';
import '../inequalities/universal/inequality_family_detector.dart';
import '../linear_system_solver.dart';
import '../systems_2x2/system_2x2_fractions.dart';
import 'free_system_rewrite.dart';
import 'nonlinear_system_solver.dart';

/// Sistemas 2x2 y 3x3 en entrada libre (`miembro izquierdo = miembro derecho` por ecuacion):
/// lineales desordenados (parentesis, fracciones) y no lineales 2x2 (lineal + cuadratica,
/// dos cuadraticas en x², y², exponenciales, logaritmicas y racionales).
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

  /// Resuelve el sistema de [lhs] = [rhs] (2 o 3 ecuaciones).
  static StepByStepResolution solve(
    List<String> lhs,
    List<String> rhs, {
    SystemResolutionMethod method = SystemResolutionMethod.sustitucion,
  }) {
    final n = lhs.length;
    if (n < 2 || n > 3 || rhs.length != n) throw const FormatException('Un sistema libre tiene 2 o 3 ecuaciones.');
    for (var i = 0; i < n; i++) {
      if (lhs[i].trim().isEmpty && rhs[i].trim().isEmpty) {
        throw const FormatException('Completa todas las ecuaciones del sistema.');
      }
    }
    final sides = [for (var i = 0; i < n; i++) (_parse(lhs[i]), _parse(rhs[i]))];
    _checkVariables(sides, n);
    final forms = [for (final (l, r) in sides) FreeSystemRewrite.rewrite(l, r)];
    final conditions = {for (final f in forms) ...f.conditions}.toList();
    final original = '\\begin{cases} ${[for (final (l, r) in sides) '${l.latex()} = ${r.latex()}'].join(' \\\\ ')} \\end{cases}';

    final linear = forms.every((f) => f.poly.degree <= 1);
    final notes = [for (final f in forms) if (f.note != null) f.note!];
    final rewritten = [for (final f in forms) if (f.rewrite != null) f.rewrite!];
    if (!linear) {
      if (n == 3) throw const FormatException('Los sistemas 3x3 libres deben ser lineales.');
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

    final vars = n == 2 ? ['x', 'y'] : ['x', 'y', 'z'];
    final rows = <List<Rational>>[
      for (final f in forms)
        [
          for (var i = 0; i < n; i++) f.poly.coef([i == 0 ? 1 : 0, i == 1 ? 1 : 0, i == 2 ? 1 : 0]),
          -f.poly.constantTerm,
        ],
    ];
    final ordered = '\\begin{cases} ${[for (final r in rows) _lin(r, vars)].join(' \\\\ ')} \\end{cases}';
    final first = MathStep(
      index: 1,
      shortTitle: 'Expandir, quitar denominadores y ordenar',
      latexExpression: '$original \\;\\Longrightarrow\\; $ordered',
      pedagogicalNote:
          'Quitamos paréntesis, pasamos las incógnitas al primer miembro y los números al segundo, y las ordenamos como a·x + b·y${n == 3 ? ' + c·z' : ''} = d.',
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
    final bad = <String>{};
    for (final (l, r) in sides) {
      for (final node in [l, r]) {
        InequalityFamilyDetector.walk(node, (v) {
          if (v is! XVar) return;
          final ok = v.name == 'X' || v.name == 'Y' || (n == 3 && v.name == 'Z');
          if (!ok) bad.add(v.name.toLowerCase());
        });
      }
    }
    if (bad.isNotEmpty) {
      throw FormatException(n == 2
          ? 'Un sistema de 2 ecuaciones solo usa las incógnitas x e y.'
          : 'Un sistema de 3 ecuaciones solo usa las incógnitas x, y y z.');
    }
  }
}
