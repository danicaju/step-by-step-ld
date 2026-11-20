import '../../core/rational.dart';
import '../exact/ext_expr.dart';
import '../exact/ext_evaluator.dart';
import '../trig_and_angles_solver.dart';
import 'sym_build.dart';
import 'sym_diff_rules.dart';
import 'sym_latex.dart';

/// Regla aplicada durante la derivacion (para los pasos didacticos).
typedef RuleLogger = void Function(String title, String latex, String note);

/// Derivacion simbolica sobre el AST completo (polinomios, potencias racionales,
/// raices, trigonometricas directas e inversas, exponenciales y logaritmos).
class SymDiff {
  final RuleLogger? log;
  const SymDiff({this.log});

  static String _t(XNode n) => SymLatex.tex(n);

  static Rational? _constValue(XNode n) {
    if (Sx.hasX(n)) return null;
    try {
      return ExtEvaluator(angle: AngleUnit.rad).eval(n).asRational;
    } on FormatException {
      return null;
    }
  }

  XNode d(XNode f) {
    if (!Sx.hasX(f)) return Sx.zero;
    switch (f) {
      case XVar():
        return Sx.one;
      case XNeg(:final a):
        return Sx.neg(d(a));
      case XBin(:final l, :final op, :final r):
        return _bin(f, l, op, r);
      case XPow(:final base, :final exp):
        return _pow(f, base, exp);
      case XRoot(:final index, :final rad):
        final n = index == null ? Rational(2) : _constValue(index);
        if (n == null) throw const ExtUnsupported('Índice de raíz no constante');
        final du = d(rad);
        final outer = SymDiffRules.rootOuter(n, rad);
        _chain(f, rad, outer, du);
        return Sx.mul(outer, du);
      case XFn():
        return _fn(f);
      default:
        throw const ExtUnsupported('Funcion no derivable en este modo');
    }
  }

  XNode _bin(XNode f, XNode l, String op, XNode r) {
    switch (op) {
      case '+':
        return Sx.add(d(l), d(r));
      case '-':
        return Sx.sub(d(l), d(r));
      case '*':
        if (!Sx.hasX(l)) return Sx.mul(l, d(r));
        if (!Sx.hasX(r)) return Sx.mul(d(l), r);
        final dl = d(l);
        final dr = d(r);
        final res = Sx.add(Sx.mul(dl, r), Sx.mul(l, dr));
        log?.call(
          'Regla del producto',
          "\\left(u \\cdot v\\right)' = u'v + uv' \\implies \\left(${_t(f)}\\right)' = \\left(${_t(dl)}\\right)\\left(${_t(r)}\\right) + \\left(${_t(l)}\\right)\\left(${_t(dr)}\\right)",
          'Tomamos u = ${_t(l)} y v = ${_t(r)}. La derivada de un producto es u\'·v + u·v\'.',
        );
        return res;
      default:
        if (!Sx.hasX(r)) return Sx.div(d(l), r);
        if (!Sx.hasX(l)) {
          // c / g^n = c * g^(-n): regla de la potencia (y de la cadena)
          final inv = r is XPow && !Sx.hasX(r.exp)
              ? XPow(r.base, Sx.neg(r.exp))
              : XPow(r, Sx.num(-1));
          return Sx.mul(l, d(inv));
        }
        final dl = d(l);
        final dr = d(r);
        final num = Sx.sub(Sx.mul(dl, r), Sx.mul(l, dr));
        final res = Sx.div(num, Sx.pow(r, Sx.num(2)));
        log?.call(
          'Regla del cociente',
          "\\left(\\frac{u}{v}\\right)' = \\frac{u'v - uv'}{v^{2}} \\implies \\left(${_t(f)}\\right)' = \\frac{\\left(${_t(dl)}\\right)\\left(${_t(r)}\\right) - \\left(${_t(l)}\\right)\\left(${_t(dr)}\\right)}{\\left(${_t(r)}\\right)^{2}}",
          'Tomamos u = ${_t(l)} y v = ${_t(r)}. La derivada de un cociente es (u\'v - uv\') / v².',
        );
        return res;
    }
  }

  void _chain(XNode f, XNode inner, XNode outerDeriv, XNode dInner) {
    if (inner is XVar) return;
    log?.call(
      'Regla de la cadena',
      "\\left(f(g(x))\\right)' = f'(g(x)) \\cdot g'(x) \\implies \\left(${_t(f)}\\right)' = ${_t(outerDeriv)} \\cdot \\left(${_t(dInner)}\\right)",
      'La función interior es g(x) = ${_t(inner)}: derivamos la función exterior sin tocar g y multiplicamos por g\'(x) = ${_t(dInner)}.',
    );
  }

  XNode _pow(XNode f, XNode base, XNode exp) {
    if (!Sx.hasX(exp)) {
      final n = _constValue(exp);
      if (n == null) throw const ExtUnsupported('Exponente no racional');
      final inner = d(base);
      final outer = Sx.mul(Sx.rat(n), Sx.powR(base, n - Rational(1)));
      _chain(f, base, outer, inner);
      return Sx.mul(outer, inner);
    }
    if (!Sx.hasX(base)) {
      // a^g = a^g * ln a * g'
      final isE = base is XConst && base.kind == 'e';
      final dg = d(exp);
      final outer = isE ? f : Sx.mul(f, XFn('ln', base));
      _chain(f, exp, outer, dg);
      return Sx.mul(outer, dg);
    }
    // f^g = e^(g ln f): (f^g)' = f^g (g' ln f + g f'/f)
    final df = d(base);
    final dg = d(exp);
    return Sx.mul(
      f,
      Sx.add(Sx.mul(dg, XFn('ln', base)), Sx.div(Sx.mul(exp, df), base)),
    );
  }

  XNode _fn(XFn f) {
    final u = f.arg;
    final du = d(u);
    XNode outer;
    switch (f.name) {
      case 'sin':
        outer = XFn('cos', u);
      case 'cos':
        outer = Sx.neg(XFn('sin', u));
      case 'tan':
        outer = Sx.div(Sx.one, Sx.pow(XFn('cos', u), Sx.num(2)));
      case 'asin':
        outer = Sx.div(Sx.one, XRoot(null, Sx.sub(Sx.one, Sx.pow(u, Sx.num(2)))));
      case 'acos':
        outer = Sx.neg(Sx.div(Sx.one, XRoot(null, Sx.sub(Sx.one, Sx.pow(u, Sx.num(2))))));
      case 'atan':
        outer = Sx.div(Sx.one, Sx.add(Sx.one, Sx.pow(u, Sx.num(2))));
      case 'ln':
        outer = Sx.div(Sx.one, u);
      case 'log':
        // log_b(u) = u' / (u ln b)
        final b = f.base ?? Sx.num(10);
        outer = Sx.div(Sx.one, Sx.mul(u, XFn('ln', b)));
      default:
        final h = SymDiffRules.hyperbolicOuter(f.name, u);
        if (h == null) throw const ExtUnsupported('Función no derivable en este modo');
        outer = h;
    }
    _chain(f, u, outer, du);
    return Sx.mul(outer, du);
  }
}
