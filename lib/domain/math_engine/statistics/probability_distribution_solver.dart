import 'dart:math' as math;

import '../arithmetic/casio_iberia_arsenal.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../proportion/proportion_conversion_solver.dart';

/// Operaciones de la Normal y de la Binomial.
enum NormalOp { le, ge, between }

enum BinomialOp { eq, le, ge }

/// Resultado de una Normal: probabilidad, limites (null = infinito) y pasos.
class NormalResult {
  final double probability;
  final double mu;
  final double sigma;
  final double? lower;
  final double? upper;
  final StepByStepResolution resolution;
  const NormalResult(this.probability, this.mu, this.sigma, this.lower, this.upper, this.resolution);
}

class BinomialResult {
  final Rational? exact; // null si el numerador/denominador no cabe en int
  final double probability;
  final double mean;
  final double sigma;
  final StepByStepResolution resolution;
  const BinomialResult(this.exact, this.probability, this.mean, this.sigma, this.resolution);
}

MathStep _step(int i, String title, String latex, String note, {String? trick}) =>
    MathStep(index: i, shortTitle: title, latexExpression: latex, pedagogicalNote: note, warningTrick: trick);

/// Distribuciones Normal N(mu, sigma) y Binomial B(n, p) paso a paso.
class ProbabilityDistributionSolver {
  const ProbabilityDistributionSolver._();

  static const int maxN = 1000;

  static Rational _q(String text, String name) {
    try {
      return ProportionSolver.parseQuantity(text);
    } on ArsenalException {
      throw ArsenalException('Sintaxis incompleta: completa $name.');
    }
  }

  /// `0,1234` con coma decimal y [dec] decimales.
  static String fmt(double v, int dec) => v.toStringAsFixed(dec).replaceAll('.', '{,}');

  static String _rat(Rational r) => ArsenalLatex.rat(r);

  // ---------------------------------------------------------------- Normal

  /// Funcion de distribucion normal estandar (Hart/West, error ~1e-15).
  static double phi(double x) {
    final ax = x.abs();
    double cum;
    if (ax > 37) {
      cum = 0;
    } else {
      final e = math.exp(-ax * ax / 2);
      if (ax < 7.07106781186547) {
        var b = 3.52624965998911e-02 * ax + 0.700383064443688;
        b = b * ax + 6.37396220353165;
        b = b * ax + 33.912866078383;
        b = b * ax + 112.079291497871;
        b = b * ax + 221.213596169931;
        b = b * ax + 220.206867912376;
        final c = e * b;
        b = 8.83883476483184e-02 * ax + 1.75566716318264;
        b = b * ax + 16.064177579207;
        b = b * ax + 86.7807322029461;
        b = b * ax + 296.564248779674;
        b = b * ax + 637.333633378831;
        b = b * ax + 793.826512519948;
        b = b * ax + 440.413735824752;
        cum = c / b;
      } else {
        var b = ax + 0.65;
        b = ax + 4 / b;
        b = ax + 3 / b;
        b = ax + 2 / b;
        b = ax + 1 / b;
        cum = e / b / 2.506628274631;
      }
    }
    return x > 0 ? 1 - cum : cum;
  }

  /// Densidad de N(mu, sigma) en x.
  static double pdf(double x, double mu, double sigma) =>
      math.exp(-0.5 * math.pow((x - mu) / sigma, 2)) / (sigma * math.sqrt(2 * math.pi));

