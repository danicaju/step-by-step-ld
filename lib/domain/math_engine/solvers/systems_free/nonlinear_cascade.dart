import 'dart:math' as math;

import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../exact/ext_expr.dart';
import '../inequalities/universal/inequality_family_detector.dart';
import '../inequalities/universal/numeric_function.dart';
import 'dpoly.dart';
import 'nd_common.dart';

/// Ecuacion `p = 0` del sistema: polinomica ([p]) o, si no se puede, su arbol [ast] (`lhs - rhs`).
class CascadeEq {
  final DPoly? p;
  final XNode? ast;
  const CascadeEq.poly(DPoly this.p) : ast = null;
  const CascadeEq.ast(XNode this.ast) : p = null;

  Set<int> vars() {
    if (p != null) return p!.used;
    final s = <int>{};
    InequalityFamilyDetector.walk(ast!, (v) {
      if (v is XVar) {
        final i = NdSystem.vars.indexOf(v.name);
        if (i >= 0) s.add(i);
      }
    });
    return s;
  }
}

/// Sustitucion en cascada / triangular (4x4 -> 3x3 -> 2x2 ...) sobre sistemas polinomicos, con
/// raices numericas para las ecuaciones de una incognita y la receta simetrica 2x2.
class NonlinearCascade {
  final NdSystem sys;
  NonlinearCascade(this.sys);

  /// `null` si la cascada no puede reducir el sistema. Cada solucion es un vector de 4 valores.
  List<List<double>>? run(List<CascadeEq> eqs, List<MathStep> steps) =>
      _solve(eqs, {for (var i = 0; i < sys.n; i++) i}, steps, 0);

  String _eqLatex(CascadeEq e) => e.p != null ? '${e.p!.latex()} = 0' : '${e.ast!.latex()} = 0';

  String _system(List<CascadeEq> eqs) => NdFmt.cases([for (final e in eqs) _eqLatex(e)]);

  CascadeEq _subst(CascadeEq e, int v, DPoly by) {
    if (e.p != null) return CascadeEq.poly(e.p!.substitute(v, by));
    return CascadeEq.ast(_substAst(e.ast!, v, by.constantTerm));
  }

  static XNode _substAst(XNode n, int v, double val) => switch (n) {
        XVar(:final name) when name == NdSystem.vars[v] => XNum(Rational.fromDouble(val, 1000000000)),
        XNeg(:final a) => XNeg(_substAst(a, v, val)),
        XBin(:final l, :final op, :final r) => XBin(_substAst(l, v, val), op, _substAst(r, v, val)),
        XPow(:final base, :final exp) => XPow(_substAst(base, v, val), _substAst(exp, v, val)),
        XRoot(:final index, :final rad) => XRoot(index == null ? null : _substAst(index, v, val), _substAst(rad, v, val)),
        XAbs(:final a) => XAbs(_substAst(a, v, val)),
        XFn(:final name, :final arg, :final base) =>
          XFn(name, _substAst(arg, v, val), base: base == null ? null : _substAst(base, v, val)),
        _ => n,
      };

  List<double> _scanRoots(XNode ast, int v) {
    double? f(double t) => NumFn.evalEnv(ast, {NdSystem.vars[v]: t}, unit: sys.unit);
    const lo = -30.0, hi = 30.0, m = 600;
    final out = <double>[];
    double? prev = f(lo);
    var px = lo;
    for (var i = 1; i <= m; i++) {
      final x = lo + (hi - lo) * i / m;
      final cur = f(x);
      if (prev != null && cur != null) {
        if (cur == 0) {
          out.add(x);
        } else if (prev * cur < 0) {
          final r = NumericRootFinder.bisect(f, px, x, iterations: 80);
          if (r != null) out.add(r);
        }
      }
      prev = cur;
      px = x;
    }
    return NdFmt.dedupe([for (final r in out) [r]]).map((e) => e.first).toList();
  }

