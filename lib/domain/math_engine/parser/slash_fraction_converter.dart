// Extracted from ExpressionParser for modularity and 500-line limit.
import '../../../core/editor/lcd_cursor_tokens.dart';

class SlashFractionConverter {
  static const String cursorSentinel = '\uE000';
  static const String cursorMidLatex = LcdCursor.bar;
  static const String cursorBoxLatex = LcdCursor.box;

  static String convertSlashesToLatex(String src, String cursorSentinel) {
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
            '\\frac{${formatFractionSlot(rawNum, cursorSentinel)}}{${formatFractionSlot(rawDen, cursorSentinel)}}';
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
        final numStart = scanNumeratorLeft(out, i, cursorSentinel);
        final denEnd = scanDenominatorRight(out, i, cursorSentinel);
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
      final numTex = formatFractionSlot(rawNum, cursorSentinel);
      final denTex = formatFractionSlot(rawDen, cursorSentinel);

      out = '${out.substring(0, target.numStart)}\\frac{$numTex}{$denTex}${out.substring(target.denEnd)}';
    }

    return out;
  }

  static int scanNumeratorLeft(String s, int slashIdx, String cursorSentinel) {
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
      if (isFractionAtomChar(ch, cursorSentinel)) {
        i--;
        continue;
      }
      return i + 1;
    }
    return 0;
  }

  /// Indice justo despues del `)` que cierra el grupo abierto en [open]; `null` si sigue abierto.
  static int? _closedGroupEnd(String s, int open) {
    var depth = 0;
    for (var j = open; j < s.length; j++) {
      if (s[j] == '(') depth++;
      if (s[j] == ')') {
        depth--;
        if (depth == 0) return j + 1;
      }
    }
    return null;
  }

  /// Fin de un denominador-plantilla `(den)`: solo las potencias (`^2`, `^(n)`) siguen unidas a el
  /// (`1/(2)^2` = 1/4). Lo que se escribe despues -cifras, letras, `(`, y el propio cursor- queda
  /// FUERA de la fraccion, igual que lo evalua el parser (`(1)/(2)3` = 3/2).
  static int _templateDenominatorEnd(String s, int groupEnd, String sentinel) {
    var i = groupEnd;
    while (i < s.length && s[i] == '^') {
      i++;
      if (sentinel.isNotEmpty && i < s.length && s[i] == sentinel) i++;
      if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
      if (i < s.length && s[i] == '(') {
        i = _closedGroupEnd(s, i) ?? s.length;
        continue;
      }
      final runStart = i;
      while (i < s.length && isFractionAtomChar(s[i], sentinel)) {
        i++;
      }
      if (sentinel.isNotEmpty && i > runStart && s[i - 1] == sentinel) i--;
    }
    return i;
  }

  static int scanDenominatorRight(String s, int slashIdx, String cursorSentinel) {
    int i = slashIdx + 1;
    if (i < s.length && s[i] == '(') {
      final end = _closedGroupEnd(s, i);
      if (end != null) return _templateDenominatorEnd(s, end, cursorSentinel);
    }
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
      if (isFractionAtomChar(ch, cursorSentinel)) {
        i++;
        continue;
      }
      return i;
    }
    return s.length;
  }

  static bool isFractionAtomChar(String ch, String cursorSentinel) {
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

  static String formatFractionSlot(String rawSlot, String cursorSentinel) {
    var trimmed = rawSlot.trim();
    if (trimmed.isEmpty) return r'\square';
    if (cursorSentinel.isNotEmpty && trimmed == cursorSentinel) {
      return cursorBoxLatex;
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

    if (hasOuterBalancedParens(core)) {
      final inner = core.substring(1, core.length - 1).trim();
      final rebuilt =
          '${leadCursor ? cursorSentinel : ''}$inner${trailCursor ? cursorSentinel : ''}';
      if (rebuilt.isEmpty) return r'\square';
      if (cursorSentinel.isNotEmpty && rebuilt == cursorSentinel) {
        return cursorBoxLatex;
      }
      return rebuilt;
    }

    return trimmed;
  }

  static bool hasOuterBalancedParens(String s) {
    if (s.length < 2 || !s.startsWith('(') || !s.endsWith(')')) return false;
    int depth = 0;
    for (int i = 0; i < s.length; i++) {
      if (s[i] == '(') depth++;
      if (s[i] == ')') depth--;
      if (depth == 0 && i < s.length - 1) return false;
    }
    return depth == 0;
  }

}
