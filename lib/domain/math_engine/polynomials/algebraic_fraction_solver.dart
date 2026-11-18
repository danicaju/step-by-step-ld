import '../arithmetic/casio_iberia_arsenal.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/equations/eq_poly.dart';
import 'algebraic_fraction_steps.dart';
import 'spanish_box_division_solver.dart';

enum FractionOp { simplify, add, sub, mul, div }

/// Polinomio factorizado: constante por factores monicos con su multiplicidad.
class Factored {
  final Rational c;
  final Map<String, (Poly, int)> factors; // clave = LaTeX del factor monico
  const Factored(this.c, this.factors);

  Poly expand() {
    var p = PolyOps.constant(c);
    factors.forEach((_, v) {
      for (var i = 0; i < v.$2; i++) {
        p = PolyOps.mul(p, v.$1);
      }
    });
    return p;
  }

  /// `2(x - 1)^{2}(x + 3)`; `fallback` si es la constante 1 sin factores.
  String latex({Set<String> grey = const {}}) {
    final parts = <String>[];
    factors.forEach((k, v) {
      final base = k == 'x' ? 'x' : '($k)';
      var s = v.$2 > 1 ? '$base^{${v.$2}}' : base;
      if (grey.contains(k)) s = '\\textcolor{#7A8A7E}{$s}';
      parts.add(s);
    });
    final cs = c == Rational(1) ? '' : (c == Rational(-1) ? '-' : ArsenalLatex.ratParen(c));
    if (parts.isEmpty) return ArsenalLatex.rat(c);
    return '$cs${parts.join()}';
  }
}

class AlgebraicFractionResult {
  final Poly num;
  final Poly den;
  final StepByStepResolution resolution;
  const AlgebraicFractionResult(this.num, this.den, this.resolution);
}

/// Fracciones algebraicas: simplificar, sumar/restar (m.c.m.), multiplicar y dividir.
class AlgebraicFractionSolver {
  const AlgebraicFractionSolver._();

  static String _p(Poly p) => PolyOps.latex(p);

  static String _frac(Poly n, Poly d) => '\\frac{${_p(n)}}{${_p(d)}}';

  /// Factoriza por raices racionales; lo que no se puede romper queda como un factor.
  static Factored factor(Poly input) {
    var rest = PolyOps.clean(input);
    if (rest.isEmpty) return Factored(Rational(0), {});
    final lead = PolyOps.coeff(rest, PolyOps.degree(rest));
    rest = PolyOps.scale(rest, Rational(1) / lead);
    final out = <String, (Poly, int)>{};
    void add(Poly f) {
      final k = PolyOps.latex(f);
      out[k] = (f, (out[k]?.$2 ?? 0) + 1);
    }

    var guard = 0;
    while (PolyOps.degree(rest) >= 1 && guard++ < 24) {
      final r = PolyRoots.rationalRoot(PolyOps.toIntegers(rest));
      if (r == null) break;
      rest = PolyOps.clean(PolyOps.deflate(rest, r));
      add({1: Rational(1), if (!r.isZero) 0: -r});
    }
    if (PolyOps.degree(rest) >= 1) add(rest);
    final sorted = out.entries.toList()
      ..sort((a, b) => PolyOps.degree(a.value.$1).compareTo(PolyOps.degree(b.value.$1)) != 0
          ? PolyOps.degree(a.value.$1).compareTo(PolyOps.degree(b.value.$1))
          : a.key.compareTo(b.key));
    return Factored(lead, {for (final e in sorted) e.key: e.value});
  }

  static List<String> _restrictions(Poly den) {
    if (PolyOps.degree(den) < 1) return const [];
    return [for (final r in PolyRoots.real(den)) 'x \\neq ${r.toLatex()}'];
  }

  static MathStep _s(int i, String t, String l, String n, {String? trick}) =>
      MathStep(index: i, shortTitle: t, latexExpression: l, pedagogicalNote: n, warningTrick: trick);

