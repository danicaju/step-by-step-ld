/// Sanitizador defensivo de renderizado: TODA formula pasa por aqui antes de `Math.tex`.
///
/// Garantiza que flutter_math_fork recibe LaTeX bien formado:
///  * repara comandos comidos por un escape Dart perdido (`"\textcolor"` -> TAB+`extcolor`);
///  * elimina caracteres de control, `%` y `#` sueltos y comandos truncados;
///  * balancea `{ }`, `\left` / `\right` (con `.` como delimitador invisible) y
///    `\begin` / `\end`;
///  * normaliza superindices unicode, tildes dentro de `\text{}` y saltos de fila.
abstract final class LatexRenderSanitizer {
  static const Map<String, String> _ctrl = {
    '\t': 't', '\n': 'n', '\r': 'r', '\f': 'f', '\b': 'b', '\v': 'v', '\x07': 'a',
  };

  /// Comandos que un escape perdido (`\t \n \r \f \b \v \a`) suele destruir.
  static const Set<String> _known = {
    'textcolor', 'text', 'textbf', 'textrm', 'times', 'tfrac', 'theta', 'tau', 'to', 'top',
    'tilde', 'neq', 'newline', 'nu', 'ne', 'not', 'neg', 'nabla', 'right', 'rightarrow',
    'rho', 'rangle', 'rfloor', 'rceil', 'rule', 'frac', 'forall', 'flat', 'phi', 'bar',
    'beta', 'binom', 'begin', 'boldsymbol', 'bmod', 'blacksquare', 'bullet', 'vec', 'varphi',
    'vert', 'vdots', 'vee', 'vphantom', 'alpha', 'approx', 'angle', 'aleph', 'amalg',
  };

  static const Set<String> _delims = {
    'langle', 'rangle', 'lfloor', 'rfloor', 'lceil', 'rceil', 'vert', 'Vert', 'lvert',
    'rvert', 'lbrace', 'rbrace', 'lbrack', 'rbrack', 'uparrow', 'downarrow', 'backslash',
  };

