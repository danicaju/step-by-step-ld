import '../../core/rational.dart';
import '../equations/eq_poly.dart';
import '../exact/ext_expr.dart';
import 'integral_table.dart';
import 'sym_build.dart';
import 'sym_diff.dart';
import 'sym_latex.dart';

typedef StepLogger = void Function(String title, String latex, String note);

/// ({coef, num, den}) factores de un producto/cociente.
typedef Factors = ({Rational coef, List<XNode> num, List<XNode> den});

/// Integracion simbolica: linealidad, tabla, sustitucion y partes.
class SymIntegrator {
  final StepLogger? log;
  SymIntegrator({this.log});

  static String _t(XNode n) => SymLatex.tex(n);
  static String _k(XNode n) => SymLatex.tex(n);

  XNode? integrate(XNode f, {int depth = 0, bool allowParts = true}) {
    if (depth > 7) return null;
    if (!Sx.hasX(f)) return Sx.mul(f, Sx.x);
    if (f is XBin && (f.op == '+' || f.op == '-')) {
      final a = integrate(f.l, depth: depth + 1, allowParts: allowParts);
      final b = integrate(f.r, depth: depth + 1, allowParts: allowParts);
      if (a == null || b == null) return null;
      return f.op == '+' ? Sx.add(a, b) : Sx.sub(a, b);
    }
    if (f is XNeg) {
      final a = integrate(f.a, depth: depth + 1, allowParts: allowParts);
      return a == null ? null : Sx.neg(a);
    }
    final cf = _constFactor(f);
    if (cf != null) {
      final r = integrate(cf.$2, depth: depth + 1, allowParts: allowParts);
      return r == null ? null : Sx.mul(cf.$1, r);
    }
    final split = _splitMonomialDenominator(f);
    if (split != null) return integrate(split, depth: depth + 1, allowParts: allowParts);
    final composite = f is XBin && f.op == '*' && Sx.hasX(f.l) && Sx.hasX(f.r);
    if (composite) {
      final sub = _substitution(f, depth);
      if (sub != null) return sub;
    }
    final direct = IntegralTable.lookup(f);
    if (direct != null) return direct;
    if (!composite) {
      final sub = _substitution(f, depth);
      if (sub != null) return sub;
    }
    if (!allowParts) return null;
    return _expTrig(f) ?? _byParts(f, depth);
  }

  (XNode, XNode)? _constFactor(XNode f) {
    if (f is XBin && f.op == '*') {
      if (!Sx.hasX(f.l)) return (f.l, f.r);
      if (!Sx.hasX(f.r)) return (f.r, f.l);
    }
    if (f is XBin && f.op == '/' && !Sx.hasX(f.r)) {
      return (Sx.div(Sx.one, f.r), f.l);
    }
    return null;
  }

  /// (a + b) / x^k  ->  a/x^k + b/x^k
  XNode? _splitMonomialDenominator(XNode f) {
    if (f is! XBin || f.op != '/') return null;
    final num = f.l;
    if (num is! XBin || (num.op != '+' && num.op != '-')) return null;
    final den = f.r;
    final mono = den is XVar ||
        (den is XPow && den.base is XVar && IntegralTable.constValue(den.exp) != null);
    if (!mono) return null;
    return num.op == '+'
        ? Sx.add(Sx.div(num.l, den), Sx.div(num.r, den))
        : Sx.sub(Sx.div(num.l, den), Sx.div(num.r, den));
  }

  // ---------------------------------------------------------------- partes

  /// e^(ax+b) * sin/cos(cx+d): integral ciclica con forma cerrada.
  XNode? _expTrig(XNode f) {
    if (f is! XBin || f.op != '*') return null;
    XNode? e;
    XFn? t;
    for (final p in [f.l, f.r]) {
      if (p is XPow && p.base is XConst && (p.base as XConst).kind == 'e') e = p;
      if (p is XFn && (p.name == 'sin' || p.name == 'cos')) t = p;
    }
    if (e == null || t == null) return null;
    final la = IntegralTable.linear((e as XPow).exp);
    final lc = IntegralTable.linear(t.arg);
    if (la == null || lc == null) return null;
    final a = la.$1;
    final c = lc.$1;
    final den = a * a + c * c;
    final u = t.arg;
    final sinU = XFn('sin', u);
    final cosU = XFn('cos', u);
    final inner = t.name == 'sin'
        ? Sx.sub(Sx.mul(Sx.rat(a), sinU), Sx.mul(Sx.rat(c), cosU))
        : Sx.add(Sx.mul(Sx.rat(a), cosU), Sx.mul(Sx.rat(c), sinU));
    log?.call(
      'Integración por partes (dos veces)',
      "I = \\int ${_t(f)}\\,dx \\implies I = ${_t(Sx.div(Sx.mul(e, inner), Sx.rat(den)))}",
      'Al aplicar partes dos veces reaparece la integral inicial I: queda una ecuación I = ... - k·I que se despeja.',
    );
    return Sx.div(Sx.mul(e, inner), Sx.rat(den));
  }

  static int _liate(XNode n) {
    if (n is XFn) {
      if (n.name == 'ln' || n.name == 'log') return 1;
      if (n.name.startsWith('a')) return 2;
      return 4;
    }
    if (n is XPow && !Sx.hasX(n.base)) return 5;
    if (n is XPow && n.base is XFn) return 4;
    if (PolyOps.polyOf(n) != null || n is XPow) return 3;
    return 3;
  }

