import 'cursor_navigation_helper.dart';
import 'template_navigation_helper.dart';
import 'slash_fraction_converter.dart';

class LiveLatexFormatter {
  static const String _cursorSentinel = '\uE000';
  static const String _cursorMidLatex = r'\textcolor{#2E86DE}{\mid}';
  static const String _cursorBoxLatex = r'\textcolor{#2E86DE}{\blacksquare}';

  static String finalizeForEvaluation(String raw) {
    var out = TemplateNavigationHelper.finalizeMcmMcdInput(raw);
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
      final safePos = CursorNavigationHelper.snapCursorOutsideKeywords(raw, cursorPos);
      out = raw.substring(0, safePos) + _cursorSentinel + raw.substring(safePos);
    }

    const c = _cursorSentinel;
    const numPat = r'(?:(?:\d+|' + c + r'\d+)(?:\.(?:\d*|' + c + r'\d*))?|\d*' + c + r'\d*(?:\.\d*)?)';
    const atomPat =
        r'(?:[0-9a-zA-Zπ.]+' + c + r'[0-9a-zA-Zπ.]*|' + c + r'[0-9a-zA-Zπ.]+|[0-9a-zA-Zπ.]+)';

    // 0. Conversión universal por bloques de cualquier división `/` o `frac(a, b)`
    //    a fracción vertical `\frac{...}{...}` (incluye fracciones vacías, negativas,
    //    con potencias `x^2`, funciones o paréntesis compuestos `(x+2)/(x-1)`).
    out = SlashFractionConverter.convertSlashesToLatex(out, c);

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

    // 0c. Placeholders tenues para huecos a y b en binomios e identidades notables ( + ), ( - )
    out = out.replaceAllMapped(
      RegExp(r'\(\s*(' + c + r'?)\s*([+\-])\s*(' + c + r'?)\s*\)'),
      (m) {
        final slotA = m[1]!;
        final sign = m[2]!;
        final slotB = m[3]!;
        final formattedA = slotA == c
            ? _cursorBoxLatex
            : (slotA.isEmpty ? r'{\color{gray} a}' : slotA);
        final formattedB = slotB == c
            ? _cursorBoxLatex
            : (slotB.isEmpty ? r'{\color{gray} b}' : slotB);
        return '($formattedA $sign $formattedB)';
      },
    );
    out = out.replaceAllMapped(
      RegExp(r'\(([^()+\-]+)\s*([+\-])\s*(' + c + r'?)\s*\)'),
      (m) {
        final leftExpr = m[1]!;
        final sign = m[2]!;
        final slotB = m[3]!;
        final formattedB = slotB == c
            ? _cursorBoxLatex
            : (slotB.isEmpty ? r'{\color{gray} b}' : slotB);
        return '($leftExpr $sign $formattedB)';
      },
    );
    out = out.replaceAllMapped(
      RegExp(r'\(\s*(' + c + r'?)\s*([+\-])\s*([^()+\-]+)\)'),
      (m) {
        final slotA = m[1]!;
        final sign = m[2]!;
        final rightExpr = m[3]!;
        final formattedA = slotA == c
            ? _cursorBoxLatex
            : (slotA.isEmpty ? r'{\color{gray} a}' : slotA);
        return '($formattedA $sign $rightExpr)';
      },
    );

