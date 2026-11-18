/// Edicion de una celda numerica de coeficientes con fraccion vertical `num/den`.
///
/// El texto de la celda es `num/den` (`-3/4`). La tecla a/b puede pulsarse con la celda
/// vacia (o solo con `-`): se abre la fraccion y se escribe primero el numerador. Una
/// bandera `numEdit` indica que parte recibe las teclas (numerador o denominador).
class CellFractionEditor {
  const CellFractionEditor._();

  /// Tecla a/b. Devuelve (texto, editandoNumerador).
  /// Con texto previo (`3`) la fraccion se abre en el denominador; vacia o `-`, en el numerador.
  static (String, bool) slash(String cur, bool numEdit) {
    if (cur.contains('/')) return (cur, numEdit);
    return ('$cur/', cur.isEmpty || cur == '-');
  }

  /// Escribe [token] (`0-9`, `.`, `-`) en la parte activa de la fraccion.
  /// `-` cambia el signo de toda la fraccion (siempre en el numerador).
  static String append(String cur, String token, bool numEdit) {
    final i = cur.indexOf('/');
    if (i < 0) return cur;
    var n = cur.substring(0, i);
    var d = cur.substring(i + 1);
    if (token == '-') {
      n = n.startsWith('-') ? n.substring(1) : '-$n';
    } else if (token == '.') {
      if (numEdit) {
        n = _dot(n);
      } else {
        d = _dot(d);
      }
    } else if (RegExp(r'^[0-9]$').hasMatch(token)) {
      if (numEdit) {
        n += token;
      } else {
        d += token;
      }
    }
    return '$n/$d';
  }

  static String _dot(String part) {
    if (part.contains('.')) return part;
    return part.isEmpty || part == '-' ? '${part}0.' : '$part.';
  }

  /// DEL. Devuelve (texto, editandoNumerador). Con la parte activa vacia deshace la fraccion.
  static (String, bool) backspace(String cur, bool numEdit) {
    final i = cur.indexOf('/');
    if (i < 0) {
      return (cur.isEmpty ? cur : cur.substring(0, cur.length - 1), false);
    }
    var n = cur.substring(0, i);
    var d = cur.substring(i + 1);
    if (numEdit) {
      if (n.isEmpty || n == '-') {
        // Numerador vacio: si tambien lo esta el denominador se cierra la fraccion.
        return d.isEmpty ? (n, false) : (cur, true);
      }
      n = n.substring(0, n.length - 1);
      return ('$n/$d', true);
    }
    if (d.isEmpty) return (n, false); // quita la barra y deja el numerador como numero
    d = d.substring(0, d.length - 1);
    return ('$n/$d', false);
  }

  /// D-Pad dentro de la celda: ▶/▼ pasan del numerador al denominador y ◀/▲ al reves.
  /// Devuelve el nuevo `numEdit`, o `null` si no lo consume (se sale de la celda).
  static bool? dpad(String cur, bool numEdit, String dir) {
    if (!cur.contains('/')) return null;
    switch (dir) {
      case 'right':
      case 'down':
        return numEdit ? false : null;
      case 'left':
      case 'up':
        return numEdit ? null : true;
    }
    return null;
  }

  /// Partes (numerador, denominador) de un texto `num/den`; `null` si no es fraccion.
  static (String, String)? parts(String cur) {
    final i = cur.indexOf('/');
    if (i < 0) return null;
    return (cur.substring(0, i), cur.substring(i + 1));
  }
}
