import 'dart:math' as math;

import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/equations/eq_poly.dart';
import '../solvers/exact/ext_expr.dart';
import 'function_numeric.dart';

/// Extremo de un intervalo del dominio (con su LaTeX exacto).
class DomainBound {
  final double v;
  final String latex;
  const DomainBound(this.v, this.latex);

  static const negInf = DomainBound(double.negativeInfinity, r'-\infty');
  static const posInf = DomainBound(double.infinity, r'+\infty');
  bool get isInf => v.isInfinite;
}

class DomainInterval {
  final DomainBound lo;
  final DomainBound hi;
  final bool loOpen;
  final bool hiOpen;
  const DomainInterval(this.lo, this.hi, {this.loOpen = true, this.hiOpen = true});

  bool contains(double x) =>
      (x > lo.v || (x == lo.v && !loOpen)) && (x < hi.v || (x == hi.v && !hiOpen));

  String get latex {
    if (lo.v == hi.v) return '\\left\\{${lo.latex}\\right\\}';
    final l = loOpen || lo.isInf ? '(' : '[';
    final r = hiOpen || hi.isInf ? ')' : ']';
    return '$l${lo.latex},\\,${hi.latex}$r';
  }
}

class DomainResult {
  final List<DomainInterval> intervals;
  final List<MathStep> steps;
  final List<String> notes;

  const DomainResult(this.intervals, this.steps, this.notes);

  bool contains(double x) => intervals.any((i) => i.contains(x));

  /// Extremos finitos de los intervalos: candidatos a asintota vertical.
  List<double> get finiteBoundaries {
    final out = <double>{};
    for (final i in intervals) {
      if (!i.lo.isInf) out.add(i.lo.v);
      if (!i.hi.isInf) out.add(i.hi.v);
    }
    return out.toList()..sort();
  }

  bool get isAllReals => intervals.length == 1 && intervals.first.lo.isInf && intervals.first.hi.isInf;

  String get latex => intervals.isEmpty
      ? r'\varnothing'
      : isAllReals
          ? r'\mathbb{R}'
          : intervals.map((i) => i.latex).join(r' \cup ');
}

class _Constraint {
  final Poly g;
  final String kind; // ne | ge | gt
  const _Constraint(this.g, this.kind);

  String get latex {
    final sym = switch (kind) { 'ne' => r'\neq 0', 'ge' => r'\geq 0', _ => '> 0' };
    return '${PolyOps.latex(g)} $sym';
  }
}

/// Dominio de f(x): polinomicas, racionales, raices de indice par y logaritmos.
class DomainSolver {
  const DomainSolver._();

