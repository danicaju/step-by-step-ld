import 'dart:math' as math;

import '../core/rational.dart';
import '../solvers/equations/eq_poly.dart';
import '../solvers/exact/ext_expr.dart';
import 'function_family.dart';

/// Reconoce a que familia pertenece una f(x) y extrae sus coeficientes.
///
/// Forma general admitida: `A * g(B x + C) + D` con g = raiz, `a^x`, log, sin, cos, tan;
/// ademas de polinomios (grado 0..3) y fracciones algebraicas P(x)/Q(x).
class FunctionFamilyClassifier {
  const FunctionFamilyClassifier._();

  static FamilyInfo detect(XNode node) {
    final core = _peel(node);
    if (core != null) return core;
    final poly = PolyOps.polyOf(node);
    if (poly != null) {
      final fam = switch (PolyOps.degree(poly)) {
        <= 0 => FunctionFamily.constant,
        1 => FunctionFamily.linear,
        2 => FunctionFamily.quadratic,
        3 => FunctionFamily.cubic,
        _ => FunctionFamily.unknown,
      };
      return FamilyInfo(fam, poly: poly);
    }
    final rat = PolyOps.rationalOf(node);
    if (rat != null && PolyOps.degree(rat.$2) >= 1) {
      return FamilyInfo(FunctionFamily.rational, poly: rat.$1, den: rat.$2);
    }
    return FamilyInfo(FunctionFamily.unknown);
  }

  /// Constante racional del nodo (sin x), si lo es.
  static Rational? _const(XNode n) {
    final p = PolyOps.polyOf(n);
    return p != null && PolyOps.degree(p) <= 0 ? PolyOps.coeff(p, 0) : null;
  }

  /// Polinomio de grado exactamente 1 en x.
  static Poly? _linear(XNode n) {
    final p = PolyOps.polyOf(n);
    return p != null && PolyOps.degree(p) == 1 ? p : null;
  }

  /// Quita constantes aditivas y factores constantes: `A * core + D`.
  static FamilyInfo? _peel(XNode n, {Rational? a, Rational? d}) {
    final A = a ?? Rational(1), D = d ?? Rational(0);
    switch (n) {
      case XNeg(a: final inner):
        return _peel(inner, a: -A, d: D);
      case XBin(:final l, :final op, :final r):
        final cl = _const(l), cr = _const(r);
        if (op == '+' || op == '-') {
          if (cr != null && cl == null) return _peel(l, a: A, d: D + A * (op == '+' ? cr : -cr));
          if (cl != null && cr == null) {
            return _peel(r, a: op == '+' ? A : -A, d: D + A * cl);
          }
        } else if (op == '*') {
          if (cl != null && cr == null && !cl.isZero) return _peel(r, a: A * cl, d: D);
          if (cr != null && cl == null && !cr.isZero) return _peel(l, a: A * cr, d: D);
        } else if (op == '/' && cr != null && cl == null && !cr.isZero) {
          return _peel(l, a: A / cr, d: D);
        }
        return null;
      default:
        return _core(n, A, D);
    }
  }

  static FamilyInfo? _core(XNode n, Rational A, Rational D) {
    switch (n) {
      case XRoot(:final index, :final rad):
        final lin = _linear(rad);
        if (lin == null) return null;
        final idx = index == null ? 2 : (index is XNum && index.value.isInteger ? index.value.numerator : 0);
        if (idx < 2) return null;
        return FamilyInfo(idx.isEven ? FunctionFamily.radicalEven : FunctionFamily.radicalOdd,
            inner: lin, a: A, d: D, base: idx.toDouble());
      case XPow(:final base, :final exp):
        final lin = _linear(exp);
        if (lin == null) return null;
        if (base is XConst && base.kind == 'e') {
          return FamilyInfo(FunctionFamily.exponential, inner: lin, a: A, d: D);
        }
        final bv = _const(base);
        if (bv == null || !bv.isPositive || bv == Rational(1)) return null;
        return FamilyInfo(FunctionFamily.exponential,
            inner: lin, a: A, d: D, base: bv.toDouble(), baseLatex: base.latex());
      case XFn(:final name, :final arg, base: final lb):
        final lin = _linear(arg);
        if (lin == null) return null;
        switch (name) {
          case 'sin':
            return FamilyInfo(FunctionFamily.sine, inner: lin, a: A, d: D);
          case 'cos':
            return FamilyInfo(FunctionFamily.cosine, inner: lin, a: A, d: D);
          case 'tan':
            return FamilyInfo(FunctionFamily.tangent, inner: lin, a: A, d: D);
          case 'ln':
            return FamilyInfo(FunctionFamily.logarithmic, inner: lin, a: A, d: D);
          case 'log':
            if (lb == null) {
              return FamilyInfo(FunctionFamily.logarithmic,
                  inner: lin, a: A, d: D, base: 10, baseLatex: '10');
            }
            final bv = _const(lb);
            if (bv == null || !bv.isPositive || bv == Rational(1)) return null;
            return FamilyInfo(FunctionFamily.logarithmic,
                inner: lin, a: A, d: D, base: bv.toDouble(), baseLatex: lb.latex());
        }
        return null;
      default:
        return null;
    }
  }

  /// ln de la base (e si es `null`).
  static double lnBase(FamilyInfo i) => i.base == null ? 1 : math.log(i.base!);
}
