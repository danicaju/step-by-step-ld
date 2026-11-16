import 'cursor_navigation_helper.dart';

class TemplateNavigationHelper {
  static ({int fnStart, int openParen, int? closeParen, String fnName})?
      activeMcmMcdContext(String raw, int cursorPos) {
    final safe = CursorNavigationHelper.snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
    final stack = <({int openParen, int? fnStart, String? fnName})>[];

    for (int i = 0; i < safe; i++) {
      final ch = raw[i];
      if (ch == '(') {
        if (i >= 3) {
          final prefix = raw.substring(i - 3, i).toLowerCase();
          if (prefix == 'mcm' || prefix == 'mcd') {
            stack.add((openParen: i, fnStart: i - 3, fnName: prefix));
            continue;
          }
        }
        stack.add((openParen: i, fnStart: null, fnName: null));
      } else if (ch == ')' && stack.isNotEmpty) {
        stack.removeLast();
      }
    }

    for (int k = stack.length - 1; k >= 0; k--) {
      final entry = stack[k];
      if (entry.fnName != null && entry.fnStart != null) {
        int depth = 1;
        int? closeIdx;
        for (int j = entry.openParen + 1; j < raw.length; j++) {
          if (raw[j] == '(') {
            depth++;
          } else if (raw[j] == ')') {
            depth--;
            if (depth == 0) {
              closeIdx = j;
              break;
            }
          }
        }
        return (
          fnStart: entry.fnStart!,
          openParen: entry.openParen,
          closeParen: closeIdx,
          fnName: entry.fnName!,
        );
      }
    }
    return null;
  }

  /// Gestiona la pulsación de `.` o `,` dentro de `mcm(...)` o `mcd(...)` abriendo
  /// un nuevo argumento con `,`. Devuelve `null` si el cursor está fuera.
  static (String raw, int cursor)? handleMcmMcdCommaOrDot(
    String raw,
    int cursorPos,
  ) {
    final ctx = activeMcmMcdContext(raw, cursorPos);
    if (ctx == null) return null;

    final safe = CursorNavigationHelper.snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
    if (safe <= ctx.openParen + 1) {
      return (raw, safe);
    }
    final charBefore = raw[safe - 1];
    if (charBefore == ',' || charBefore == '(') {
      return (raw, safe);
    }
    final updated = '${raw.substring(0, safe)},${raw.substring(safe)}';
    return (updated, safe + 1);
  }

  /// Gestiona D-Pad derecha (`▶`) dentro de `mcm(...)` o `mcd(...)`:
  /// - Si está al final del número actual y no quedan caracteres en el hueco, abre `,` para otro número.
  /// - Si el hueco tras `,` está vacío y ya hay >= 2 argumentos, cierra el paréntesis limpiando la coma sobrante.
  /// - Devuelve `null` si debe ejecutarse el avance normal de cursor.
  static (String raw, int cursor)? handleMcmMcdRightArrow(
    String raw,
    int cursorPos,
  ) {
    final ctx = activeMcmMcdContext(raw, cursorPos);
    if (ctx == null) return null;

    final safe = CursorNavigationHelper.snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
    final slotEnd = ctx.closeParen ?? raw.length;
    if (safe < slotEnd) {
      return null; // Aún quedan caracteres dentro de la llamada para avanzar normalmente
    }

    final insideBefore = raw.substring(ctx.openParen + 1, safe);
    final parts = insideBefore.split(',');
    final lastArg = parts.last.trim();

    if (lastArg.isNotEmpty) {
      // Abrir hueco para el siguiente número (2º, 3º, 4º, ...)
      final updated = '${raw.substring(0, safe)},${raw.substring(safe)}';
      return (updated, safe + 1);
    }

    // Si estamos en un hueco vacío tras ',' (ej. mcm(12, 18,|) y ya hay >= 2 argumentos rellenos
    final nonEmptyCount = parts.where((p) => p.trim().isNotEmpty).length;
    if (parts.length >= 2 && nonEmptyCount >= 2) {
      final beforeComma = raw.substring(0, safe - 1).trimRight();
      final after = raw.substring(safe);
      if (ctx.closeParen != null && after.startsWith(')')) {
        final updated = beforeComma + after;
        return (updated, beforeComma.length + 1);
      } else {
        final updated = '$beforeComma)$after';
        return (updated, beforeComma.length + 1);
      }
    }

    return (raw, safe);
  }

