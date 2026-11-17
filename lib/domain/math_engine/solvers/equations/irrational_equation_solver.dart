import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../exact/ext_expr.dart';
import 'eq_context.dart';
import 'eq_poly.dart';

/// Ecuaciones irracionales: sqrt(A) = B y dos radicales, con comprobacion
/// obligatoria de cada solucion en la ecuacion original.
class IrrationalEquationSolver {
  const IrrationalEquationSolver._();

  static bool matches(EqCtx c) => _hasRoot(c.left) || _hasRoot(c.right);

  static bool _hasRoot(XNode n) => switch (n) {
        XRoot(:final index, :final rad) => PolyOps.containsX(rad) &&
            (index == null || (index is XNum && index.value == Rational(2))),
        XNeg(:final a) || XAbs(:final a) => _hasRoot(a),
        XBin(:final l, :final r) => _hasRoot(l) || _hasRoot(r),
        XPow(:final base) => _hasRoot(base),
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
    final p = PolyOps.polyOf(n);
    if (p == null || PolyOps.degree(p) > 0) return null;
    return PolyOps.coeff(p, 0);
  }

  /// `k * sqrt(A)` -> (k, A); `null` si el termino no es un radical con x.
  static (Rational, Poly)? _radical(XNode t) {
    switch (t) {
      case XRoot(:final rad):
        if (!_hasRoot(t)) return null;
        final p = PolyOps.polyOf(rad);
        return p == null ? null : (Rational(1), p);
      case XNeg(:final a):
        final r = _radical(a);
        return r == null ? null : (-r.$1, r.$2);
      case XBin(:final l, :final op, :final r):
        if (op == '*') {
          final k = _const(l);
          final rr = _radical(r);
          if (k != null && rr != null) return (k * rr.$1, rr.$2);
          final k2 = _const(r);
          final ll = _radical(l);
          if (k2 != null && ll != null) return (k2 * ll.$1, ll.$2);
        } else if (op == '/') {
          final k = _const(r);
          final ll = _radical(l);
          if (k != null && !k.isZero && ll != null) return (ll.$1 / k, ll.$2);
        }
        return null;
      default:
        return null;
    }
  }

  static String _sqrt(Poly a) => '\\sqrt{${PolyOps.latex(a)}}';
  static String _p(Poly a) => '\\left(${PolyOps.latex(a)}\\right)';
  static String _k(Rational k, String body) {
    if (k == Rational(1)) return body;
    if (k == Rational(-1)) return '-$body';
    return '${k.isInteger ? '${k.numerator}' : '\\frac{${k.numerator}}{${k.denominator}}'}$body';
  }

  static StepByStepResolution? solve(EqCtx c) {
    final items = <(int, XNode)>[];
    _terms(c.left, 1, items);
    _terms(c.right, -1, items);
    final radicals = <(Rational, Poly)>[];
    var rest = <int, Rational>{};
    for (final (s, t) in items) {
      final r = _radical(t);
      if (r != null) {
        radicals.add((r.$1 * Rational(s), r.$2));
      } else {
        final p = PolyOps.polyOf(t);
        if (p == null) return null;
        rest = PolyOps.add(rest, PolyOps.scale(p, Rational(s)));
      }
    }
    if (radicals.isEmpty || radicals.length > 2) return null;
    final b = PolyOps.neg(rest); // sum k_i sqrt(A_i) = b

    late Poly equation;
    if (radicals.length == 1) {
      final (k, a) = radicals.first;
      final iso = PolyOps.scale(b, Rational(1) / k);
      c.add(
        'Aislar el radical en un miembro',
        '${_sqrt(a)} = ${PolyOps.latex(iso)}',
        'Para resolver una ecuación irracional, lo primero es dejar la raíz sola en un miembro antes de elevar al cuadrado.',
      );
      final sq = PolyOps.mul(iso, iso);
      c.add(
        'Elevar al cuadrado ambos miembros',
        '\\left(${_sqrt(a)}\\right)^{2} = ${_p(iso)}^{2} \\implies ${PolyOps.latex(a)} = ${PolyOps.latex(sq)}',
        'Elevamos al cuadrado los dos miembros para eliminar la raíz. Si el otro miembro es un binomio usamos (a ± b)² = a² ± 2ab + b².',
        warn:
            'Al elevar al cuadrado pueden aparecer soluciones falsas (raíces extrañas). Es OBLIGATORIO comprobarlas en la ecuación original.',
      );
      equation = PolyOps.sub(a, sq);
    } else {
      final (k1, a1) = radicals[0];
      final (k2, a2) = radicals[1];
      c.add(
        'Aislar el radical en un miembro',
        '${_k(k1, _sqrt(a1))} = ${PolyOps.latex(b)} ${k2.isNegative ? '+' : '-'} ${_k(k2.abs(), _sqrt(a2))}',
        'Con dos radicales, aislamos uno de ellos y dejamos el otro junto al resto de términos.',
      );
      // (k1 sqrt A1)^2 = (b - k2 sqrt A2)^2  =>  k1^2 A1 = b^2 + k2^2 A2 - 2 k2 b sqrt A2
      final s = PolyOps.sub(
        PolyOps.add(PolyOps.mul(b, b), PolyOps.scale(a2, k2 * k2)),
        PolyOps.scale(a1, k1 * k1),
      );
      final q = PolyOps.scale(b, Rational(2) * k2);
      c.add(
        'Elevar al cuadrado ambos miembros',
        '${k1 * k1 == Rational(1) ? '' : '${(k1 * k1).toLatex()}\\cdot'}${_p(a1)} = ${_p(b)}^{2} - 2\\cdot${k2.toLatex()}\\cdot${_p(b)}${_sqrt(a2)} + ${(k2 * k2).toLatex()}\\cdot${_p(a2)}',
        'Elevamos al cuadrado: aparece un doble producto que todavía contiene un radical.',
      );
      c.add(
        'Aislar el radical restante',
        '${PolyOps.latex(q) == '1' ? '' : _p(q)}${_sqrt(a2)} = ${PolyOps.latex(s)}',
        'Dejamos el radical que queda solo en un miembro y volvemos a elevar al cuadrado.',
      );
      c.add(
        'Elevar al cuadrado de nuevo',
        '${_p(q)}^{2}\\cdot${_p(a2)} = ${_p(s)}^{2}',
        'Con este segundo cuadrado desaparece la última raíz y obtenemos una ecuación polinómica.',
        warn: 'Al elevar dos veces al cuadrado aumenta el riesgo de soluciones falsas: comprueba siempre.',
      );
      equation = PolyOps.sub(
        PolyOps.mul(PolyOps.mul(q, q), a2),
        PolyOps.mul(s, s),
      );
    }

    if (PolyOps.degree(equation) < 0) {
      c.add('Ecuación resultante', '0 = 0',
          'Los dos miembros coinciden: la igualdad se cumple siempre que los radicandos sean no negativos.');
      return c.finish(const [],
          exactOverride: '\\text{Infinitas soluciones en el dominio}',
          decimalOverride: '\\text{Infinitas soluciones en el dominio}');
    }
    final roots = PolyRoots.real(equation);
    c.addPolynomialSolveStep(equation, roots);
    final v = c.verify(roots);
    c.add(
      'Comprobacion obligatoria en la ecuacion original',
      v.latex.isEmpty ? '\\text{Ninguna candidata}' : v.latex,
      'Sustituimos cada candidata en la ecuación con radicales. Descartamos las que no cumplen la igualdad exacta (raíces extrañas).',
    );
    return c.finish(v.valid);
  }
}
