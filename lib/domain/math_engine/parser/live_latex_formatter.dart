import 'balanced_scan.dart';
import 'live_function_formatter.dart';
import 'cursor_navigation_helper.dart';
import 'template_navigation_helper.dart';
import 'slash_fraction_converter.dart';
import '../arithmetic/classwiz_constants.dart';

class LiveLatexFormatter {
  static const String _cursorSentinel = '\uE000';
  static const String _cursorMidLatex = r'\textcolor{#1A2530}{\mid}';
  static const String _cursorBoxLatex = r'\textcolor{#1A2530}{\blacksquare}';

  static String finalizeForEvaluation(String raw) {
    var out = TemplateNavigationHelper.finalizeMcmMcdInput(raw);
    // Pila de aperturas pendientes: cierra en orden inverso `(` y `{`.
    final stack = <String>[];
    for (int i = 0; i < out.length; i++) {
      final ch = out[i];
      if (ch == '(' || ch == '{') {
        stack.add(ch);
      } else if ((ch == ')' || ch == '}') && stack.isNotEmpty) {
        stack.removeLast();
      }
    }
    if (stack.isNotEmpty) {
      out += stack.reversed.map((o) => o == '(' ? ')' : '}').join();
    }
    return out;
  }

  static String _formatMcmMcdLiveArgs(String inner) {
    const c = _cursorSentinel;
    final parts = BalancedScan.splitTopLevel(inner);
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
  static String rawToLiveLatex(String raw, {int? cursorPos, bool overwrite = false}) {
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
    out = _replaceBalancedPrefix(
      out,
      'mcm(',
      (inner, _) => '\\text{m.c.m.}\\left(${_formatMcmMcdLiveArgs(inner)}\\right)',
    );
    out = _replaceBalancedPrefix(
      out,
      'mcd(',
      (inner, _) => '\\text{M.C.D.}\\left(${_formatMcmMcdLiveArgs(inner)}\\right)',
    );

    // 0c. Placeholders tenues para huecos a y b en binomios e identidades notables ( + ), ( - )
    //     (no se aplican a argumentos de funciones: `sin(-30)`, `√(-4)`).
    const notFn = r'(?<!sin|cos|tan|ln|log|√|⁻¹|_|root|asin|acos|atan|\^)';
    out = out.replaceAllMapped(
      RegExp(notFn + r'\(\s*(' + c + r'?)\s*([+\-])\s*(' + c + r'?)\s*\)'),
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
      RegExp(notFn + r'\(([^()+\-]+)\s*([+\-])\s*(' + c + r'?)\s*\)'),
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
      RegExp(notFn + r'\(\s*(' + c + r'?)\s*([+\-])\s*([^()+\-]+)\)'),
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
    out = _replaceBalancedPrefix(out, 'root(', (inner, closed) {
      if (inner == c) return '\\sqrt[$_cursorBoxLatex]{\\square}';
      final parts = BalancedScan.splitTopLevel(inner);
      if (parts.length > 1) {
        final idx = parts[0];
        final rad = parts.sublist(1).join(',');
        if (rad == c && !closed) return '\\sqrt[$idx]{$_cursorBoxLatex}';
        if (rad.isEmpty) return '\\sqrt[$idx]{\\square}';
        return '\\sqrt[$idx]{$rad}';
      }
      return '\\sqrt[$inner]{\\square}';
    });

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

    // 5d0. Funciones trigonométricas y log / ln (antes de log_ para no robarle cierres)
    out = _formatFunctionCalls(out, c);

    // 5f. Sexagesimal, porcentaje y constante pi
    out = out.replaceAll('°', '^\\circ ');
    out = out.replaceAll("''", "'' ");
    out = out.replaceAll('"', "'' ");
    out = out.replaceAll('%', r'\%');
    out = out.replaceAll('π', r'\pi ');
    out = out.replaceAllMapped(RegExp(r'\bpi\b'), (_) => r'\pi ');

    // 6. Memoria ANS y variables
    out = out.replaceAll('Ran#', r'\mathrm{Ran}\#');
    out = out.replaceAllMapped(
      ClassWizConstants.tokenRe,
      (m) => ClassWizConstants.byToken(m.group(0)!)!.latex,
    );
    for (final (tok, tex) in const [
      ('#k', r'\mathrm{k}'), ('#M', r'\mathrm{M}'), ('#G', r'\mathrm{G}'),
      ('#m', r'\mathrm{m}'), ('#u', r'\mu '), ('#n', r'\mathrm{n}'),
      ('#r', r'^{r}'), ('#g', r'^{g}'),
    ]) {
      out = out.replaceAll(tok, tex);
    }
    out = out.replaceAll('ANS', r'\text{Ans}');
    out = out.replaceAll('ans', r'\text{Ans}');

    // 7. Operadores de multiplicación española (\cdot), desigualdades e igualdad
    out = out
        .replaceAll('*', r' \cdot ')
        .replaceAll('+', ' + ')
        .replaceAllMapped(
          RegExp(r'(?<=[0-9a-zA-Zπ)}\]>])\s*-\s*'),
          (_) => ' - ',
        )
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll('∶', r' \;{:}\; ')
        .replaceAll(':', ' : ')
        .replaceAll('<=', r' \le ')
        .replaceAll('≤', r' \le ')
        .replaceAll('>=', r' \ge ')
        .replaceAll('≥', r' \ge ')
        .replaceAll('<', ' < ')
        .replaceAll('>', ' > ')
        .replaceAll('=', ' = ');

    // 8. Reemplazar el centinela de cursor por marcador visual azul eléctrico
    out = out.replaceAll(c, overwrite ? _cursorBoxLatex : _cursorMidLatex);

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
        final inner =
            _replaceBalancedPrefix(out.substring(openParen + 1, closeIdx), prefix, replacer);
        final replacement = replacer(inner, true);
        out = out.substring(0, idx) + replacement + out.substring(closeIdx + 1);
        searchFrom = idx + replacement.length;
      } else {
        final inner = _replaceBalancedPrefix(out.substring(openParen + 1), prefix, replacer);
        final replacement = replacer(inner, false);
        out = out.substring(0, idx) + replacement;
        break;
      }
    }
    return out;
  }

  static String _formatFunctionCalls(String src, String cursorSentinel) =>
      LiveFunctionFormatter.format(src, cursorSentinel, _cursorBoxLatex);

  /// Parsea la cadena del teclado y devuelve el AST tipado para StepEvaluator
}
