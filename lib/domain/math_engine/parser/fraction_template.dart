import 'balanced_scan.dart';
import 'slash_fraction_converter.dart';

/// Plantilla de fraccion explicita `(num)/(den)`: los parentesis son los
/// contenedores `{numerador}` y `{denominador}`, de modo que `+`/`-` nunca
/// rompen el agrupamiento.
class FractionTemplate {
  const FractionTemplate._();

  static bool _hasOuterGroup(String s) =>
      SlashFractionConverter.hasOuterBalancedParens(s);

  /// Tecla a/b. Envuelve el operando previo (cursor en el denominador) o
  /// abre `()/()` con el cursor en el numerador.
  static (String raw, int cursor) insert(String raw, int cursor) {
    if (raw == '0' || raw.trim().isEmpty) return ('()/()', 1);
    final cur = cursor.clamp(0, raw.length);
    final numStart = SlashFractionConverter.scanNumeratorLeft(raw, cur, '');
    final before = raw.substring(0, cur);
    final operand = (numStart < cur && !before.endsWith(' '))
        ? raw.substring(numStart, cur)
        : '';
    final after = raw.substring(cur);
    if (operand.isEmpty) {
      return ('$before()/()$after', cur + 1);
    }
    final head = raw.substring(0, numStart);
    final num = _hasOuterGroup(operand) ? operand : '($operand)';
    final built = '$head$num/()';
    return ('$built$after', built.length - 1);
  }

  /// Indice del `(` que abre el grupo cuyo cierre esta en [closeIdx].
  static int? _openOf(String raw, int closeIdx) {
    var depth = 0;
    for (var i = closeIdx; i >= 0; i--) {
      final ch = raw[i];
      if (ch == ')') depth++;
      if (ch == '(') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  static bool _closesNumerator(String raw, int closeIdx) =>
      raw.startsWith('/(', closeIdx + 1);

  /// `▶` al final del numerador -> inicio del denominador.
  static (String raw, int cursor)? handleRight(String raw, int cursor) {
    if (cursor < 0 || cursor >= raw.length || raw[cursor] != ')') return null;
    if (_openOf(raw, cursor) == null) return null;
    if (_closesNumerator(raw, cursor)) return (raw, cursor + 3);
    return null;
  }

  /// `◀` al inicio del denominador -> final del numerador; al inicio del
  /// numerador -> fuera a la izquierda.
  static (String raw, int cursor)? handleLeft(String raw, int cursor) {
    if (cursor < 1 || cursor > raw.length || raw[cursor - 1] != '(') return null;
    if (cursor >= 3 && raw[cursor - 2] == '/' && raw[cursor - 3] == ')') {
      return (raw, cursor - 3);
    }
    final close = BalancedScan.findClose(raw, cursor - 1);
    if (close != null && _closesNumerator(raw, close)) {
      return (raw, cursor - 1);
    }
    return null;
  }

  /// Backspace sin dejar parentesis huerfanos en fracciones vacias.
  static (String raw, int cursor)? delete(String raw, int cursor) {
    if (cursor >= 1 && raw.startsWith('()/()', cursor - 1)) {
      return (raw.replaceRange(cursor - 1, cursor + 4, ''), cursor - 1);
    }
    if (cursor >= 4 && raw.startsWith('()/()', cursor - 4)) {
      return (raw.replaceRange(cursor - 4, cursor + 1, ''), cursor - 4);
    }
    if (cursor >= 3 &&
        cursor < raw.length &&
        raw.startsWith('/()', cursor - 2) &&
        raw[cursor - 3] == ')') {
      return (raw.replaceRange(cursor - 2, cursor + 1, ''), cursor - 2);
    }
    return null;
  }
}
