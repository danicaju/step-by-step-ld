import 'dart:math' as math;

import '../../models/step_resolution.dart';
import '../calculus/sym_build.dart';
import '../calculus/sym_latex.dart';
import '../exact/ext_expr.dart';
import '../trig_and_angles_solver.dart';
import 'atom_equation_form.dart';
import 'eq_context.dart';
import 'eq_poly.dart';

/// Ecuaciones `A * arcsen(ax + b) + D = K` (y arccos, arctan): se comprueba que el
/// valor este en el rango de la inversa y se aplica la funcion directa.
class InverseFunctionEquationSolver {
  const InverseFunctionEquationSolver._();

  static const _direct = {'asin': 'sin', 'acos': 'cos', 'atan': 'tan'};

  static bool _isAtom(XNode n) {
    if (n is! XFn || !_direct.containsKey(n.name) || !PolyOps.containsX(n.arg)) return false;
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

  /// Media vuelta en la unidad activa (`pi`, `180`, `200`) como valor numerico.
  static double _half(AngleUnit u) => switch (u) {
        AngleUnit.deg => 180,
        AngleUnit.rad => math.pi,
        AngleUnit.grad => 200,
      };

  static String _halfLatex(AngleUnit u, int num, int den) {
    if (u == AngleUnit.rad) {
      final top = num == 1 ? r'\pi' : '$num\\pi';
      return den == 1 ? top : '\\frac{$top}{$den}';
    }
    final v = num * (u == AngleUnit.deg ? 180 : 200);
    return v % den == 0 ? '${v ~/ den}' : '\\frac{$v}{$den}';
  }

  static StepByStepResolution? solve(EqCtx c) {
    final form = AtomEquationForm.parse(c, _isAtom);
    if (form == null) return null;
    final fn = form.atom as XFn;
    final lin = PolyOps.polyOf(fn.arg)!;
    final a = PolyOps.coeff(lin, 1), b = PolyOps.coeff(lin, 0);
    final target = form.target;
    final t = AtomEquationForm.evalConst(target, c.angle);
    if (t == null) return null;
    final tl = t.toLatex();
    final inv = fn.name == 'asin' ? '\\arcsin' : (fn.name == 'acos' ? '\\arccos' : '\\arctan');
    final u = c.angle;
    final half = _half(u);
    final tv = t.approx;
    final (lo, hi, closed, rangeTex) = switch (fn.name) {
      'asin' => (-half / 2, half / 2, true, '-${_halfLatex(u, 1, 2)} \\leq $tl \\leq ${_halfLatex(u, 1, 2)}'),
      'acos' => (0.0, half, true, '0 \\leq $tl \\leq ${_halfLatex(u, 1, 1)}'),
      _ => (-half / 2, half / 2, false, '-${_halfLatex(u, 1, 2)} < $tl < ${_halfLatex(u, 1, 2)}'),
    };
    c.add(
      'Aislar la funcion inversa',
      '$inv\\left(${PolyOps.latex(lin)}\\right) = $tl',
      'Dejamos la función trigonométrica inversa sola en un miembro. Su valor es un ángulo.',
    );
    final eps = 1e-12 * (1 + half);
    final inRange = closed ? (tv >= lo - eps && tv <= hi + eps) : (tv > lo + eps && tv < hi - eps);
    final imageTex = switch (fn.name) {
      'asin' => 'arcsen tiene como imagen [-${u == AngleUnit.rad ? 'π/2' : (u == AngleUnit.deg ? '90' : '100')}, ${u == AngleUnit.rad ? 'π/2' : (u == AngleUnit.deg ? '90' : '100')}]',
      'acos' => 'arccos tiene como imagen [0, ${u == AngleUnit.rad ? 'π' : (u == AngleUnit.deg ? '180' : '200')}]',
      _ => 'arctan tiene como imagen el intervalo abierto (-${u == AngleUnit.rad ? 'π/2' : (u == AngleUnit.deg ? '90' : '100')}, ${u == AngleUnit.rad ? 'π/2' : (u == AngleUnit.deg ? '90' : '100')})',
    };
    c.add(
      'Comprobar el rango de la funcion inversa',
      '$rangeTex \\;\\Rightarrow\\; ${inRange ? '\\text{Dentro del rango}' : '\\text{Fuera del rango}'}',
      '$imageTex. ${inRange ? 'El valor está dentro, así que la ecuación tiene solución.' : 'El valor queda fuera: ningún x produce ese ángulo, así que no hay solución real.'}',
    );
    if (!inRange) return c.finish(const []);
    final dName = _direct[fn.name]!;
    final uNode = XFn(dName, target);
    final uVal = AtomEquationForm.evalConst(uNode, c.angle);
    final xNode = Sx.div(Sx.sub(uNode, Sx.rat(b)), Sx.rat(a));
    final x = AtomEquationForm.evalConst(xNode, c.angle);
    if (uVal == null || x == null) return null;
    c.add(
      'Aplicar la funcion directa',
      '${PolyOps.latex(lin)} = ${SymLatex.tex(uNode)} = ${uVal.toLatex()}',
      'Aplicamos $dName a los dos miembros: ${PolyOps.latex(lin)} = $dName(${SymLatex.tex(target)}).',
    );
    c.add(
      'Despejar x',
      'x = ${x.toLatex()}',
      'Despejamos x de la ecuación lineal ${PolyOps.latex(lin)} = ${uVal.toLatex()}.',
    );
    final v = c.verify([x]);
    c.add(
      'Comprobacion en la ecuacion original',
      v.latex.isEmpty ? '\\text{Ninguna candidata}' : v.latex,
      'Sustituimos x en la ecuación original para confirmar que cumple la igualdad.',
    );
    return c.finish(v.valid);
  }
}
