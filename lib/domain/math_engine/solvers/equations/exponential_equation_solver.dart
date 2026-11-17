import 'dart:math' as math;

import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../exact/exact_number.dart';
import '../exact/ext_evaluator.dart';
import '../exact/ext_expr.dart';
import '../exact/ext_math.dart';
import '../trig_and_angles_solver.dart';
import 'eq_context.dart';
import 'eq_poly.dart';

/// Termino exponencial `k * base^(m x + n)`; base racional o `e` (base == null).
class _ExpTerm {
  final Rational k;
  final Rational? base;
  final Rational m;
  final Rational n;
  const _ExpTerm(this.k, this.base, this.m, this.n);
}

/// Ecuaciones exponenciales: igualacion de bases, cambio de variable t = a^x
/// y toma de logaritmos.
class ExponentialEquationSolver {
  const ExponentialEquationSolver._();

  static bool matches(EqCtx c) => _inExponent(c.left) || _inExponent(c.right);

  static bool _inExponent(XNode n) => switch (n) {
        XPow(:final base, :final exp) =>
          PolyOps.containsX(exp) || _inExponent(base) || _inExponent(exp),
        XNeg(:final a) => _inExponent(a),
        XBin(:final l, :final r) => _inExponent(l) || _inExponent(r),
        _ => false,
      };

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
    if (PolyOps.containsX(n)) return null;
    try {
      return ExtEvaluator(angle: AngleUnit.deg).eval(n).asRational;
    } on FormatException {
      return null;
    }
  }

  static _ExpTerm? _expTerm(XNode t) {
    switch (t) {
      case XPow(:final base, :final exp):
        final e = PolyOps.polyOf(exp);
        if (e == null || PolyOps.degree(e) != 1) return null;
        final m = PolyOps.coeff(e, 1);
        final n = PolyOps.coeff(e, 0);
        if (base is XConst && base.kind == 'e') return _ExpTerm(Rational(1), null, m, n);
        final b = _const(base);
        if (b == null || !b.isPositive || b == Rational(1)) return null;
        return _ExpTerm(Rational(1), b, m, n);
      case XNeg(:final a):
        final r = _expTerm(a);
        return r == null ? null : _ExpTerm(-r.k, r.base, r.m, r.n);
      case XBin(:final l, :final op, :final r):
        if (op == '*') {
          final kl = _const(l);
          final er = _expTerm(r);
          if (kl != null && er != null) return _ExpTerm(kl * er.k, er.base, er.m, er.n);
          final kr = _const(r);
          final el = _expTerm(l);
          if (kr != null && el != null) return _ExpTerm(kr * el.k, el.base, el.m, el.n);
        } else if (op == '/') {
          final kr = _const(r);
          final el = _expTerm(l);
          if (kr != null && !kr.isZero && el != null) {
            return _ExpTerm(el.k / kr, el.base, el.m, el.n);
          }
        }
        return null;
      default:
        return null;
    }
  }

  static Map<int, int> _exps(Rational r) {
    final m = <int, int>{};
    Rational.primeFactorsMap(r.numerator.abs()).forEach((p, k) => m[p] = k);
    Rational.primeFactorsMap(r.denominator).forEach((p, k) => m[p] = (m[p] ?? 0) - k);
    m.removeWhere((_, v) => v == 0);
    return m;
  }

  /// Base comun `b0` con cada base = b0^k_i (k_i entero); `null` si no existe.
  static (Rational, List<int>)? _commonBase(List<Rational> bases) {
    final vecs = bases.map(_exps).toList();
    final first = vecs.first;
    if (first.isEmpty) return null;
    var g = 0;
    for (final v in first.values) {
      g = Rational.gcd(g, v.abs());
    }
    final u = {for (final e in first.entries) e.key: e.value ~/ g};
    final sgn = u[u.keys.reduce(math.min)]! > 0 ? 1 : -1;
    final unit = {for (final e in u.entries) e.key: e.value * sgn};
    final ks = <int>[];
    for (final v in vecs) {
      if (v.keys.toSet().difference(unit.keys.toSet()).isNotEmpty) return null;
      int? k;
      for (final e in unit.entries) {
        final num = v[e.key] ?? 0;
        if (num % e.value != 0) return null;
        final kk = num ~/ e.value;
        if (k != null && k != kk) return null;
        k = kk;
      }
      if (k == null || k == 0) return null;
      ks.add(k);
    }
    var b0 = Rational(1);
    unit.forEach((p, e) => b0 = b0 * Rational(p).pow(e));
    return (b0, ks);
  }

  static String _pow(String base, String exp) => '$base^{$exp}';
  static String _lin(Rational m, Rational n) {
    final p = <int, Rational>{1: m, 0: n};
    return PolyOps.latex(p);
  }

  static String _logRatio(ExNum t, Rational? base) {
    final num = t.isExact && t.isRational ? '\\ln(${t.toLatex()})' : '\\ln\\left(${t.toLatex()}\\right)';
    return base == null ? num : '\\frac{$num}{\\ln(${base.toLatex()})}';
  }

  static ExNum _xFromT(ExNum t, Rational? base) {
    final lt = t.approx;
    final value = base == null ? math.log(lt) : math.log(lt) / math.log(base.toDouble());
    final tr = t.asRational;
    if (tr != null) {
      if (base == null) {
        if (tr == Rational(1)) return ExNum.integer(0);
      } else {
        final k = ExtMath.logExact(base, tr);
        if (k != null) return k;
      }
    }
    if (base == null && t.isExact && t.terms.length == 1) {
      final e = t.terms.entries.first;
      if (e.key.$1 == 1 && e.key.$2 == 0 && e.value == Rational(1)) {
        return ExNum.integer(e.key.$3);
      }
    }
    return ExNum.opaque(_logRatio(t, base), value);
  }

  static StepByStepResolution? solve(EqCtx c) {
    final items = <(int, XNode)>[];
    _terms(c.left, 1, items);
    _terms(c.right, -1, items);
    final exps = <_ExpTerm>[];
    var constant = Rational(0);
    for (final (s, t) in items) {
      final e = PolyOps.containsX(t) ? _expTerm(t) : null;
      if (e != null) {
        exps.add(_ExpTerm(e.k * Rational(s), e.base, e.m, e.n));
      } else if (!PolyOps.containsX(t)) {
        final v = _const(t);
        if (v == null) return null;
        constant = constant + v * Rational(s);
      } else {
        return null;
      }
    }
    if (exps.isEmpty) return null;

    // Base comun
    final hasE = exps.any((e) => e.base == null);
    final hasR = exps.any((e) => e.base != null);
    if (hasE && hasR) return null;
    Rational? b0;
    var ks = List<int>.filled(exps.length, 1);
    if (hasR) {
      final cb = _commonBase(exps.map((e) => e.base!).toList());
      if (cb == null) return null;
      b0 = cb.$1;
      ks = cb.$2;
    }
    final bLatex = b0 == null ? 'e' : b0.toLatex();

    if (exps.length == 1) return _single(c, exps.first, constant, b0, ks.first, bLatex);

    // Cambio de variable t = b0^x: terminos k * b0^(ki*n) * t^(ki*m)
    final terms = <int, Rational>{};
    for (var i = 0; i < exps.length; i++) {
      final e = exps[i];
      final km = e.m * Rational(ks[i]);
      final kn = e.n * Rational(ks[i]);
      if (!km.isInteger || !kn.isInteger) return null;
      final baseVal = b0 ?? Rational(1);
      if (b0 == null && !kn.isZero) return null;
      final coef = e.k * baseVal.pow(kn.numerator);
      terms[km.numerator] = (terms[km.numerator] ?? Rational(0)) + coef;
    }
    terms[0] = (terms[0] ?? Rational(0)) + constant;
    final shift = -terms.keys.reduce(math.min);
    final poly = PolyOps.clean({
      for (final e in terms.entries) e.key + (shift > 0 ? shift : 0): e.value,
    });
    c.add(
      'Cambio de variable t = $bLatex^x',
      't = ${_pow(bLatex, 'x')},\\; t > 0 \\implies ${PolyOps.latex(poly, v: 't')} = 0',
      'Escribimos todas las potencias con la misma base usando a^(m+n) = a^m · a^n y (a^x)^k = a^(kx); después llamamos t = $bLatex^x (siempre positivo).',
      warn: 'Como t = $bLatex^x es positivo, las soluciones t ≤ 0 se descartan.',
    );

    final tRoots = PolyRoots.real(poly);
    c.addPolynomialSolveStep(poly, tRoots,
        title: 'Resolucion en la variable auxiliar t');
    final back = <String>[];
    final cands = <ExNum>[];
    for (final t in tRoots) {
      if (t.approx <= 1e-12) {
        back.add('t = ${t.toLatex()} \\le 0 \\implies \\text{Descartada}');
      } else {
        final x = _xFromT(t, b0);
        cands.add(x);
        back.add('${_pow(bLatex, 'x')} = ${t.toLatex()} \\implies x = ${x.toLatex()}');
      }
    }
    c.add(
      'Deshacer el cambio t = a^x',
      back.isEmpty ? '\\text{Sin solucion real}' : back.join(' \\\\ '),
      'Deshacemos el cambio: igualamos bases o tomamos logaritmos para despejar x.',
    );
    final v = c.verify(cands);
    if (v.latex.isNotEmpty) {
      c.add('Comprobacion en la ecuacion original', v.latex,
          'Sustituimos cada solución en la ecuación de partida para confirmar que es válida.');
    }
    return c.finish(v.valid);
  }

  static StepByStepResolution? _single(
    EqCtx c,
    _ExpTerm e,
    Rational constant,
    Rational? b0,
    int k,
    String bLatex,
  ) {
    // e.k * base^(m x + n) + constant = 0  =>  base^(mx+n) = -constant / e.k
    final rhs = -constant / e.k;
    final f = _lin(e.m, e.n);
    c.add(
      'Aislar la potencia',
      '${_pow(e.base?.toLatex() ?? 'e', f)} = ${rhs.toLatex()}',
      'Dejamos la potencia sola en un miembro dividiendo entre su coeficiente.',
    );
    if (!rhs.isPositive) {
      c.add('Solucion final', '${rhs.toLatex()} \\le 0 \\implies \\text{Sin solucion real}',
          'Una potencia de base positiva siempre es positiva: no puede valer 0 ni un número negativo.');
      return c.finish(const []);
    }
    final base = e.base;
    final exact = base == null ? null : ExtMath.logExact(base, rhs);
    ExNum target;
    if (exact != null) {
      final kk = exact.asRational!;
      c.add(
        'Igualacion de bases: a^f(x) = a^k',
        '${_pow(bLatex, f)} = ${_pow(bLatex, kk.toLatex())}',
        'Escribimos el segundo miembro como potencia de la misma base ($bLatex).',
      );
      c.add(
        'Igualar exponentes: f(x) = k',
        '$f = ${kk.toLatex()}',
        'Si dos potencias de la misma base (distinta de 0 y 1) son iguales, sus exponentes son iguales.',
      );
      target = exact;
    } else {
      target = _xFromT(ExNum.rational(rhs), base);
      c.add(
        'Tomar logaritmos en ambos miembros',
        '$f = ${target.toLatex()}',
        'Las bases no se pueden igualar: tomamos logaritmos y usamos log(a^b) = b · log(a).',
      );
    }
    // m x + n = target  =>  x = (target - n) / m
    var x = target;
    if (!e.n.isZero) x = x - ExNum.rational(e.n);
    if (e.m != Rational(1)) x = x / ExNum.rational(e.m);
    c.add('Despejar x', 'x = ${x.toLatex()}',
        'Resolvemos la ecuación de primer grado en x.');
    final v = c.verify([x]);
    c.add('Solucion final', v.latex,
        'Comprobamos la solución en la ecuación original.');
    return c.finish(v.valid);
  }
}