  /// Simplifica `n/d` y devuelve (n', d', pasos).
  static (Poly, Poly, List<MathStep>) reduce(Poly n, Poly d, int start) {
    final steps = <MathStep>[];
    final fn = factor(n), fd = factor(d);
    final common = <String>{
      for (final k in fn.factors.keys)
        if (fd.factors.containsKey(k)) k,
    };
    steps.add(_s(start, 'Factorizar numerador y denominador',
        '${_frac(n, d)} = \\frac{${fn.latex(grey: common)}}{${fd.latex(grey: common)}}',
        'Numerador: ${AlgebraicFractionSteps.method(n)}. Denominador: ${AlgebraicFractionSteps.method(d)}. Los factores en gris son comunes y se tachan.'));
    final cn = <String, (Poly, int)>{}, cd = <String, (Poly, int)>{};
    fn.factors.forEach((k, v) {
      final m = common.contains(k) ? (v.$2 - fd.factors[k]!.$2).clamp(0, 99) : v.$2;
      if (m > 0) cn[k] = (v.$1, m);
    });
    fd.factors.forEach((k, v) {
      final m = common.contains(k) ? (v.$2 - fn.factors[k]!.$2).clamp(0, 99) : v.$2;
      if (m > 0) cd[k] = (v.$1, m);
    });
    final ratio = fn.c / fd.c;
    final nn = Factored(Rational(ratio.numerator), cn), dd = Factored(Rational(ratio.denominator), cd);
    final rn = nn.expand(), rd = dd.expand();
    steps.add(_s(
      start + 1,
      common.isEmpty ? 'No hay factores comunes' : 'Simplificar',
      '\\frac{${nn.latex()}}{${dd.latex()}} = ${_frac(rn, rd)}',
      common.isEmpty
          ? 'La fracción ya es irreducible.'
          : 'Dividimos numerador y denominador entre los factores comunes y la constante entre su m.c.d.',
      trick: _restrictions(d).isEmpty ? null : 'La simplificación solo vale si ${_restrictions(d).join(r',\;')}.',
    ));
    return (rn, rd, steps);
  }

  static AlgebraicFractionResult simplify(String n, String d) {
    final pn = SpanishBoxDivisionSolver.parsePoly(n, 'el numerador P(x)');
    final pd = SpanishBoxDivisionSolver.parsePoly(d, 'el denominador Q(x)');
    final (rn, rd, steps) = reduce(pn, pd, 1);
    return _wrap(_frac(pn, pd), rn, rd, steps);
  }