  List<List<double>>? _solve(List<CascadeEq> eqsIn, Set<int> vars, List<MathStep>? steps, int depth) {
    if (depth > 8) return null;
    final eqs = <CascadeEq>[];
    for (final e in eqsIn) {
      if (e.p != null && e.p!.isConstant) {
        if (e.p!.constantTerm.abs() > 1e-7) return [];
        continue;
      }
      if (e.ast != null && e.vars().isEmpty) {
        final v = NumFn.evalEnv(e.ast!, const {}, unit: sys.unit);
        if (v == null || v.abs() > 1e-6) return [];
        continue;
      }
      eqs.add(e);
    }
    if (vars.isEmpty) {
      return eqs.isEmpty ? [List<double>.filled(4, 0)] : null;
    }
    if (eqs.length < vars.length) return null;

    // Regla A: ecuacion de una sola incognita (polinomica o no): se resuelve y se ramifica.
    for (final e in eqs) {
      final used = e.vars();
      if (used.length != 1) continue;
      final v = used.first;
      final roots = e.p != null ? (e.p!.degree >= 1 ? e.p!.realRoots(v) : <double>[]) : _scanRoots(e.ast!, v);
      steps?.add(NdFmt.step(
        'Ecuación de una sola incógnita: ${NdSystem.names[v]}',
        '${_eqLatex(e)} \\;\\Rightarrow\\; ${roots.isEmpty ? r'\text{sin raices reales}' : roots.map((r) => '${NdSystem.names[v]} = ${NdFmt.num(r)}').join(r',\; ')}',
        e.p != null
            ? 'Esta ecuación solo tiene ${NdSystem.names[v]}: la resolvemos directamente (cada raíz real da una rama de solución).'
            : 'Esta ecuación solo tiene ${NdSystem.names[v]} y no es polinómica: buscamos sus raíces reales por cambio de signo y bisección (aproximadas).',
      ));
      final rest = [for (final o in eqs) if (!identical(o, e)) o];
      final out = <List<double>>[];
      for (var k = 0; k < roots.length; k++) {
        final by = DPoly.constant(roots[k]);
        final sub = [for (final o in rest) _subst(o, v, by)];
        if (steps != null && roots.length > 1 && k == 0) {
          steps.add(NdFmt.step(
            'Sustituir cada raíz de ${NdSystem.names[v]}',
            _system(sub),
            'Seguimos primero con ${NdSystem.names[v]} = ${NdFmt.num(roots[k])}; el resto de raíces se tratan igual.',
          ));
        } else if (steps != null && roots.length == 1) {
          steps.add(NdFmt.step('Sustituir ${NdSystem.names[v]} en el resto', _system(sub), 'Con el valor hallado el sistema tiene una incógnita menos.'));
        }
        final res = _solve(sub, {...vars}..remove(v), k == 0 ? steps : null, depth + 1);
        if (res == null) return null;
        for (final s in res) {
          out.add([...s]..[v] = roots[k]);
        }
      }
      return out;
    }

    // Regla B: ecuacion polinomica lineal en una incognita con coeficiente constante.
    for (final e in eqs) {
      final p = e.p;
      if (p == null) continue;
      for (final v in p.used) {
        if (p.degreeIn(v) != 1) continue;
        final c = p.coefOf(v, 1);
        if (!c.isConstant) continue;
        // v no puede estar en ecuaciones no polinomicas (no sabemos sustituir un polinomio en ellas).
        if (eqs.any((o) => o.p == null && o.vars().contains(v))) continue;
        final coef = c.constantTerm;
        final expr = (p - DPoly.variable(v).scale(coef)).scale(-1 / coef);
        final name = NdSystem.names[v];
        steps?.add(NdFmt.step(
          'Despejar $name',
          '$name = ${expr.latex()}',
          'De ${eqs.indexOf(e) + 1 == 1 ? 'una de las ecuaciones' : 'la ecuación ${eqs.indexOf(e) + 1}'} se despeja $name, porque aparece con grado 1 y coeficiente constante.',
        ));
        final rest = [for (final o in eqs) if (!identical(o, e)) _subst(o, v, expr)];
        steps?.add(NdFmt.step(
          'Sustituir $name y reducir el sistema',
          rest.isEmpty ? r'\text{Sin ecuaciones restantes}' : _system(rest),
          'Sustituimos $name en las demás ecuaciones: el sistema pasa a tener una ecuación y una incógnita menos.',
        ));
        final res = _solve(rest, {...vars}..remove(v), steps, depth + 1);
        if (res == null) return null;
        return [
          for (final s in res) [...s]..[v] = expr.eval(s),
        ];
      }
    }

    // Regla C: restar ecuaciones con la misma parte de mayor grado (eje radical, etc.).
    final polys = [for (final e in eqs) e.p];
    for (var i = 0; i < eqs.length; i++) {
      for (var j = 0; j < eqs.length; j++) {
        final p = polys[i], q = polys[j];
        if (i == j || p == null || q == null) continue;
        final d = p.degree;
        if (d < 2 || q.degree != d) continue;
        final lam = _proportion(p, q, d);
        if (lam == null) continue;
        final comb = q - p.scale(lam);
        if (comb.isZero || comb.degree >= d) continue;
        steps?.add(NdFmt.step(
          'Restar ecuaciones para quitar los términos de grado $d',
          '${comb.latex()} = 0',
          'Las ecuaciones ${i + 1} y ${j + 1} tienen la misma parte de grado $d; al restarlas queda una ecuación de menor grado.',
        ));
        final next = [for (var k = 0; k < eqs.length; k++) k == j ? CascadeEq.poly(comb) : eqs[k]];
        return _solve(next, vars, steps, depth + 1);
      }
    }

    // Regla D: dos ecuaciones simetricas en x² + y², x·y y constante.
    if (vars.length == 2 && eqs.length == 2 && eqs.every((e) => e.p != null)) {
      final r = _symmetric(eqs[0].p!, eqs[1].p!, vars.toList(), steps);
      if (r != null) return r;
    }
    return null;
  }

