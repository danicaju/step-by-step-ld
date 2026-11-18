import 'dart:math' as math;

import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';

/// Factorizacion de Ruffini estructurada: `constante * x^k * prod(q·x - p) * resto`.
///
/// [remaining] son los coeficientes (de mayor a menor grado) del factor que no se descompone
/// con raices racionales (`[1]` si no queda nada). Permite comprobar algebraicamente que el
/// producto desarrollado coincide con el polinomio original (`expand`).
class RuffiniFactorization {
  final int constant;
  final int xPower;

  /// Raices racionales `p/q` (`q > 0`); cada una aporta el factor primitivo `(q·x - p)`.
  final List<(int, int)> roots;
  final List<int> remaining;

  const RuffiniFactorization({
    required this.constant,
    required this.xPower,
    required this.roots,
    required this.remaining,
  });

  /// Producto desarrollado `[a_n, ..., a_0]`.
  List<int> expand() {
    var p = <int>[constant];
    for (final (r, q) in roots) {
      p = multiply(p, [q, -r]);
    }
    p = multiply(p, remaining);
    return [...p, ...List<int>.filled(xPower, 0)];
  }

  static List<int> multiply(List<int> a, List<int> b) {
    final out = List<int>.filled(a.length + b.length - 1, 0);
    for (var i = 0; i < a.length; i++) {
      for (var j = 0; j < b.length; j++) {
        out[i + j] += a[i] * b[j];
      }
    }
    return out;
  }
}

/// Candidatos a raiz `±p/q` (p divide a `a_0`, q divide a `a_n`).
class RuffiniCandidates {
  const RuffiniCandidates._();

  static List<int> positiveDivisors(int n) {
    final absN = n.abs();
    if (absN == 0) return const [1];
    final out = <int>{};
    for (var i = 1; i * i <= absN; i++) {
      if (absN % i == 0) {
        out
          ..add(i)
          ..add(absN ~/ i);
      }
    }
    return out.toList()..sort();
  }

  /// Fracciones positivas irreducibles `p/q` ordenadas por valor.
  static List<(int, int)> positive(int a0, int an) {
    final seen = <(int, int)>{};
    for (final p in positiveDivisors(a0)) {
      for (final q in positiveDivisors(an)) {
        final g = Rational.gcd(p, q);
        seen.add((p ~/ g, q ~/ g));
      }
    }
    return seen.toList()..sort((a, b) => (a.$1 * b.$2).compareTo(b.$1 * a.$2));
  }

  /// Orden de prueba: primero los enteros `+1, -1, +2, -2...` y despues las fracciones.
  static List<(int, int)> searchOrder(int a0, int an) {
    final pos = positive(a0, an);
    return [
      for (final (p, q) in pos)
        if (q == 1) ...[(p, 1), (-p, 1)],
      for (final (p, q) in pos)
        if (q > 1) ...[(p, q), (-p, q)],
    ];
  }

  static String fractionLatex(int p, int q) => q == 1 ? '$p' : '\\frac{$p}{$q}';

  /// `\pm 1, \pm \frac{1}{2}, ...` (recortado a [max] elementos).
  static String listLatex(List<(int, int)> pos, {int max = 12}) {
    final shown = pos.take(max).map((c) => '\\pm ${fractionLatex(c.$1, c.$2)}').toList();
    if (pos.length > max) shown.add(r'\ldots');
    return shown.join(', ');
  }

  /// Factor primitivo `(q·x - p)` de la raiz `p/q`.
  static String factorLatex(int p, int q) {
    if (q == 1) return AlgebraicLatexFormatter.linearFactor(p);
    return p >= 0 ? '(${q}x - $p)' : '(${q}x + ${-p})';
  }
}

/// Division sintetica por `(x - raiz)` con raiz racional.
class RationalRuffini {
  const RationalRuffini._();

  static ({List<Rational> quotient, List<Rational> products, Rational remainder}) divide(
    List<int> coeffs,
    Rational root,
  ) {
    final quotient = <Rational>[Rational(coeffs.first)];
    final products = <Rational>[];
    var current = Rational(coeffs.first);
    for (var i = 1; i < coeffs.length; i++) {
      final prod = current * root;
      products.add(prod);
      current = Rational(coeffs[i]) + prod;
      if (i < coeffs.length - 1) quotient.add(current);
    }
    return (quotient: quotient, products: products, remainder: current);
  }

