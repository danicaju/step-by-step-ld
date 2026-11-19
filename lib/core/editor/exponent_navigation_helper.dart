/// Contrato unico del exponente estilo Casio ClassWiz sobre el buffer del editor (Dart puro).
///
/// En el buffer el exponente es `x^(expr)` (la LCD lo pinta `x^{expr}`) y la fraccion `(num)/(den)`.
/// Reglas (todos los modos y campos matematicos):
/// - `x^■`, SHIFT+x², `e^■`, `10^■` y la tecla `^` insertan `^()` con el cursor DENTRO.
/// - `x²`, `x³` insertan `^(2)`, `^(3)` con el cursor tras `)`: ◀ entra a editar el exponente.
/// - Dentro de `^( ... )` todo token se escribe dentro: un `)` suelto nunca cierra el exponente.
/// - Solo ▶ (o ▼) sale a la linea base; ◀ tras `^(..)|` vuelve a entrar; ◀ al inicio salta `^(`.
/// - DEL dentro borra el ultimo token interno; con `^()` vacio borra el bloque; tras `^(..)|`
///   entra y borra el ultimo token interno; al inicio de un exponente con contenido lo desenvuelve.
///   El buffer queda siempre balanceado.
abstract final class ExponentNavigationHelper {
  /// Apertura del exponente en el buffer.
  static const String open = '^(';

  /// Teclas rapidas: cursor tras `)` (◀ entra al exponente).
  static const String square = '^(2)';
  static const String cube = '^(3)';
  static const String inverse = '^(-1)';

  /// Aplana exponentes enteros simples para los parsers de texto heredados: `x^(2)` -> `x^2`.
  static String flattenSimplePowers(String s) =>
      s.replaceAllMapped(RegExp(r'\^\((\d+)\)'), (m) => '^${m.group(1)}');

  /// Indice del `(` que abre el exponente `^(` que contiene al cursor; `null` si no hay.
  static int? enclosingOpen(String raw, int pos) {
    var depth = 0;
    for (var i = pos.clamp(0, raw.length) - 1; i >= 0; i--) {
      final c = raw[i];
      if (c == ')') {
        depth++;
      } else if (c == '(') {
        if (depth > 0) {
          depth--;
        } else if (i > 0 && raw[i - 1] == '^') {
          return i;
        }
      }
    }
    return null;
  }

  /// `true` si el cursor esta dentro de un exponente `^( ... )` (activa la pista de la LCD).
  static bool isInsideExponent(String raw, int pos) => enclosingOpen(raw, pos) != null;

  /// Indice del `)` que cierra el `(` de [openIdx]; `null` si falta.
  static int? closeOf(String raw, int openIdx) {
    var depth = 0;
    for (var i = openIdx; i < raw.length; i++) {
      if (raw[i] == '(') depth++;
      if (raw[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  /// Indice del `(` que abre el grupo cuyo cierre esta en [closeIdx]; `null` si falta.
  static int? openOf(String raw, int closeIdx) {
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

  /// Posicion justo despues del `)` del exponente que contiene al cursor (▼); `null` si no hay.
  static int? exitDown(String raw, int pos) {
    final o = enclosingOpen(raw, pos);
    if (o == null) return null;
    final close = closeOf(raw, o);
    return close == null ? raw.length : close + 1;
  }

  /// `true` si el `)` de [closeIdx] pertenece a una plantilla (exponente, numerador o
  /// denominador de fraccion) y por tanto no debe "saltarse" al teclear `)`.
  static bool isTemplateClose(String raw, int closeIdx) {
    final o = openOf(raw, closeIdx);
    if (o == null) return false;
    if (o > 0 && (raw[o - 1] == '^' || raw[o - 1] == '/')) return true;
    return closeIdx + 2 < raw.length && raw[closeIdx + 1] == '/' && raw[closeIdx + 2] == '(';
  }

  /// ▶ con el exponente sin cerrar al final del buffer: lo cierra y deja el cursor en la linea
  /// base. Tambien sale de `^n` suelto (sin parentesis) anadiendo un espacio. `null` si no aplica.
  static (String raw, int cursor)? handleRight(String raw, int cursorPos, {required int openDepth}) {
    if (raw.isEmpty || cursorPos != raw.length || raw.endsWith(' ')) return null;
    final lastOpen = raw.lastIndexOf(open);
    if (lastOpen != -1 && closeOf(raw, lastOpen + 1) == null && _innermostOpen(raw) == lastOpen + 1) {
      return ('$raw)', raw.length + 1);
    }
    // No interceptar si hay una plantilla log_/root/ln abierta sin cerrar.
    if (openDepth > 0) return null;
    if (RegExp(r'\^[0-9a-zA-Zπ.]+$').hasMatch(raw)) return ('$raw ', raw.length + 1);
    return null;
  }

  /// DEL con el cursor pegado a un exponente (justo tras `^(..)|` o al inicio `^(|..)`).
  /// `null` si el cursor no esta en ninguno de esos dos bordes (borrado normal).
  static (String raw, int cursor)? deleteAtBorder(
    String raw,
    int pos,
    (String raw, int cursor) Function(String raw, int pos) deleteInside,
  ) {
    if (pos < 2 || pos > raw.length) return null;
    // Tras `^(..)|` no vacio: entra y borra el ultimo token interno (el `)` nunca se borra).
    if (raw[pos - 1] == ')') {
      final o = openOf(raw, pos - 1);
      if (o == null || o == 0 || raw[o - 1] != '^') return null;
      // `^()|` vacio: se elimina el bloque entero.
      if (o == pos - 2) return (raw.substring(0, o - 1) + raw.substring(pos), o - 1);
      return deleteInside(raw, pos - 1);
    }
    // Al inicio `^(|2x)` con contenido: desenvuelve (quita `^(` y su `)`).
    if (raw.startsWith(open, pos - 2) && pos < raw.length && raw[pos] != ')') {
      final close = closeOf(raw, pos - 1);
      if (close == null) return null;
      final next = raw.substring(0, pos - 2) + raw.substring(pos, close) + raw.substring(close + 1);
      return (next, pos - 2);
    }
    return null;
  }

  static int _innermostOpen(String raw) {
    final stack = <int>[];
    for (var i = 0; i < raw.length; i++) {
      if (raw[i] == '(') {
        stack.add(i);
      } else if (raw[i] == ')' && stack.isNotEmpty) {
        stack.removeLast();
      }
    }
    return stack.isEmpty ? -1 : stack.last;
  }
}
