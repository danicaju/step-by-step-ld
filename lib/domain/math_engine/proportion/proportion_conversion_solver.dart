import '../arithmetic/casio_iberia_arsenal.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

/// Reglas de 3 (directa e inversa) paso a paso.
class ProportionSolver {
  const ProportionSolver._();

  /// Lee una cantidad: entero, decimal (`2.5` / `2,5`) o fraccion `a/b`.
  static Rational parseQuantity(String text) {
    final s = text.trim().replaceAll(' ', '');
    if (s.isEmpty || s == '-' || s == '/' || s == '.') {
      throw const ArsenalException('Sintaxis incompleta: completa todas las casillas.');
    }
    try {
      final slash = s.split('/');
      if (slash.length == 2) {
        final a = Rational.fromDecimalString(slash[0]);
        final b = Rational.fromDecimalString(slash[1]);
        if (b.isZero) throw const ArsenalException('Math ERROR: denominador 0.');
        return a / b;
      }
      if (slash.length > 2) throw const FormatException('fraccion');
      return Rational.fromDecimalString(s);
    } on ArsenalException {
      rethrow;
    } on Object {
      throw const ArsenalException('Sintaxis incompleta: cantidad no valida.');
    }
  }

  static String _table(Rational a, Rational b, Rational c) =>
      '\\begin{array}{ccc} ${ArsenalLatex.rat(a)} & \\to & ${ArsenalLatex.rat(b)} \\\\ '
      '${ArsenalLatex.rat(c)} & \\to & x \\end{array}';

  /// Regla de 3 directa: `A -> B`, `C -> x`, `x = B*C/A`.
  static StepByStepResolution direct(Rational a, Rational b, Rational c) {
    if (a.isZero) throw const ArsenalException('Math ERROR: A no puede ser 0.');
    final x = (b * c) / a;
    return _build(
      title: 'Regla de 3 directa',
      table: _table(a, b, c),
      relation: '\\frac{${ArsenalLatex.rat(a)}}{${ArsenalLatex.rat(b)}} = \\frac{${ArsenalLatex.rat(c)}}{x}',
      relationNote: 'Magnitudes directamente proporcionales: si una aumenta, la otra tambien; el cociente se mantiene.',
      formula: 'x = \\frac{B \\cdot C}{A}',
      formulaNote: 'Despeje cruzado: x = (B por C) entre A.',
      substituted: 'x = \\frac{${ArsenalLatex.ratParen(b)} \\cdot ${ArsenalLatex.ratParen(c)}}{${ArsenalLatex.ratParen(a)}}',
      x: x,
    );
  }

  /// Regla de 3 inversa: `A -> B`, `C -> x`, `x = A*B/C`.
  static StepByStepResolution inverse(Rational a, Rational b, Rational c) {
    if (c.isZero) throw const ArsenalException('Math ERROR: C no puede ser 0.');
    final x = (a * b) / c;
    return _build(
      title: 'Regla de 3 inversa',
      table: _table(a, b, c),
      relation: '${ArsenalLatex.ratParen(a)} \\cdot ${ArsenalLatex.ratParen(b)} = ${ArsenalLatex.ratParen(c)} \\cdot x',
      relationNote: 'Magnitudes inversamente proporcionales: si una aumenta, la otra disminuye; el producto se mantiene.',
      formula: 'x = \\frac{A \\cdot B}{C}',
      formulaNote: 'Despeje paralelo: x = (A por B) entre C.',
      substituted: 'x = \\frac{${ArsenalLatex.ratParen(a)} \\cdot ${ArsenalLatex.ratParen(b)}}{${ArsenalLatex.ratParen(c)}}',
      x: x,
    );
  }

