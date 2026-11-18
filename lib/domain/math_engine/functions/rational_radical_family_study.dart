import 'dart:math' as math;

import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/equations/eq_poly.dart';
import 'function_family.dart';

/// Estudio de pizarra de las funciones racionales P(x)/Q(x) (incluida k/x) y radicales.
class RationalRadicalFamilyStudy {
  const RationalRadicalFamilyStudy._();

  static String _pt(String x, String y) => '\\left($x,\\,$y\\right)';
  static String _dec(double v) => fdec(v);

  static double _ev(Poly p, double x) {
    var s = 0.0;
    for (final e in p.entries) {
      s += e.value.toDouble() * math.pow(x, e.key);
    }
    return s;
  }

  /// Raiz n-esima exacta de [r] si es racional.
  static Rational? _exactRoot(Rational r, int n) {
    if (r.isNegative && n.isEven) return null;
    final sign = r.isNegative ? -1 : 1;
    final nu = math.pow(r.numerator.abs(), 1 / n).round();
    final de = math.pow(r.denominator, 1 / n).round();
    final cand = Rational(sign * nu, de == 0 ? 1 : de);
    return cand.pow(n) == r ? cand : null;
  }

  static String _inf(double v) => v > 0 ? '+\\infty' : '-\\infty';

  /// Cociente de la division polinomica (solo se usa para la asintota oblicua).
  static Poly _quotient(Poly n, Poly d) {
    var rem = Map<int, Rational>.of(PolyOps.clean(n));
    final q = <int, Rational>{};
    final dd = PolyOps.degree(d);
    final lc = PolyOps.coeff(d, dd);
    var guard = 0;
    while (PolyOps.degree(rem) >= dd && rem.isNotEmpty && guard++ < 20) {
      final k = PolyOps.degree(rem) - dd;
      final co = PolyOps.coeff(rem, PolyOps.degree(rem)) / lc;
      q[k] = co;
      rem = PolyOps.sub(rem, PolyOps.mul(d, {k: co}));
    }
    return q;
  }

  // ----------------------------------------------------------------- racional

  static List<MathStep> rational(Poly num, Poly den) {
    final p = PolyOps.clean(num), q = PolyOps.clean(den);
    final dp = PolyOps.degree(p), dq = PolyOps.degree(q);
    final qRoots = PolyRoots.real(q);
    final isInverse = dp == 0 && dq == 1 && PolyOps.coeff(q, 0).isZero;
    final steps = <MathStep>[
      fstep(
          'Tipo de función',
          'f(x) = \\frac{${PolyOps.latex(p)}}{${PolyOps.latex(q)}}',
          isInverse
              ? 'Proporcionalidad inversa f(x) = k/x: su gráfica es una hipérbola con ejes como asíntotas.'
              : 'Función racional P(x)/Q(x): cociente de dos polinomios. Su gráfica puede tener asíntotas.'),
      fstep(
          'Dominio',
          qRoots.isEmpty
              ? '\\text{Dom}(f) = \\mathbb{R}'
              : 'Q(x) = 0 \\implies ${[for (final r in qRoots) 'x = ${r.toLatex()}'].join(',\\; ')} \\implies \\text{Dom}(f) = \\mathbb{R} \\setminus \\left\\{${[for (final r in qRoots) r.toLatex()].join(',\\,')}\\right\\}',
          'El denominador no puede valer 0: quitamos esos valores de R.'),
    ];
    for (final r in qRoots) {
      final a = r.approx;
      if (_ev(p, a).abs() < 1e-9) {
        steps.add(fstep('Hueco en x = ${_dec(a)}', '\\frac{0}{0}', 'P y Q se anulan a la vez: hay un hueco (punto sin definir) y no una asíntota vertical. Simplifica la fracción.'));
        continue;
      }
      final l = _ev(p, a - 1e-6) / _ev(q, a - 1e-6), rr = _ev(p, a + 1e-6) / _ev(q, a + 1e-6);
      steps.add(fstep(
          'Asíntota vertical',
          'x_{AV} = ${r.toLatex()}:\\quad \\lim_{x \\to ${r.toLatex()}^{-}} f = ${_inf(l)},\\quad \\lim_{x \\to ${r.toLatex()}^{+}} f = ${_inf(rr)}',
          'Los límites laterales en x = ${r.toLatex()} tienden a infinito: la recta vertical x = ${r.toLatex()} es asíntota vertical (AV).'));
    }
    if (dp < dq) {
      steps.add(fstep('Asíntota horizontal', '\\lim_{x \\to \\pm\\infty} f(x) = 0 \\implies y_{AH} = 0',
          'El denominador tiene mayor grado que el numerador: f tiende a 0 en el infinito (y = 0).'));
    } else if (dp == dq) {
      final h = PolyOps.coeff(p, dp) / PolyOps.coeff(q, dq);
      steps.add(fstep('Asíntota horizontal', '\\lim_{x \\to \\pm\\infty} f(x) = \\frac{${rl(PolyOps.coeff(p, dp))}}{${rl(PolyOps.coeff(q, dq))}} \\implies y_{AH} = ${rl(h)}',
          'Mismo grado: el límite es el cociente de los coeficientes principales (p/r).'));
    } else if (dp == dq + 1) {
      final qu = _quotient(p, q);
      steps.add(fstep('Asíntota oblicua', 'y_{AO} = ${PolyOps.latex(qu)}',
          'El grado del numerador supera en uno al del denominador: dividimos P entre Q y el cociente es la asíntota oblicua (AO).'));
    } else {
      steps.add(fstep('Asíntotas horizontales y oblicuas', '\\text{AH: ninguna},\\quad \\text{AO: ninguna}',
          'El numerador tiene grado muy superior al denominador: no hay asíntota horizontal ni oblicua.'));
    }
    final q0 = PolyOps.coeff(q, 0);
    steps.add(fstep(
        'Corte con el eje OY',
        q0.isZero ? '0 \\notin \\text{Dom}(f) \\implies \\text{sin corte}' : 'f(0) = \\frac{${rl(PolyOps.coeff(p, 0))}}{${rl(q0)}} = ${rl(PolyOps.coeff(p, 0) / q0)} \\implies ${_pt('0', rl(PolyOps.coeff(p, 0) / q0))}',
        'Evaluamos en x = 0 si pertenece al dominio.'));
    final pRoots = PolyRoots.real(p).where((r) => !qRoots.any((s) => (s.approx - r.approx).abs() < 1e-9)).toList();
    steps.add(fstep(
        'Cortes con el eje OX',
        pRoots.isEmpty ? '\\text{sin cortes}' : 'P(x) = 0 \\implies ${[for (final r in pRoots) _pt(r.toLatex(), '0')].join(',\\; ')}',
        'Los cortes con OX son los ceros del numerador que no anulan el denominador.'));
    return steps;
  }

