import 'dart:math' as math;

import '../../models/step_resolution.dart';
import '../inequalities/universal/inequality_family_detector.dart';
import '../inequalities/universal/numeric_function.dart';
import '../exact/ext_expr.dart';
import '../trig_and_angles_solver.dart' show AngleUnit;
import 'nd_common.dart';

/// Resolucion numerica universal N x N (N = 2, 3, 4) por Newton-Raphson N-D: Jacobiano por
/// diferencias centrales, Gauss con pivoteo parcial y busqueda lineal amortiguada.
abstract final class NonlinearNumericNdSolver {
  static const double _tolF = 1e-7;
  static const int _maxIter = 40;
  static const int _budgetMs = 250;

  static double _halton(int index, int base) {
    var f = 1.0, r = 0.0;
    var i = index;
    while (i > 0) {
      f /= base;
      r += f * (i % base);
      i ~/= base;
    }
    return r;
  }

  /// ~36 semillas deterministas: Halton en [-3,3]^N, positivas en [0.3,4]^N y, con
  /// trigonometria, puntos en [0, vuelta completa)^N.
  static List<List<double>> seeds(int n, {required bool trig, required AngleUnit unit}) {
    const primes = [2, 3, 5, 7];
    List<List<double>> gen(int count, double lo, double hi, int offset) => [
          for (var k = 1; k <= count; k++)
            [for (var i = 0; i < n; i++) lo + (hi - lo) * _halton(k + offset, primes[i])],
        ];
    final turn = NdFmt.fullTurn(unit);
    return [
      ...gen(trig ? 10 : 16, -3, 3, 0),
      ...gen(trig ? 8 : 14, 0.3, 4, 20),
      if (trig) ...gen(12, 0, turn, 40) else ...gen(6, -1, 1, 60),
    ];
  }

  static List<double>? _gauss(List<List<double>> a, List<double> b) {
    final n = b.length;
    final m = [for (var i = 0; i < n; i++) [...a[i], b[i]]];
    for (var c = 0; c < n; c++) {
      var p = c;
      for (var r = c + 1; r < n; r++) {
        if (m[r][c].abs() > m[p][c].abs()) p = r;
      }
      if (m[p][c].abs() < 1e-13) return null;
      final t = m[c];
      m[c] = m[p];
      m[p] = t;
      for (var r = c + 1; r < n; r++) {
        final f = m[r][c] / m[c][c];
        for (var k = c; k <= n; k++) {
          m[r][k] -= f * m[c][k];
        }
      }
    }
    final x = List<double>.filled(n, 0);
    for (var i = n - 1; i >= 0; i--) {
      var s = m[i][n];
      for (var k = i + 1; k < n; k++) {
        s -= m[i][k] * x[k];
      }
      x[i] = s / m[i][i];
    }
    return x;
  }

  static List<double>? _f(NdSystem sys, List<double> v) {
    final out = <double>[];
    for (var i = 0; i < sys.n; i++) {
      final r = sys.residual(i, v);
      if (r == null || !r.isFinite) return null;
      out.add(r);
    }
    return out;
  }

  static double _norm(List<double> f) => f.fold(0.0, (m, e) => math.max(m, e.abs()));

  static List<double>? _newton(NdSystem sys, List<double> start) {
    var x = [...start];
    var f = _f(sys, x);
    if (f == null) return null;
    for (var it = 0; it < _maxIter; it++) {
      final nf = _norm(f!);
      if (nf < 1e-11) return x;
      final jac = List.generate(sys.n, (_) => List<double>.filled(sys.n, 0));
      for (var j = 0; j < sys.n; j++) {
        final h = 1e-6 * (1 + x[j].abs());
        final xp = [...x]..[j] += h, xm = [...x]..[j] -= h;
        final fp = _f(sys, xp), fm = _f(sys, xm);
        if (fp == null || fm == null) return nf < _tolF ? x : null;
        for (var i = 0; i < sys.n; i++) {
          jac[i][j] = (fp[i] - fm[i]) / (2 * h);
        }
      }
      final dx = _gauss(jac, [for (final e in f) -e]);
      if (dx == null) return nf < _tolF ? x : null;
      var t = 1.0;
      List<double>? nx;
      List<double>? nfv;
      for (var k = 0; k < 14; k++) {
        final cand = [for (var i = 0; i < sys.n; i++) x[i] + t * dx[i]];
        final fc = _f(sys, cand);
        if (fc != null && _norm(fc) < nf * (1 - 1e-4 * t) + 1e-15) {
          nx = cand;
          nfv = fc;
          break;
        }
        t /= 2;
      }
      if (nx == null) return nf < _tolF ? x : null;
      x = nx;
      f = nfv;
    }
    return _norm(f!) < _tolF ? x : null;
  }

