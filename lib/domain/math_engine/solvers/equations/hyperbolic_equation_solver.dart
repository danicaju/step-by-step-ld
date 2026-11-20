import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../calculus/sym_build.dart';
import '../calculus/sym_latex.dart';
import '../exact/exact_number.dart';
import '../exact/ext_expr.dart';
import 'atom_equation_form.dart';
import 'eq_context.dart';
import 'eq_poly.dart';

/// Ecuaciones `A * senh(ax + b) + D = K` (y cosh, tgh) con despeje por logaritmos:
/// `senh u = k -> u = ln(k + √(k²+1))`, `cosh u = k -> u = ±ln(k + √(k²-1))` (k >= 1),
/// `tgh u = k -> u = ½·ln((1+k)/(1-k))` (|k| < 1).
class HyperbolicEquationSolver {
  const HyperbolicEquationSolver._();

  static const _names = {'sinh', 'cosh', 'tanh'};

  static bool _isAtom(XNode n) {
    if (n is! XFn || !_names.contains(n.name) || !PolyOps.containsX(n.arg)) return false;
    final p = PolyOps.polyOf(n.arg);
    return p != null && PolyOps.degree(p) == 1;
  }

  static bool _has(XNode n) => switch (n) {
        XFn() => _isAtom(n) || _has(n.arg),
        XNeg(:final a) || XAbs(:final a) => _has(a),
        XBin(:final l, :final r) => _has(l) || _has(r),
        XPow(:final base) => _has(base),
        _ => false,
      };

  static bool matches(EqCtx c) => _has(c.left) || _has(c.right);

  static XNode _ln(XNode v) => XFn('ln', v);

  static StepByStepResolution? solve(EqCtx c) {
    final form = AtomEquationForm.parse(c, _isAtom);
    if (form == null) return null;
    final fn = form.atom as XFn;
    final lin = PolyOps.polyOf(fn.arg)!;
    final a = PolyOps.coeff(lin, 1), b = PolyOps.coeff(lin, 0);
    final kNode = form.target;
    final kVal = AtomEquationForm.evalConst(kNode, c.angle);
    if (kVal == null) return null;
    final k = kVal.approx;
    final name = '\\${fn.name}';
    final argTex = PolyOps.latex(lin);
    c.add(
      'Aislar la funcion hiperbolica',
      '$name\\left($argTex\\right) = ${kVal.toLatex()}',
      'Dejamos la función hiperbólica sola en un miembro.',
    );
    final one = Sx.one;
    final k2 = Sx.pow(kNode, Sx.num(2));
    final List<XNode> us; // valores posibles del argumento
    final String rangeTex;
    final String rangeNote;
    final bool solvable;
    switch (fn.name) {
      case 'sinh':
        solvable = true;
        rangeTex = '\\sinh u \\in \\mathbb{R} \\;\\Rightarrow\\; \\text{Siempre hay solucion}';
        rangeNote = 'senh toma todos los valores reales y es inyectiva: hay exactamente una solución.';
        us = [_ln(Sx.add(kNode, XRoot(null, Sx.add(k2, one))))];
      case 'cosh':
        solvable = k >= 1 - 1e-12;
        rangeTex = '\\cosh u \\geq 1 \\;\\Rightarrow\\; ${kVal.toLatex()} ${solvable ? '\\geq' : '<'} 1';
        rangeNote = solvable
            ? 'cosh vale siempre 1 o más. Si k = 1 la solución es u = 0; si k > 1 hay dos soluciones simétricas ±u.'
            : 'cosh vale siempre 1 o más, y el valor k es menor que 1: la ecuación no tiene solución real.';
        if ((k - 1).abs() <= 1e-12) {
          us = [Sx.zero];
        } else {
          final r = _ln(Sx.add(kNode, XRoot(null, Sx.sub(k2, one))));
          us = [Sx.neg(r), r];
        }
      default:
        solvable = k.abs() < 1 - 1e-12;
        rangeTex = '-1 < \\tanh u < 1 \\;\\Rightarrow\\; ${kVal.toLatex()} ${solvable ? '\\in' : '\\notin'} (-1,\\,1)';
        rangeNote = solvable
            ? 'tgh queda siempre entre -1 y 1 (sin tocarlos): como |k| < 1 la ecuación tiene una solución.'
            : 'tgh queda siempre estrictamente entre -1 y 1: como |k| ≥ 1 la ecuación no tiene solución real.';
        us = [Sx.mul(Sx.rat(Rational(1, 2)), _ln(Sx.div(Sx.add(one, kNode), Sx.sub(one, kNode))))];
    }
    c.add('Comprobar el rango de la funcion', rangeTex, rangeNote);
    if (!solvable) return c.finish(const []);
    final sols = <ExNum>[];
    final texts = <String>[];
    for (final u in us) {
      final uVal = AtomEquationForm.evalConst(u, c.angle);
      final xVal = AtomEquationForm.evalConst(Sx.div(Sx.sub(u, Sx.rat(b)), Sx.rat(a)), c.angle);
      if (uVal == null || xVal == null) return null;
      texts.add('$argTex = ${SymLatex.tex(u)}');
      if (!sols.any((s) => (s.approx - xVal.approx).abs() < 1e-12)) sols.add(xVal);
    }
    c.add(
      'Despejar con logaritmos',
      texts.join(', \\quad '),
      'Aplicamos la función inversa (logaritmo): ${_formula(fn.name)}.',
    );
    c.add(
      'Despejar x',
      sols.map((s) => 'x = ${s.toLatex()}').join(', \\quad '),
      'Despejamos x en la ecuación lineal ${PolyOps.latex(lin)} = valor del argumento.',
    );
    final v = c.verify(sols);
    c.add(
      'Comprobacion en la ecuacion original',
      v.latex.isEmpty ? '\\text{Ninguna candidata}' : v.latex,
      'Sustituimos cada candidata en la ecuación original.',
    );
    return c.finish(v.valid);
  }

  static String _formula(String name) => switch (name) {
        'sinh' => 'u = ln(k + √(k² + 1))',
        'cosh' => 'u = ± ln(k + √(k² - 1))',
        _ => 'u = ½ · ln((1 + k) / (1 - k))',
      };
}
