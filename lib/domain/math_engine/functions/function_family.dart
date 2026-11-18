import '../calculus/domain_solver.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/equations/eq_poly.dart';

/// Familias de funciones de ESO y Bachillerato que M5 estudia por separado.
enum FunctionFamily {
  constant,
  linear,
  quadratic,
  cubic,
  rational,
  radicalEven,
  radicalOdd,
  exponential,
  logarithmic,
  sine,
  cosine,
  tangent,
  unknown;

  /// Tipo del desplegable `Tipo` de M5 (2..8; 1 = Funcion libre) al que pertenece.
  int get kind => switch (this) {
        constant || linear => 2,
        quadratic => 3,
        cubic => 4,
        rational => 5,
        radicalEven || radicalOdd => 6,
        exponential || logarithmic => 7,
        sine || cosine || tangent => 8,
        unknown => 1,
      };

  bool get isPolynomial => this == constant || this == linear || this == quadratic || this == cubic;
  bool get isTrig => this == sine || this == cosine || this == tangent;
}

/// Nombre didactico de cada tipo del desplegable (indice 0..7 = teclas 1..8).
const List<String> kM5KindLabels = [
  'Función libre f(x)',
  'Constante / Lineal',
  'Cuadrática',
  'Cúbica',
  'Racional P(x)/Q(x)',
  'Radical √ / ³√',
  'Exponencial / Log',
  'Trigonométrica',
];

/// Forma `A * g(B x + C) + D` (radical, exponencial, logaritmo, trig) o polinomio / racional.
class FamilyInfo {
  final FunctionFamily family;

  /// Polinomio completo (familias polinomicas) o numerador (racional).
  final Poly poly;

  /// Denominador (solo racional).
  final Poly den;

  /// Argumento interno `B x + C` como polinomio de grado 1 (familias con funcion elemental).
  final Poly inner;
  final Rational a; // factor externo A
  final Rational d; // desplazamiento vertical D

  /// Base de la exponencial / logaritmo (`null` = e para `ln` y `e^x`).
  final double? base;
  final String baseLatex;

  FamilyInfo(
    this.family, {
    this.poly = const {},
    this.den = const {},
    this.inner = const {},
    Rational? a,
    Rational? d,
    this.base,
    this.baseLatex = 'e',
  })  : a = a ?? Rational(1),
        d = d ?? Rational(0);

  Rational get b => PolyOps.coeff(inner, 1);
  Rational get c => PolyOps.coeff(inner, 0);
}

/// Decimal LaTeX con coma decimal protegida (`1{,}25`).
String fdec(double v) {
  final t = NumLatex.decimal(v);
  return t.contains('{,}') ? t : t.replaceAll(',', '{,}');
}

/// `pprox 1{,}25`, o el entero exacto si v lo es.
String fapx(double v) => (v - v.roundToDouble()).abs() < 1e-9 ? fdec(v.roundToDouble()) : '\\approx ${fdec(v)}';

MathStep fstep(String title, String latex, String note, {String? warning}) =>
    MathStep(index: 0, shortTitle: title, latexExpression: latex, pedagogicalNote: note, warningTrick: warning);

/// Coeficiente con signo como LaTeX: `2`, `-\frac{1}{2}`.
String rl(Rational r) => domainRationalLatex(r);

/// Numera los pasos como hace `LimitsAsymptotesSolver` (`1. titulo`).
List<MathStep> numberSteps(List<MathStep> raw) => [
      for (var i = 0; i < raw.length; i++)
        MathStep(
          index: i + 1,
          shortTitle: '${i + 1}. ${raw[i].shortTitle}',
          latexExpression: raw[i].latexExpression,
          pedagogicalNote: raw[i].pedagogicalNote,
          warningTrick: raw[i].warningTrick,
        ),
    ];

/// `= 3` si v es entero, `\approx 1{,}26` si no (para ir tras un `f(0)`).
String feq(double v) => (v - v.roundToDouble()).abs() < 1e-9 ? '= ${fdec(v.roundToDouble())}' : '\\approx ${fdec(v)}';
