import 'dart:math' as math;

import '../exact/ext_expr.dart';
import '../inequalities/universal/inequality_family_detector.dart';
import '../inequalities/universal/numeric_function.dart';
import '../trig_and_angles_solver.dart' show AngleUnit;
import 'nd_common.dart';

/// Polinomio en `x, y, z, w` con coeficientes `double` (para constantes trascendentes como
/// `log(5)·sin(5)`). Clave `"i,j,k,l"` = exponentes.
class DPoly {
  final Map<String, double> terms;
  const DPoly._(this.terms);

  static const int nv = 4;
  static const double eps = 1e-12;
  static final DPoly zero = DPoly._(const {});

  static String _key(List<int> e) => e.join(',');
  static List<int> _exps(String k) => k.split(',').map(int.parse).toList();
  static final String zeroKey = _key(List.filled(nv, 0));

  factory DPoly.fromTerms(Map<String, double> t) =>
      DPoly._({for (final e in t.entries) if (e.value.abs() > eps) e.key: e.value});

  factory DPoly.constant(double c) => DPoly.fromTerms({zeroKey: c});

  factory DPoly.variable(int i) => DPoly.fromTerms({_key(List.filled(nv, 0)..[i] = 1): 1});

  bool get isZero => terms.isEmpty;
  bool get isConstant => terms.keys.every((k) => k == zeroKey);
  double get constantTerm => terms[zeroKey] ?? 0;

  int get degree => terms.keys.fold(0, (m, k) => math.max(m, _exps(k).fold(0, (a, b) => a + b)));

  int degreeIn(int v) => terms.keys.fold(0, (m, k) => math.max(m, _exps(k)[v]));

  /// Variables que aparecen.
  Set<int> get used => {
        for (final k in terms.keys)
          for (final e in _exps(k).asMap().entries)
            if (e.value > 0) e.key,
      };

  /// Coeficiente del monomio de exponentes [e] (rellena con ceros).
  double coef(List<int> e) => terms[_key([for (var i = 0; i < nv; i++) i < e.length ? e[i] : 0])] ?? 0;

  DPoly operator +(DPoly o) {
    final t = {...terms};
    o.terms.forEach((k, v) => t[k] = (t[k] ?? 0) + v);
    return DPoly.fromTerms(t);
  }

  DPoly operator -(DPoly o) => this + o.scale(-1);

  DPoly scale(double r) => DPoly.fromTerms({for (final e in terms.entries) e.key: e.value * r});

  DPoly operator *(DPoly o) {
    final t = <String, double>{};
    for (final a in terms.entries) {
      final ea = _exps(a.key);
      for (final b in o.terms.entries) {
        final eb = _exps(b.key);
        final k = _key([for (var i = 0; i < nv; i++) ea[i] + eb[i]]);
        t[k] = (t[k] ?? 0) + a.value * b.value;
      }
    }
    return DPoly.fromTerms(t);
  }

  DPoly pow(int n) {
    var r = DPoly.constant(1);
    for (var i = 0; i < n; i++) {
      r = r * this;
    }
    return r;
  }

  /// Sustituye la variable [v] por [by].
  DPoly substitute(int v, DPoly by) {
    var out = DPoly.zero;
    for (final e in terms.entries) {
      final ex = _exps(e.key);
      final rest = [...ex]..[v] = 0;
      out = out + DPoly.fromTerms({_key(rest): e.value}) * by.pow(ex[v]);
    }
    return out;
  }

  /// Parte de la variable [v] con exponente [k]: coeficiente polinomico (sin `v`).
  DPoly coefOf(int v, int k) {
    final t = <String, double>{};
    for (final e in terms.entries) {
      final ex = _exps(e.key);
      if (ex[v] == k) t[_key([...ex]..[v] = 0)] = e.value;
    }
    return DPoly.fromTerms(t);
  }

  double eval(List<double> vals) {
    var s = 0.0;
    terms.forEach((k, c) {
      final ex = _exps(k);
      var m = c;
      for (var i = 0; i < nv; i++) {
        for (var j = 0; j < ex[i]; j++) {
          m *= vals[i];
        }
      }
      s += m;
    });
    return s;
  }

  /// Raices reales de un polinomio univariable en [v] (grado >= 1), ordenadas y sin repetir.
  List<double> realRoots(int v) {
    final d = degreeIn(v);
    if (d < 1) return const [];
    final c = [for (var k = 0; k <= d; k++) coefOf(v, k).constantTerm];
    return realRootsOf(c);
  }

  /// Raices reales de `c[0] + c[1] t + ... + c[d] t^d`.
  static List<double> realRootsOf(List<double> c) {
    var d = c.length - 1;
    while (d > 0 && c[d].abs() < eps) {
      d--;
    }
    if (d < 1) return const [];
    final out = <double>[];
    if (d == 1) {
      out.add(-c[0] / c[1]);
    } else if (d == 2) {
      final disc = c[1] * c[1] - 4 * c[2] * c[0];
      final scale = c[1] * c[1] + (4 * c[2] * c[0]).abs();
      if (disc.abs() <= 1e-12 * scale) {
        out.add(-c[1] / (2 * c[2]));
      } else if (disc > 0) {
        final s = math.sqrt(disc);
        out.addAll([(-c[1] - s) / (2 * c[2]), (-c[1] + s) / (2 * c[2])]);
      }
    } else {
      out.addAll(_durandKerner([for (var k = 0; k <= d; k++) c[k]]));
    }
    out.sort();
    final uniq = <double>[];
    for (final r in out) {
      if (uniq.isEmpty || (r - uniq.last).abs() > 1e-7 * (1 + r.abs())) uniq.add(r);
    }
    return uniq;
  }