  static NormalResult normal({
    required String mu,
    required String sigma,
    required String a,
    String? b,
    required NormalOp op,
  }) {
    final m = _q(mu, 'la media μ');
    final s = _q(sigma, 'la desviación σ');
    if (!s.isPositive) throw const ArsenalException('Math ERROR: σ debe ser mayor que 0.');
    final ra = _q(a, op == NormalOp.between ? 'el límite a' : 'el valor a');
    final rb = op == NormalOp.between ? _q(b ?? '', 'el límite b') : null;
    if (rb != null && ra.toDouble() > rb.toDouble()) {
      throw const ArsenalException('Math ERROR: se exige a menor o igual que b.');
    }
    final za = (ra - m) / s;
    final zb = rb == null ? null : (rb - m) / s;
    final fa = phi(za.toDouble());
    final fb = zb == null ? null : phi(zb.toDouble());
    final p = switch (op) {
      NormalOp.le => fa,
      NormalOp.ge => 1 - fa,
      NormalOp.between => fb! - fa,
    };
    final mS = _rat(m), sS = _rat(s);
    final steps = <MathStep>[
      _step(1, 'Distribución', 'X \\sim N($mS,\\,$sS)', 'Media μ = $mS y desviación típica σ = $sS.'),
      _step(
        2,
        'Tipificación',
        'Z = \\frac{X - \\mu}{\\sigma} = \\frac{X - $mS}{$sS}',
        'Convertimos X en una variable Z con distribución N(0, 1).',
      ),
      _step(
        3,
        'Valores de Z',
        'z_{a} = \\frac{${_rat(ra)} - $mS}{$sS} = ${_rat(za)} \\approx ${fmt(za.toDouble(), 2)}'
        '${zb == null ? '' : '\\qquad z_{b} = \\frac{${_rat(rb!)} - $mS}{$sS} = ${_rat(zb)} \\approx ${fmt(zb.toDouble(), 2)}'}',
        'Restamos la media y dividimos entre σ. En las tablas se redondea z a 2 decimales.',
      ),
      switch (op) {
        NormalOp.le => _step(4, 'Probabilidad', 'P(X \\leq ${_rat(ra)}) = P(Z \\leq ${fmt(za.toDouble(), 2)}) = \\Phi(${fmt(za.toDouble(), 2)}) = ${fmt(fa, 4)}',
            'Φ(z) es el área bajo la campana a la izquierda de z.'),
        NormalOp.ge => _step(4, 'Probabilidad',
            'P(X \\geq ${_rat(ra)}) = 1 - \\Phi(${fmt(za.toDouble(), 2)}) = 1 - ${fmt(fa, 4)} = ${fmt(1 - fa, 4)}',
            'El área a la derecha es el complemento: P(Z ≥ z) = 1 - Φ(z).'),
        NormalOp.between => _step(4, 'Probabilidad',
            'P(${_rat(ra)} \\leq X \\leq ${_rat(rb!)}) = \\Phi(${fmt(zb!.toDouble(), 2)}) - \\Phi(${fmt(za.toDouble(), 2)}) = ${fmt(fb!, 4)} - ${fmt(fa, 4)} = ${fmt(p, 4)}',
            'El área entre a y b es Φ(zb) - Φ(za).'),
      },
      _step(5, 'Resultado', 'P = ${fmt(p, 4)} \\approx ${fmt(p * 100, 2)}\\%', 'Probabilidad con 4 decimales, como en las tablas de la N(0, 1).'),
    ];
    final res = StepByStepResolution(
      originalInputLatex: 'X \\sim N($mS,\\,$sS)',
      steps: steps,
      exactResultLatex: fmt(p, 4),
      decimalApproxLatex: fmt(p, 6),
    );
    return NormalResult(
      p,
      m.toDouble(),
      s.toDouble(),
      op == NormalOp.le ? null : ra.toDouble(),
      op == NormalOp.le ? ra.toDouble() : (op == NormalOp.between ? rb!.toDouble() : null),
      res,
    );
  }

  // -------------------------------------------------------------- Binomial

  static BigInt _choose(int n, int k) {
    var r = BigInt.one;
    final kk = math.min(k, n - k);
    for (var i = 1; i <= kk; i++) {
      r = r * BigInt.from(n - kk + i) ~/ BigInt.from(i);
    }
    return r;
  }

  /// `num/den` como double con ~15 cifras (BigInt seguro).
  static double _div(BigInt num, BigInt den) {
    if (num == BigInt.zero) return 0;
    final scaled = (num * BigInt.from(10).pow(18)) ~/ den;
    return scaled.toDouble() / 1e18;
  }

