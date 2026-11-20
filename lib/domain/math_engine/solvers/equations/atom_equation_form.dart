import '../../core/rational.dart';
import '../calculus/sym_build.dart';
import '../exact/exact_number.dart';
import '../exact/ext_evaluator.dart';
import '../exact/ext_expr.dart';
import '../trig_and_angles_solver.dart';
import 'eq_context.dart';
import 'eq_poly.dart';

/// Ecuacion de la forma `k * atomo + resto = 0`, donde `atomo` es una funcion
/// elemental con x (raiz n-esima, arcsen, senh...) y `resto` no depende de x.
class AtomEquationForm {
  final XNode atom;

  /// Coeficiente no nulo del atomo.
  final Rational k;

  /// Suma (con signo) de los terminos sin x.
  final XNode rest;

  const AtomEquationForm(this.atom, this.k, this.rest);

  /// Valor al que se iguala el atomo: `-rest / k` (como arbol, para que los valores
  /// notables como `pi/6` se evaluen de forma exacta).
  XNode get target => Sx.div(Sx.neg(rest), Sx.rat(k));

  static void _terms(XNode n, int sign, List<(int, XNode)> out) {
    if (n is XBin && (n.op == '+' || n.op == '-')) {
      _terms(n.l, sign, out);
      _terms(n.r, n.op == '+' ? sign : -sign, out);
    } else if (n is XNeg) {
      _terms(n.a, -sign, out);
    } else {
      out.add((sign, n));
    }
  }

  static Rational? _const(XNode n) {
    final p = PolyOps.polyOf(n);
    return p != null && PolyOps.degree(p) <= 0 ? PolyOps.coeff(p, 0) : null;
  }

  /// `c * atomo` -> (c, atomo) o `null`.
  static (Rational, XNode)? _peel(XNode n, bool Function(XNode) isAtom) {
    if (isAtom(n)) return (Rational(1), n);
    switch (n) {
      case XNeg(:final a):
        final r = _peel(a, isAtom);
        return r == null ? null : (-r.$1, r.$2);
      case XBin(:final l, :final op, :final r):
        if (op == '*') {
          final cl = _const(l), cr = _const(r);
          if (cl != null) {
            final p = _peel(r, isAtom);
            if (p != null) return (cl * p.$1, p.$2);
          }
          if (cr != null) {
            final p = _peel(l, isAtom);
            if (p != null) return (cr * p.$1, p.$2);
          }
        } else if (op == '/') {
          final cr = _const(r);
          if (cr != null && !cr.isZero) {
            final p = _peel(l, isAtom);
            if (p != null) return (p.$1 / cr, p.$2);
          }
        }
        return null;
      default:
        return null;
    }
  }

  /// Descompone `left = right` o devuelve `null` si no tiene esta forma.
  static AtomEquationForm? parse(EqCtx c, bool Function(XNode) isAtom) {
    final items = <(int, XNode)>[];
    _terms(c.left, 1, items);
    _terms(c.right, -1, items);
    XNode? atom;
    var k = Rational(0);
    XNode rest = Sx.zero;
    for (final (s, t) in items) {
      if (!PolyOps.containsX(t)) {
        rest = s > 0 ? Sx.add(rest, t) : Sx.sub(rest, t);
        continue;
      }
      final p = _peel(t, isAtom);
      if (p == null) return null;
      if (atom != null && atom.latex() != p.$2.latex()) return null;
      atom = p.$2;
      k = k + Rational(s) * p.$1;
    }
    if (atom == null || k.isZero) return null;
    return AtomEquationForm(atom, k, rest);
  }

  /// Evalua un arbol sin x con la unidad angular [angle]; `null` si no esta definido.
  static ExNum? evalConst(XNode n, AngleUnit angle) {
    try {
      return ExtEvaluator(angle: angle).eval(n);
    } on FormatException {
      return null;
    }
  }
}