    // 3. Potencias con paréntesis libre ^(expr), exponente negativo ^-n y ^n
    out = _replaceBalancedPrefix(out, '^(', (inner, isClosed) {
      if (inner == c) return '^{$_cursorBoxLatex}';
      if (!isClosed) {
        if (inner.isEmpty) return '^{\\square}';
        return '^{$inner}';
      }
      return '^{$inner}';
    });
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
          if (rad.isEmpty) return '\\sqrt[$idx]{\\square}';
          return '\\sqrt[$idx]{$rad}';
        }
        return '\\sqrt[$inner]{\\square}';
      },
    );

    // 5b. Raíces cúbicas (³√)
    out = _replaceBalancedPrefix(out, '³√(', (inner, isClosed) {
      if (inner == c) return '\\sqrt[3]{$_cursorBoxLatex}';
      if (!isClosed) {
        if (inner.isEmpty) return '\\sqrt[3]{\\square}';
        return '\\sqrt[3]{$inner}';
      }
      return '\\sqrt[3]{$inner}';
    });
    out = out.replaceAllMapped(
      RegExp('³√($numPat)'),
      (m) => '\\sqrt[3]{${m[1]}}',
    );
    out = out.replaceAll('³√$c', '\\sqrt[3]{$_cursorBoxLatex}');
    out = out.replaceAll(RegExp(r'³√(?![\\{])'), r'\sqrt[3]{\square}');

    // 5c. Raíces cuadradas
    out = _replaceBalancedPrefix(out, '√(', (inner, isClosed) {
      if (inner == c) return '\\sqrt{$_cursorBoxLatex}';
      if (!isClosed) {
        if (inner.isEmpty) return '\\sqrt{\\square}';
        return '\\sqrt{$inner}';
      }
      return '\\sqrt{$inner}';
    });
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

  static String _replaceBalancedPrefix(
    String src,
    String prefix,
    String Function(String inner, bool isClosed) replacer,
  ) {
    String out = src;
    int searchFrom = 0;
    while (true) {
      final idx = out.indexOf(prefix, searchFrom);
      if (idx == -1) break;
      final openParen = idx + prefix.length - 1;
      int depth = 1;
      int? closeIdx;
      for (int i = openParen + 1; i < out.length; i++) {
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
        final inner = out.substring(openParen + 1, closeIdx);
        final replacement = replacer(inner, true);
        out = out.substring(0, idx) + replacement + out.substring(closeIdx + 1);
        searchFrom = idx + replacement.length;
      } else {
        final inner = out.substring(openParen + 1);
        final replacement = replacer(inner, false);
        out = out.substring(0, idx) + replacement;
        break;
      }
    }
    return out;
  }

  static String _formatFunctionCalls(String src, String cursorSentinel) {
    // Soporte para potencias de funciones trigonométricas directas (ej: sin^2(x) o sin^(2)(x))
    final trigPowerPattern = RegExp(
      r'\b(sin|cos|tan)\^([0-9]+|\([0-9]+\))\(',
      caseSensitive: false,
    );
    String out = src;
    int pSearch = 0;
    while (true) {
      final m = trigPowerPattern.firstMatch(out.substring(pSearch));
      if (m == null) break;
      final fullMatch = m.group(0)!;
      final matchStart = pSearch + m.start;
      final fn = m.group(1)!.toLowerCase();
      final exp = m.group(2)!.replaceAll('(', '').replaceAll(')', '');
      final openIdx = matchStart + fullMatch.length - 1;
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
      final inner = closeIdx != null
          ? out.substring(openIdx + 1, closeIdx)
          : out.substring(openIdx + 1);
      final recInner = _formatFunctionCalls(inner, cursorSentinel);
      final formattedInner = recInner == cursorSentinel
          ? _cursorBoxLatex
          : (recInner.isEmpty ? r'\square' : recInner);
      final replacement = closeIdx != null
          ? '\\$fn^{$exp}\\left($formattedInner\\right)'
          : '\\$fn^{$exp}($formattedInner';
      final endIdx = closeIdx != null ? closeIdx + 1 : out.length;
      out = out.substring(0, matchStart) + replacement + out.substring(endIdx);
      pSearch = matchStart + replacement.length;
      if (closeIdx == null) break;
    }

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
          final recInner = _formatFunctionCalls(inner, cursorSentinel);
          final formattedInner = recInner == cursorSentinel
              ? _cursorBoxLatex
              : (recInner.isEmpty ? r'\square' : recInner);
          final replacement = '$latexFn\\left($formattedInner\\right)';
          out = out.substring(0, idx) + replacement + out.substring(closeIdx + 1);
          searchFrom = idx + replacement.length;
        } else {
          final inner = out.substring(openIdx + 1);
          final recInner = _formatFunctionCalls(inner, cursorSentinel);
          final formattedInner = recInner == cursorSentinel
              ? _cursorBoxLatex
              : (recInner.isEmpty ? r'\square' : recInner);
          final replacement = '$latexFn($formattedInner';
          out = out.substring(0, idx) + replacement;
          break;
        }
      }
    }
    return out;
  }

  /// Parsea la cadena del teclado y devuelve el AST tipado para StepEvaluator
}
