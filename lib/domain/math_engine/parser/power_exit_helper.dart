/// Salida del exponente `^( ... )` y deteccion de parentesis de plantilla.
///
/// En el buffer el exponente es `x^(5)` y la fraccion `(num)/(den)`: el cursor solo sale de
/// ellos con ▶ (borde derecho) o ▼ (exponente); un `)` suelto nunca los cierra.
class PowerExitHelper {
  const PowerExitHelper._();

  /// Indice del `(` que abre el exponente `^(` que contiene al cursor; `null` si no hay.
  static int? enclosingPowerOpen(String raw, int pos) {
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

  /// Posicion justo despues del `)` del exponente que contiene al cursor (▼); `null` si no hay.
  static int? exitDown(String raw, int pos) {
    final open = enclosingPowerOpen(raw, pos);
    if (open == null) return null;
    final close = _closeOf(raw, open);
    return close == null ? raw.length : close + 1;
  }

  /// Indice del `)` que cierra el `(` de [open]; `null` si falta.
  static int? _closeOf(String raw, int open) {
    var depth = 0;
    for (var i = open; i < raw.length; i++) {
      if (raw[i] == '(') depth++;
      if (raw[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  /// `true` si el `)` de [closeIdx] pertenece a una plantilla (exponente, numerador o
  /// denominador de fraccion) y por tanto no debe "saltarse" al teclear `)`.
  static bool isTemplateClose(String raw, int closeIdx) {
    var depth = 0;
    for (var j = closeIdx; j >= 0; j--) {
      if (raw[j] == ')') depth++;
      if (raw[j] == '(') {
        depth--;
        if (depth == 0) {
          if (j > 0 && (raw[j - 1] == '^' || raw[j - 1] == '/')) return true;
          return closeIdx + 2 < raw.length && raw[closeIdx + 1] == '/' && raw[closeIdx + 2] == '(';
        }
      }
    }
    return false;
  }
}