  static StepByStepResolution _build({
    required String title,
    required String table,
    required String relation,
    required String relationNote,
    required String formula,
    required String formulaNote,
    required String substituted,
    required Rational x,
  }) {
    final res = ArsenalLatex.rat(x);
    return StepByStepResolution(
      originalInputLatex: table,
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Planteamiento de magnitudes',
          latexExpression: table,
          pedagogicalNote: 'Colocamos los datos: A corresponde a B y C corresponde a la incognita x.',
        ),
        MathStep(index: 2, shortTitle: title, latexExpression: relation, pedagogicalNote: relationNote),
        MathStep(index: 3, shortTitle: 'Despejar x', latexExpression: formula, pedagogicalNote: formulaNote),
        MathStep(
          index: 4,
          shortTitle: 'Sustituir',
          latexExpression: substituted,
          pedagogicalNote: 'Reemplazamos A, B y C por sus valores.',
        ),
        MathStep(
          index: 5,
          shortTitle: 'Simplificar',
          latexExpression: 'x = $res',
          pedagogicalNote: 'Operamos y simplificamos hasta la fraccion irreducible.',
        ),
      ],
      exactResultLatex: res,
      decimalApproxLatex: x.toDecimalLatex(),
    );
  }
}

/// Unidad simple de una magnitud con su factor a la unidad base.
class SimpleUnit {
  final String id;
  final String latex;
  final String dim;
  final Rational toBase; // 1 unidad = toBase unidades base

  const SimpleUnit(this.id, this.latex, this.dim, this.toBase);
}

/// Unidad (simple o compuesta `num/den^p`) del catalogo de conversion.
class ConversionUnit {
  final String label;
  final SimpleUnit num;
  final SimpleUnit? den;
  final int denPow;

  const ConversionUnit(this.label, this.num, [this.den, this.denPow = 1]);

  String get dimension => den == null ? num.dim : '${num.dim}/${den!.dim}^$denPow';

  String get latex {
    if (den == null) return '\\mathrm{${num.id}}';
    final d = denPow == 1 ? '\\mathrm{${den!.id}}' : '\\mathrm{${den!.id}}^{$denPow}';
    return '\\frac{\\mathrm{${num.id}}}{$d}';
  }
}

/// Catalogo de unidades (longitud, masa, tiempo, velocidad, densidad, presion, energia).
class ConversionCatalog {
  const ConversionCatalog._();

  static final _km = SimpleUnit('km', 'km', 'longitud', Rational(1000));
  static final _m = SimpleUnit('m', 'm', 'longitud', Rational(1));
  static final _dm = SimpleUnit('dm', 'dm', 'longitud', Rational(1, 10));
  static final _cm = SimpleUnit('cm', 'cm', 'longitud', Rational(1, 100));
  static final _mm = SimpleUnit('mm', 'mm', 'longitud', Rational(1, 1000));
  static final _t = SimpleUnit('t', 't', 'masa', Rational(1000));
  static final _kg = SimpleUnit('kg', 'kg', 'masa', Rational(1));
  static final _g = SimpleUnit('g', 'g', 'masa', Rational(1, 1000));
  static final _mg = SimpleUnit('mg', 'mg', 'masa', Rational(1, 1000000));
  static final _d = SimpleUnit('d', 'd', 'tiempo', Rational(86400));
  static final _h = SimpleUnit('h', 'h', 'tiempo', Rational(3600));
  static final _min = SimpleUnit('min', 'min', 'tiempo', Rational(60));
  static final _s = SimpleUnit('s', 's', 'tiempo', Rational(1));
  static final _ms = SimpleUnit('ms', 'ms', 'tiempo', Rational(1, 1000));
  static final _atm = SimpleUnit('atm', 'atm', 'presion', Rational(101325));
  static final _bar = SimpleUnit('bar', 'bar', 'presion', Rational(100000));
  static final _kpa = SimpleUnit('kPa', 'kPa', 'presion', Rational(1000));
  static final _pa = SimpleUnit('Pa', 'Pa', 'presion', Rational(1));
  static final _kcal = SimpleUnit('kcal', 'kcal', 'energia', Rational(4184));
  static final _kj = SimpleUnit('kJ', 'kJ', 'energia', Rational(1000));
  static final _cal = SimpleUnit('cal', 'cal', 'energia', Rational(523, 125));
  static final _j = SimpleUnit('J', 'J', 'energia', Rational(1));

