import 'dart:math' as math;

import '../../models/step_resolution.dart';
import '../exact/exact_number.dart';
import '../exact/ext_expr.dart';
import 'eq_context.dart';
import 'eq_poly.dart';

/// Cociente de logaritmos de la misma base igualado a una constante entera:
/// `log(A) / log(B) = k`  =>  `log_B(A) = k`  =>  `A = B^k`, con `A > 0`, `B > 0` y `log(B) != 0`.
class LogarithmicRatioSolver {
  const LogarithmicRatioSolver._();

  static (Poly, String)? _logOf(XNode n) {
    if (n is! XFn || (n.name != 'log' && n.name != 'ln')) return null;
    final arg = PolyOps.polyOf(n.arg);
    if (arg == null || PolyOps.degree(arg) < 1) return null;
    final base = n.name == 'ln' ? 'ln' : (n.base == null ? '10' : n.base!.latex());
    return (arg, base);
  }

  static double _eval(Poly p, double x) {
    var acc = 0.0;
    p.forEach((k, v) => acc += v.toDouble() * math.pow(x, k));
    return acc;
  }

  static StepByStepResolution? solve(EqCtx c) {
    XNode? ratio;
    XNode? other;
    if (c.left is XBin && (c.left as XBin).op == '/') {
      ratio = c.left;
      other = c.right;
    } else if (c.right is XBin && (c.right as XBin).op == '/') {
      ratio = c.right;
      other = c.left;
    }
    if (ratio is! XBin || other == null) return null;
    final kPoly = PolyOps.polyOf(other);
    if (kPoly == null || PolyOps.degree(kPoly) > 0) return null;
    final k = PolyOps.coeff(kPoly, 0);
    if (!k.isInteger || k.numerator < 0 || k.numerator > 6) return null;
    final a = _logOf(ratio.l), b = _logOf(ratio.r);
    if (a == null || b == null || a.$2 != b.$2) return null;
    final kk = k.numerator;
    final name = a.$2 == 'ln' ? r'\ln' : (a.$2 == '10' ? r'\log' : '\\log_{${a.$2}}');
    String w(Poly p) => '\\left(${PolyOps.latex(p)}\\right)';

    c.add(
      'Cociente de logaritmos = logaritmo en otra base',
      '\\frac{$name${w(a.$1)}}{$name${w(b.$1)}} = $kk \\implies \\log_{${PolyOps.latex(b.$1)}}${w(a.$1)} = $kk',
      'El cociente log(A) / log(B) es el logaritmo de A en base B (cambio de base). Hay que exigir ya log(B) ≠ 0, es decir B ≠ 1.',
      warn: 'El denominador log(B) no puede valer 0: eso ocurre cuando B = 1.',
    );
    final power = PolyOps.pow(b.$1, kk);
    final eq = PolyOps.sub(a.$1, power);
    c.add(
      'Definición de logaritmo: log_B(A) = k  =>  A = B^k',
      '${PolyOps.latex(a.$1)} = ${w(b.$1)}^{$kk} = ${PolyOps.latex(power)} \\implies ${EqCtx.polyEq(eq)}',
      'Por definición, log_B(A) = k equivale a A = B^k. Pasamos todo a un miembro y queda una ecuación polinómica.',
    );
    final roots = PolyOps.degree(eq) < 1 ? <ExNum>[] : PolyRoots.real(eq);
    c.addPolynomialSolveStep(eq, roots, title: 'Soluciones algebraicas preliminares');

    final lines = <String>[];
    final valid = <ExNum>[];
    for (final r in roots) {
      final av = _eval(a.$1, r.approx), bv = _eval(b.$1, r.approx);
      final String verdict;
      if ((bv - 1).abs() < 1e-9) {
        verdict = r'\text{Descartada: } \log(B) = 0 \text{ anula el denominador}';
      } else if (av <= 1e-12 || bv <= 1e-12) {
        verdict = r'\text{Descartada: el argumento debe ser positivo}';
      } else if (c.check(r).ok) {
        valid.add(r);
        verdict = r'\text{Valida } (\checkmark)';
      } else {
        verdict = r'\text{Descartada}';
      }
      lines.add('x = ${r.toLatex()}: \\; A = ${_fmt(av)},\\; B = ${_fmt(bv)} \\implies $verdict');
    }
    c.add(
      'Comprobación del dominio (A > 0, B > 0 y B ≠ 1)',
      lines.isEmpty ? r'\text{Ninguna candidata}' : lines.join(' \\\\ '),
      'Una solución algebraica solo vale si los dos argumentos son positivos y el denominador log(B) no es 0 (B ≠ 1).',
      warn: 'Una solución algebraica puede no existir en la ecuación logarítmica original.',
    );
    return c.finish(valid);
  }

  static String _fmt(double v) =>
      (v - v.roundToDouble()).abs() < 1e-9 ? '${v.round()}' : v.toStringAsFixed(3).replaceAll('.', '{,}');
}