  /// Gestiona el cierre `)` cuando el cursor está dentro de `mcm(...)` o `mcd(...)`,
  /// eliminando comas finales vacías si el usuario cierra inmediatamente.
  static (String raw, int cursor)? handleMcmMcdCloseParen(
    String raw,
    int cursorPos,
  ) {
    final ctx = activeMcmMcdContext(raw, cursorPos);
    if (ctx == null) return null;

    var safe = CursorNavigationHelper.snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
    var working = raw;
    if (safe > ctx.openParen + 1 && working[safe - 1] == ',') {
      working = working.substring(0, safe - 1) + working.substring(safe);
      safe--;
    }

    final closeIdx = ctx.closeParen != null
        ? (ctx.closeParen! - (raw.length - working.length))
        : null;
    if (closeIdx != null && closeIdx >= safe && working[closeIdx] == ')') {
      return (working, closeIdx + 1);
    }
    final updated = '${working.substring(0, safe)})${working.substring(safe)}';
    return (updated, safe + 1);
  }

  /// Limpia comas sobrantes al final y cierra paréntesis abiertos de `mcm(...)` / `mcd(...)`
  /// antes de parsear tras pulsar `=`.
  static String finalizeMcmMcdInput(String raw) {
    var out = raw.trim();
    // Eliminar coma sobrante antes de ')' o al final en mcm/mcd
    out = out.replaceAllMapped(
      RegExp(r'(mcm|mcd)\(([^()]*)\)'),
      (m) {
        final trimmed = m[2]!.replaceFirst(RegExp(r',\s*$'), '');
        return '${m[1]}($trimmed)';
      },
    );
    // Si hay mcm(/mcd( sin cerrar, quitar coma final y añadir ')'
    int openCount = 0;
    for (int i = 0; i < out.length; i++) {
      if (out[i] == '(') openCount++;
      if (out[i] == ')' && openCount > 0) openCount--;
    }
    if (openCount > 0 &&
        RegExp(r'(mcm|mcd)\([^()]*$', caseSensitive: false).hasMatch(out)) {
      out = out.replaceFirst(RegExp(r',\s*$'), '');
      out = '$out)';
    }
    return out;
  }

  /// Gestiona D-Pad derecha (`▶`) dentro de plantillas de 2 huecos como `log_(base,arg)`
  /// o `root(n,rad)`: al pulsar `▶` al final del primer hueco, abre `,` para pasar al segundo.
  static (String raw, int cursor)? handleTwoSlotRightArrow(
    String raw,
    int cursorPos,
  ) {
    final safe = CursorNavigationHelper.snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
    for (final fnPrefix in ['log_(', 'root(']) {
      final start = raw.lastIndexOf(fnPrefix, safe);
      if (start == -1) continue;
      final openParen = start + fnPrefix.length - 1;
      if (safe <= openParen) continue;

      int depth = 1;
      int? closeIdx;
      for (int i = openParen + 1; i < raw.length; i++) {
        if (raw[i] == '(') depth++;
        if (raw[i] == ')') {
          depth--;
          if (depth == 0) {
            closeIdx = i;
            break;
          }
        }
      }
      final endBoundary = closeIdx ?? raw.length;
      if (safe > endBoundary) continue;

      final inside = raw.substring(openParen + 1, endBoundary);
      final commaIdx = inside.indexOf(',');
      if (commaIdx == -1 && safe == endBoundary && inside.trim().isNotEmpty) {
        final updated = '${raw.substring(0, safe)},${raw.substring(safe)}';
        return (updated, safe + 1);
      }
      if (commaIdx != -1 && safe == endBoundary && !inside.endsWith(',')) {
        if (closeIdx == null) {
          final updated = '${raw.substring(0, safe)})${raw.substring(safe)}';
          return (updated, safe + 1);
        }
      }
    }

    // Plantillas de identidades notables: (a + b)^2, (a - b)^2, (a + b)(a - b)
    final parenMatch = RegExp(r'\(([^)]*)\)').firstMatch(raw);
    if (parenMatch != null) {
      final insideStart = parenMatch.start + 1;
      final insideEnd = parenMatch.end - 1;
      if (safe >= insideStart && safe <= insideEnd) {
        final inside = raw.substring(insideStart, insideEnd);
        final opMatch = RegExp(r'\s*([+\-])\s*').firstMatch(inside);
        if (opMatch != null) {
          final sepStart = insideStart + opMatch.start;
          final sepEnd = insideStart + opMatch.end;
          if (safe >= insideStart && safe <= sepEnd && safe >= sepStart) {
            return (raw, sepEnd);
          }
        }
      }
    }

    return null;
  }