  static AlgebraicFractionResult operate(FractionOp op, String n1, String d1, String n2, String d2) {
    if (op == FractionOp.simplify) return simplify(n1, d1);
    final a = SpanishBoxDivisionSolver.parsePoly(n1, 'el numerador 1');
    final b = SpanishBoxDivisionSolver.parsePoly(d1, 'el denominador 1');
    final c = SpanishBoxDivisionSolver.parsePoly(n2, 'el numerador 2');
    final d = SpanishBoxDivisionSolver.parsePoly(d2, 'el denominador 2');
    final given = '${_frac(a, b)} ${_opSym(op)} ${_frac(c, d)}';
    final steps = <MathStep>[
      AlgebraicFractionSteps.factorization(1, [
        ('P1(x)', a), ('Q1(x)', b), ('P2(x)', c), ('Q2(x)', d),
      ]),
    ];
    Poly num, den;
    if (op == FractionOp.mul || op == FractionOp.div) {
      final (x, y) = op == FractionOp.mul ? (c, d) : (d, c);
      num = PolyOps.mul(a, x);
      den = PolyOps.mul(b, y);
      steps.add(_s(steps.length + 1, op == FractionOp.mul ? 'Multiplicar numeradores y denominadores' : 'Multiplicar por la inversa',
          '$given = ${_frac(a, b)} \\cdot ${_frac(x, y)} = ${_frac(num, den)}',
          op == FractionOp.mul ? 'Producto: numerador por numerador y denominador por denominador.' : 'Dividir es multiplicar por la fracción inversa.',
          trick: op == FractionOp.div ? 'El divisor ${_frac(c, d)} no puede ser 0.' : null));
    } else {
      final fb = factor(b), fd = factor(d);
      final keys = {...fb.factors.keys, ...fd.factors.keys};
      final lcm = <String, (Poly, int)>{};
      for (final k in keys) {
        final ba = fb.factors[k], da = fd.factors[k];
        final m = (ba?.$2 ?? 0) > (da?.$2 ?? 0) ? ba!.$2 : da!.$2;
        lcm[k] = ((ba ?? da)!.$1, m);
      }
      final cb = fb.c, cd = fd.c;
      final cLcm = Rational(Rational.lcm(cb.numerator.abs(), cd.numerator.abs()));
      final big = Factored(cLcm, lcm);
      steps.add(_s(steps.length + 1, 'm.c.m. de los denominadores',
          '${_p(b)} = ${fb.latex()},\\quad ${_p(d)} = ${fd.latex()}\\;\\Rightarrow\\; \\text{m.c.m.} = ${big.latex()}',
          'Factorizamos cada denominador y tomamos los factores comunes y no comunes con el mayor exponente.'));
      Poly lift(Poly numr, Factored f) {
        var m = PolyOps.constant(cLcm / f.c);
        lcm.forEach((k, v) {
          final have = f.factors[k]?.$2 ?? 0;
          for (var i = 0; i < v.$2 - have; i++) {
            m = PolyOps.mul(m, v.$1);
          }
        });
        return PolyOps.mul(numr, m);
      }

      final n1e = lift(a, fb), n2e = lift(c, fd);
      steps.add(_s(steps.length + 1, 'Fracciones equivalentes',
          '${_frac(a, b)} = ${_frac(n1e, big.expand())},\\quad ${_frac(c, d)} = ${_frac(n2e, big.expand())}',
          'Multiplicamos numerador y denominador de cada fracción por lo que falta para llegar al m.c.m.'));
      num = op == FractionOp.add ? PolyOps.add(n1e, n2e) : PolyOps.sub(n1e, n2e);
      den = big.expand();
      final sign = op == FractionOp.add ? '+' : '-';
      steps.add(_s(steps.length + 1, op == FractionOp.add ? 'Sumar numeradores' : 'Restar numeradores',
          '${_frac(n1e, den)} ${_opSym(op)} ${_frac(n2e, den)} = \\frac{(${_p(n1e)}) $sign (${_p(n2e)})}{${_p(den)}}',
          'Con el mismo denominador, operamos los numeradores (con paréntesis en la resta).'));
      steps.add(_s(steps.length + 1, 'Desarrollar y reducir términos semejantes',
          '(${_p(n1e)}) $sign (${_p(n2e)}) = ${_p(num)}',
          'Quitamos paréntesis (en la resta cambia el signo de todo el segundo numerador) y agrupamos términos semejantes.'));
    }
    if (num.isEmpty) {
      steps.add(_s(steps.length + 1, 'Resultado', '0', 'El numerador es 0: la fracción vale 0.'));
      return AlgebraicFractionResult(num, den, StepByStepResolution(
          originalInputLatex: given, steps: steps, exactResultLatex: '0', decimalApproxLatex: ''));
    }
    final (rn, rd, more) = reduce(num, den, steps.length + 1);
    steps.addAll(more);
    return _wrap(given, rn, rd, steps);
  }

  static String _opSym(FractionOp op) => switch (op) {
        FractionOp.add => '+',
        FractionOp.sub => '-',
        FractionOp.mul => r'\cdot',
        _ => ':',
      };

  static AlgebraicFractionResult _wrap(String given, Poly n, Poly d, List<MathStep> steps) {
    final dc = PolyOps.degree(d) == 0 && PolyOps.coeff(d, 0) == Rational(1);
    final result = dc ? _p(n) : _frac(n, d);
    return AlgebraicFractionResult(
      n,
      d,
      StepByStepResolution(originalInputLatex: given, steps: steps, exactResultLatex: result, decimalApproxLatex: ''),
    );
  }
}