  double? _proportion(DPoly p, DPoly q, int d) {
    Map<String, double> top(DPoly x) => {
          for (final e in x.terms.entries)
            if (e.key.split(',').fold(0, (a, b) => a + int.parse(b)) == d) e.key: e.value,
        };
    final tp = top(p), tq = top(q);
    if (tp.isEmpty || tp.length != tq.length) return null;
    final k0 = tp.keys.first;
    if (!tq.containsKey(k0)) return null;
    final lam = tq[k0]! / tp[k0]!;
    for (final k in tp.keys) {
      if ((tq[k] ?? double.nan) - lam * tp[k]! > 1e-9 || (tq[k] ?? double.nan) - lam * tp[k]! < -1e-9) return null;
    }
    return lam;
  }

  List<List<double>>? _symmetric(DPoly p, DPoly q, List<int> vs, List<MathStep>? steps) {
    final i = vs[0], j = vs[1];
    List<double>? coords(DPoly x) {
      final e2 = List.filled(4, 0);
      final xx = x.coef([...e2]..[i] = 2), yy = x.coef([...e2]..[j] = 2), xy = x.coef([...e2]..[i] = 1..[j] = 1);
      final known = DPoly.variable(i).pow(2).scale(xx) + DPoly.variable(j).pow(2).scale(yy) + (DPoly.variable(i) * DPoly.variable(j)).scale(xy);
      final rest = x - known;
      if (!rest.isConstant || (xx - yy).abs() > 1e-9) return null;
      return [xx, xy, rest.constantTerm];
    }

    final a = coords(p), b = coords(q);
    if (a == null || b == null) return null;
    final det = a[0] * b[1] - a[1] * b[0];
    if (det.abs() < 1e-12) return null;
    final u = (-a[2] * b[1] + a[1] * b[2]) / det, w = (-a[0] * b[2] + a[2] * b[0]) / det;
    final xn = NdSystem.names[i], yn = NdSystem.names[j];
    steps?.add(NdFmt.step(
      'Tomar $xn² + $yn² y $xn·$yn como incógnitas',
      '$xn^{2} + $yn^{2} = ${NdFmt.num(u)} \\quad ($xn + $yn)^{2} = ${NdFmt.num(u + 2 * w)} \\quad ($xn - $yn)^{2} = ${NdFmt.num(u - 2 * w)}',
      'El sistema es simétrico: se resuelve primero como lineal en $xn² + $yn² y en $xn·$yn, y después se usan (x + y)² = x² + y² + 2xy y (x - y)² = x² + y² - 2xy.',
    ));
    final s2 = u + 2 * w, d2 = u - 2 * w;
    if (s2 < -1e-9 || d2 < -1e-9) return [];
    final s = math.sqrt(math.max(0, s2)), d = math.sqrt(math.max(0, d2));
    final out = <List<double>>[];
    for (final ss in [s, -s]) {
      for (final dd in [d, -d]) {
        out.add(List<double>.filled(4, 0)
          ..[i] = (ss + dd) / 2
          ..[j] = (ss - dd) / 2);
      }
    }
    return NdFmt.dedupe(out.map((e) => [e[i], e[j]]).toList()).map((e) => List<double>.filled(4, 0)
      ..[i] = e[0]
      ..[j] = e[1]).toList();
  }
}