  static List<double> _durandKerner(List<double> c) {
    final d = c.length - 1;
    final a = [for (final x in c) x / c[d]];
    final re = List<double>.generate(d, (i) => 0.4 * math.cos(2 * math.pi * i / d + 0.3) * (1 + i));
    final im = List<double>.generate(d, (i) => 0.4 * math.sin(2 * math.pi * i / d + 0.3) * (1 + i));
    (double, double) p(double x, double y) {
      var r = 1.0, i = 0.0;
      for (var k = d - 1; k >= 0; k--) {
        final nr = r * x - i * y + a[k];
        i = r * y + i * x;
        r = nr;
      }
      return (r, i);
    }

    for (var it = 0; it < 300; it++) {
      var move = 0.0;
      for (var i = 0; i < d; i++) {
        var (nr, ni) = p(re[i], im[i]);
        var dr = 1.0, di = 0.0;
        for (var j = 0; j < d; j++) {
          if (j == i) continue;
          final xr = re[i] - re[j], xi = im[i] - im[j];
          final t = dr * xr - di * xi;
          di = dr * xi + di * xr;
          dr = t;
        }
        final den = dr * dr + di * di;
        if (den == 0) continue;
        final qr = (nr * dr + ni * di) / den, qi = (ni * dr - nr * di) / den;
        re[i] -= qr;
        im[i] -= qi;
        move = math.max(move, qr.abs() + qi.abs());
      }
      if (move < 1e-14) break;
    }
    return [
      for (var i = 0; i < d; i++)
        if (im[i].abs() < 1e-6 * (1 + re[i].abs())) re[i],
    ];
  }

  /// LaTeX ordenado por grado descendente (`x^{2} + 0{,}5 y - 3`).
  String latex() {
    if (isZero) return '0';
    final keys = terms.keys.toList()
      ..sort((a, b) {
        final da = _exps(a).fold(0, (p, q) => p + q), db = _exps(b).fold(0, (p, q) => p + q);
        return da != db ? db.compareTo(da) : b.compareTo(a);
      });
    final buf = StringBuffer();
    var first = true;
    for (final k in keys) {
      final c = terms[k]!;
      final ex = _exps(k);
      final mono = StringBuffer();
      for (var i = 0; i < nv; i++) {
        if (ex[i] == 1) mono.write(NdSystem.names[i]);
        if (ex[i] > 1) mono.write('${NdSystem.names[i]}^{${ex[i]}}');
      }
      final body = mono.isEmpty
          ? NdFmt.num(c.abs())
          : ((c.abs() - 1).abs() < 1e-12 ? mono.toString() : '${NdFmt.num(c.abs())}$mono');
      if (first) {
        buf.write(c < 0 ? '-$body' : body);
      } else {
        buf.write(c < 0 ? ' - $body' : ' + $body');
      }
      first = false;
    }
    return buf.toString();
  }

  // ------------------------------------------------------------------ desde el AST
  static bool hasVar(XNode n) {
    var found = false;
    InequalityFamilyDetector.walk(n, (v) {
      if (v is XVar && v.name != 'ANS') found = true;
    });
    return found;
  }

  /// `true` si [n] (sin variables) es una constante no racional: `log(5)`, `sin(5)`, `sqrt(2)`, `e^2`...
  static bool isTranscendentalConst(XNode n) {
    if (hasVar(n)) return false;
    var found = false;
    InequalityFamilyDetector.walk(n, (v) {
      if (v is XFn || v is XConst || v is XRoot) found = true;
      if (v is XPow && !(v.exp is XNum && (v.exp as XNum).value.isInteger)) found = true;
    });
    return found;
  }

  /// Convierte el AST en polinomio; `null` si no es polinomico. Las subexpresiones sin variables
  /// se evaluan a constante (respetando [unit]); si no estan definidas lanza [FormatException].
  static DPoly? fromNode(XNode n, AngleUnit unit) {
    if (!hasVar(n)) {
      final v = NumFn.evalEnv(n, const {}, unit: unit);
      if (v == null || v.isInfinite) {
        throw const FormatException(
            'Una constante del sistema no está definida: revisa el argumento del logaritmo o de la raíz.');
      }
      return DPoly.constant(v);
    }
    switch (n) {
      case XVar(:final name):
        final i = NdSystem.vars.indexOf(name);
        return i < 0 ? null : DPoly.variable(i);
      case XNeg(:final a):
        return fromNode(a, unit)?.scale(-1);
      case XBin(:final l, :final op, :final r):
        final a = fromNode(l, unit);
        if (a == null) return null;
        if (op == '/') {
          if (hasVar(r)) return null;
          final d = NumFn.evalEnv(r, const {}, unit: unit);
          if (d == null || d == 0) {
            throw const FormatException('Hay una división entre cero en el sistema.');
          }
          return a.scale(1 / d);
        }
        final b = fromNode(r, unit);
        if (b == null) return null;
        return switch (op) { '+' => a + b, '-' => a - b, _ => a * b };
      case XPow(:final base, :final exp):
        if (hasVar(exp)) return null;
        final e = NumFn.evalEnv(exp, const {}, unit: unit);
        if (e == null || e != e.roundToDouble() || e < 0 || e > 8) return null;
        return fromNode(base, unit)?.pow(e.round());
      default:
        return null;
    }
  }
}