  // ------------------------------------------------------------------ radical

  static List<MathStep> radical(FamilyInfo i) {
    final n = i.base!.round();
    final b = i.b, c = i.c, a = i.a, d = i.d;
    final x0 = -c / b;
    final even = n.isEven;
    final rad = PolyOps.latex(i.inner);
    final root = n == 2 ? '\\sqrt{$rad}' : '\\sqrt[$n]{$rad}';
    final steps = <MathStep>[
      fstep('Tipo de función', 'f(x) = ${_amp(a)}$root${_shift(d)}',
          even ? 'Función radical de índice par (raíz cuadrada): solo existe si el radicando es mayor o igual que 0.' : 'Función radical de índice impar: existe para cualquier x porque la raíz de un negativo está definida.'),
    ];
    if (even) {
      final ge = b.isPositive ? '\\ge' : '\\le';
      steps
        ..add(fstep('Condición de existencia', '$rad \\ge 0 \\implies x $ge ${rl(x0)}', 'El radicando no puede ser negativo: resolvemos la inecuación.'))
        ..add(fstep('Dominio e imagen', b.isPositive ? '\\text{Dom}(f) = \\left[${rl(x0)},\\,+\\infty\\right)' : '\\text{Dom}(f) = \\left(-\\infty,\\,${rl(x0)}\\right]',
            'La imagen es ${a.isPositive ? '[${rl(d)}, +∞)' : '(-∞, ${rl(d)}]'}: la raíz nunca es negativa.'))
        ..add(fstep('Punto de arranque', 'f(${rl(x0)}) = ${rl(d)} \\implies ${_pt(rl(x0), rl(d))}', 'La curva nace en el punto donde el radicando vale 0.'));
    } else {
      steps
        ..add(fstep('Dominio e imagen', '\\text{Dom}(f) = \\mathbb{R},\\quad \\text{Im}(f) = \\mathbb{R}', 'Cualquier x vale y la raíz impar recorre todos los reales.'))
        ..add(fstep('Punto de simetría', 'x_{0} = -\\frac{c}{b} = ${rl(x0)} \\implies ${_pt(rl(x0), rl(d))}', 'Es el punto de inflexión y centro de simetría de la curva.'));
    }
    // Tabla de valores con raices exactas: radicando = k^n.
    final ks = even ? [0, 1, 2, 3] : [-1, 0, 1, 2];
    final rows = <String>[];
    for (final k in ks) {
      final r = Rational(k).pow(n);
      final x = (r - c) / b;
      rows.add('${rl(x)}\\to ${rl(a * Rational(k) + d)}');
    }
    steps.add(fstep('Tabla de valores', rows.join(';\\; '), 'Elegimos x para que el radicando sea una potencia perfecta y la raíz sea exacta.'));
    final r0 = c; // radicando en x = 0
    if (even && r0.isNegative) {
      steps.add(fstep('Corte con el eje OY', '${rl(r0)} < 0 \\implies \\text{sin corte}', 'x = 0 no está en el dominio.'));
    } else {
      final ex = _exactRoot(r0, n);
      steps.add(fstep('Corte con el eje OY', ex != null ? 'f(0) = ${rl(a * ex + d)} \\implies ${_pt('0', rl(a * ex + d))}' : 'f(0) ${feq(a.toDouble() * (r0.isNegative ? -math.pow(-r0.toDouble(), 1 / n) : math.pow(r0.toDouble(), 1 / n)) + d.toDouble())}',
          'Sustituimos x = 0 en la función.'));
    }
    final target = -d / a; // raiz n-esima de (Bx+C) = -D/A
    if (even && target.isNegative) {
      steps.add(fstep('Cortes con el eje OX', '\\text{sin cortes}', 'La raíz cuadrada no puede ser igual a un número negativo.'));
    } else {
      final xr = (target.pow(n) - c) / b;
      steps.add(fstep('Corte con el eje OX', 'f(x) = 0 \\implies $rad = ${rl(target.pow(n))} \\implies x = ${rl(xr)} \\implies ${_pt(rl(xr), '0')}',
          'Igualamos a 0 y elevamos a ${n == 2 ? 'cuadrado' : 'la potencia $n'} para quitar la raíz.'));
    }
    return steps;
  }

  static String _amp(Rational a) => a == Rational(1) ? '' : (a == Rational(-1) ? '-' : '${rl(a)}\\,');
  static String _shift(Rational d) => d.isZero ? '' : (d.isNegative ? ' - ${rl(d.abs())}' : ' + ${rl(d)}');
}