  static final Map<String, SimpleUnit> baseOf = {
    'longitud': _m,
    'masa': _kg,
    'tiempo': _s,
    'presion': _pa,
    'energia': _j,
  };

  static final List<ConversionUnit> units = [
    ConversionUnit('km', _km), ConversionUnit('m', _m), ConversionUnit('dm', _dm),
    ConversionUnit('cm', _cm), ConversionUnit('mm', _mm),
    ConversionUnit('t', _t), ConversionUnit('kg', _kg), ConversionUnit('g', _g), ConversionUnit('mg', _mg),
    ConversionUnit('d', _d), ConversionUnit('h', _h), ConversionUnit('min', _min),
    ConversionUnit('s', _s), ConversionUnit('ms', _ms),
    ConversionUnit('km/h', _km, _h), ConversionUnit('m/s', _m, _s), ConversionUnit('cm/s', _cm, _s),
    ConversionUnit('g/cm3', _g, _cm, 3), ConversionUnit('kg/m3', _kg, _m, 3), ConversionUnit('kg/dm3', _kg, _dm, 3),
    ConversionUnit('atm', _atm), ConversionUnit('bar', _bar), ConversionUnit('kPa', _kpa), ConversionUnit('Pa', _pa),
    ConversionUnit('kcal', _kcal), ConversionUnit('cal', _cal), ConversionUnit('kJ', _kj), ConversionUnit('J', _j),
  ];

  static ConversionUnit byLabel(String label) => units.firstWhere((u) => u.label == label);
}

/// Una fraccion unitaria `top/bottom` (cantidades enteras y unidades).
class _UnitFraction {
  final int topAmt;
  final SimpleUnit topUnit;
  final int botAmt;
  final SimpleUnit botUnit;
  const _UnitFraction(this.topAmt, this.topUnit, this.botAmt, this.botUnit);
}

/// Factores de conversion paso a paso con cancelacion de unidades.
class ConversionFactorSolver {
  const ConversionFactorSolver._();

  static const String _grey = '#7A8A7E';

  static String _g(String s, bool cancelled) => cancelled ? '\\textcolor{$_grey}{$s}' : s;

  /// Cadena de fracciones unitarias de [from] a [to] pasando por la unidad base.
  static List<_UnitFraction> _chain(SimpleUnit from, SimpleUnit to) {
    if (from.id == to.id) return const [];
    final base = ConversionCatalog.baseOf[from.dim]!;
    final out = <_UnitFraction>[];
    if (from.id != base.id) {
      out.add(_UnitFraction(from.toBase.numerator, base, from.toBase.denominator, from));
    }
    if (to.id != base.id) {
      out.add(_UnitFraction(to.toBase.denominator, to, to.toBase.numerator, base));
    }
    return out;
  }

  /// Fraccion dibujada; [flip] la invierte (componente del denominador) y [pow] la eleva.
  static String _draw(_UnitFraction f, {required bool flip, required bool cancelTop, required bool cancelBot, int pow = 1}) {
    final top = flip ? f.botAmt : f.topAmt;
    final topU = flip ? f.botUnit : f.topUnit;
    final bot = flip ? f.topAmt : f.botAmt;
    final botU = flip ? f.topUnit : f.botUnit;
    final body = '\\frac{${_g('$top\\,\\mathrm{${topU.id}}', cancelTop)}}{${_g('$bot\\,\\mathrm{${botU.id}}', cancelBot)}}';
    return pow == 1 ? body : '\\left($body\\right)^{$pow}';
  }