  /// Gestiona la pulsación de `▶` (flecha derecha) al final del contenido interior
  /// de un bloque estructurado abierto (raíz `√(`, cúbica `³√(`, exponente `^(`,
  /// o funciones `sin(`, `cos(`, etc.), cerrando el bloque con `)` y situando el cursor
  /// inmediatamente fuera a su derecha para seguir operando sin necesidad de teclear `)`.
  static (String raw, int cursor)? handleStructuredBlockRightArrow(
    String raw,
    int cursorPos,
  ) {
    if (raw.isEmpty) return null;
    final safe = CursorNavigationHelper.snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
    if (safe <= 0) return null;

    // Si ya hay un ')' justo delante del cursor, stepCursorRight ya avanzará sobre él.
    if (safe < raw.length && raw[safe] == ')') {
      return null;
    }

    // Buscar el paréntesis abierto más interno no cerrado hasta 'safe'
    int depth = 0;
    int? innermostOpenParen;
    for (int i = safe - 1; i >= 0; i--) {
      if (raw[i] == ')') {
        depth++;
      } else if (raw[i] == '(') {
        if (depth > 0) {
          depth--;
        } else {
          innermostOpenParen = i;
          break;
        }
      }
    }

    if (innermostOpenParen == null) return null;

    // CRÍTICO: SOLO autocerrar si es un bloque estructurado de plantilla de función
    // o exponente / raíz (ej: ^(, √(, ³√(, root(, log_(, sin(, cos(, tan(, ln(),
    // NUNCA para un paréntesis aritmético o algebraico normal de usuario como (x + 1) o (1/2 - 3).
    final beforeOpen = raw.substring(0, innermostOpenParen);
    const structuredPrefixes = [
      '^',
      '√',
      '³√',
      'root',
      'log_',
      'sin',
      'cos',
      'tan',
      'asin',
      'acos',
      'atan',
      'ln',
    ];
    final isStructuredTemplate = structuredPrefixes.any(beforeOpen.endsWith);
    if (!isStructuredTemplate) {
      // Paréntesis de usuario normal: NO autocerrar con flecha derecha.
      return null;
    }

    // Verificar si ese '(' ya tiene un ')' de cierre después de 'safe'
    int forwardDepth = 1;
    bool hasClosingParen = false;
    for (int j = innermostOpenParen + 1; j < raw.length; j++) {
      if (raw[j] == '(') forwardDepth++;
      if (raw[j] == ')') {
        forwardDepth--;
        if (forwardDepth == 0) {
          hasClosingParen = true;
          break;
        }
      }
    }

    // Si no está cerrado y el cursor está al final del contenido del bloque abierto
    if (!hasClosingParen && safe >= raw.length) {
      final updated = '${raw.substring(0, safe)})${raw.substring(safe)}';
      return (updated, safe + 1);
    }

    return null;
  }

  /// Gestiona la salida de una potencia con la flecha derecha `▶`:
  /// si el cursor está al final de un exponente sin espacio posterior,
  /// inserta un espacio `' '` o cierra el bloque para situar el cursor en la línea base.
  static (String raw, int cursor)? handlePowerRightArrow(
    String raw,
    int cursorPos,
  ) {
    if (raw.isEmpty) return null;
    final safe = CursorNavigationHelper.snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
    if (safe != raw.length) return null;
    if (raw.endsWith(' ')) return null;

    final lastPowParen = raw.lastIndexOf('^(');
    if (lastPowParen != -1) {
      final after = raw.substring(lastPowParen + 2);
      if (!after.contains(')')) {
        return ('$raw)', safe + 1);
      }
    }

    final powMatch = RegExp(r'\^[0-9a-zA-Zπ.]+$|\^\([^)]+\)$').firstMatch(raw);
    if (powMatch != null) {
      return ('$raw ', safe + 1);
    }

    return null;
  }
}
