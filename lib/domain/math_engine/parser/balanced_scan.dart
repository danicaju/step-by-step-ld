/// Escáner balanceado por profundidad para paréntesis, llaves y corchetes.
///
/// Sustituye a las búsquedas planas (`[^)]*`, `indexOf(')')`) que se cerraban
/// en el primer cierre y rompían expresiones anidadas como `sin(cos(30))`.
class BalancedScan {
  const BalancedScan._();

  static bool _isOpen(String ch) => ch == '(' || ch == '{' || ch == '[';
  static bool _isClose(String ch) => ch == ')' || ch == '}' || ch == ']';

  /// Índice del cierre que balancea al paréntesis de apertura en [openIdx],
  /// o `null` si no está cerrado.
  static int? findClose(String s, int openIdx) {
    var depth = 0;
    for (var i = openIdx; i < s.length; i++) {
      final ch = s[i];
      if (_isOpen(ch)) {
        depth++;
      } else if (_isClose(ch)) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  /// Parte [s] por [sep] solo cuando la profundidad es 0.
  static List<String> splitTopLevel(String s, [String sep = ',']) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (_isOpen(ch)) {
        depth++;
      } else if (_isClose(ch)) {
        if (depth > 0) depth--;
      } else if (depth == 0 && ch == sep) {
        parts.add(s.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(s.substring(start));
    return parts;
  }

  /// Primer [sep] a profundidad 0 en [s], o -1.
  static int topLevelIndexOf(String s, [String sep = ',']) {
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (_isOpen(ch)) {
        depth++;
      } else if (_isClose(ch)) {
        if (depth > 0) depth--;
      } else if (depth == 0 && ch == sep) {
        return i;
      }
    }
    return -1;
  }

  /// Profundidad de paréntesis abiertos sin cerrar en [s].
  static int openDepth(String s) {
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '(') {
        depth++;
      } else if (s[i] == ')' && depth > 0) {
        depth--;
      }
    }
    return depth;
  }
}
