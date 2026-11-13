import '../ast/ast_nodes.dart';

class ExpressionParser {
  late List<String> _tokens;
  int _pos = 0;

  static const String _cursorSentinel = '\uE000';
  static const String _cursorMidLatex = r'\textcolor{#2E86DE}{\mid}';
  static const String _cursorBoxLatex = r'\textcolor{#2E86DE}{\blacksquare}';

  static const List<String> atomicKeywords = [
    'sin⁻¹(',
    'cos⁻¹(',
    'tan⁻¹(',
    'arcsin(',
    'arccos(',
    'arctan(',
    'root(',
    'asin(',
    'acos(',
    'atan(',
    'log_(',
    'mcm(',
    'mcd(',
    'sin(',
    'cos(',
    'tan(',
    'log(',
    'ln(',
    '³√(',
    '*10^(',
    '*10^',
    'ANS',
    'ans',
    '√(',
    '^(',
  ];

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
  }) {
    if (raw == '0' && currentPos == 1 && !keepLeadingZero) {
      return (token, token.length);
    }
    final safe = snapCursorOutsideKeywords(raw, currentPos);
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
      final numStart = _scanNumeratorLeft(raw, i, '');
      final denEnd = _scanDenominatorRight(raw, i, '');
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
  static ({int fnStart, int openParen, int? closeParen, String fnName})?
      activeMcmMcdContext(String raw, int cursorPos) {
    final safe = snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
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

    final safe = snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
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

    final safe = snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
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

    var safe = snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
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
    final safe = snapCursorOutsideKeywords(raw, cursorPos).clamp(0, raw.length);
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
    return null;
  }

  /// Limpia comas finales y autocierra cualquier paréntesis abierto antes de evaluar.
  static String finalizeForEvaluation(String raw) {
    var out = finalizeMcmMcdInput(raw);
    int balance = 0;
    for (int i = 0; i < out.length; i++) {
      if (out[i] == '(') {
        balance++;
      } else if (out[i] == ')' && balance > 0) {
        balance--;
      }
    }
    if (balance > 0) {
      out = '$out${')' * balance}';
    }
    return out;
  }

  static String _formatMcmMcdLiveArgs(String inner) {
    const c = _cursorSentinel;
    final parts = inner.split(',');
    final formatted = <String>[];
    for (final part in parts) {
      final seg = part.trim();
      if (seg.isEmpty) {
        formatted.add(r'\square');
      } else if (seg == c) {
        formatted.add(_cursorBoxLatex);
      } else {
        formatted.add(seg);
      }
    }
    if (formatted.isEmpty) {
      formatted.add(_cursorBoxLatex);
    }
    return formatted.join(' ; ');
  }

  /// Convierte la entrada en vivo del teclado en LaTeX estilo Casio Natural Display
  /// incluso cuando el alumno aún no ha terminado de escribir la operación.
  /// Si [cursorPos] no es nulo, inyecta un cursor visual compatible con `flutter_math_fork`.
  static String rawToLiveLatex(String raw, {int? cursorPos}) {
    if (raw.isEmpty) {
      return cursorPos != null ? _cursorBoxLatex : '0';
    }

    String out = raw;
    if (cursorPos != null) {
      final safePos = snapCursorOutsideKeywords(raw, cursorPos);
      out = raw.substring(0, safePos) + _cursorSentinel + raw.substring(safePos);
    }

    const c = _cursorSentinel;
    const numPat = r'(?:(?:\d+|' + c + r'\d+)(?:\.(?:\d*|' + c + r'\d*))?|\d*' + c + r'\d*(?:\.\d*)?)';
    const atomPat =
        r'(?:[0-9a-zA-Zπ.]+' + c + r'[0-9a-zA-Zπ.]*|' + c + r'[0-9a-zA-Zπ.]+|[0-9a-zA-Zπ.]+)';

    // 0. Conversión universal por bloques de cualquier división `/` o `frac(a, b)`
    //    a fracción vertical `\frac{...}{...}` (incluye fracciones vacías, negativas,
    //    con potencias `x^2`, funciones o paréntesis compuestos `(x+2)/(x-1)`).
    out = _convertSlashesToLatex(out, c);

    // 0b. Funciones mcm y mcd (soporte N-ario: mcm(a ; b ; c ; ...))
    out = out.replaceAllMapped(
      RegExp(r'mcm\(([^)]*)\)'),
      (m) => '\\text{m.c.m.}\\left(${_formatMcmMcdLiveArgs(m[1]!)}\\right)',
    );
    out = out.replaceAllMapped(
      RegExp(r'mcm\(([^)]*)'),
      (m) => '\\text{m.c.m.}\\left(${_formatMcmMcdLiveArgs(m[1]!)}\\right)',
    );
    out = out.replaceAllMapped(
      RegExp(r'mcd\(([^)]*)\)'),
      (m) => '\\text{M.C.D.}\\left(${_formatMcmMcdLiveArgs(m[1]!)}\\right)',
    );
    out = out.replaceAllMapped(
      RegExp(r'mcd\(([^)]*)'),
      (m) => '\\text{M.C.D.}\\left(${_formatMcmMcdLiveArgs(m[1]!)}\\right)',
    );

    // 3. Potencias con paréntesis libre ^(expr), exponente negativo ^-n y ^n
    out = out.replaceAllMapped(
      RegExp(r'\^\(([^)]+)\)'),
      (m) {
        final inner = m[1]!;
        if (inner == c) return '^{$_cursorBoxLatex}';
        return '^{$inner}';
      },
    );
    out = out.replaceAllMapped(
      RegExp(r'\^\(([^)]*)'),
      (m) {
        final inner = m[1]!;
        if (inner == c) return '^{$_cursorBoxLatex}';
        return '^{$inner\\square}';
      },
    );
    out = out.replaceAllMapped(
      RegExp('\\^-($atomPat)'),
      (m) => '^{-${m[1]}}',
    );
    out = out.replaceAllMapped(
      RegExp('\\^($atomPat)'),
      (m) => '^{${m[1]}}',
    );

    // 4. Potencias a mitad de escribir: ^ -> ^{\square}
    out = out.replaceAllMapped(
      RegExp('\\^$c'),
      (_) => '^{$_cursorBoxLatex}',
    );
    out = out.replaceAllMapped(
      RegExp(r'\^(?!\{)'),
      (_) => '^{\\square}',
    );

    // 5. Raíces n-ésimas (root(n,x))
    out = out.replaceAllMapped(
      RegExp(r'root\(([^,]+),([^)]+)\)'),
      (m) => '\\sqrt[${m[1]}]{${m[2]}}',
    );
    out = out.replaceAllMapped(
      RegExp(r'root\(([^)]*)'),
      (m) {
        final inner = m[1]!;
        if (inner == c) return '\\sqrt[$_cursorBoxLatex]{\\square}';
        if (inner.contains(',')) {
          final parts = inner.split(',');
          final idx = parts[0];
          final rad = parts.length > 1 ? parts[1] : '';
          if (rad == c) return '\\sqrt[$idx]{$_cursorBoxLatex}';
          return '\\sqrt[$idx]{$rad\\square}';
        }
        return '\\sqrt[$inner]{\\square}';
      },
    );

    // 5b. Raíces cúbicas (³√)
    out = out.replaceAllMapped(
      RegExp(r'³√\(([^)]+)\)'),
      (m) {
        final inner = m[1]!;
        if (inner == c) return '\\sqrt[3]{$_cursorBoxLatex}';
        return '\\sqrt[3]{$inner}';
      },
    );
    out = out.replaceAllMapped(
      RegExp(r'³√\(([^)]*)'),
      (m) {
        final inner = m[1]!;
        if (inner == c) return '\\sqrt[3]{$_cursorBoxLatex}';
        return '\\sqrt[3]{$inner\\square}';
      },
    );
    out = out.replaceAllMapped(
      RegExp('³√($numPat)'),
      (m) => '\\sqrt[3]{${m[1]}}',
    );
    out = out.replaceAll('³√$c', '\\sqrt[3]{$_cursorBoxLatex}');
    out = out.replaceAll(RegExp(r'³√(?![\\{])'), r'\sqrt[3]{\square}');

    // 5c. Raíces cuadradas
    out = out.replaceAllMapped(
      RegExp(r'√\(([^)]+)\)'),
      (m) {
        final inner = m[1]!;
        if (inner == c) return '\\sqrt{$_cursorBoxLatex}';
        return '\\sqrt{$inner}';
      },
    );
    out = out.replaceAllMapped(
      RegExp(r'√\(([^)]*)'),
      (m) {
        final inner = m[1]!;
        if (inner == c) return '\\sqrt{$_cursorBoxLatex}';
        return '\\sqrt{$inner\\square}';
      },
    );
    out = out.replaceAllMapped(
      RegExp('√($numPat)'),
      (m) => '\\sqrt{${m[1]}}',
    );
    out = out.replaceAll('√$c', '\\sqrt{$_cursorBoxLatex}');
    out = out.replaceAll(RegExp(r'√(?![\\{])'), r'\sqrt{\square}');

    // 5d. Logaritmo en base arbitraria log_(base,arg)
    out = out.replaceAllMapped(
      RegExp(r'log_\(([^,]*),([^)]*)\)'),
      (m) {
        final base = m[1] == c ? _cursorBoxLatex : (m[1]!.isEmpty ? r'\square' : m[1]!);
        final arg = m[2] == c ? _cursorBoxLatex : (m[2]!.isEmpty ? r'\square' : m[2]!);
        return '\\log_{$base}\\left($arg\\right)';
      },
    );
    out = out.replaceAllMapped(
      RegExp(r'log_\(([^)]*)'),
      (m) {
        final inner = m[1]!;
        if (inner.contains(',')) {
          final parts = inner.split(',');
          final base = parts[0] == c ? _cursorBoxLatex : (parts[0].isEmpty ? r'\square' : parts[0]);
          final argRaw = parts.length > 1 ? parts[1] : '';
          final arg = argRaw == c ? _cursorBoxLatex : (argRaw.isEmpty ? r'\square' : argRaw);
          return '\\log_{$base}\\left($arg\\right)';
        }
        final base = inner == c ? _cursorBoxLatex : (inner.isEmpty ? _cursorBoxLatex : inner);
        return '\\log_{$base}\\left(\\square\\right)';
      },
    );

    // 5e. Funciones trigonométricas y log / ln
    out = _formatFunctionCalls(out, c);

    // 5f. Sexagesimal, porcentaje y constante pi
    out = out.replaceAll('°', '^\\circ ');
    out = out.replaceAll("''", "'' ");
    out = out.replaceAll('"', "'' ");
    out = out.replaceAll('%', r'\%');
    out = out.replaceAll('π', r'\pi ');
    out = out.replaceAllMapped(RegExp(r'\bpi\b'), (_) => r'\pi ');

    // 6. Memoria ANS y variables
    out = out.replaceAll('ANS', r'\text{ANS}');
    out = out.replaceAll('ans', r'\text{ANS}');

    // 7. Operadores de multiplicación española (\cdot), desigualdades e igualdad
    out = out
        .replaceAll('*', r' \cdot ')
        .replaceAll('+', ' + ')
        .replaceAll(':', ' : ')
        .replaceAll('<=', r' \le ')
        .replaceAll('≤', r' \le ')
        .replaceAll('>=', r' \ge ')
        .replaceAll('≥', r' \ge ')
        .replaceAll('<', ' < ')
        .replaceAll('>', ' > ')
        .replaceAll('=', ' = ');

    // 8. Reemplazar el centinela de cursor por marcador visual azul eléctrico
    out = out.replaceAll(c, _cursorMidLatex);

    return out;
  }

  /// Convierte cualquier estructura `frac(a, b)` o división `/` (sin importar si los
  /// operandos contienen variables, potencias, paréntesis compuestos o huecos vacíos)
  /// en fracciones verticales LaTeX `\frac{...}{...}`, garantizando 0 `/` residuales.
  static String _convertSlashesToLatex(String src, String cursorSentinel) {
    String out = src;

    // 1. Soportar plantilla explícita `frac(num, den)` si se recibe en crudo
    int fracSearch = 0;
    while (true) {
      final idx = out.indexOf('frac(', fracSearch);
      if (idx == -1) break;
      if (idx > 0 && RegExp(r'[a-zA-Z\\]').hasMatch(out[idx - 1])) {
        fracSearch = idx + 5;
        continue;
      }
      final openIdx = idx + 4;
      int depth = 1;
      int? closeIdx;
      int? commaIdx;
      for (int i = openIdx + 1; i < out.length; i++) {
        final ch = out[i];
        if (ch == '(') {
          depth++;
        } else if (ch == ')') {
          depth--;
          if (depth == 0) {
            closeIdx = i;
            break;
          }
        } else if (ch == ',' && depth == 1 && commaIdx == null) {
          commaIdx = i;
        }
      }
      if (commaIdx != null) {
        final endIdx = closeIdx ?? out.length;
        final rawNum = out.substring(openIdx + 1, commaIdx);
        final rawDen = out.substring(commaIdx + 1, endIdx);
        final replacement =
            '\\frac{${_formatFractionSlot(rawNum, cursorSentinel)}}{${_formatFractionSlot(rawDen, cursorSentinel)}}';
        final after = closeIdx != null ? out.substring(closeIdx + 1) : '';
        out = out.substring(0, idx) + replacement + after;
        fracSearch = idx + replacement.length;
      } else {
        fracSearch = idx + 5;
      }
    }

    // 2. Convertir de dentro hacia fuera todas las divisiones `/`
    int iterations = 0;
    while (out.contains('/') && iterations < 64) {
      iterations++;
      ({int numStart, int slashIdx, int denEnd})? chosen;
      ({int numStart, int slashIdx, int denEnd})? fallback;

      for (int i = 0; i < out.length; i++) {
        if (out[i] != '/') continue;
        final numStart = _scanNumeratorLeft(out, i, cursorSentinel);
        final denEnd = _scanDenominatorRight(out, i, cursorSentinel);
        final candidate = (numStart: numStart, slashIdx: i, denEnd: denEnd);
        fallback ??= candidate;

        final leftSlice = out.substring(numStart, i);
        final rightSlice = out.substring(i + 1, denEnd);
        if (!leftSlice.contains('/') && !rightSlice.contains('/')) {
          chosen = candidate;
          break;
        }
      }

      final target = chosen ?? fallback;
      if (target == null) break;

      final rawNum = out.substring(target.numStart, target.slashIdx);
      final rawDen = out.substring(target.slashIdx + 1, target.denEnd);
      final numTex = _formatFractionSlot(rawNum, cursorSentinel);
      final denTex = _formatFractionSlot(rawDen, cursorSentinel);

      out = '${out.substring(0, target.numStart)}\\frac{$numTex}{$denTex}${out.substring(target.denEnd)}';
    }

    return out;
  }

  static int _scanNumeratorLeft(String s, int slashIdx, String cursorSentinel) {
    int i = slashIdx - 1;
    while (i >= 0) {
      final ch = s[i];
      if (ch == ')') {
        int depth = 1;
        int j = i - 1;
        while (j >= 0 && depth > 0) {
          if (s[j] == ')') depth++;
          if (s[j] == '(') depth--;
          j--;
        }
        if (depth != 0) {
          return i + 1;
        }
        i = j;
        continue;
      }
      if (ch == '}') {
        int depth = 1;
        int j = i - 1;
        while (j >= 0 && depth > 0) {
          if (s[j] == '}') depth++;
          if (s[j] == '{') depth--;
          j--;
        }
        if (depth != 0) {
          return i + 1;
        }
        // Absorber argumentos opcionales [..] o grupos previos `{...}` y el `\comando`
        i = j;
        if (i >= 0 && s[i] == ']') {
          int bDepth = 1;
          int k = i - 1;
          while (k >= 0 && bDepth > 0) {
            if (s[k] == ']') bDepth++;
            if (s[k] == '[') bDepth--;
            k--;
          }
          if (bDepth == 0) i = k;
        }
        if (i >= 0 && s[i] != '}') {
          int k = i;
          while (k >= 0 && RegExp(r'[a-zA-Z]').hasMatch(s[k])) {
            k--;
          }
          if (k >= 0 && s[k] == r'\') {
            i = k - 1;
          }
        }
        continue;
      }
      if (ch == '^') {
        i--;
        continue;
      }
      if (ch == '-' || ch == '+') {
        if (i > 0 && s[i - 1] == '^') {
          i--;
          continue;
        }
        return i + 1;
      }
      if (_isFractionAtomChar(ch, cursorSentinel)) {
        i--;
        continue;
      }
      return i + 1;
    }
    return 0;
  }

  static int _scanDenominatorRight(String s, int slashIdx, String cursorSentinel) {
    int i = slashIdx + 1;
    if (i < s.length && cursorSentinel.isNotEmpty && s[i] == cursorSentinel) {
      i++;
    }
    if (i < s.length && s[i] == '-') {
      i++;
    }
    while (i < s.length) {
      final ch = s[i];
      if (ch == '(') {
        int depth = 1;
        int j = i + 1;
        while (j < s.length && depth > 0) {
          if (s[j] == '(') depth++;
          if (s[j] == ')') depth--;
          j++;
        }
        if (depth == 0) {
          i = j;
          continue;
        }
        // Paréntesis aún abierto mientras el usuario escribe: cortar solo ante `=`, `<`, `>`, `;`
        while (i < s.length &&
            s[i] != '=' &&
            s[i] != '<' &&
            s[i] != '>' &&
            s[i] != '≤' &&
            s[i] != '≥' &&
            s[i] != ';') {
          i++;
        }
        return i;
      }
      if (ch == '{') {
        int depth = 1;
        int j = i + 1;
        while (j < s.length && depth > 0) {
          if (s[j] == '{') depth++;
          if (s[j] == '}') depth--;
          j++;
        }
        i = j;
        continue;
      }
      if (ch == '[') {
        int depth = 1;
        int j = i + 1;
        while (j < s.length && depth > 0) {
          if (s[j] == '[') depth++;
          if (s[j] == ']') depth--;
          j++;
        }
        i = j;
        continue;
      }
      if (ch == r'\') {
        i++;
        while (i < s.length && RegExp(r'[a-zA-Z]').hasMatch(s[i])) {
          i++;
        }
        continue;
      }
      if (ch == '^') {
        i++;
        if (i < s.length && cursorSentinel.isNotEmpty && s[i] == cursorSentinel) {
          i++;
        }
        if (i < s.length && (s[i] == '-' || s[i] == '+')) {
          i++;
        }
        continue;
      }
      if (_isFractionAtomChar(ch, cursorSentinel)) {
        i++;
        continue;
      }
      return i;
    }
    return s.length;
  }

  static bool _isFractionAtomChar(String ch, String cursorSentinel) {
    if (cursorSentinel.isNotEmpty && ch == cursorSentinel) return true;
    final code = ch.codeUnitAt(0);
    if ((code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122)) {
      return true; // a-z
    }
    return ch == '.' ||
        ch == 'π' ||
        ch == '°' ||
        ch == '%' ||
        ch == "'" ||
        ch == '"' ||
        ch == '√' ||
        ch == '³' ||
        ch == '_' ||
        ch == '⁻' ||
        ch == '¹' ||
        ch == '²' ||
        ch == '⁴' ||
        ch == '⁵' ||
        ch == '⁶' ||
        ch == '⁷' ||
        ch == '⁸' ||
        ch == '⁹' ||
        ch == '⁰' ||
        ch == 'ⁿ';
  }

  static String _formatFractionSlot(String rawSlot, String cursorSentinel) {
    var trimmed = rawSlot.trim();
    if (trimmed.isEmpty) return r'\square';
    if (cursorSentinel.isNotEmpty && trimmed == cursorSentinel) {
      return _cursorBoxLatex;
    }

    final leadCursor =
        cursorSentinel.isNotEmpty && trimmed.startsWith(cursorSentinel);
    final trailCursor =
        cursorSentinel.isNotEmpty && trimmed.endsWith(cursorSentinel);
    var core = trimmed;
    if (leadCursor) core = core.substring(cursorSentinel.length).trimLeft();
    if (trailCursor &&
        !(cursorSentinel.isNotEmpty && core == cursorSentinel)) {
      core = core.substring(0, core.length - cursorSentinel.length).trimRight();
    }

    if (_hasOuterBalancedParens(core)) {
      final inner = core.substring(1, core.length - 1).trim();
      final rebuilt =
          '${leadCursor ? cursorSentinel : ''}$inner${trailCursor ? cursorSentinel : ''}';
      if (rebuilt.isEmpty) return r'\square';
      if (cursorSentinel.isNotEmpty && rebuilt == cursorSentinel) {
        return _cursorBoxLatex;
      }
      return rebuilt;
    }

    return trimmed;
  }

  static bool _hasOuterBalancedParens(String s) {
    if (s.length < 2 || !s.startsWith('(') || !s.endsWith(')')) return false;
    int depth = 0;
    for (int i = 0; i < s.length; i++) {
      if (s[i] == '(') depth++;
      if (s[i] == ')') depth--;
      if (depth == 0 && i < s.length - 1) return false;
    }
    return depth == 0;
  }

  static String _formatFunctionCalls(String src, String cursorSentinel) {
    final mapping = <String, String>{
      'sin⁻¹(': r'\sin^{-1}',
      'cos⁻¹(': r'\cos^{-1}',
      'tan⁻¹(': r'\tan^{-1}',
      'arcsin(': r'\sin^{-1}',
      'arccos(': r'\cos^{-1}',
      'arctan(': r'\tan^{-1}',
      'asin(': r'\sin^{-1}',
      'acos(': r'\cos^{-1}',
      'atan(': r'\tan^{-1}',
      'sin(': r'\sin',
      'cos(': r'\cos',
      'tan(': r'\tan',
      'log(': r'\log',
      'ln(': r'\ln',
    };

    String out = src;
    for (final entry in mapping.entries) {
      final token = entry.key;
      final latexFn = entry.value;
      int searchFrom = 0;
      while (true) {
        final idx = out.indexOf(token, searchFrom);
        if (idx == -1) break;
        final openIdx = idx + token.length - 1;
        int depth = 1;
        int? closeIdx;
        for (int i = openIdx + 1; i < out.length; i++) {
          if (out[i] == '(') depth++;
          if (out[i] == ')') {
            depth--;
            if (depth == 0) {
              closeIdx = i;
              break;
            }
          }
        }
        if (closeIdx != null) {
          final inner = out.substring(openIdx + 1, closeIdx);
          final formattedInner = inner == cursorSentinel
              ? _cursorBoxLatex
              : (inner.isEmpty ? r'\square' : inner);
          final replacement = '$latexFn\\left($formattedInner\\right)';
          out = out.substring(0, idx) + replacement + out.substring(closeIdx + 1);
          searchFrom = idx + replacement.length;
        } else {
          final inner = out.substring(openIdx + 1);
          final formattedInner = inner == cursorSentinel
              ? _cursorBoxLatex
              : (inner.isEmpty ? r'\square' : '$inner\\square');
          final replacement = '$latexFn\\left($formattedInner\\right)';
          out = out.substring(0, idx) + replacement;
          break;
        }
      }
    }
    return out;
  }

  /// Parsea la cadena del teclado y devuelve el AST tipado para StepEvaluator
  ExprNode parse(String input) {
    final cleaned = input.replaceAll(' ', '');
    if (cleaned.isEmpty) {
      return const IntNode(0);
    }

    _tokens = _tokenize(cleaned);
    _pos = 0;

    final result = _parseAddSub();
    if (_pos < _tokens.length) {
      throw const FormatException('Expresión incompleta o paréntesis sin cerrar');
    }
    return result;
  }

  List<String> _tokenize(String src) {
    final regex = RegExp(
      r"\d+\.\d+|\.\d+|\d+|''|[+\-*:/^(),%°'"
      '"]'
      r'|arcsin|arccos|arctan|sin⁻¹|cos⁻¹|tan⁻¹|asin|acos|atan|sin|cos|tan|log_|log|ln|sqrt|cbrt|root|mcm|mcd|ANS|ans|pi|π|[√³ⁿ]|[A-Fa-fXYxy]',
    );
    return regex.allMatches(src).map((m) => m.group(0)!).toList();
  }

  String? get _current => _pos < _tokens.length ? _tokens[_pos] : null;

  String _consume() => _tokens[_pos++];

  bool _canStartPrimary(String? token) {
    if (token == null) return false;
    if (token == '(' ||
        token == '√' ||
        token == 'sqrt' ||
        token == '³' ||
        token == 'cbrt' ||
        token == 'root' ||
        token == 'ⁿ' ||
        token == 'mcm' ||
        token == 'mcd' ||
        token == 'sin' ||
        token == 'cos' ||
        token == 'tan' ||
        token == 'asin' ||
        token == 'acos' ||
        token == 'atan' ||
        token == 'sin⁻¹' ||
        token == 'cos⁻¹' ||
        token == 'tan⁻¹' ||
        token == 'arcsin' ||
        token == 'arccos' ||
        token == 'arctan' ||
        token == 'log' ||
        token == 'log_' ||
        token == 'ln' ||
        token == 'pi' ||
        token == 'π') {
      return true;
    }
    if (token.toUpperCase() == 'ANS') return true;
    if (RegExp(r'^[A-Fa-fXYxy]$').hasMatch(token)) return true;
    return false;
  }

  // Nivel 1: Suma y Resta (izquierda a derecha)
  ExprNode _parseAddSub() {
    ExprNode left = _parseMulDiv();
    while (_current == '+' || _current == '-') {
      final opToken = _consume();
      final right = _parseMulDiv();
      left = BinaryOpNode(
        left,
        opToken == '+' ? BinaryOperator.add : BinaryOperator.subtract,
        right,
      );
    }
    return left;
  }

  // Nivel 2: Multiplicación (*) y División (:, /)
  ExprNode _parseMulDiv() {
    ExprNode left = _parseUnary();
    while (_current == '*' ||
        _current == ':' ||
        _current == '/' ||
        _canStartPrimary(_current)) {
      BinaryOperator op = BinaryOperator.multiply;
      if (_current == '*' || _current == ':' || _current == '/') {
        final opToken = _consume();
        op = opToken == '*' ? BinaryOperator.multiply : BinaryOperator.divide;
      }
      final right = _parseUnary();
      left = BinaryOpNode(
        left,
        op,
        right,
      );
    }
    return left;
  }

  // Nivel 3: Signo menos unario (-3^2 se evalúa como UnaryMinusNode(PowerNode(3, 2)))
  ExprNode _parseUnary() {
    if (_current == '-') {
      _consume();
      final operand = _parseUnary();
      return UnaryMinusNode(operand);
    }
    if (_current == '+') {
      _consume();
      return _parseUnary();
    }
    return _parsePower();
  }

  // Nivel 4: Potencias (x^n, 10^-5, 10^(-2)) - Mayor prioridad que el menos unario
  ExprNode _parsePower() {
    ExprNode base = _parsePostfix();
    while (_current == '^') {
      _consume();
      int exp;
      if (_current == '(') {
        _consume();
        final expNode = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis en el exponente');
        }
        _consume();
        final evalExp = _evalSimpleInt(expNode);
        if (evalExp == null) {
          throw const FormatException('El exponente debe ser un número entero');
        }
        exp = evalExp;
      } else {
        int sign = 1;
        if (_current == '-') {
          _consume();
          sign = -1;
        }
        if (_current == null || int.tryParse(_current!) == null) {
          throw const FormatException('Falta el exponente entero');
        }
        exp = sign * int.parse(_consume());
      }
      base = PowerNode(base, exp);
    }
    return base;
  }

  ExprNode _parsePostfix() {
    ExprNode node = _parsePrimary();
    while (_current == '%' || _current == '°') {
      if (_current == '%') {
        _consume();
        node = PercentNode(node);
      } else if (_current == '°') {
        _consume(); // '°'
        if (node is DecimalNode) {
          node = DecimalNode(node.rawText, isDegrees: true);
        } else if (node is IntNode) {
          int min = 0;
          double sec = 0;
          bool hasMin = false;
          bool hasSec = false;
          if (_current != null &&
              int.tryParse(_current!) != null &&
              _pos + 1 < _tokens.length &&
              _tokens[_pos + 1] == "'") {
            min = int.parse(_consume());
            _consume(); // "'"
            hasMin = true;
          }
          if (_current != null &&
              double.tryParse(_current!) != null &&
              _pos + 1 < _tokens.length &&
              (_tokens[_pos + 1] == '"' || _tokens[_pos + 1] == "''")) {
            sec = double.parse(_consume());
            _consume(); // '"' or "''"
            hasSec = true;
          }
          node = DmsNode(
            degrees: node.value,
            minutes: min,
            seconds: sec,
            hasMinutes: hasMin,
            hasSeconds: hasSec,
          );
        }
      }
    }
    return node;
  }

  int? _evalSimpleInt(ExprNode node) {
    return switch (node) {
      IntNode(:final value) => value,
      UnaryMinusNode(:final operand) => () {
          final v = _evalSimpleInt(operand);
          return v == null ? null : -v;
        }(),
      BinaryOpNode(:final left, :final op, :final right) => () {
          final l = _evalSimpleInt(left);
          final r = _evalSimpleInt(right);
          if (l == null || r == null) return null;
          return switch (op) {
            BinaryOperator.add => l + r,
            BinaryOperator.subtract => l - r,
            BinaryOperator.multiply => l * r,
            BinaryOperator.divide => (r != 0 && l % r == 0) ? l ~/ r : null,
          };
        }(),
      _ => null,
    };
  }

  // Nivel 5: Paréntesis, Raíces (√, ³√, root), Fracciones (a/b), mcm/mcd y Números enteros
  ExprNode _parsePrimary() {
    final token = _current;
    if (token == null) {
      throw const FormatException('Expresión incompleta');
    }

    if (token == 'mcm' || token == 'mcd') {
      final isMcm = token == 'mcm';
      _consume();
      if (_current != '(') {
        throw const FormatException('Se esperaba "(" después de mcm/mcd');
      }
      _consume(); // '('
      if (_current == ')') {
        throw const FormatException('Introduce al menos 2 números en mcm/mcd');
      }
      final args = <ExprNode>[_parseAddSub()];
      while (_current == ',') {
        _consume(); // ','
        if (_current == ')') {
          throw const FormatException('Falta introducir el siguiente número tras la coma');
        }
        args.add(_parseAddSub());
      }
      if (_current != ')') {
        throw const FormatException('Falta cerrar paréntesis ")" en mcm/mcd');
      }
      _consume(); // ')'
      if (args.length < 2) {
        throw FormatException(
          '${isMcm ? "m.c.m." : "M.C.D."} requiere al menos 2 números (pulsa ▶ o . para añadir más)',
        );
      }
      return isMcm ? McmNode(args) : McdNode(args);
    }

    if (token == '³' || token == 'cbrt') {
      _consume();
      if (_current == '√') _consume();
      if (_current == '(') {
        _consume();
        final inside = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis en la raíz cúbica');
        }
        _consume();
        return CbrtNode(inside);
      }
      final inside = _parsePrimary();
      return CbrtNode(inside);
    }

    if (token == 'root' || token == 'ⁿ') {
      _consume();
      if (_current == '√') _consume();
      if (_current == '(') {
        _consume();
        final firstArg = _parseAddSub();
        if (_current == ',') {
          _consume(); // ','
          final secondArg = _parseAddSub();
          if (_current != ')') {
            throw const FormatException('Falta cerrar paréntesis en la raíz');
          }
          _consume(); // ')'
          int n = 2;
          if (firstArg is IntNode) {
            n = firstArg.value;
          }
          return NthRootNode(n, secondArg);
        } else {
          if (_current != ')') {
            throw const FormatException('Falta cerrar paréntesis en la raíz');
          }
          _consume();
          return SqrtNode(firstArg);
        }
      }
      final inside = _parsePrimary();
      return SqrtNode(inside);
    }

    if (token == '√' || token == 'sqrt') {
      _consume();
      if (_current == '(') {
        _consume();
        final inside = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis en la raíz');
        }
        _consume();
        return SqrtNode(inside);
      }
      final inside = _parsePrimary();
      return SqrtNode(inside);
    }

    if (token == '(') {
      _consume(); // '('
      // Caso especial: número negativo entre paréntesis como (-3) para (-3)^2
      if (_current == '-' &&
          _pos + 2 < _tokens.length &&
          int.tryParse(_tokens[_pos + 1]) != null &&
          _tokens[_pos + 2] == ')') {
        _consume(); // '-'
        final val = int.parse(_consume());
        _consume(); // ')'
        return UnaryMinusNode(IntNode(val), hasExplicitParentheses: true);
      }

      final inside = _parseAddSub();
      if (_current != ')') {
        throw const FormatException('Falta cerrar paréntesis )');
      }
      _consume(); // ')'
      if (inside is BinaryOpNode) {
        return BinaryOpNode(inside.left, inside.op, inside.right, parenthesized: true);
      }
      return inside;
    }

    if (token.toUpperCase() == 'ANS') {
      _consume();
      return const VariableNode('ANS');
    }

    if (token == 'pi' || token == 'π') {
      _consume();
      return const PiNode();
    }

    final trigFn = _matchTrigFunction(token);
    if (trigFn != null) {
      _consume();
      if (_current == '(') {
        _consume();
        final arg = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis ")" en función trigonométrica');
        }
        _consume();
        return TrigNode(trigFn, arg);
      }
      final arg = _parsePrimary();
      return TrigNode(trigFn, arg);
    }

    if (token == 'ln') {
      _consume();
      if (_current == '(') {
        _consume();
        final arg = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis ")" en ln');
        }
        _consume();
        return LogNode(arg: arg, isNaturalLn: true);
      }
      return LogNode(arg: _parsePrimary(), isNaturalLn: true);
    }

    if (token == 'log') {
      _consume();
      if (_current == '(') {
        _consume();
        final firstArg = _parseAddSub();
        if (_current == ',') {
          _consume();
          final secondArg = _parseAddSub();
          if (_current != ')') {
            throw const FormatException('Falta cerrar paréntesis ")" en log');
          }
          _consume();
          return LogNode(base: firstArg, arg: secondArg);
        }
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis ")" en log');
        }
        _consume();
        return LogNode(arg: firstArg);
      }
      return LogNode(arg: _parsePrimary());
    }

    if (token == 'log_') {
      _consume();
      if (_current == '(') {
        _consume();
        final baseArg = _parseAddSub();
        if (_current != ',') {
          throw const FormatException('Pulsa ▶ tras la base para introducir el argumento del logaritmo');
        }
        _consume();
        final valArg = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis ")" en logaritmo');
        }
        _consume();
        return LogNode(base: baseArg, arg: valArg);
      }
      final baseArg = _parsePrimary();
      if (_current != '(') {
        throw const FormatException('Se esperaba "(" tras la base del logaritmo');
      }
      _consume();
      final valArg = _parseAddSub();
      if (_current != ')') {
        throw const FormatException('Falta cerrar paréntesis ")" en logaritmo');
      }
      _consume();
      return LogNode(base: baseArg, arg: valArg);
    }

    final isVar = RegExp(r'^[A-Fa-fXYxy]$').hasMatch(token);
    if (isVar) {
      _consume();
      return VariableNode(token.toUpperCase());
    }

    final intVal = int.tryParse(token);
    if (intVal != null) {
      _consume();
      // Si justo después del número hay una barra '/', creamos un FractionNode(num, den)
      if (_current == '/') {
        _consume(); // '/'
        if (_current == null || int.tryParse(_current!) == null) {
          throw const FormatException('Falta el denominador de la fracción');
        }
        final denVal = int.parse(_consume());
        return FractionNode(intVal, denVal);
      }
      return IntNode(intVal);
    }

    if (token.contains('.') && double.tryParse(token) != null) {
      _consume();
      return DecimalNode(token);
    }

    throw FormatException('Símbolo inesperado: $token');
  }

  static TrigFunction? _matchTrigFunction(String token) {
    return switch (token) {
      'sin' => TrigFunction.sin,
      'cos' => TrigFunction.cos,
      'tan' => TrigFunction.tan,
      'asin' || 'arcsin' || 'sin⁻¹' => TrigFunction.asin,
      'acos' || 'arccos' || 'cos⁻¹' => TrigFunction.acos,
      'atan' || 'arctan' || 'tan⁻¹' => TrigFunction.atan,
      _ => null,
    };
  }
}
