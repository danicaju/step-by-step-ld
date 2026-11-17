import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../exact/exact_number.dart';
import '../exact/ext_expr.dart';
import 'eq_context.dart';
import 'eq_poly.dart';

/// Ecuaciones racionales P(x)/Q(x) = R(x)/S(x): dominio, m.c.m., reduccion a
/// polinomica y descarte explicito de raices prohibidas.
class RationalEquationSolver {
  const RationalEquationSolver._();

  static bool matches(EqCtx c) {
    final dens = <XNode>[];
    PolyOps.collectDenominators(c.left, dens);
    PolyOps.collectDenominators(c.right, dens);
    return dens.isNotEmpty;
  }

  /// Factoriza (raices racionales + resto irreducible): [(factor monico, multiplicidad)].
  static List<(Poly, int)> _factors(Poly input) {
    var p = PolyOps.clean(input);
    final lead = PolyOps.coeff(p, PolyOps.degree(p));
    p = PolyOps.scale(p, Rational(1) / lead);
    final out = <(Poly, int)>[];
    var guard = 0;
    while (PolyOps.degree(p) >= 1 && guard++ < 12) {
      final r = PolyRoots.rationalRoot(PolyOps.toIntegers(p));
      if (r == null) break;
      var m = 0;
      while (PolyOps.degree(p) >= 1 && PolyOps.eval(p, r).isZero) {
        p = PolyOps.deflate(p, r);
        m++;
      }
      out.add(({1: Rational(1), 0: -r}, m));
    }
    if (PolyOps.degree(p) >= 1) out.add((p, 1));
    return out;
  }

  static String _fac(Poly f, int m) {
    final base = PolyOps.degree(f) == 1 && PolyOps.coeff(f, 0).isZero
        ? 'x'
        : '\\left(${PolyOps.latex(f)}\\right)';
    return m == 1 ? base : '$base^{$m}';
  }

  static String _mcm(List<Poly> dens) {
    final best = <String, (Poly, int)>{};
    for (final d in dens) {
      for (final (f, m) in _factors(d)) {
        final key = PolyOps.latex(f);
        if (!best.containsKey(key) || best[key]!.$2 < m) best[key] = (f, m);
      }
    }
    if (best.isEmpty) return '1';
    return best.values.map((e) => _fac(e.$1, e.$2)).join(' \\cdot ');
  }

  static StepByStepResolution? solve(EqCtx c) {
    final fl = PolyOps.rationalOf(c.left);
    final fr = PolyOps.rationalOf(c.right);
    if (fl == null || fr == null) return null;
    final denNodes = <XNode>[];
    PolyOps.collectDenominators(c.left, denNodes);
    PolyOps.collectDenominators(c.right, denNodes);
    final dens = <Poly>[];
    final seen = <String>{};
    for (final n in denNodes) {
      final p = PolyOps.polyOf(n);
      if (p == null) return null;
      if (PolyOps.degree(p) < 1) continue;
      if (seen.add(PolyOps.latex(p))) dens.add(p);
    }
    if (dens.isEmpty) return null;

    // 1. Dominio
    final forbidden = <ExNum>[];
    final lines = <String>[];
    for (final d in dens) {
      final roots = PolyRoots.real(d);
      for (final r in roots) {
        if (!forbidden.any((f) => (f.approx - r.approx).abs() < 1e-9)) forbidden.add(r);
      }
      lines.add(
        '${PolyOps.latex(d)} = 0 \\implies ${roots.isEmpty ? '\\text{sin restriccion real}' : roots.map((r) => 'x \\neq ${r.toLatex()}').join(', \\; ')}',
      );
    }
    c.add(
      'Identificar valores prohibidos (Denominador nulo)',
      lines.join(' \\\\ '),
      'En una ecuación racional los denominadores nunca pueden valer 0. Cada valor de x que anule un denominador queda fuera del dominio.',
      warn: 'Si una solución coincide con un valor prohibido hay que descartarla.',
    );

    // 2. m.c.m. y eliminacion de denominadores
    c.add(
      'Reducir a comun denominador (m.c.m.)',
      '\\text{m.c.m.} = ${_mcm(dens)}',
      'Factorizamos cada denominador y tomamos los factores comunes y no comunes con su mayor exponente: ese es el m.c.m. por el que multiplicamos los dos miembros.',
    );
    final lhs = PolyOps.mul(fl.$1, fr.$2);
    final rhs = PolyOps.mul(fr.$1, fl.$2);
    c.add(
      'Eliminar denominadores',
      '${PolyOps.latex(lhs)} = ${PolyOps.latex(rhs)}',
      'Multiplicamos en cruz (equivale a multiplicar ambos miembros por el producto de los denominadores) y desarrollamos los productos.',
    );

    final eq = PolyOps.sub(lhs, rhs);
    if (PolyOps.degree(eq) < 0) {
      c.add('Ecuación resultante', '0 = 0',
          'La igualdad se cumple para todos los valores del dominio.');
      return c.finish(const [],
          exactOverride: '\\text{Todo } x \\text{ del dominio}',
          decimalOverride: '\\text{Todo } x \\text{ del dominio}');
    }
    final roots = PolyRoots.real(eq);
    c.addPolynomialSolveStep(eq, roots);

    final v = c.verify(roots);
    c.add(
      'Comprobacion de soluciones y valores prohibidos',
      v.latex.isEmpty ? '\\text{Ninguna candidata}' : v.latex,
      'Sustituimos cada candidata: si anula algún denominador es un valor prohibido y se descarta; si no, se comprueba la igualdad.',
    );
    return c.finish(v.valid);
  }
}
