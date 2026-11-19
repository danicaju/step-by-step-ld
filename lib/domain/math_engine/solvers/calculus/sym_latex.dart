import '../../core/rational.dart';
import '../exact/ext_expr.dart';
import 'sym_build.dart';

/// Impresor LaTeX "de libro de texto" para expresiones simbolicas:
/// coeficientes pegados (2x), potencias negativas como fracciones, raices y
/// restas sin `+ -`.
class SymLatex {
  const SymLatex._();

  static String tex(XNode n) => _t(n);

  static bool _isAtom(XNode n) => switch (n) {
        XNum(:final value) => !value.isNegative && value.isInteger,
        XVar() || XConst() || XRoot() || XAbs() || XFact() => true,
        XFn() => true,
        XPow() => true,
        XBin(:final op) => op == '/',
        _ => false,
      };

  static String _wrap(XNode n) =>
      _isAtom(n) && n is! XBin ? _t(n) : '\\left(${_t(n)}\\right)';

  static String _t(XNode n) {
    switch (n) {
      case XNum():
        return n.latex();
      case XConst() || XVar():
        return n.latex();
      case XNeg(:final a):
        final inner = _t(a);
        return a is XBin && (a.op == '+' || a.op == '-') ? '-\\left($inner\\right)' : '-$inner';
      case XBin(:final l, :final op, :final r):
        return _bin(l, op, r);
      case XPow(:final base, :final exp):
        return _pow(base, exp);
      case XRoot(:final index, :final rad):
        return index == null || Sx.isNum(index, 2)
            ? '\\sqrt{${_t(rad)}}'
            : '\\sqrt[${_t(index)}]{${_t(rad)}}';
      case XAbs(:final a):
        return '\\left|${_t(a)}\\right|';
      case XFact(:final a):
        return '${_wrap(a)}!';
      case XComb():
        return n.latex();
      case XFn():
        return _fn(n);
    }
  }

  static String _fn(XFn f) {
    final a = _t(f.arg);
    if (f.name == 'ln' && f.arg is XAbs) {
      return '\\ln${_t(f.arg)}';
    }
    if (f.name == 'log') {
      return f.base == null
          ? '\\log\\left($a\\right)'
          : '\\log_{${_t(f.base!)}}\\left($a\\right)';
    }
    const inv = {'asin': 'arcsin', 'acos': 'arccos', 'atan': 'arctan'};
    return '\\${inv[f.name] ?? f.name}\\left($a\\right)';
  }

  static String _bin(XNode l, String op, XNode r) {
    switch (op) {
      case '+':
        return _sum(l, r, true);
      case '-':
        return _sum(l, r, false);
      default:
        return _frac(XBin(l, op, r));
    }
  }

  static String _sum(XNode l, XNode r, bool plus) {
    final left = _t(l);
    final negR = r is XNeg || (Sx.numVal(r)?.isNegative ?? false);
    var rr = negR ? _t(Sx.neg(r)) : _t(r);
    var flip = negR;
    final isSum = r is XBin && (r.op == '+' || r.op == '-');
    if (isSum && !negR) {
      rr = plus ? rr : '\\left($rr\\right)';
    } else if (!negR && !isSum && rr.startsWith('-')) {
      // Producto o cociente con coeficiente negativo (`-2/x`): el signo pasa al operador.
      rr = rr.substring(1);
      flip = true;
    }
    if (flip) return '$left ${plus ? '-' : '+'} $rr';
    return '$left ${plus ? '+' : '-'} $rr';
  }

  /// Producto/cociente normalizado a una sola fraccion `coef * nums / dens`.
  static String _frac(XNode n) {
    var coef = Rational(1);
    final num = <XNode>[];
    final den = <XNode>[];
    void walk(XNode t, bool inv) {
      switch (t) {
        case XNum(:final value) when !value.isZero:
          coef = inv ? coef / value : coef * value;
        case XNeg(:final a):
          coef = -coef;
          walk(a, inv);
        case XBin(:final l, :final op, :final r) when op == '*':
          walk(l, inv);
          walk(r, inv);
        case XBin(:final l, :final op, :final r) when op == '/':
          walk(l, inv);
          walk(r, !inv);
        case XPow(:final base, :final exp) when Sx.numVal(exp)?.isNegative ?? false:
          (inv ? num : den).add(Sx.pow(base, XNum(-Sx.numVal(exp)!)));
        default:
          (inv ? den : num).add(t);
      }
    }

    walk(n, false);
    final sign = coef.isNegative ? '-' : '';
    final c = coef.abs();
    final nStr = _factors(c.numerator, num);
    if (den.isEmpty && c.denominator == 1) return '$sign$nStr';
    final dStr = _factors(c.denominator, den);
    return '$sign\\frac{$nStr}{$dStr}';
  }

  static String _factors(int coef, List<XNode> fs) {
    if (fs.isEmpty) return '$coef';
    String w(XNode t) {
      final single = fs.length == 1 && coef == 1;
      if (single) return _t(t);
      return t is XBin && (t.op == '+' || t.op == '-') || t is XNeg
          ? '\\left(${_t(t)}\\right)'
          : _t(t);
    }

    final parts = <String>[if (coef != 1) '$coef', ...fs.map(w)];
    final buf = StringBuffer(parts.first);
    for (var i = 1; i < parts.length; i++) {
      final p = parts[i];
      final needDot = RegExp(r'^[0-9]|^\\frac').hasMatch(p);
      buf.write(needDot ? ' \\cdot $p' : p);
    }
    return buf.toString();
  }

  static String _pow(XNode base, XNode exp) {
    final ve = Sx.numVal(exp);
    if (ve != null) {
      if (ve.isNegative) {
        final pos = Sx.pow(base, XNum(-ve));
        return '\\frac{1}{${_t(pos)}}';
      }
      if (ve == Rational(1, 2)) return '\\sqrt{${_t(base)}}';
      if (ve.denominator != 1) {
        if (ve.numerator == 1) return '\\sqrt[${ve.denominator}]{${_t(base)}}';
        return '${_pb(base)}^{${_t(exp)}}';
      }
      if (base is XFn && ve.isInteger) {
        final s = _fn(base);
        final cut = s.indexOf('\\left(');
        return '${s.substring(0, cut)}^{${ve.numerator}}${s.substring(cut)}';
      }
    }
    return '${_pb(base)}^{${_t(exp)}}';
  }

  static String _pb(XNode b) {
    if (b is XConst || b is XVar) return _t(b);
    if (b is XNum && !b.value.isNegative && b.value.isInteger) return _t(b);
    if (b is XFn) return _t(b);
    return '\\left(${_t(b)}\\right)';
  }
}
