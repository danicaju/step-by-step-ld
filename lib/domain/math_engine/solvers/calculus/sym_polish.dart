import '../../core/rational.dart';
import '../equations/eq_poly.dart';
import '../exact/ext_expr.dart';
import 'sym_build.dart';

/// Limpieza final de una derivada: desarrolla los polinomios, saca factor comun no polinomico
/// (`2x e^x + (x^2 + 1) e^x = (x^2 + 2x + 1) e^x`) y reduce el numerador de un cociente
/// (`(2(x+3) - (2x-1)) / (x+3)^2 = 7 / (x+3)^2`).
class SymPolish {
  const SymPolish._();

  static XNode polish(XNode input) {
    final n = Sx.rebuild(input);
    if (n is XBin && n.op == '/') {
      final num = polish(n.l);
      return Sx.div(num, n.r);
    }
    final p = PolyOps.polyOf(n);
    if (p != null) return polyNode(p);
    return _commonFactor(n) ?? n;
  }

  /// Polinomio ordenado de mayor a menor grado como arbol.
  static XNode polyNode(Poly p) {
    final c = PolyOps.clean(p);
    if (c.isEmpty) return Sx.zero;
    final degs = c.keys.toList()..sort((a, b) => b.compareTo(a));
    XNode acc = Sx.zero;
    for (final k in degs) {
      final coef = c[k]!;
      final mono = k == 0 ? XNum(coef.abs()) : Sx.mul(XNum(coef.abs()), Sx.pow(Sx.x, Sx.num(k)));
      if (Sx.isNum(acc, 0)) {
        acc = coef.isNegative ? Sx.neg(mono) : mono;
      } else {
        acc = coef.isNegative ? Sx.sub(acc, mono) : Sx.add(acc, mono);
      }
    }
    return acc;
  }

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

  static void _factors(XNode n, List<XNode> out) {
    if (n is XBin && n.op == '*') {
      _factors(n.l, out);
      _factors(n.r, out);
    } else {
      out.add(n);
    }
  }

  /// `sum_i P_i(x) * F` con el mismo factor no polinomico `F` -> `(sum P_i) * F`.
  static XNode? _commonFactor(XNode n) {
    final terms = <(int, XNode)>[];
    _terms(n, 1, terms);
    if (terms.length < 2) return null;
    Poly total = {};
    String? key;
    List<XNode>? shared;
    for (final (sign, t) in terms) {
      final factors = <XNode>[];
      _factors(t, factors);
      var poly = PolyOps.constant(Rational(sign));
      final rest = <XNode>[];
      for (final f in factors) {
        final fp = PolyOps.polyOf(f);
        if (fp != null) {
          poly = PolyOps.mul(poly, fp);
        } else {
          rest.add(f);
        }
      }
      if (rest.isEmpty) return null;
      final k = rest.map((e) => e.latex()).join('*');
      if (key != null && k != key) return null;
      key = k;
      shared ??= rest;
      total = PolyOps.add(total, poly);
    }
    if (shared == null) return null;
    var f = shared.first;
    for (final extra in shared.skip(1)) {
      f = Sx.mul(f, extra);
    }
    final pn = polyNode(total);
    return Sx.isNum(pn, 0) ? Sx.zero : Sx.mul(pn, f);
  }
}
