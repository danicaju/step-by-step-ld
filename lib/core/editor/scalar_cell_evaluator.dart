import '../../domain/math_engine/core/rational.dart';
import '../../domain/math_engine/solvers/exact/exact_number.dart';
import '../../domain/math_engine/solvers/exact/ext_evaluator.dart';
import '../../domain/math_engine/solvers/exact/ext_expr.dart';
import '../../domain/math_engine/solvers/exact/ext_parser.dart';
import '../../domain/math_engine/solvers/trig_and_angles_solver.dart';
import 'cell_expression_input.dart';

/// Evaluador compartido de las casillas numericas de M9 (matrices), M10 (vectores,
/// triangulos, rectas) y M11 (complejos).
///
/// Una celda puede ser un entero, un decimal, una fraccion simple (`-3/4`) o una expresion
/// real con cualquiera de las 8 familias: `\sqrt[3]{8}`, `\ln(e^2)`, `\cosh(0)`,
/// `\arctan(1)`, `\frac{\sqrt{2}}{2}`, `\pi/4`, `\log_{2}(8)`, `root(3,8)`, `sinh(0)`...
/// Los numeros simples se resuelven sin pasar por el parser para conservar la exactitud
/// racional; el resto usa el motor exacto (`ExNum`).
class ScalarCellEvaluator {
  const ScalarCellEvaluator._();

  static final RegExp _int = RegExp(r'^-?\d+$');
  static final RegExp _decimal = RegExp(r'^-?\d*\.\d+$');
  static final RegExp _fraction = RegExp(r'^(-?\d+)/(-?\d+)$');

  /// Resultado exacto de la celda; lanza [FormatException] o [ExMathError] si no es valida.
  /// Los angulos de las funciones trigonometricas siguen [angle] (por defecto grados).
  static ExNum eval(String raw, {AngleUnit angle = AngleUnit.deg}) {
    var text = CellExpressionInput.closed(raw.trim()).replaceAll(' ', '');
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    if (text.isEmpty || text == '-') throw const FormatException('Celda vacía.');
    final quick = _quick(text);
    if (quick != null) return ExNum.rational(quick);
    try {
      final node = ExtParser().parse(text);
      return ExtEvaluator(angle: angle).eval(node);
    } on ExtUnsupported catch (e) {
      throw FormatException(e.message);
    }
  }

  /// Como [eval], pero `null` si la celda esta vacia.
  static ExNum? tryEval(String raw, {AngleUnit angle = AngleUnit.deg}) {
    final t = raw.trim();
    if (t.isEmpty || t == '-') return null;
    return eval(t, angle: angle);
  }

  /// Valor racional de la celda: exacto si es entero, decimal, fraccion o una expresion que
  /// se simplifica a racional (`\sqrt[3]{8}` = 2, `\ln(e^3)` = 3); aproximado en otro caso.
  static Rational rational(String raw, {AngleUnit angle = AngleUnit.deg}) {
    final v = eval(raw, angle: angle);
    return v.asRational ?? Rational.fromDouble(v.approx, 1000000);
  }

  /// `true` si el valor de la celda es exactamente racional (no se ha aproximado).
  static bool isExactRational(String raw, {AngleUnit angle = AngleUnit.deg}) =>
      eval(raw, angle: angle).asRational != null;

  /// Valor decimal de la celda.
  static double toDouble(String raw, {AngleUnit angle = AngleUnit.deg}) =>
      eval(raw, angle: angle).approx;

  static Rational? _quick(String t) {
    if (_int.hasMatch(t)) {
      final v = int.tryParse(t);
      return v == null ? null : Rational(v);
    }
    if (_decimal.hasMatch(t)) {
      final s = t.startsWith('.') ? '0$t' : (t.startsWith('-.') ? '-0${t.substring(1)}' : t);
      return Rational.fromDecimalString(s);
    }
    final m = _fraction.firstMatch(t);
    if (m != null) {
      final n = int.tryParse(m.group(1)!);
      final d = int.tryParse(m.group(2)!);
      if (n == null || d == null) return null;
      if (d == 0) throw const ExMathError(ExMathError.divByZero);
      return Rational(n, d);
    }
    return null;
  }
}