  static DomainResult of(FunctionModel f) {
    final cons = <_Constraint>[];
    final notes = <String>[];
    _collect(f.node, cons, notes);
    final seen = <String>{};
    cons.retainWhere((c) => seen.add('${c.kind}${c.latex}'));

    var set = <DomainInterval>[const DomainInterval(DomainBound.negInf, DomainBound.posInf)];
    for (final c in cons) {
      set = _intersect(set, _solve(c));
    }
    set = _merge(set);

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Condiciones del dominio',
        latexExpression: cons.isEmpty
            ? r'\text{sin restricciones}'
            : cons.map((c) => c.latex).join(r';\;'),
        pedagogicalNote: cons.isEmpty
            ? 'Una funcion polinomica esta definida para todo numero real.'
            : 'Denominador distinto de 0, radicando de indice par mayor o igual que 0 y argumento del logaritmo mayor que 0.',
        warningTrick: notes.isEmpty ? null : notes.join(' '),
      ),
    ];
    final res = DomainResult(set, steps, notes);
    return DomainResult(set, [
      ...steps,
      MathStep(
        index: 2,
        shortTitle: 'Dominio en intervalos',
        latexExpression: r'\mathrm{Dom}(f) = ' + res.latex,
        pedagogicalNote: 'Resolvemos cada condicion con el signo del polinomio entre sus raices y tomamos la interseccion.',
      ),
    ], notes);
  }

  // --------------------------------------------------------------- condiciones

  static bool _evenIndex(XNode? index) {
    if (index == null) return true;
    return index is XNum && index.value.isInteger && index.value.numerator.isEven;
  }

  static void _collect(XNode n, List<_Constraint> out, List<String> notes) {
    switch (n) {
      case XBin(:final l, :final op, :final r):
        if (op == '/' && PolyOps.containsX(r)) {
          final p = PolyOps.polyOf(r);
          if (p != null) {
            out.add(_Constraint(p, 'ne'));
          } else if (r is XRoot) {
            final rp = PolyOps.polyOf(r.rad);
            if (rp != null) out.add(_Constraint(rp, _evenIndex(r.index) ? 'gt' : 'ne'));
          } else {
            notes.add('Hay un denominador no polinomico: el dominio se estima.');
          }
        }
        _collect(l, out, notes);
        _collect(r, out, notes);
      case XNeg(:final a) || XAbs(:final a) || XFact(:final a):
        _collect(a, out, notes);
      case XRoot(:final index, :final rad):
        if (_evenIndex(index)) {
          final p = PolyOps.polyOf(rad);
          if (p != null) out.add(_Constraint(p, 'ge'));
        }
        _collect(rad, out, notes);
      case XPow(:final base, :final exp):
        final ep = PolyOps.polyOf(exp);
        final e = ep != null && PolyOps.degree(ep) <= 0 ? PolyOps.coeff(ep, 0) : null;
        final bp = PolyOps.polyOf(base);
        if (e != null && bp != null && !e.isZero) {
          if (e.isInteger) {
            if (e.isNegative) out.add(_Constraint(bp, 'ne'));
          } else if (e.denominator.isEven) {
            out.add(_Constraint(bp, e.isNegative ? 'gt' : 'ge'));
          } else if (e.isNegative) {
            out.add(_Constraint(bp, 'ne'));
          }
        }
        _collect(base, out, notes);
      case XFn(:final name, :final arg):
        final p = PolyOps.polyOf(arg);
        if (name == 'ln' || name == 'log') {
          if (p != null) out.add(_Constraint(p, 'gt'));
        } else if (name == 'tan') {
          notes.add('tan(x) no esta definida en x = pi/2 + k pi.');
        } else if (p != null) {
          final one = PolyOps.constant(Rational(1));
          switch (name) {
            case 'asin' || 'acos':
              out.add(_Constraint(PolyOps.sub(one, p), 'ge'));
              out.add(_Constraint(PolyOps.add(one, p), 'ge'));
            case 'acosh':
              out.add(_Constraint(PolyOps.sub(p, one), 'ge'));
            case 'atanh':
              out.add(_Constraint(PolyOps.sub(one, p), 'gt'));
              out.add(_Constraint(PolyOps.add(one, p), 'gt'));
          }
        }
        _collect(arg, out, notes);
      default:
        break;
    }
  }

  // ------------------------------------------------------------ analisis de signo

  static double _val(Poly p, double x) {
    var acc = 0.0;
    p.forEach((k, c) => acc += c.toDouble() * math.pow(x, k));
    return acc;
  }

  static List<DomainInterval> _solve(_Constraint c) {
    final all = [const DomainInterval(DomainBound.negInf, DomainBound.posInf)];
    final g = PolyOps.clean(c.g);
    if (PolyOps.degree(g) <= 0) {
      final v = g.isEmpty ? 0.0 : g[0]!.toDouble();
      final ok = switch (c.kind) { 'ne' => v != 0, 'ge' => v >= 0, _ => v > 0 };
      return ok ? all : const [];
    }
    final roots = PolyRoots.real(g);
    final pts = [DomainBound.negInf, for (final r in roots) DomainBound(r.approx, r.toLatex()), DomainBound.posInf];
    final out = <DomainInterval>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i].v, b = pts[i + 1].v;
      final mid = a.isInfinite ? b - 1 : (b.isInfinite ? a + 1 : (a + b) / 2);
      final positive = _val(g, mid) > 0;
      if (c.kind == 'ne' || positive) {
        out.add(DomainInterval(pts[i], pts[i + 1], loOpen: c.kind != 'ge', hiOpen: c.kind != 'ge'));
      }
    }
    if (c.kind == 'ge') {
      // Las raices (g = 0) tambien cumplen g >= 0, incluso aisladas.
      for (final r in roots) {
        final b = DomainBound(r.approx, r.toLatex());
        out.add(DomainInterval(b, b, loOpen: false, hiOpen: false));
      }
    }
    return _merge(out);
  }

  static List<DomainInterval> _intersect(List<DomainInterval> a, List<DomainInterval> b) {
    final out = <DomainInterval>[];
    for (final x in a) {
      for (final y in b) {
        final lo = x.lo.v > y.lo.v || (x.lo.v == y.lo.v && x.loOpen) ? x : y;
        final hi = x.hi.v < y.hi.v || (x.hi.v == y.hi.v && x.hiOpen) ? x : y;
        final loOpen = x.lo.v == y.lo.v ? (x.loOpen || y.loOpen) : lo.loOpen;
        final hiOpen = x.hi.v == y.hi.v ? (x.hiOpen || y.hiOpen) : hi.hiOpen;
        if (lo.lo.v < hi.hi.v || (lo.lo.v == hi.hi.v && !loOpen && !hiOpen)) {
          out.add(DomainInterval(lo.lo, hi.hi, loOpen: loOpen, hiOpen: hiOpen));
        }
      }
    }
    return out;
  }

  static List<DomainInterval> _merge(List<DomainInterval> list) {
    final s = [...list]..sort((p, q) => p.lo.v != q.lo.v ? p.lo.v.compareTo(q.lo.v) : (p.loOpen ? 1 : 0) - (q.loOpen ? 1 : 0));
    final out = <DomainInterval>[];
    for (final i in s) {
      if (out.isNotEmpty) {
        final last = out.last;
        final touch = i.lo.v < last.hi.v || (i.lo.v == last.hi.v && !(i.loOpen && last.hiOpen));
        if (touch) {
          final useHi = i.hi.v > last.hi.v || (i.hi.v == last.hi.v && !i.hiOpen);
          out[out.length - 1] = DomainInterval(
            last.lo,
            useHi ? i.hi : last.hi,
            loOpen: last.loOpen,
            hiOpen: useHi ? i.hiOpen : last.hiOpen,
          );
          continue;
        }
      }
      out.add(i);
    }
    return out;
  }
}

/// Ayuda para mostrar un `Rational` como LaTeX sin depender de SETUP.
String domainRationalLatex(Rational r) =>
    r.isInteger ? '${r.numerator}' : '${r.isNegative ? '-' : ''}\\frac{${r.numerator.abs()}}{${r.denominator}}';