  XNode? _byParts(XNode f, int depth) {
    XNode u;
    XNode dv;
    if (f is XBin && f.op == '*' && Sx.hasX(f.l) && Sx.hasX(f.r)) {
      final lu = _liate(f.l) <= _liate(f.r);
      u = lu ? f.l : f.r;
      dv = lu ? f.r : f.l;
    } else if (f is XFn && const {'ln', 'log', 'asin', 'acos', 'atan', 'asinh', 'acosh', 'atanh'}.contains(f.name)) {
      u = f;
      dv = Sx.one;
    } else {
      return null;
    }
    final v = dv is XNum
        ? Sx.mul(dv, Sx.x)
        : integrate(dv, depth: depth + 1, allowParts: false);
    if (v == null) return null;
    final du = SymDiff().d(u);
    final rest = integrate(Sx.mul(v, du), depth: depth + 1);
    if (rest == null) return null;
    log?.call(
      'Integración por partes',
      "\\int u\\,dv = uv - \\int v\\,du \\implies u = ${_t(u)},\\; dv = ${_t(dv)}\\,dx \\implies du = ${_t(du)}\\,dx,\\; v = ${_t(v)}",
      'Elegimos u según la regla LIATE (logaritmo, trigonométrica inversa, algebraica, trigonométrica, exponencial) y dv como el resto. Después aplicamos ∫u dv = u·v - ∫v du.',
    );
    return Sx.sub(Sx.mul(u, v), rest);
  }

  // ----------------------------------------------------------- sustitucion

  Factors _split(XNode f) {
    var coef = Rational(1);
    final num = <XNode>[];
    final den = <XNode>[];
    void walk(XNode n, bool inDen) {
      switch (n) {
        case XNum(:final value):
          coef = inDen ? coef / value : coef * value;
        case XNeg(:final a):
          coef = -coef;
          walk(a, inDen);
        case XBin(:final l, :final op, :final r) when op == '*':
          walk(l, inDen);
          walk(r, inDen);
        case XBin(:final l, :final op, :final r) when op == '/':
          walk(l, inDen);
          walk(r, !inDen);
        case XPow(:final base, :final exp) when Sx.numVal(exp)?.isNegative ?? false:
          walk(Sx.powR(base, -Sx.numVal(exp)!), !inDen);
        default:
          (inDen ? den : num).add(n);
      }
    }

    walk(f, false);
    return (coef: coef, num: num, den: den);
  }

  static bool _remove(List<XNode> from, XNode item) {
    final key = _k(item);
    final i = from.indexWhere((e) => _k(e) == key);
    if (i < 0) return false;
    from.removeAt(i);
    return true;
  }

  void _candidates(XNode n, Map<String, XNode> out) {
    void add(XNode g) {
      if (Sx.hasX(g) && g is! XVar && g is! XNum) out[_k(g)] = g;
    }

    switch (n) {
      case XFn(:final arg):
        add(n);
        add(arg);
        _candidates(arg, out);
      case XPow(:final base, :final exp):
        if (Sx.hasX(exp)) add(exp);
        if (!Sx.hasX(exp)) add(base);
        _candidates(base, out);
        _candidates(exp, out);
      case XRoot(:final rad):
        add(rad);
        _candidates(rad, out);
      case XBin(:final l, :final op, :final r):
        if (op == '/') add(r);
        _candidates(l, out);
        _candidates(r, out);
      case XNeg(:final a) || XAbs(:final a):
        _candidates(a, out);
      default:
        break;
    }
  }

  XNode? _substitution(XNode f, int depth) {
    final cands = <String, XNode>{};
    _candidates(f, cands);
    for (final g in cands.values) {
      if (IntegralTable.linear(g) != null) continue;
      final dg = SymDiff().d(g);
      final ff = _split(f);
      final gg = _split(dg);
      if (gg.coef.isZero) continue;
      final num = List<XNode>.of(ff.num);
      final den = List<XNode>.of(ff.den);
      var ok = true;
      for (final x in gg.num) {
        if (!_remove(num, x)) ok = false;
      }
      for (final x in gg.den) {
        if (!_remove(den, x)) ok = false;
      }
      if (!ok) continue;
      final coef = ff.coef / gg.coef;
      XNode rest = Sx.rat(coef);
      for (final x in num) {
        rest = Sx.mul(rest, x);
      }
      for (final x in den) {
        rest = Sx.div(rest, x);
      }
      final gKey = _k(g);
      const u = XVar('U');
      final inU = Sx.subst(rest, (n) => _k(n) == gKey, u);
      if (_hasX(inU)) continue;
      final asX = Sx.subst(inU, (n) => n is XVar && n.name == 'U', Sx.x);
      final inner = SymIntegrator(log: null).integrate(asX, depth: depth + 1);
      if (inner == null) continue;
      final back = Sx.subst(inner, (n) => n is XVar, g);
      log?.call(
        'Cambio de variable (sustitución)',
        "u = ${_t(g)} \\implies du = ${_t(dg)}\\,dx \\implies \\int ${_t(asXu(asX))}\\,du = ${_t(asXu(inner))}",
        'Si la integral tiene la forma ∫f\'(g(x))·g\'(x)dx, llamamos u = g(x), du = g\'(x)dx. Integramos en u y deshacemos el cambio sustituyendo u = ${_t(g)}.',
      );
      return back;
    }
    return null;
  }

  static XNode asXu(XNode n) => Sx.subst(n, (e) => e is XVar, const XVar('u'));

  static bool _hasX(XNode n) => switch (n) {
        XVar(:final name) => name == 'X',
        XNeg(:final a) || XAbs(:final a) || XFact(:final a) => _hasX(a),
        XBin(:final l, :final r) => _hasX(l) || _hasX(r),
        XPow(:final base, :final exp) => _hasX(base) || _hasX(exp),
        XRoot(:final index, :final rad) => _hasX(rad) || (index != null && _hasX(index)),
        XFn(:final arg, :final base) => _hasX(arg) || (base != null && _hasX(base)),
        _ => false,
      };
}
