import 'dart:math' as math;

import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../exact/exact_number.dart';
import '../exact/ext_evaluator.dart';
import '../exact/ext_expr.dart';
import '../trig_and_angles_solver.dart';
import 'eq_context.dart';
import 'eq_poly.dart';
import 'logarithmic_ratio_solver.dart';

/// Ecuaciones logaritmicas: propiedades (suma, resta, potencia), definicion de
/// logaritmo e inyectividad, con descarte obligatorio de argumentos <= 0.
class LogarithmicEquationSolver {
  const LogarithmicEquationSolver._();

  static bool matches(EqCtx c) => _hasLog(c.left) || _hasLog(c.right);

  static bool _hasLog(XNode n) => switch (n) {
        XFn(:final name, :final arg) =>
          (name == 'log' || name == 'ln') && PolyOps.containsX(arg),
        XNeg(:final a) => _hasLog(a),
        XBin(:final l, :final r) => _hasLog(l) || _hasLog(r),
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

  /// `c * log_b(A)` -> (c, base|null=e, A).
  static (Rational, Rational?, Poly)? _logTerm(XNode t) {
    switch (t) {
      case XFn(:final name, :final arg, :final base):
        if (name != 'log' && name != 'ln') return null;
        final a = PolyOps.polyOf(arg);
        if (a == null) return null;
        if (name == 'ln') return (Rational(1), null, a);
        final b = base == null ? Rational(10) : _const(base);
        if (b == null || !b.isPositive || b == Rational(1)) return null;
        return (Rational(1), b, a);
      case XNeg(:final a):
        final r = _logTerm(a);
        return r == null ? null : (-r.$1, r.$2, r.$3);
      case XBin(:final l, :final op, :final r):
        if (op == '*') {
          final k = _const(l);
          final rr = _logTerm(r);
          if (k != null && rr != null) return (k * rr.$1, rr.$2, rr.$3);
          final k2 = _const(r);
          final ll = _logTerm(l);
          if (k2 != null && ll != null) return (k2 * ll.$1, ll.$2, ll.$3);
        } else if (op == '/') {
          final k = _const(r);
          final ll = _logTerm(l);
          if (k != null && !k.isZero && ll != null) return (ll.$1 / k, ll.$2, ll.$3);
        }
        return null;
      default:
        return null;
    }
  }

  static String _name(Rational? b) => b == null
      ? '\\ln'
      : (b == Rational(10) ? '\\log' : '\\log_{${b.toLatex()}}');

  static String _wrap(Poly p) => '\\left(${PolyOps.latex(p)}\\right)';

  static StepByStepResolution? solve(EqCtx c) {
    // log(A)/log(B) = k: cambio de base y comprobacion del denominador.
    final ratio = LogarithmicRatioSolver.solve(c);
    if (ratio != null) return ratio;
    final items = <(int, XNode)>[];
    _terms(c.left, 1, items);
    _terms(c.right, -1, items);
    final logs = <(Rational, Poly)>[];
    Rational? base;
    var baseSet = false;
    var constant = Rational(0);
    for (final (s, t) in items) {
      final lt = _logTerm(t);
      if (lt != null) {
        if (baseSet && lt.$2 != base) return null;
        base = lt.$2;
        baseSet = true;
        logs.add((lt.$1 * Rational(s), lt.$3));
      } else {
        final p = PolyOps.polyOf(t);
        if (p == null || PolyOps.degree(p) > 0) return null;
        constant = constant + PolyOps.coeff(p, 0) * Rational(s);
      }
    }
    if (logs.isEmpty || logs.any((l) => !l.$1.isInteger)) return null;
    final name = _name(base);
    final v = -constant; // sum c_i log(A_i) = v

    // 1. Propiedades: N / D
    var num = PolyOps.constant(Rational(1));
    var den = PolyOps.constant(Rational(1));
    final shown = <String>[];
    for (final (cI, a) in logs) {
      final k = cI.numerator;
      if (k > 0) {
        num = PolyOps.mul(num, PolyOps.pow(a, k));
      } else {
        den = PolyOps.mul(den, PolyOps.pow(a, -k));
      }
      shown.add(k == 1 || k == -1 ? _wrap(a) : '${_wrap(a)}^{${k.abs()}}');
    }
    final numShown = logs.where((l) => l.$1.numerator > 0).map((l) {
      final k = l.$1.numerator;
      return k == 1 ? _wrap(l.$2) : '${_wrap(l.$2)}^{$k}';
    }).join(' \\cdot ');
    final denShown = logs.where((l) => l.$1.numerator < 0).map((l) {
      final k = -l.$1.numerator;
      return k == 1 ? _wrap(l.$2) : '${_wrap(l.$2)}^{$k}';
    }).join(' \\cdot ');
    final combined = denShown.isEmpty
        ? (numShown.isEmpty ? '1' : numShown)
        : '\\frac{${numShown.isEmpty ? '1' : numShown}}{$denShown}';
    c.add(
      'Propiedades de los logaritmos',
      '$name\\left($combined\\right) = ${v.toLatex()}',
      'Usamos n·log(A) = log(A^n), log(A) + log(B) = log(A·B) y log(A) - log(B) = log(A/B) para dejar un único logaritmo.',
    );

    // 2. Definicion de logaritmo: N/D = b^v
    final bv = base ?? Rational(1);
    ExNum? kappa;
    if (base == null) {
      kappa = v.isZero ? ExNum.integer(1) : ExNum.euler().powInt(v.isInteger ? v.numerator : 0);
      if (!v.isInteger && !v.isZero) return null;
    } else {
      final r = ExNum.rational(bv).powInt(v.isInteger ? v.numerator : 0);
      kappa = r;
      if (!v.isInteger) return null;
    }
    final kRat = kappa.asRational;
    final PolyEquationHolder holder;
    if (kRat != null) {
      holder = PolyEquationHolder(PolyOps.sub(num, PolyOps.scale(den, kRat)), null);
      c.add(
        'Definicion de logaritmo: log_b(M) = k => M = b^k',
        '${PolyOps.latex(num)} = ${kappa.toLatex()}\\cdot${_wrap(den)} \\implies ${EqCtx.polyEq(holder.poly)}',
        'Por definición, log_b(M) = k equivale a M = b^k. Pasamos a una ecuación sin logaritmos.',
      );
    } else {
      // base e con k != 0: solo si N es lineal y D = 1.
      if (PolyOps.degree(num) != 1 || PolyOps.degree(den) != 0) return null;
      holder = PolyEquationHolder({}, kappa);
      c.add(
        'Definicion de logaritmo: log_b(M) = k => M = b^k',
        '${PolyOps.latex(num)} = ${kappa.toLatex()}',
        'Por definición, ln(M) = k equivale a M = e^k.',
      );
    }

    List<ExNum> roots;
    if (holder.irrational != null) {
      final m = PolyOps.coeff(num, 1);
      final n = PolyOps.coeff(num, 0);
      roots = [
        (holder.irrational! - ExNum.rational(n)) / ExNum.rational(m),
      ];
      c.add('Despejar x', 'x = ${roots.first.toLatex()}',
          'Resolvemos la ecuación de primer grado en x.');
    } else {
      if (PolyOps.degree(holder.poly) < 0) {
        c.add('Ecuación resultante', '0 = 0',
            'Se cumple siempre que los argumentos sean positivos.');
        return c.finish(const [],
            exactOverride: '\\text{Infinitas soluciones en el dominio}',
            decimalOverride: '\\text{Infinitas soluciones en el dominio}');
      }
      roots = PolyRoots.real(holder.poly);
      c.addPolynomialSolveStep(holder.poly, roots, title: 'Soluciones algebraicas preliminares');
    }

    // 3. Argumentos > 0
    final lines = <String>[];
    final valid = <ExNum>[];
    for (final r in roots) {
      var allPos = true;
      final parts = <String>[];
      for (final (_, a) in logs) {
        final val = _evalPoly(a, r);
        if (val <= 1e-12) allPos = false;
        parts.add('${PolyOps.latex(a)} = ${NumLatex.decimal(val)}');
      }
      final ok = allPos && c.check(r).ok;
      if (ok) valid.add(r);
      lines.add(
        'x = ${r.toLatex()}: \\; ${parts.join(', \\; ')} \\implies ${ok ? '\\text{Valida } (\\checkmark)' : '\\text{Descartada}'}',
      );
    }
    c.add(
      'Comprobacion de existencia del logaritmo (Argumentos > 0)',
      lines.isEmpty ? '\\text{Ninguna candidata}' : lines.join(' \\\\ '),
      'El argumento de un logaritmo debe ser estrictamente positivo. Descartamos cualquier solución que haga un argumento menor o igual que 0.',
      warn: 'Una solución algebraica puede no existir en la ecuación logarítmica original.',
    );
    return c.finish(valid);
  }

  static double _evalPoly(Poly p, ExNum x) {
    var acc = 0.0;
    p.forEach((k, v) => acc += v.toDouble() * math.pow(x.approx, k));
    return acc;
  }
}

/// Resultado intermedio: polinomio racional o constante irracional (e^k).
class PolyEquationHolder {
  final Poly poly;
  final ExNum? irrational;
  const PolyEquationHolder(this.poly, this.irrational);
}
