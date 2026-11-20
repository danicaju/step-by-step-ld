import '../core/rational.dart';
import 'step_resolution.dart';

/// Operaciones disponibles en el Modo 13 (Números Complejos: Binómica ⬄ Polar).
enum ComplexOperation {
  add('z₁ + z₂'),
  subtract('z₁ - z₂'),
  multiply('z₁ · z₂'),
  divide('z₁ / z₂'),
  toPolar('a+bi → r_α'),
  fromPolar('r_α → a+bi'),
  powerOfI('iⁿ (potencia)'),
  expZ('e^z (Euler)'),
  lnZ('Ln z');

  final String shortLabel;
  const ComplexOperation(this.shortLabel);

  bool get needsSecondComplex =>
      this == ComplexOperation.add ||
      this == ComplexOperation.subtract ||
      this == ComplexOperation.multiply ||
      this == ComplexOperation.divide;

  /// Indice de la ultima celda editable (potencia de i: solo el exponente n).
  int get lastCellIndex => needsSecondComplex ? 3 : (this == ComplexOperation.powerOfI ? 0 : 1);
}

/// Número complejo exacto en forma binómica `a + bi` con coeficientes [Rational].
class RationalComplex {
  final Rational real;
  final Rational imag;
  Rational get imaginary => imag;

  const RationalComplex(this.real, this.imag);

  factory RationalComplex.fromInts(int real, int imag) =>
      RationalComplex(Rational(real), Rational(imag));

  bool get isZero => real.isZero && imag.isZero;

  RationalComplex conjugate() => RationalComplex(real, -imag);

  Rational normSquared() => real * real + imag * imag;

  RationalComplex operator +(RationalComplex other) =>
      RationalComplex(real + other.real, imag + other.imag);

  RationalComplex operator -(RationalComplex other) =>
      RationalComplex(real - other.real, imag - other.imag);

  RationalComplex operator *(RationalComplex other) => RationalComplex(
        real * other.real - imag * other.imag,
        real * other.imag + imag * other.real,
      );

  RationalComplex operator /(RationalComplex other) {
    final denom = other.normSquared();
    if (denom.isZero) {
      throw const FormatException('No se puede dividir entre 0 + 0i.');
    }
    final numProd = this * other.conjugate();
    return RationalComplex(numProd.real / denom, numProd.imag / denom);
  }

  /// Representación humana en LaTeX sin `0i`, `1i` ni signos dobles `+ -`.
  String toLatex() {
    if (real.isZero && imag.isZero) return '0';
    final imagPart = _formatImaginaryCore(imag.abs());
    if (real.isZero) {
      return imag.isNegative ? '-$imagPart' : imagPart;
    }
    if (imag.isZero) {
      return real.toLatex();
    }
    final sign = imag.isNegative ? ' - ' : ' + ';
    return '${real.toLatex()}$sign$imagPart';
  }

  String toDecimalLatex() {
    if (real.isZero && imag.isZero) return '0';
    final absIm = imag.abs();
    final imStr = absIm == Rational(1) ? 'i' : '${absIm.toDecimalLatex()}i';
    if (real.isZero) {
      return imag.isNegative ? '-$imStr' : imStr;
    }
    if (imag.isZero) return real.toDecimalLatex();
    final sign = imag.isNegative ? ' - ' : ' + ';
    return '${real.toDecimalLatex()}$sign$imStr';
  }

  static String _formatImaginaryCore(Rational absCoeff) {
    if (absCoeff == Rational(1)) return 'i';
    return '${absCoeff.toLatex()}i';
  }

  @override
  bool operator ==(Object other) =>
      other is RationalComplex && other.real == real && other.imag == imag;

  @override
  int get hashCode => Object.hash(real, imag);
}

/// Resultado estructurado para operaciones con números complejos.
class ComplexResult {
  final RationalComplex? binomial;
  final String? polarModulusLatex;
  final double? polarAngleDegrees;
  final StepByStepResolution resolution;

  const ComplexResult({
    this.binomial,
    this.polarModulusLatex,
    this.polarAngleDegrees,
    required this.resolution,
  });
}
