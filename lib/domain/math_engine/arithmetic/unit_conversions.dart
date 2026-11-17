import '../core/rational.dart';
import '../models/step_resolution.dart';

/// Conversion clasica del catalogo CONV: `y = x * factor + offset` (exacta).
class UnitConversion {
  final String label; // `km/h►m/s` (menu LCD)
  final String fromLatex;
  final String toLatex;
  final Rational factor;
  final Rational offset;

  const UnitConversion(this.label, this.fromLatex, this.toLatex, this.factor, this.offset);

  Rational apply(Rational x) => (x * factor + offset).simplify();

  /// Resolucion paso a paso de convertir [x].
  StepByStepResolution solve(Rational x) {
    final y = apply(x);
    final hasOffset = !offset.isZero;
    final op = hasOffset
        ? '${x.toLatex()} ${offset.isNegative ? '-' : '+'} ${(offset.isNegative ? -offset : offset).toDecimalLatex()}'
        : '${x.toLatex()} \\cdot ${factor.toLatex()}';
    return StepByStepResolution(
      originalInputLatex: '${x.toLatex()}\\;$fromLatex',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Conversion $label',
          latexExpression: '${x.toLatex()}\\;$fromLatex \\to ?\\;$toLatex',
          pedagogicalNote: hasOffset
              ? 'Las escalas de temperatura se convierten sumando un desplazamiento.'
              : 'Multiplicamos por el factor de conversion exacto.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Resultado',
          latexExpression: '$op = ${y.toLatex()}\\;$toLatex',
          pedagogicalNote: 'Valor convertido a la unidad de destino.',
        ),
      ],
      exactResultLatex: y.toLatex(),
      decimalApproxLatex: y.toDecimalLatex(),
    );
  }
}

class UnitConversions {
  const UnitConversions._();

  static final List<UnitConversion> all = [
    UnitConversion('km/h►m/s', r'\mathrm{km/h}', r'\mathrm{m/s}', Rational(5, 18), Rational(0)),
    UnitConversion('m/s►km/h', r'\mathrm{m/s}', r'\mathrm{km/h}', Rational(18, 5), Rational(0)),
    UnitConversion('atm►Pa', r'\mathrm{atm}', r'\mathrm{Pa}', Rational(101325), Rational(0)),
    UnitConversion('Pa►atm', r'\mathrm{Pa}', r'\mathrm{atm}', Rational(1, 101325), Rational(0)),
    UnitConversion('cal►J', r'\mathrm{cal}', r'\mathrm{J}', Rational(523, 125), Rational(0)),
    UnitConversion('J►cal', r'\mathrm{J}', r'\mathrm{cal}', Rational(125, 523), Rational(0)),
    UnitConversion('in►cm', r'\mathrm{in}', r'\mathrm{cm}', Rational(127, 50), Rational(0)),
    UnitConversion('cm►in', r'\mathrm{cm}', r'\mathrm{in}', Rational(50, 127), Rational(0)),
    UnitConversion('°C►K', r'^{\circ}\mathrm{C}', r'\mathrm{K}', Rational(1), Rational(27315, 100)),
    UnitConversion('K►°C', r'\mathrm{K}', r'^{\circ}\mathrm{C}', Rational(1), Rational(-27315, 100)),
  ];
}
