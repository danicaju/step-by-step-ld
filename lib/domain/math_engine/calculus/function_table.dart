import '../core/rational.dart';
import 'function_numeric.dart';

/// Fila de la tabla `x | f(x) | g(x)`; `null` = fuera del dominio (`Error / AV`).
class TableRowData {
  final Rational x;
  final double? f;
  final double? g;
  const TableRowData(this.x, this.f, this.g);
}

/// Error de configuracion de la tabla (paso 0, rango incoherente, demasiadas filas).
class TableConfigException implements Exception {
  final String message;
  const TableConfigException(this.message);
  @override
  String toString() => message;
}

/// Modo TABLE de la ClassWiz: valores de f(x) (y g(x) opcional) sin lanzar excepciones
/// cuando x esta fuera del dominio.
class FunctionTable {
  const FunctionTable._();

  static const int maxRows = 30;
  static const String errorText = 'Error / AV';

  /// Cantidad numerica: entero, decimal o fraccion `a/b`.
  static Rational parseNumber(String text, String name) {
    final s = text.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (s.isEmpty || s == '-' || s == '.' || s == '/') {
      throw TableConfigException('Sintaxis incompleta: Completa $name.');
    }
    try {
      final parts = s.split('/');
      if (parts.length == 2) {
        final d = Rational.fromDecimalString(parts[1]);
        if (d.isZero) throw const TableConfigException('Math ERROR: Denominador 0.');
        return Rational.fromDecimalString(parts[0]) / d;
      }
      if (parts.length > 2) throw const FormatException('Fracción no válida.');
      return Rational.fromDecimalString(s);
    } on TableConfigException {
      rethrow;
    } on Object {
      throw TableConfigException('Sintaxis incompleta: $name no es valido.');
    }
  }

  static List<TableRowData> build({
    required FunctionModel f,
    FunctionModel? g,
    required Rational start,
    required Rational end,
    required Rational step,
  }) {
    if (step.isZero) throw const TableConfigException('Math ERROR: El paso no puede ser 0.');
    final span = end - start;
    if (!span.isZero && span.isNegative != step.isNegative) {
      throw const TableConfigException('Math ERROR: El paso no lleva de Inicio a Fin.');
    }
    final count = (span / step).toDouble().floor() + 1;
    if (count > maxRows) {
      throw TableConfigException('Math ERROR: La tabla admite como maximo $maxRows filas (hay $count).');
    }
    return [
      for (var i = 0; i < count; i++)
        () {
          final x = start + step * Rational(i);
          final xd = x.toDouble();
          return TableRowData(x, f.at(xd), g?.at(xd));
        }(),
    ];
  }

  /// Texto de una celda: numero con coma decimal o [errorText].
  static String cell(double? v) {
    if (v == null) return errorText;
    if (v == v.roundToDouble() && v.abs() < 1e12) return v.toInt().toString();
    var s = v.toStringAsFixed(5);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    return s.replaceAll('.', ',');
  }

  static String xText(Rational x) => x.isInteger
      ? '${x.numerator}'
      : (x.denominator <= 100 && 100 % x.denominator == 0 || x.denominator <= 1000 && 1000 % x.denominator == 0
          ? cell(x.toDouble())
          : '${x.numerator}/${x.denominator}');
}
