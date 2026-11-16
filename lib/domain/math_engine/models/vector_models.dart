import 'dart:math' as math;

import '../core/rational.dart';
import 'step_resolution.dart';

/// Operaciones disponibles en el Modo 12 (Vectores 2D / 3D).
enum VectorOperation {
  modulus('|u| Módulo'),
  dotAndAngle('u·v y Ángulo'),
  crossAndArea('u×v y Área'),
  add('u + v'),
  subtract('u - v');

  final String shortLabel;
  const VectorOperation(this.shortLabel);

  bool get needsSecondVector => this != VectorOperation.modulus;
}

/// Vector exacto en 2D o 3D con componentes racionales ([Rational]).
class RationalVector {
  final int dimension; // 2 o 3
  final Rational x;
  final Rational y;
  final Rational z;

  RationalVector._({
    required this.dimension,
    required this.x,
    required this.y,
    required this.z,
  });

  factory RationalVector.d2(Rational x, Rational y) =>
      RationalVector._(dimension: 2, x: x, y: y, z: Rational(0));

  factory RationalVector.d3(Rational x, Rational y, Rational z) =>
      RationalVector._(dimension: 3, x: x, y: y, z: z);

  factory RationalVector.fromInts(List<int> coords) {
    if (coords.length == 2) {
      return RationalVector.d2(Rational(coords[0]), Rational(coords[1]));
    }
    if (coords.length == 3) {
      return RationalVector.d3(
        Rational(coords[0]),
        Rational(coords[1]),
        Rational(coords[2]),
      );
    }
    throw const FormatException('Un vector debe tener 2 o 3 coordenadas.');
  }

  factory RationalVector.fromRationals(List<Rational> coords) {
    if (coords.length == 2) {
      return RationalVector.d2(coords[0], coords[1]);
    }
    if (coords.length == 3) {
      return RationalVector.d3(coords[0], coords[1], coords[2]);
    }
    throw const FormatException('Un vector debe tener 2 o 3 coordenadas.');
  }

  bool get isZero => x.isZero && y.isZero && (dimension == 2 || z.isZero);

  Rational normSquared() => x * x + y * y + (dimension == 3 ? z * z : Rational(0));

  double normDouble() => math.sqrt(normSquared().toDouble());

  Rational dot(RationalVector other) =>
      x * other.x + y * other.y + z * other.z;

  RationalVector cross(RationalVector other) => RationalVector.d3(
        y * other.z - z * other.y,
        -(x * other.z - z * other.x),
        x * other.y - y * other.x,
      );

  RationalVector operator +(RationalVector other) {
    final dim = math.max(dimension, other.dimension);
    return dim == 2
        ? RationalVector.d2(x + other.x, y + other.y)
        : RationalVector.d3(x + other.x, y + other.y, z + other.z);
  }

  RationalVector operator -(RationalVector other) {
    final dim = math.max(dimension, other.dimension);
    return dim == 2
        ? RationalVector.d2(x - other.x, y - other.y)
        : RationalVector.d3(x - other.x, y - other.y, z - other.z);
  }

  String toLatex() {
    if (dimension == 2) {
      return '\\left(${x.toLatex()},\\; ${y.toLatex()}\\right)';
    }
    return '\\left(${x.toLatex()},\\; ${y.toLatex()},\\; ${z.toLatex()}\\right)';
  }

  /// Notación compacta `(x, y, z)` sin delimitadores altos para comparaciones y resúmenes.
  String toCompactLatex() {
    if (dimension == 2) {
      return '(${x.toLatex()}, ${y.toLatex()})';
    }
    return '(${x.toLatex()}, ${y.toLatex()}, ${z.toLatex()})';
  }

  @override
  bool operator ==(Object other) =>
      other is RationalVector &&
      other.dimension == dimension &&
      other.x == x &&
      other.y == y &&
      other.z == z;

  @override
  int get hashCode => Object.hash(dimension, x, y, z);
}

/// Resultado estructurado de operaciones vectoriales para facilitar aserciones y tutoría.
class VectorAnalysisResult {
  final Rational? dotValue;
  final RationalVector? resultVector;
  final double? angleDegrees;
  final String exactNormLatex;
  final StepByStepResolution resolution;

  const VectorAnalysisResult({
    this.dotValue,
    this.resultVector,
    this.angleDegrees,
    this.exactNormLatex = '',
    required this.resolution,
  });
}
