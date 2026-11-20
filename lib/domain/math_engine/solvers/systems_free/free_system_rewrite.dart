import '../../core/rational.dart';
import '../exact/ext_expr.dart';
import '../inequalities/universal/inequality_family_detector.dart';
import '../inequalities/universal/numeric_function.dart';
import 'multivar_poly.dart';

/// Ecuacion ya reducida a `poly = 0`, con las condiciones de existencia que impuso.
class EqForm {
  final MPoly poly;
  final List<String> conditions;

  /// LaTeX de la transformacion aplicada (`null` si la ecuacion ya era polinomica).
  final String? rewrite;

  /// Explicacion en texto plano de la transformacion.
  final String? note;

  const EqForm(this.poly, {this.conditions = const [], this.rewrite, this.note});
}

/// Lleva una ecuacion `lhs = rhs` (racional, exponencial o logaritmica) a un polinomio igualado a 0.
abstract final class FreeSystemRewrite {
  static EqForm rewrite(XNode l, XNode r) =>
      _direct(l, r) ??
      _exponential(l, r) ??
      _logarithmic(l, r) ??
      (throw const FormatException(
          'Ecuación no soportada: usa polinomios, fracciones, logaritmos o exponenciales.'));

  // --------------------------------------------------------------- directa
  static EqForm? _direct(XNode l, XNode r) {
    final a = RFun.fromNode(l), b = RFun.fromNode(r);
    if (a == null || b == null) return null;
    final diff = a - b;
    final conds = {
      ...InequalityFamilyDetector.domainConditions(l),
      ...InequalityFamilyDetector.domainConditions(r),
    }.toList();
    final cleared = !diff.den.isConstant;
    return EqForm(
      diff.num,
      conditions: conds,
      rewrite: cleared ? '${l.latex()} = ${r.latex()} \\implies ${diff.num.latex()} = 0' : null,
      note: cleared
          ? 'Multiplicamos por los denominadores para quitarlos. Los valores que los anulan quedan excluidos al final.'
          : null,
    );
  }

  static Rational? _constant(XNode n) {
    if (NumFn.hasX(n) || _hasAnyVar(n)) return null;
    final f = RFun.fromNode(n);
    if (f == null || !f.num.isConstant || !f.den.isConstant || f.den.constantTerm.isZero) return null;
    return f.num.constantTerm / f.den.constantTerm;
  }

  static bool _hasAnyVar(XNode n) {
    var found = false;
    InequalityFamilyDetector.walk(n, (v) {
      if (v is XVar) found = true;
    });
    return found;
  }

  // ---------------------------------------------------------- exponenciales
  /// `base^E` o producto / cociente de potencias de la misma base: `(base, E)`.
  static (Rational, XNode)? _expOf(XNode n) {
    if (n is XPow && _hasAnyVar(n.exp)) {
      final b = _constant(n.base);
      return b == null || b.isNegative || b.isZero || b == Rational(1) ? null : (b, n.exp);
    }
    if (n is XBin && (n.op == '*' || n.op == '/')) {
      final a = _expOf(n.l), b = _expOf(n.r);
      if (a == null || b == null || a.$1 != b.$1) return null;
      return (a.$1, XBin(a.$2, n.op == '*' ? '+' : '-', b.$2));
    }
    return null;
  }

  static int? _intLog(Rational base, Rational c) {
    if (c.isNegative || c.isZero) return null;
    for (var k = -18; k <= 18; k++) {
      if (base.pow(k) == c) return k;
    }
    return null;
  }

  static EqForm? _exponential(XNode l, XNode r) {
    final el = _expOf(l), er = _expOf(r);
    if (el == null && er == null) return null;
    XNode exponent;
    String latex;
    if (el != null && er != null && el.$1 == er.$1) {
      exponent = XBin(el.$2, '-', er.$2);
      latex = '${l.latex()} = ${r.latex()} \\implies ${el.$2.latex()} = ${er.$2.latex()}';
    } else {
      final (b, e, c) = el != null ? (el.$1, el.$2, _constant(r)) : (er!.$1, er.$2, _constant(l));
      if (c == null) return null;
      final k = _intLog(b, c);
      if (k == null) {
        throw FormatException('La ecuación exponencial no se puede resolver de forma exacta (${c.toLatex()} no es potencia de ${b.toLatex()}).');
      }
      exponent = XBin(e, '-', XNum(Rational(k)));
      latex = '${l.latex()} = ${r.latex()} \\implies ${e.latex()} = $k';
    }
    final f = RFun.fromNode(exponent);
    if (f == null) return null;
    return EqForm(
      f.num,
      rewrite: latex,
      note: 'Con la misma base se suman o restan los exponentes y se igualan: si las bases son iguales, los exponentes también.',
    );
  }

