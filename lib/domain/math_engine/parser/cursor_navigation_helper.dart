import 'balanced_scan.dart';
import 'expression_tokenizer.dart';
import 'fraction_template.dart';
import 'slash_fraction_converter.dart';

class CursorNavigationHelper {

  static const List<String> atomicKeywords = ExpressionTokenizer.atomicKeywords;

  /// Ajusta una posición de cursor para que nunca divida por la mitad una palabra clave atómica
  /// como `ANS`, `mcm(`, `mcd(`, `√(`, `³√(`, `root(` o `^(`.
  static int snapCursorOutsideKeywords(String raw, int pos, {bool preferLeft = false}) {
    int p = pos.clamp(0, raw.length);
    bool moved = true;
    while (moved) {
      moved = false;
      for (final kw in atomicKeywords) {
        int start = 0;
        while (true) {
          final idx = raw.indexOf(kw, start);
          if (idx == -1) break;
          final end = idx + kw.length;
          if (p > idx && p < end) {
            p = preferLeft ? idx : end;
            moved = true;
            break;
          }
          start = idx + 1;
        }
        if (moved) break;
      }
    }
    return p;
  }

  /// Desplaza el cursor un paso hacia la izquierda respetando tokens atómicos.
  static int stepCursorLeft(String raw, int currentPos) {
    final safe = snapCursorOutsideKeywords(raw, currentPos, preferLeft: true);
    if (safe <= 0) return 0;
    final prefix = raw.substring(0, safe);
    for (final kw in atomicKeywords) {
      if (prefix.endsWith(kw)) {
        return safe - kw.length;
      }
    }
    // Manejo seguro del símbolo compuesto ³√ sin paréntesis
    if (prefix.endsWith('³√')) {
      return safe - 2;
    }
    return safe - 1;
  }

  /// Desplaza el cursor un paso hacia la derecha respetando tokens atómicos.
  static int stepCursorRight(String raw, int currentPos) {
    final safe = snapCursorOutsideKeywords(raw, currentPos, preferLeft: false);
    if (safe >= raw.length) return raw.length;
    final suffix = raw.substring(safe);
    for (final kw in atomicKeywords) {
      if (suffix.startsWith(kw)) {
        return safe + kw.length;
      }
    }
    if (suffix.startsWith('³√')) {
      return safe + 2;
    }
    return safe + 1;
  }

  /// Inserta una subcadena/token en la posición exacta del cursor.
  static (String raw, int cursor) insertAtCursor(
    String raw,
    int currentPos,
    String token, {
    bool keepLeadingZero = false,
    bool overwrite = false,
  }) {
    // Modo sobrescritura (SHIFT + DEL / INS): sustituye el token que hay tras el cursor.
    if (overwrite && currentPos < raw.length && !(raw == '0' && currentPos == 1)) {
      final from = snapCursorOutsideKeywords(raw, currentPos);
      if (from < raw.length) {
        final end = stepCursorRight(raw, from);
        return insertAtCursor(
          raw.substring(0, from) + raw.substring(end),
          from,
          token,
          keepLeadingZero: keepLeadingZero,
        );
      }
    }
    // Una potencia nunca queda huérfana: sin operando previo se usa `0` como base.
    if (token.startsWith('^') && raw.isEmpty) {
      return ('0$token', 1 + token.length);
    }
    if (raw == '0' && currentPos == 1 && !keepLeadingZero && !token.startsWith('^')) {
      return (token, token.length);
    }
    final safe = snapCursorOutsideKeywords(raw, currentPos);
    if (token.startsWith('^') && (safe == 0 || '+-*/(,;=<>≤≥:'.contains(raw[safe - 1]))) {
      final withBase = '${raw.substring(0, safe)}0$token${raw.substring(safe)}';
      return (withBase, safe + 1 + token.length);
    }
    if (token == ')'&& safe < raw.length && raw[safe] == ')') {
      return (raw, safe + 1);
    }
    final updated = raw.substring(0, safe) + token + raw.substring(safe);
    return (updated, safe + token.length);
  }