  static BinomialResult binomial({
    required String n,
    required String p,
    required String k,
    required BinomialOp op,
  }) {
    final rn = _q(n, 'n'), rp = _q(p, 'p'), rk = _q(k, 'k');
    if (!rn.isInteger || rn.numerator < 1 || rn.numerator > maxN) {
      throw const ArsenalException('Math ERROR: n debe ser un entero entre 1 y 1000.');
    }
    if (!rp.isPositive || rp.toDouble() >= 1) {
      throw const ArsenalException('Math ERROR: p debe cumplir 0 < p < 1.');
    }
    final nn = rn.numerator;
    if (!rk.isInteger || rk.numerator < 0 || rk.numerator > nn) {
      throw const ArsenalException('Math ERROR: k debe ser un entero entre 0 y n.');
    }
    final kk = rk.numerator;
    final pn = BigInt.from(rp.numerator), pd = BigInt.from(rp.denominator);
    final qn = pd - pn;
    BigInt term(int i) => _choose(nn, i) * pn.pow(i) * qn.pow(nn - i);
    final den = pd.pow(nn);

    final from = op == BinomialOp.ge ? kk : (op == BinomialOp.eq ? kk : 0);
    final to = op == BinomialOp.le ? kk : (op == BinomialOp.eq ? kk : nn);
    var num = BigInt.zero;
    for (var i = from; i <= to; i++) {
      num += term(i);
    }
    final g = num == BigInt.zero ? BigInt.one : num.gcd(den);
    final rn2 = num ~/ g, rd2 = den ~/ g;
    final prob = _div(num, den);
    final fits = rn2.bitLength < 62 && rd2.bitLength < 62;
    final exact = fits ? Rational(rn2.toInt(), rd2.toInt()) : null;

    final q = Rational(1) - rp;
    final mean = rn * rp;
    final varQ = rn * rp * q;
    final sigma = math.sqrt(varQ.toDouble());
    final pS = _rat(rp), qS = _rat(q);
    final symbol = switch (op) { BinomialOp.eq => '=', BinomialOp.le => r'\leq', BinomialOp.ge => r'\geq' };

    String termLatex(int i) =>
        '\\binom{$nn}{$i}\\,$pS^{$i}\\,$qS^{${nn - i}}';
    final count = to - from + 1;
    final shown = count <= 4
        ? [for (var i = from; i <= to; i++) termLatex(i)].join(' + ')
        : '${termLatex(from)} + ${termLatex(from + 1)} + \\cdots + ${termLatex(to)}';

    final steps = <MathStep>[
      _step(1, 'Distribución', 'X \\sim B($nn,\\,$pS),\\quad q = 1 - p = $qS', 'Éxito con probabilidad p en cada una de las n pruebas independientes.'),
      _step(2, 'Fórmula', 'P(X = k) = \\binom{n}{k}\\,p^{k}\\,q^{\\,n-k}', 'Combinaciones de k éxitos entre n pruebas por la probabilidad de cada una.'),
      _step(3, 'Sustituir', 'P(X $symbol $kk) = $shown',
          op == BinomialOp.eq ? 'Sustituimos n, p, q y k.' : 'Sumamos las probabilidades de cada valor de X incluido.'),
      _step(
        4,
        'Calcular',
        'P(X $symbol $kk) = ${exact == null ? '' : '${ArsenalLatex.rat(exact)} \\approx '}${fmt(prob, 6)}',
        'Operamos con fracciones exactas y damos el valor decimal.',
      ),
      _step(
        5,
        'Media y desviación típica',
        '\\mu = n\\,p = ${_rat(mean)},\\quad \\sigma = \\sqrt{n\\,p\\,q} = \\sqrt{${_rat(varQ)}} \\approx ${fmt(sigma, 4)}',
        'Para B(n, p): μ = n·p y σ = √(n·p·q).',
      ),
    ];
    final res = StepByStepResolution(
      originalInputLatex: 'X \\sim B($nn,\\,$pS)',
      steps: steps,
      exactResultLatex: exact == null || exact.denominator == 1 ? fmt(prob, 6) : ArsenalLatex.rat(exact),
      decimalApproxLatex: fmt(prob, 6),
    );
    return BinomialResult(exact, prob, mean.toDouble(), sigma, res);
  }
}