  // ------------------------------------------------------------ logaritmos
  static bool _collect(XNode n, int sign, List<(XNode, int)> logs, List<Rational> consts, List<Rational> bases) {
    switch (n) {
      case XBin(:final l, :final op, :final r) when op == '+' || op == '-':
        return _collect(l, sign, logs, consts, bases) && _collect(r, op == '+' ? sign : -sign, logs, consts, bases);
      case XNeg(:final a):
        return _collect(a, -sign, logs, consts, bases);
      case XFn(:final name, :final arg, :final base) when (name == 'ln' || name == 'log') && _hasAnyVar(arg):
        final bv = name == 'ln' ? Rational(-1) : (base == null ? Rational(10) : _constant(base));
        if (bv == null || bv.isZero || bv == Rational(1) || (bv.isNegative && name != 'ln')) return false;
        bases.add(bv);
        logs.add((arg, sign));
        return true;
      case XBin(:final l, :final op, :final r) when op == '*':
        final k = _constant(l);
        if (k != null && k.isInteger && r is XFn) return _collectScaled(r, sign * k.numerator, logs, consts, bases);
        final k2 = _constant(r);
        if (k2 != null && k2.isInteger && l is XFn) return _collectScaled(l, sign * k2.numerator, logs, consts, bases);
        return false;
      default:
        final c = _constant(n);
        if (c == null) return false;
        consts.add(c * Rational(sign));
        return true;
    }
  }

  static bool _collectScaled(XFn f, int k, List<(XNode, int)> logs, List<Rational> consts, List<Rational> bases) {
    final tmp = <(XNode, int)>[];
    if (!_collect(f, 1, tmp, consts, bases) || tmp.length != 1) return false;
    logs.add((tmp.first.$1, tmp.first.$2 * k));
    return true;
  }

  static EqForm? _logarithmic(XNode l, XNode r) {
    final logs = <(XNode, int)>[];
    final consts = <Rational>[];
    final bases = <Rational>[];
    if (!_collect(l, 1, logs, consts, bases) || !_collect(r, -1, logs, consts, bases) || logs.isEmpty) return null;
    if (bases.any((b) => b != bases.first)) {
      throw const FormatException('Los logaritmos deben tener la misma base para combinarlos.');
    }
    final total = consts.fold(Rational(0), (a, b) => a + b);
    final rhsExp = -total; // sum k_i log(a_i) = rhsExp
    final isE = bases.first.isNegative;
    if (isE && !rhsExp.isZero) {
      throw const FormatException('Con logaritmos neperianos el segundo miembro debe ser 0 para obtener solución exacta.');
    }
    if (!isE && !rhsExp.isInteger) {
      throw const FormatException('El segundo miembro de la ecuación logarítmica debe ser un entero.');
    }
    final bPow = isE ? Rational(1) : bases.first.pow(rhsExp.numerator);
    var prod = RFun.poly(MPoly.constant(Rational(1)));
    final conds = <String>[];
    for (final (arg, k) in logs) {
      final f = RFun.fromNode(arg);
      if (f == null) return null;
      final p = f.pow(k);
      if (p == null) return null;
      prod = prod * p;
      final c = '${arg.latex()} > 0';
      if (!conds.contains(c)) conds.add(c);
    }
    final poly = prod.num - prod.den.scale(bPow);
    final shown = StringBuffer();
    final up = [for (final (a, k) in logs) if (k > 0) _power(a, k)];
    final down = [for (final (a, k) in logs) if (k < 0) _power(a, -k)];
    final numTex = up.isEmpty ? '1' : up.join(r' \cdot ');
    shown.write(down.isEmpty ? numTex : '\\frac{$numTex}{${down.join(r' \cdot ')}}');
    return EqForm(
      poly,
      conditions: conds,
      rewrite: '${l.latex()} = ${r.latex()} \\implies $shown = ${bPow.toLatex()}',
      note:
          'La suma de logaritmos es el logaritmo del producto y la resta el del cociente. Después se pasa a forma exponencial. Cada argumento debe ser positivo: si no, la solución se descarta.',
    );
  }

  static String _power(XNode a, int k) => k == 1 ? a.wrap(2) : '${a.wrap(5)}^{$k}';
}