  static String tableLatex(
    List<int> coeffs,
    Rational root,
    List<Rational> quotient,
    List<Rational> products,
    Rational remainder,
  ) {
    final colSpec = 'r|${'r' * coeffs.length}';
    return '\\begin{array}{$colSpec}\n'
        ' & ${coeffs.join(' & ')} \\\\\n'
        '${root.toLatex()} & ${products.map((p) => p.toLatex()).join(' & ')} \\\\\n'
        '\\hline\n'
        ' & ${quotient.map((q) => q.toLatex()).join(' & ')} & \\boxed{${remainder.toLatex()}}\n'
        '\\end{array}';
  }
}

/// Resultado del remate de un cuadratico `a x^2 + b x + c` (a > 0, primitivo).
class QuadraticClosure {
  final String title;
  final String latex;
  final String note;
  final String? warning;

  /// Factores LaTeX a anadir al producto (sin la constante `absorbedConstant`).
  final String factorLatex;
  final List<(int, int)> rationalRoots;
  final List<String> rootsLatex;
  final List<String> rootsPlain;

  /// Constante que pasa delante del producto (`a` en el caso de raices irracionales).
  final int absorbedConstant;
  final bool irreducible;
  final bool irrational;

  const QuadraticClosure({
    required this.title,
    required this.latex,
    required this.note,
    required this.factorLatex,
    this.warning,
    this.rationalRoots = const [],
    this.rootsLatex = const [],
    this.rootsPlain = const [],
    this.absorbedConstant = 1,
    this.irreducible = false,
    this.irrational = false,
  });
}

class RuffiniQuadratic {
  const RuffiniQuadratic._();

  static String _vTerm(int v, int t, bool imag) {
    final coef = v == 1 ? '' : '$v';
    if (imag) return t > 1 ? '${coef}i\\sqrt{$t}' : '${coef}i';
    return '$coef\\sqrt{$t}';
  }

  /// `(u ± v√t) / w` con signo [sign] (`+`, `-` o `\pm`).
  static String _root(int u, int v, int t, int w, String sign, {bool imag = false}) {
    final vt = _vTerm(v, t, imag);
    final String num;
    if (u == 0) {
      num = sign == '+' ? vt : (sign == '-' ? '-$vt' : '\\pm $vt');
    } else {
      num = '$u $sign $vt';
    }
    return w == 1 ? num : '\\frac{$num}{$w}';
  }

  static String _rootPlain(int u, int v, int t, int w, {required bool imag}) {
    final coef = v == 1 ? '' : '$v';
    final vt = imag ? '${coef}i${t > 1 ? '√$t' : ''}' : '$coef√$t';
    final num = u == 0 ? '±$vt' : '$u ± $vt';
    return w == 1 ? num : '($num)/$w';
  }

