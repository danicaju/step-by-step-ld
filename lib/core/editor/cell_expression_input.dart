/// Edicion de celdas numericas (M9, M10, M11) cuando contienen una expresion real
/// (`sinh(0)`, `root(3,8)`, `ln(ℯ^(3))`, `π/4`...) en lugar de un entero, decimal o `a/b`.
///
/// La celda se edita siempre por el final (como el resto de celdas): los parentesis
/// pendientes se dibujan atenuados y se cierran al evaluar. `▶` rellena la coma de
/// `root(n,x)` / `log_(b,x)` y cierra el parentesis abierto; `◀` lo deshace.
abstract final class CellExpressionInput {
  static final RegExp _plain = RegExp(r'^[0-9.\-/]*$');
  static const Set<String> _symbols = {'ℯ', 'π'};
  static const Set<String> _operators = {'+', '*', '(', ')', '^'};
  static const List<String> _keywords = [
    'ℯ^(', 'asinh(', 'acosh(', 'atanh(', 'sinh(', 'cosh(', 'tanh(', 'arcsin(', 'arccos(',
    'arctan(', 'sin⁻¹(', 'cos⁻¹(', 'tan⁻¹(', 'root(', 'log_(', '³√(', 'sin(', 'cos(', 'tan(',
    'log(', 'ln(', '√(', 'Abs(',
  ];

  /// `true` si [cell] ya no es un numero simple (`3`, `-2.5`, `3/4`).
  static bool isExpression(String cell) => !_plain.hasMatch(cell.trim());

  /// `true` si la tecla [token] debe tratarse como entrada de expresion en [cell].
  static bool accepts(String cell, String token) {
    if (token.length > 1 || _symbols.contains(token)) return true;
    if (!isExpression(cell)) return false;
    return _operators.contains(token) ||
        token == '/' ||
        token == '.' ||
        token == '-' ||
        RegExp(r'^[0-9]$').hasMatch(token);
  }

  /// Pendientes de cierre: cantidad de `(` sin su `)`.
  static int pending(String cell) {
    var depth = 0;
    for (final ch in cell.split('')) {
      if (ch == '(') {
        depth++;
      } else if (ch == ')' && depth > 0) {
        depth--;
      }
    }
    return depth;
  }

  /// [cell] con todos los parentesis cerrados (para evaluar).
  static String closed(String cell) => cell + ')' * pending(cell);

  /// Anade [token] al final de [cell].
  static String append(String cell, String token) {
    if (token == ')' && pending(cell) == 0) return cell;
    return '$cell$token';
  }

  /// Borra la ultima palabra clave entera (`sinh(`, `root(`...) o el ultimo caracter.
  static String backspace(String cell) {
    if (cell.isEmpty) return cell;
    for (final k in _keywords) {
      if (cell.endsWith(k)) return cell.substring(0, cell.length - k.length);
    }
    return cell.substring(0, cell.length - 1);
  }

  /// Contenido del ultimo parentesis abierto: `(cabecera hasta el `(`, texto interior)`.
  static (String, String)? _innermostOpen(String cell) {
    var depth = 0;
    for (var i = cell.length - 1; i >= 0; i--) {
      final ch = cell[i];
      if (ch == ')') depth++;
      if (ch == '(') {
        if (depth == 0) return (cell.substring(0, i + 1), cell.substring(i + 1));
        depth--;
      }
    }
    return null;
  }

  /// `▶` dentro de la celda: coma entre los dos slots o cierre del parentesis abierto.
  /// `null` si no hay nada que completar (el D-Pad pasa a la celda siguiente).
  static String? dpadRight(String cell) {
    final open = _innermostOpen(cell);
    if (open == null) return null;
    final (head, inner) = open;
    final twoSlot = head.endsWith('root(') || head.endsWith('log_(');
    if (twoSlot && !_hasTopLevelComma(inner)) return '$cell,';
    return '$cell)';
  }

  /// `◀` dentro de la celda: deshace la coma o el cierre del ultimo `▶`.
  static String? dpadLeft(String cell) {
    if (!isExpression(cell)) return null;
    if (cell.endsWith(',') || cell.endsWith(')')) return cell.substring(0, cell.length - 1);
    return null;
  }

  static bool _hasTopLevelComma(String inner) {
    var depth = 0;
    for (final ch in inner.split('')) {
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == ',' && depth == 0) return true;
    }
    return false;
  }
}
