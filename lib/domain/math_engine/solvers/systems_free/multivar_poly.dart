import '../../core/rational.dart';
import '../exact/ext_expr.dart';

/// Polinomio en `x`, `y`, `z`, `w` con coeficientes racionales exactos (clave `"i,j,k,l"` = exponentes).
class MPoly {
  final Map<String, Rational> terms;
  const MPoly._(this.terms);

  static const List<String> names = ['x', 'y', 'z', 'w'];
  static const int nVars = 4;
  static const String zeroKey = '0,0,0,0';

  static String _key(List<int> e) => [for (var i = 0; i < nVars; i++) i < e.length ? e[i] : 0].join(',');
  static List<int> _exps(String k) => k.split(',').map(int.parse).toList();

  factory MPoly.fromTerms(Map<String, Rational> t) =>
      MPoly._({for (final e in t.entries) if (!e.value.isZero) e.key: e.value});

  factory MPoly.constant(Rational r) => MPoly.fromTerms({zeroKey: r});

  factory MPoly.variable(int idx) {
    final e = List<int>.filled(nVars, 0)..[idx] = 1;
    return MPoly.fromTerms({_key(e): Rational(1)});
  }

  static final MPoly zero = MPoly._(const {});

  bool get isZero => terms.isEmpty;

  /// Grado total (0 para constantes y el polinomio nulo).
  int get degree => terms.keys.fold(0, (m, k) {
        final d = _exps(k).fold(0, (a, b) => a + b);
        return d > m ? d : m;
      });

  bool get isConstant => terms.keys.every((k) => k == zeroKey);

  Rational get constantTerm => terms[zeroKey] ?? Rational(0);

  /// Coeficiente del monomio de exponentes [e].
  Rational coef(List<int> e) => terms[_key(e)] ?? Rational(0);

  /// Grado en la variable [v] (0 = x, 1 = y, 2 = z, 3 = w).
  int degreeIn(int v) => terms.keys.fold(0, (m, k) {
        final d = _exps(k)[v];
        return d > m ? d : m;
      });

  MPoly operator +(MPoly o) {
    final t = {...terms};
    o.terms.forEach((k, v) => t[k] = (t[k] ?? Rational(0)) + v);
    return MPoly.fromTerms(t);
  }

  MPoly operator -(MPoly o) => this + o.scale(Rational(-1));

  MPoly scale(Rational r) => MPoly.fromTerms({for (final e in terms.entries) e.key: e.value * r});

  MPoly operator *(MPoly o) {
    final t = <String, Rational>{};
    for (final a in terms.entries) {
      final ea = _exps(a.key);
      for (final b in o.terms.entries) {
        final eb = _exps(b.key);
        final k = _key([for (var i = 0; i < nVars; i++) ea[i] + eb[i]]);
        t[k] = (t[k] ?? Rational(0)) + a.value * b.value;
      }
    }
    return MPoly.fromTerms(t);
  }

  MPoly pow(int n) {
    var r = MPoly.constant(Rational(1));
    for (var i = 0; i < n; i++) {
      r = r * this;
    }
    return r;
  }

  /// Sustituye la variable [v] por el polinomio [by].
  MPoly substitute(int v, MPoly by) {
    var out = MPoly.zero;
    for (final e in terms.entries) {
      final ex = _exps(e.key);
      final k = ex[v];
      final rest = [...ex]..[v] = 0;
      out = out + MPoly.fromTerms({_key(rest): e.value}) * by.pow(k);
    }
    return out;
  }

  /// Polinomio univariable en [v] como mapa `grado -> coeficiente` (otras variables deben ser 0).
  Map<int, Rational>? univariate(int v) {
    final out = <int, Rational>{};
    for (final e in terms.entries) {
      final ex = _exps(e.key);
      for (var i = 0; i < nVars; i++) {
        if (i != v && ex[i] != 0) return null;
      }
      out[ex[v]] = e.value;
    }
    return out;
  }

  /// Valor numerico con las variables dadas.
  double eval(List<double> vals) {
    var s = 0.0;
    terms.forEach((k, c) {
      final ex = _exps(k);
      var m = c.toDouble();
      for (var i = 0; i < nVars; i++) {
        for (var j = 0; j < ex[i]; j++) {
          m *= vals[i];
        }
      }
      s += m;
    });
    return s;
  }

  /// LaTeX ordenado por grado descendente (`x^{2} + y^{2} - 25`).
  String latex() {
    if (isZero) return '0';
    final keys = terms.keys.toList()
      ..sort((a, b) {
        final da = _exps(a).fold(0, (p, q) => p + q), db = _exps(b).fold(0, (p, q) => p + q);
        if (da != db) return db.compareTo(da);
        return b.compareTo(a);
      });
    final buf = StringBuffer();
    var first = true;
    for (final k in keys) {
      final c = terms[k]!;
      final ex = _exps(k);
      final mono = StringBuffer();
      for (var i = 0; i < nVars; i++) {
        if (ex[i] == 1) mono.write(names[i]);
        if (ex[i] > 1) mono.write('${names[i]}^{${ex[i]}}');
      }
      final body = mono.isEmpty
          ? c.abs().toLatex()
          : (c.abs() == Rational(1) ? mono.toString() : '${c.abs().toLatex()}$mono');
      if (first) {
        buf.write(c.isNegative ? '-$body' : body);
      } else {
        buf.write(c.isNegative ? ' - $body' : ' + $body');
      }
      first = false;
    }
    return buf.toString();
  }
}

/// Funcion racional `num/den` de polinomios (para quitar denominadores).
class RFun {
  final MPoly num;
  final MPoly den;
  const RFun(this.num, this.den);

  factory RFun.poly(MPoly p) => RFun(p, MPoly.constant(Rational(1)));

  RFun operator +(RFun o) => RFun(num * o.den + o.num * den, den * o.den);
  RFun operator -(RFun o) => RFun(num * o.den - o.num * den, den * o.den);
  RFun operator *(RFun o) => RFun(num * o.num, den * o.den);
  RFun? div(RFun o) => o.num.isZero ? null : RFun(num * o.den, den * o.num);

  RFun? pow(int n) {
    if (n >= 0) return RFun(num.pow(n), den.pow(n));
    if (num.isZero) return null;
    return RFun(den.pow(-n), num.pow(-n));
  }

  /// Convierte el AST en funcion racional; `null` si lleva raices, logaritmos o exponentes variables.
  static RFun? fromNode(XNode n) {
    switch (n) {
      case XNum(:final value):
        return RFun.poly(MPoly.constant(value));
      case XVar(:final name):
        final i = switch (name) { 'X' => 0, 'Y' => 1, 'Z' => 2, 'W' => 3, _ => -1 };
        return i < 0 ? null : RFun.poly(MPoly.variable(i));
      case XNeg(:final a):
        final v = fromNode(a);
        return v == null ? null : RFun(v.num.scale(Rational(-1)), v.den);
      case XBin(:final l, :final op, :final r):
        final a = fromNode(l), b = fromNode(r);
        if (a == null || b == null) return null;
        return switch (op) { '+' => a + b, '-' => a - b, '*' => a * b, _ => a.div(b) };
      case XPow(:final base, :final exp):
        final b = fromNode(base);
        if (b == null || exp is! XNum || !exp.value.isInteger) return null;
        final e = exp.value.numerator;
        if (e.abs() > 8) return null;
        return b.pow(e);
      default:
        return null;
    }
  }
}
