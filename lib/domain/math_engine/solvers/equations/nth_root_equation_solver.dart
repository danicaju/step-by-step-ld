import '../../models/step_resolution.dart';
import '../exact/ext_expr.dart';
import 'atom_equation_form.dart';
import 'eq_context.dart';
import 'eq_poly.dart';

/// Ecuaciones con una raiz de indice n distinto de 2: `c * ⁿ√(P(x)) + d = k`.
///
/// Indice impar: se eleva a n sin riesgo (la raiz es biyectiva en R).
/// Indice par (4, 6, ...): comprobacion obligatoria, y sin solucion si el radical da negativo.
class NthRootEquationSolver {
  const NthRootEquationSolver._();

  static int? _index(XNode n) {
    if (n is! XRoot || n.index == null) return null;
    final i = n.index!;
    return i is XNum && i.value.isInteger && i.value.numerator >= 3 ? i.value.numerator : null;
  }

  static bool _isAtom(XNode n) => _index(n) != null && PolyOps.polyOf((n as XRoot).rad) != null && PolyOps.containsX(n.rad);

  static bool _has(XNode n) => switch (n) {
        XRoot() => _isAtom(n),
        XNeg(:final a) || XAbs(:final a) => _has(a),
        XBin(:final l, :final r) => _has(l) || _has(r),
        XPow(:final base) => _has(base),
        _ => false,
      };

  static bool matches(EqCtx c) => _has(c.left) || _has(c.right);

  static StepByStepResolution? solve(EqCtx c) {
    final form = AtomEquationForm.parse(c, _isAtom);
    if (form == null) return null;
    final root = form.atom as XRoot;
    final n = _index(root)!;
    final rad = PolyOps.polyOf(root.rad)!;
    final t = AtomEquationForm.evalConst(form.target, c.angle);
    final tr = t?.asRational;
    if (tr == null) return null;
    final even = n.isEven;
    final radTex = '\\sqrt[$n]{${PolyOps.latex(rad)}}';
    c.add(
      'Aislar el radical en un miembro',
      '$radTex = ${tr.toLatex()}',
      'Dejamos la raíz de índice $n sola en un miembro antes de elevar a la potencia $n.',
    );
    if (even && tr.isNegative) {
      c.add(
        'Signo del radical',
        '\\sqrt[$n]{\\cdots} \\geq 0 \\;\\Rightarrow\\; ${tr.toLatex()} < 0 \\text{ es imposible}',
        'Una raíz de índice par nunca es negativa, así que la ecuación no tiene solución real.',
      );
      return c.finish(const []);
    }
    final power = tr.pow(n);
    c.add(
      'Elevar a la potencia $n',
      '\\left($radTex\\right)^{$n} = \\left(${tr.toLatex()}\\right)^{$n} \\implies ${PolyOps.latex(rad)} = ${power.toLatex()}',
      even
          ? 'Elevamos a $n los dos miembros para quitar la raíz. Al elevar a una potencia par pueden aparecer soluciones falsas.'
          : 'Elevamos a $n los dos miembros: la raíz impar y la potencia se compensan, y no se pierde ni se inventa ninguna solución.',
      warn: even ? 'Con índice par es OBLIGATORIO comprobar la solución en la ecuación original.' : null,
    );
    final equation = PolyOps.sub(rad, PolyOps.constant(power));
    final roots = PolyRoots.real(equation);
    c.addPolynomialSolveStep(equation, roots);
    final v = c.verify(roots);
    c.add(
      'Comprobacion en la ecuacion original',
      v.latex.isEmpty ? '\\text{Ninguna candidata}' : v.latex,
      even
          ? 'Sustituimos cada candidata en la ecuación con radicales y descartamos las que no cumplen la igualdad.'
          : 'Con índice impar todas las soluciones son válidas; aun así comprobamos sustituyendo.',
    );
    return c.finish(v.valid);
  }
}