  static final RegExp _ctrlSeq = RegExp('([\t\n\r\f\b\v\x07])([a-zA-Z]+)');
  static final RegExp _ctrlLeft = RegExp('[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _colorNoSecond = RegExp(r'\\textcolor\s*\{[^{}]*\}(?!\s*\{)');
  static final RegExp _colorNoArgs = RegExp(r'\\textcolor(?!\s*\{)');
  static final RegExp _text = RegExp(r'\\text\{([^}]+)\}');

  static String sanitize(String latex) {
    if (latex.isEmpty) return '0';
    var s = _repairEscapes(latex);
    s = s
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('⁴', '^4')
        .replaceAll('⁵', '^5')
        .replaceAll('⁶', '^6');
    s = s.replaceAllMapped(_text, (m) => '\\text{${_asciiText(m[1]!)}}');
    s = s
        .replaceAllMapped(_colorNoSecond, (m) => '${m[0]}{}')
        .replaceAll(_colorNoArgs, '');
    s = _balance(s);
    s = _wrapRowBreaks(s);
    return s.trim().isEmpty ? '0' : s;
  }

  /// Texto plano de un `\text{...}`: sin tildes, eñes ni signos invertidos.
  static String _asciiText(String t) {
    const from = 'áéíóúÁÉÍÓÚñÑ';
    const to = 'aeiouAEIOUnN';
    final b = StringBuffer();
    for (final r in t.runes) {
      final ch = String.fromCharCode(r);
      final i = from.indexOf(ch);
      if (i >= 0) {
        b.write(to[i]);
      } else if (ch == '¡' || ch == '¿') {
        continue;
      } else {
        b.write(ch == '_' ? ' ' : ch);
      }
    }
    return b.toString();
  }

  static String _repairEscapes(String s) {
    var out = s.replaceAllMapped(_ctrlSeq, (m) {
      final word = '${_ctrl[m[1]]}${m[2]}';
      return _known.contains(word) ? '\\$word' : (m[1] == '\n' || m[1] == '\t' ? ' ${m[2]}' : m[2]!);
    });
    out = out
        .replaceAll('\r', '')
        .replaceAll('\n', ' ')
        .replaceAll('\t', ' ')
        .replaceAll(_ctrlLeft, '');
    return out;
  }

  static bool _isLetter(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122);

  /// Balancea llaves, `\left`/`\right` y entornos; descarta `%`, `#` y `\` finales.
  static String _balance(String s) {
    final sb = StringBuffer();
    // Pila: 'b' llave, 'l' \left. Cada entrada guarda el offset de salida tras abrir.
    final stack = <(String, int)>[];
    final envs = <String>[];
    var i = 0;
    final n = s.length;

    void insertAt(int idx, String ins) {
      final cur = sb.toString();
      sb
        ..clear()
        ..write(cur.substring(0, idx))
        ..write(ins)
        ..write(cur.substring(idx));
    }

    String delimAfter() {
      while (i < n && s[i] == ' ') {
        i++;
      }
      if (i >= n) return '.';
      final c = s[i];
      if ('()[]|./<>'.contains(c)) {
        i++;
        return c;
      }
      if (c == '\\' && i + 1 < n) {
        final d = s[i + 1];
        if ('{}|\\'.contains(d)) {
          i += 2;
          return '\\$d';
        }
        var j = i + 1;
        while (j < n && _isLetter(s.codeUnitAt(j))) {
          j++;
        }
        final name = s.substring(i + 1, j);
        if (_delims.contains(name)) {
          i = j;
          return '\\$name';
        }
      }
      return '.';
    }

    while (i < n) {
      final c = s[i];
      if (c == '\\') {
        if (i + 1 >= n) {
          i++; // `\` final: comando truncado
          continue;
        }
        if (!_isLetter(s.codeUnitAt(i + 1))) {
          sb.write(s.substring(i, i + 2)); // `\{ \} \\ \, \;` ...
          i += 2;
          continue;
        }
        var j = i + 1;
        while (j < n && _isLetter(s.codeUnitAt(j))) {
          j++;
        }
        final name = s.substring(i + 1, j);
        i = j;
        if (name == 'left') {
          final d = delimAfter();
          sb.write('\\left$d');
          stack.add(('l', sb.length));
        } else if (name == 'right') {
          final d = delimAfter();
          if (stack.isNotEmpty && stack.last.$1 == 'l') {
            stack.removeLast();
          } else {
            insertAt(stack.isEmpty ? 0 : stack.last.$2, '\\left.');
          }
          sb.write('\\right$d');
        } else if (name == 'begin' || name == 'end') {
          final m = RegExp(r'^\s*\{([A-Za-z*]+)\}').firstMatch(s.substring(i));
          if (m == null) continue; // \begin / \end sin nombre: se descarta
          i += m[0]!.length;
          if (name == 'begin') {
            envs.add(m[1]!);
            sb.write('\\begin{${m[1]}}');
          } else if (envs.isNotEmpty && envs.last == m[1]) {
            envs.removeLast();
            sb.write('\\end{${m[1]}}');
          }
        } else {
          sb.write('\\$name');
        }
        continue;
      }
      if (c == '{') {
        sb.write(c);
        stack.add(('b', sb.length));
      } else if (c == '}') {
        while (stack.isNotEmpty && stack.last.$1 == 'l') {
          stack.removeLast();
          sb.write('\\right.');
        }
        if (stack.isNotEmpty) {
          stack.removeLast();
          sb.write('}');
        } // si la pila esta vacia, la `}` sobrante se descarta
      } else if (c == '%') {
        sb.write('\\%');
      } else if (c == '#') {
        if (RegExp(r'^#[0-9A-Fa-f]{6}').hasMatch(s.substring(i))) sb.write(c);
      } else {
        sb.write(c);
      }
      i++;
    }
    for (var k = stack.length - 1; k >= 0; k--) {
      sb.write(stack[k].$1 == 'l' ? '\\right.' : '}');
    }
    for (var k = envs.length - 1; k >= 0; k--) {
      sb.write('\\end{${envs[k]}}');
    }
    return sb.toString();
  }

  /// `\\` / `\newline` fuera de un entorno generan un `CrNode` sin resolver: se envuelve.
  static String _wrapRowBreaks(String s) {
    final hasBreaks = s.contains(r'\\') || s.contains(r'\newline') || s.contains(r'\cr');
    final hasEnv = RegExp(r'\\begin\{(array|cases|matrix|aligned|gathered|[pbvBV]matrix)\}')
        .hasMatch(s);
    if (!hasBreaks || hasEnv) return s;
    var out = s.replaceAll(r'\newline', r'\\').replaceAll(r'\cr', r'\\').trim();
    while (out.endsWith(r'\\')) {
      out = out.substring(0, out.length - 2).trim();
    }
    return out.isEmpty ? '0' : '\\begin{aligned} $out \\end{aligned}';
  }
}