  /// Busca todas las soluciones reales con residuo < 1e-7. Lista vacia si no hay.
  static List<List<double>> findAll(NdSystem sys) {
    var trig = false;
    for (final (l, r) in sys.sides) {
      trig = trig || NumFn.hasTrig(l) || NumFn.hasTrig(r);
    }
    final sw = Stopwatch()..start();
    final found = <List<double>>[];
    for (final s in seeds(sys.n, trig: trig, unit: sys.unit)) {
      if (sw.elapsedMilliseconds > _budgetMs) break;
      final x = _newton(sys, s);
      if (x == null) continue;
      final f = _f(sys, x);
      if (f != null && _norm(f) < _tolF) found.add(x);
    }
    return NdFmt.dedupe(found);
  }

  static String _fLatex(NdSystem sys, int i) {
    final (l, r) = sys.sides[i];
    return 'f_{${i + 1}} = ${l.latex()} - ${_wrapRhs(r)}';
  }

  static String _wrapRhs(XNode r) => r is XBin && (r.op == '+' || r.op == '-') ? '\\left(${r.latex()}\\right)' : r.latex();

  /// Pasos didacticos + soluciones aproximadas verificadas.
  static StepByStepResolution solve(NdSystem sys, {List<MathStep> prefix = const []}) {
    final n = sys.n;
    var trig = false;
    var hasLogOrRoot = false;
    for (final (l, r) in sys.sides) {
      trig = trig || NumFn.hasTrig(l) || NumFn.hasTrig(r);
      InequalityFamilyDetector.walk(l, (v) => hasLogOrRoot = hasLogOrRoot || v is XRoot || (v is XFn && !NumFn.hasTrig(v)));
      InequalityFamilyDetector.walk(r, (v) => hasLogOrRoot = hasLogOrRoot || v is XRoot || (v is XFn && !NumFn.hasTrig(v)));
    }
    final sols = findAll(sys);
    final steps = <MathStep>[
      ...prefix,
      NdFmt.step(
        'Plantear F(x) = 0',
        NdFmt.cases([for (var i = 0; i < n; i++) '${_fLatex(sys, i)} = 0']),
        'Este sistema no tiene una receta simbólica cerrada. Pasamos todo a un miembro y buscamos los puntos donde las $n funciones valen 0 a la vez.',
      ),
      NdFmt.step(
        'Método de Newton-Raphson en $n variables',
        '\\vec{x}_{k+1} = \\vec{x}_k - J(\\vec{x}_k)^{-1} \\, \\vec{F}(\\vec{x}_k)',
        'Partimos de varias semillas fijas${trig ? ' (incluidas las del giro completo, por la trigonometría)' : hasLogOrRoot ? ' (incluidas las positivas, por logaritmos y raíces)' : ''}. En cada iteración resolvemos un sistema lineal con la matriz de derivadas (Jacobiano) y acortamos el paso si el error no baja. Solo aceptamos puntos con residuo menor que 1e-7.',
        'Es un método numérico: las soluciones son aproximadas y puede haber otras que no se hayan encontrado.',
      ),
    ];
    if (sols.isNotEmpty) {
      steps.add(NdFmt.step(
        'Soluciones aproximadas y residuo',
        NdFmt.cases([
          for (final s in sols)
            '${NdFmt.point(s, n, decimal: true)} \\quad \\lVert \\vec{F} \\rVert_{\\infty} = ${_resid(sys, s)}',
        ]),
        'Sustituimos cada punto en las ecuaciones originales: el residuo (mayor error en valor absoluto) es prácticamente 0.',
      ));
    }
    return NdFmt.finish(
      sys,
      steps,
      sols,
      approximate: true,
      noSolutionNote:
          'No se ha encontrado ninguna solución real en el dominio: el sistema puede no tenerla o estar fuera del rango de búsqueda.',
    );
  }

  static String _resid(NdSystem sys, List<double> s) {
    final f = _f(sys, s);
    if (f == null) return '0';
    final r = _norm(f);
    if (r < 1e-12) return '< 10^{-12}';
    final e = r.toStringAsExponential(1).split('e');
    return '${e[0]} \\cdot 10^{${int.parse(e[1])}}';
  }
}
