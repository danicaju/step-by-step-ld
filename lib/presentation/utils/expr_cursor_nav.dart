import '../../domain/math_engine/parser/expression_parser.dart';

/// Navegacion con cursor dentro de una expresion cruda (`raw`, `pos`): ◀ ▶ saltan
/// plantillas (fracciones, potencias, mcm/mcd, raices) y ▲ ▼ pasan de numerador a
/// denominador (o salen de un exponente). Compartida por M4 (formularios) y M12.
class ExprCursorNav {
  const ExprCursorNav._();

  static (String raw, int cursor) left(String raw, int pos) =>
      ExpressionParser.handleTwoSlotLeftArrow(raw, pos) ?? (raw, ExpressionParser.stepCursorLeft(raw, pos));

  static (String raw, int cursor) right(String raw, int pos) =>
      ExpressionParser.handleFractionRightArrow(raw, pos) ??
      ExpressionParser.handlePowerRightArrow(raw, pos) ??
      ExpressionParser.handleMcmMcdRightArrow(raw, pos) ??
      ExpressionParser.handleTwoSlotRightArrow(raw, pos) ??
      ExpressionParser.handleStructuredBlockRightArrow(raw, pos) ??
      (raw, ExpressionParser.stepCursorRight(raw, pos));

  /// Nueva posicion al subir/bajar dentro de la expresion; `null` si no hay movimiento interno.
  static int? vertical(String raw, int pos, {required bool up}) =>
      ExpressionParser.jumpFractionUpDown(raw, pos, isUp: up);
}
