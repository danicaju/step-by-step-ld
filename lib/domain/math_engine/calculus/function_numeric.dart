import '../parser/expression_parser.dart';
import '../solvers/calculus/sym_build.dart';
import '../solvers/exact/ext_expr.dart';
import '../solvers/exact/ext_parser.dart';
import '../solvers/trig_and_angles_solver.dart';

/// Funcion f(x) tipada (AST extendido) con evaluacion numerica que nunca lanza.
///
/// Lo comparten el motor de limites, el visor grafico y la tabla TABLE.
class FunctionModel {
  final String raw;
  final XNode node;

  /// Unidad angular con la que se evaluan sin/cos/tan (DEG o RAD de la calculadora).
  final AngleUnit angle;

  const FunctionModel._(this.raw, this.node, [this.angle = AngleUnit.rad]);

  /// Misma funcion evaluada con otra unidad angular.
  FunctionModel withAngle(AngleUnit unit) => FunctionModel._(raw, node, unit);

  /// Parsea `raw` (con `x`). Lanza `FormatException` si la sintaxis no es valida.
  factory FunctionModel.parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text == '0') {
      throw const FormatException('Escribe una funcion f(x).');
    }
    final fin = ExpressionParser.finalizeForEvaluation(text);
    try {
      return FunctionModel._(text, ExtParser().parse(fin));
    } on ExtUnsupported catch (e) {
      throw FormatException('Funcion no soportada: ${e.message}');
    }
  }

  /// Valor de f en [x]; `null` si x esta fuera del dominio o el resultado no es finito.
  double? at(double x) => Sx.numAt(node, x, angle: angle);

  String get latex => node.latex();
}

/// Un punto de la curva en coordenadas matematicas.
typedef CurvePoint = (double x, double y);

/// Muestreo en ramas continuas: corta en discontinuidades y asintotas verticales.
class FunctionSampler {
  const FunctionSampler._();

  /// Ramas continuas de [f] en `[xMin, xMax]` con [n] muestras.
  ///
  /// Se inicia una rama nueva cuando f no esta definida, cuando el intervalo entre
  /// dos muestras contiene un valor de [cuts] (asintota vertical) o cuando hay un
  /// salto de signo superior a [jump] (p. ej. `tan x`): nunca une +inf con -inf.
  static List<List<CurvePoint>> branches(
    double? Function(double) f,
    double xMin,
    double xMax, {
    int n = 600,
    List<double> cuts = const [],
    double jump = 50,
  }) {
    final out = <List<CurvePoint>>[];
    var cur = <CurvePoint>[];
    void close() {
      if (cur.length > 1) out.add(cur);
      cur = <CurvePoint>[];
    }

    double? prevY;
    double prevX = xMin;
    for (var i = 0; i <= n; i++) {
      final x = xMin + (xMax - xMin) * i / n;
      final y = f(x);
      if (y == null) {
        close();
        prevY = null;
        prevX = x;
        continue;
      }
      if (prevY != null) {
        final crosses = cuts.any((c) => c > prevX && c < x);
        final signFlip = (prevY < 0) != (y < 0);
        final bigJump = (y - prevY).abs() > jump && signFlip;
        if (crosses || bigJump) close();
      }
      cur.add((x, y));
      prevY = y;
      prevX = x;
    }
    close();
    return out;
  }
}