  static QuadraticClosure solve(int a, int b, int c) {
    final quad = AlgebraicLatexFormatter.polynomialExpression([a, b, c]);
    final disc = b * b - 4 * a * c;
    final formula =
        r'x = \frac{-'
        '${AlgebraicLatexFormatter.parenIfNegative(b)}'
        r' \pm \sqrt{'
        '$disc'
        r'}}{2 \cdot '
        '${AlgebraicLatexFormatter.parenIfNegative(a)}}';

    if (disc >= 0) {
      final s = math.sqrt(disc).round();
      if (s * s == disc) {
        final r1 = Rational(-b + s, 2 * a);
        final r2 = Rational(-b - s, 2 * a);
        final pairs = [(r1.numerator, r1.denominator), (r2.numerator, r2.denominator)];
        final f1 = RuffiniCandidates.factorLatex(pairs[0].$1, pairs[0].$2);
        final f2 = RuffiniCandidates.factorLatex(pairs[1].$1, pairs[1].$2);
        final isDouble = r1 == r2;
        return QuadraticClosure(
          title: 'Resolver el cociente cuadrático restante',
          latex: '$quad = 0 \\implies \\Delta = $disc \\geq 0 \\implies $formula \\implies '
              'x = ${r1.toLatex()}${isDouble ? '' : ', \\; x = ${r2.toLatex()}'}',
          note: isDouble
              ? 'Con Δ = 0 el cuadrático tiene una raíz doble: el factor aparece al cuadrado.'
              : 'Al llegar a grado 2 aplicamos la fórmula cuadrática: Δ = $disc es un cuadrado perfecto, así que las dos raíces son racionales.',
          warning: isDouble
              ? 'La raíz doble x = ${_plainRat(r1)} da el factor $f1 al cuadrado.'
              : 'Las raíces x = ${_plainRat(r1)} y x = ${_plainRat(r2)} dan los factores $f1 y $f2 (se cambia el signo y se multiplica por el denominador).',
          factorLatex: isDouble ? '$f1^{2}' : '$f1$f2',
          rationalRoots: pairs,
          rootsLatex: ['x = ${r1.toLatex()}', if (!isDouble) 'x = ${r2.toLatex()}'],
          rootsPlain: [
            'x = ${_plainRat(r1)}',
            if (!isDouble) 'x = ${_plainRat(r2)}',
          ],
        );
      }
      final d = AlgebraicLatexFormatter.decomposeIntSqrt(disc);
      final g = Rational.gcdMany([b.abs(), d.outside, 2 * a]);
      final u = -b ~/ g, v = d.outside ~/ g, t = d.inside, w = 2 * a ~/ g;
      final both = _root(u, v, t, w, r'\pm');
      final plus = _root(u, v, t, w, '+');
      final minus = _root(u, v, t, w, '-');
      final String factors;
      if (u == 0) {
        final abs = w == 1 ? _vTerm(v, t, false) : '\\frac{${_vTerm(v, t, false)}}{$w}';
        factors = '\\left(x - $abs\\right)\\left(x + $abs\\right)';
      } else if (w == 1) {
        // x - (u + v√t) = x - u - v√t: sin parentesis dobles.
        final shift = u > 0 ? '- $u' : '+ ${-u}';
        final vt = _vTerm(v, t, false);
        factors = '\\left(x $shift - $vt\\right)\\left(x $shift + $vt\\right)';
      } else {
        factors = '\\left(x - $plus\\right)\\left(x - $minus\\right)';
      }
      return QuadraticClosure(
        title: 'Resolver el cociente cuadrático restante',
        latex: '$quad = 0 \\implies \\Delta = $disc > 0 \\implies $formula \\implies x = $both',
        note:
            'Δ = $disc no es un cuadrado perfecto: las raíces son irracionales (reales) y se dejan exactas con radicales, sin decimales.',
        warning: 'Raíces irracionales: no aparecen como divisores de a₀, por eso Ruffini no las encuentra.',
        factorLatex: factors,
        rootsLatex: u == 0 && w == 1 ? ['x = $both'] : ['x = $plus', 'x = $minus'],
        rootsPlain: ['x = ${_rootPlain(u, v, t, w, imag: false)}'],
        absorbedConstant: a,
        irrational: true,
      );
    }
    final d = AlgebraicLatexFormatter.decomposeIntSqrt(-disc);
    final g = Rational.gcdMany([b.abs(), d.outside, 2 * a]);
    final u = -b ~/ g, v = d.outside ~/ g, t = d.inside, w = 2 * a ~/ g;
    final complex = _root(u, v, t, w, r'\pm', imag: true);
    final plain = _rootPlain(u, v, t, w, imag: true);
    return QuadraticClosure(
      title: 'Cuadrático irreducible en ℝ (Δ < 0)',
      latex: '$quad = 0 \\implies \\Delta = $disc < 0 \\implies \\text{sin raices reales}'
          ' \\;\\Rightarrow\\; x = $complex',
      note:
          'Como Δ = $disc < 0, la raíz cuadrada del discriminante no es real: el cuadrático no tiene raíces reales y es irreducible en ℝ, '
          'así que se deja sin descomponer. Dato extra: sus raíces complejas conjugadas son x = $plain.',
      warning: 'Δ < 0: sin raíces reales; en ℝ este factor ya no se puede factorizar más.',
      factorLatex: '($quad)',
      rootsLatex: const [],
      rootsPlain: ['x = $plain (complejas)'],
      irreducible: true,
    );
  }

  static String _plainRat(Rational r) => r.isInteger ? '${r.numerator}' : '${r.numerator}/${r.denominator}';
}