  static StepByStepResolution solve(Rational value, ConversionUnit from, ConversionUnit to) {
    if (from.dimension != to.dimension) {
      throw const ArsenalException('Math ERROR: unidades de distinta magnitud.');
    }
    final numChain = _chain(from.num, to.num);
    final denChain = from.den == null ? const <_UnitFraction>[] : _chain(from.den!, to.den!);
    final p = from.denPow;

    // Fracciones dibujadas con las unidades que se cancelan en gris.
    final drawn = <String>[];
    for (var i = 0; i < numChain.length; i++) {
      drawn.add(_draw(numChain[i], flip: false, cancelTop: i < numChain.length - 1, cancelBot: true));
    }
    for (var i = 0; i < denChain.length; i++) {
      drawn.add(_draw(denChain[i], flip: true, cancelTop: true, cancelBot: i < denChain.length - 1, pow: p));
    }

    final startUnits = from.den == null
        ? '\\mathrm{${from.num.id}}'
        : '\\frac{${_g('\\mathrm{${from.num.id}}', numChain.isNotEmpty)}}{${_g(from.denPow == 1 ? '\\mathrm{${from.den!.id}}' : '\\mathrm{${from.den!.id}}^{$p}', denChain.isNotEmpty)}}';
    final startShown = from.den == null ? _g(startUnits, numChain.isNotEmpty) : startUnits;

    // Numeros: tops y bottoms.
    final tops = <String>[];
    final bots = <String>[];
    var ratio = Rational(1);
    for (final f in numChain) {
      tops.add('${f.topAmt}');
      bots.add('${f.botAmt}');
      ratio = ratio * Rational(f.topAmt, f.botAmt);
    }
    for (final f in denChain) {
      tops.add(p == 1 ? '${f.botAmt}' : '${f.botAmt}^{$p}');
      bots.add(p == 1 ? '${f.topAmt}' : '${f.topAmt}^{$p}');
      ratio = ratio * Rational(f.botAmt, f.topAmt).pow(p);
    }
    final y = value * ratio;
    final v = ArsenalLatex.ratParen(value);
    final topLatex = tops.isEmpty ? '1' : tops.join(' \\cdot ');
    final botLatex = bots.isEmpty ? '1' : bots.join(' \\cdot ');
    final toLatex = to.latex;

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Dato y unidad de destino',
        latexExpression: '${ArsenalLatex.rat(value)}\\;${from.latex} \\to ?\\;$toLatex',
        pedagogicalNote: 'Queremos pasar de ${from.label} a ${to.label} multiplicando por fracciones que valen 1.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Fracciones unitarias',
        latexExpression: drawn.isEmpty
            ? '${ArsenalLatex.rat(value)}\\;${from.latex}'
            : '$v\\;$startShown \\cdot ${drawn.join(' \\cdot ')}',
        pedagogicalNote: drawn.isEmpty
            ? 'Las unidades ya coinciden: no hay que convertir.'
            : 'Cada fraccion vale 1 (numerador y denominador son la misma cantidad). Las unidades en gris se cancelan.',
        warningTrick: 'Coloca siempre la unidad que quieres eliminar en el lado contrario al que ya tiene el dato.',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Cancelar unidades',
        latexExpression: '$v \\cdot \\frac{$topLatex}{$botLatex}\\;$toLatex',
        pedagogicalNote: 'Tras cancelar, solo queda la unidad de destino y las cantidades numericas.',
      ),
      MathStep(
        index: 4,
        shortTitle: 'Resultado',
        latexExpression: '${ArsenalLatex.rat(value)}\\;${from.latex} = ${ArsenalLatex.rat(y)}\\;$toLatex',
        pedagogicalNote: 'Multiplicamos y simplificamos.',
      ),
    ];
    return StepByStepResolution(
      originalInputLatex: '${ArsenalLatex.rat(value)}\\;${from.latex}',
      steps: steps,
      exactResultLatex: '${ArsenalLatex.rat(y)}\\;$toLatex',
      decimalApproxLatex: '${y.toDecimalLatex()}\\;$toLatex',
    );
  }
}
