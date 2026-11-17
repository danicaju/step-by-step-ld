import 'balanced_scan.dart';

/// DEL "desenvolvedor": al borrar junto a una raiz o una fraccion con contenido,
/// elimina primero el envoltorio y conserva los operandos interiores.
class UnwrapHelper {
  const UnwrapHelper._();

  static const List<String> _rootOpeners = ['³√(', 'root(', '√('];

  /// `(raw, cursor)` tras desenvolver, o `null` si no aplica en [cursor].
  static (String raw, int cursor)? tryUnwrap(String raw, int cursor) {
    if (cursor <= 0 || cursor > raw.length) return null;
    return _unwrapRootOpen(raw, cursor) ??
        _unwrapRootClose(raw, cursor) ??
        _unwrapFraction(raw, cursor);
  }

  /// Cursor justo tras `√(`: `√(|9)` -> `|9`.
  static (String, int)? _unwrapRootOpen(String raw, int cursor) {
    final prefix = raw.substring(0, cursor);
    for (final op in _rootOpeners) {
      if (!prefix.endsWith(op)) continue;
      final close = BalancedScan.findClose(raw, cursor - 1);
      if (close == null || close == cursor) return null; // vacia: borrado normal
      final start = cursor - op.length;
      final inner = raw.substring(cursor, close);
      return (raw.substring(0, start) + inner + raw.substring(close + 1), start);
    }
    return null;
  }

  /// Cursor justo tras el `)` de una raiz: `√(9)|` -> `9|`.
  static (String, int)? _unwrapRootClose(String raw, int cursor) {
    if (raw[cursor - 1] != ')') return null;
    final open = _openOf(raw, cursor - 1);
    if (open == null || open == cursor - 2) return null;
    final head = raw.substring(0, open + 1);
    for (final op in _rootOpeners) {
      if (!head.endsWith(op)) continue;
      final start = open + 1 - op.length;
      final inner = raw.substring(open + 1, cursor - 1);
      final next = raw.substring(0, start) + inner + raw.substring(cursor);
      return (next, start + inner.length);
    }
    return null;
  }

  /// Fraccion `(n)/(d)`: DEL en el inicio del numerador, del denominador o
  /// justo despues de la fraccion quita la barra y deja `nd`.
  static (String, int)? _unwrapFraction(String raw, int cursor) {
    int? numOpen;
    if (raw[cursor - 1] == '(') {
      if (cursor >= 3 && raw.startsWith(')/(', cursor - 3)) {
        numOpen = _openOf(raw, cursor - 3);
      } else {
        final close = BalancedScan.findClose(raw, cursor - 1);
        if (close != null && raw.startsWith('/(', close + 1)) numOpen = cursor - 1;
      }
    } else if (raw[cursor - 1] == ')') {
      final denOpen = _openOf(raw, cursor - 1);
      if (denOpen != null && denOpen >= 3 && raw.startsWith(')/(', denOpen - 2)) {
        numOpen = _openOf(raw, denOpen - 2);
      }
    }
    if (numOpen == null) return null;
    final numClose = BalancedScan.findClose(raw, numOpen);
    if (numClose == null || !raw.startsWith('/(', numClose + 1)) return null;
    final denOpen = numClose + 2;
    final denClose = BalancedScan.findClose(raw, denOpen);
    if (denClose == null) return null;
    final num = raw.substring(numOpen + 1, numClose);
    final den = raw.substring(denOpen + 1, denClose);
    if (num.isEmpty || den.isEmpty) return null; // vacias: borrado normal
    final next =
        raw.substring(0, numOpen) + num + den + raw.substring(denClose + 1);
    return (next, numOpen + num.length);
  }

  /// Indice del `(` que abre el grupo cuyo cierre esta en [closeIdx].
  static int? _openOf(String raw, int closeIdx) {
    var depth = 0;
    for (var i = closeIdx; i >= 0; i--) {
      if (raw[i] == ')') depth++;
      if (raw[i] == '(') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }
}
