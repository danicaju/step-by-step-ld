import '../models/step_resolution.dart';
import 'triangle_exact.dart';

const List<String> kTriSides = ['a', 'b', 'c'];
const List<String> kTriAngles = ['A', 'B', 'C'];

/// Grados en LaTeX con coma decimal y sin ceros sobrantes: `36{,}87^{\circ}`.
String triAng(double v) => '${Val(v).dec(2)}^{\\circ}';

/// Acumulador de pasos "como en clase": cada tarjeta es formula -> sustitucion -> resultado.
class TriCtx {
  final List<MathStep> steps = [];

  void card(String title, List<String> rows, String note, {String? trick}) {
    steps.add(MathStep(
      index: steps.length + 1,
      shortTitle: title,
      latexExpression: rows.length == 1
          ? rows.first
          : '\\begin{array}{l} ${rows.join(' \\\\ ')} \\end{array}',
      pedagogicalNote: note,
      warningTrick: trick,
    ));
  }
}