  /// Borra el token o carácter inmediatamente anterior a [currentPos].
  static (String raw, int cursor) deleteAtCursor(
    String raw,
    int currentPos, {
    String emptyResult = '0',
    int emptyCursor = 1,
  }) {
    if (raw.isEmpty || (emptyResult == '0' && raw == '0')) {
      return (emptyResult, emptyCursor);
    }
    final safe = snapCursorOutsideKeywords(raw, currentPos, preferLeft: true);
    if (safe <= 0) {
      return (raw, 0);
    }
    final fracDel = FractionTemplate.delete(raw, safe);
    if (fracDel != null) {
      return fracDel.$1.isEmpty ? (emptyResult, emptyCursor) : fracDel;
    }
    final prefix = raw.substring(0, safe);
    final suffix = raw.substring(safe);

    for (final kw in atomicKeywords) {
      if (prefix.endsWith(kw)) {
        final nextRaw = prefix.substring(0, prefix.length - kw.length) + suffix;
        if (nextRaw.isEmpty) return (emptyResult, emptyCursor);
        return (nextRaw, safe - kw.length);
      }
    }
    if (prefix.endsWith('³√')) {
      final nextRaw = prefix.substring(0, prefix.length - 2) + suffix;
      if (nextRaw.isEmpty) return (emptyResult, emptyCursor);
      return (nextRaw, safe - 2);
    }

    final nextRaw = prefix.substring(0, prefix.length - 1) + suffix;
    if (nextRaw.isEmpty) return (emptyResult, emptyCursor);
    return (nextRaw, safe - 1);
  }

  /// Si el cursor está sobre una fracción (simple, agrupada entre paréntesis,
  /// potencia o vacía `/`), salta entre numerador ([isUp] == true) y denominador
  /// ([isUp] == false). Devuelve `null` si no aplica salto de fracción.
  static int? jumpFractionUpDown(String raw, int currentPos, {required bool isUp}) {
    final safe = currentPos.clamp(0, raw.length);
    ({int numStart, int slashIdx, int denEnd})? bestSpan;
    int bestWidth = raw.length + 1;

    for (int i = 0; i < raw.length; i++) {
      if (raw[i] != '/') continue;
      final numStart = SlashFractionConverter.scanNumeratorLeft(raw, i, '');
      final denEnd = SlashFractionConverter.scanDenominatorRight(raw, i, '');
      // Con grupos `(num)/(den)` el cursor pegado por fuera de la fraccion no cuenta.
      final grouped = i > numStart && raw[i - 1] == ')' && raw[numStart] == '(' &&
          i + 1 < raw.length && raw[i + 1] == '(' && raw[denEnd - 1] == ')';
      if (grouped && (safe == numStart || safe == denEnd)) continue;
      if (safe >= numStart && safe <= denEnd) {
        final width = denEnd - numStart;
        if (width < bestWidth) {
          bestWidth = width;
          bestSpan = (numStart: numStart, slashIdx: i, denEnd: denEnd);
        }
      }
    }

    if (bestSpan == null) return null;

    if (!isUp && safe <= bestSpan.slashIdx) {
      if (bestSpan.denEnd > bestSpan.slashIdx + 1 &&
          raw[bestSpan.slashIdx + 1] == '(' &&
          raw[bestSpan.denEnd - 1] == ')') {
        return bestSpan.denEnd - 1;
      }
      return bestSpan.denEnd;
    }

    if (isUp && safe >= bestSpan.slashIdx + 1) {
      if (bestSpan.slashIdx > bestSpan.numStart &&
          raw[bestSpan.slashIdx - 1] == ')') {
        return bestSpan.slashIdx - 1;
      }
      return bestSpan.slashIdx;
    }

    return null;
  }

  /// Devuelve información sobre la llamada `mcm(...)` o `mcd(...)` que envuelve
  /// a [cursorPos], o `null` si el cursor está fuera de ambas funciones.

  static (String raw, int cursor)? handleFractionRightArrow(
    String raw,
    int cursorPos,
  ) {
    if (raw.isEmpty) return null;
    final safe = snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
    final tpl = FractionTemplate.handleRight(raw, safe);
    if (tpl != null) return tpl;
    if (safe != raw.length) return null;
    if (raw.endsWith(' ')) return null;

    // Verificar si el último término es una fracción no cerrada con paréntesis
    final lastSlash = raw.lastIndexOf('/');
    if (lastSlash == -1) return null;

    // Asegurar que no hay operadores después de la barra (el cursor está al final del denominador)
    final afterSlash = raw.substring(lastSlash + 1);
    if (afterSlash.isEmpty || afterSlash.startsWith('(')) return null;
    // No interceptar si hay una plantilla (log_, ln, root...) abierta sin cerrar.
    if (BalancedScan.openDepth(raw) > 0) return null;

    // Si no contiene operadores de salida, añadir espacio para salir de la fracción
    return ('$raw ', safe + 1);
  }

}
