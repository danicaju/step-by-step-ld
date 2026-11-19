import 'package:flutter/material.dart';

/// Parentesis fantasma de cierre: cuenta los `(` sin cerrar y los dibuja al final de la
/// formula con opacidad reducida; se cierran de verdad al pulsar `=` o `Enter`.
abstract final class GhostParenthesesHelper {
  static const double ghostOpacity = 0.35;

  /// Numero de parentesis de apertura sin cerrar en [raw].
  static int pendingCount(String raw) {
    var depth = 0;
    for (final ch in raw.split('')) {
      if (ch == '(') {
        depth++;
      } else if (ch == ')' && depth > 0) {
        depth--;
      }
    }
    return depth;
  }

  /// [raw] con todos los parentesis pendientes cerrados.
  static String closeAll(String raw) => raw + ')' * pendingCount(raw);

  /// LaTeX de los `)` pendientes con el tinte atenuado (`ink` al 35 % sobre `background`).
  static String ghostLatex(String raw, {required Color ink, required Color background}) {
    final n = pendingCount(raw);
    if (n == 0) return '';
    final c = Color.lerp(background, ink, ghostOpacity)!;
    final hex = (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    return '\\textcolor{#$hex}{${')' * n}}';
  }
}
