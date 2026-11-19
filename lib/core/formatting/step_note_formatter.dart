/// Formateador centralizado de LaTeX -> texto plano legible para notas pedagogicas.
///
/// Las notas se pintan con `Text()` nativo (no con `Math.tex`), asi que cualquier fragmento
/// LaTeX debe pasar por [StepNoteFormatter.toPlain]. Regla de oro: NUNCA se usa `$1`/`$2` en un
/// reemplazo (en Dart `replaceAll(RegExp, r'$1')` imprime `$1` literal); aqui se recorre el texto
/// con un escaner de llaves balanceadas o se usa `replaceAllMapped`.
abstract final class StepNoteFormatter {
  static const Map<String, String> _symbols = {
    'cdot': '·',
    'times': '×',
    'div': '÷',
    'pm': '±',
    'mp': '∓',
    'leq': '≤',
    'le': '≤',
    'geq': '≥',
    'ge': '≥',
    'neq': '≠',
    'ne': '≠',
    'approx': '≈',
    'infty': '∞',
    'implies': '⇒',
    'Rightarrow': '⇒',
    'Leftrightarrow': '⇔',
    'rightarrow': '→',
    'to': '→',
    'in': '∈',
    'mid': '|',
    'pi': 'π',
    'alpha': 'α',
    'beta': 'β',
    'theta': 'θ',
    'lambda': 'λ',
    'mu': 'μ',
    'Delta': 'Δ',
    'sigma': 'σ',
    'circ': '°',
    'ldots': '…',
    'dots': '…',
    'cup': '∪',
    'cap': '∩',
    'quad': ' ',
    'qquad': ' ',
    'left': '',
    'right': '',
    'displaystyle': '',
    'blacksquare': '■',
    'square': '□',
    ',': ' ',
    ';': ' ',
    ':': ' ',
    '!': '',
    ' ': ' ',
    '{': '{',
    '}': '}',
    '|': '|',
    '%': '%',
    '\\': ' ',
  };

  /// Comandos de un argumento cuyo contenido se conserva.
  static const Set<String> _wrappers = {
    'text', 'mathrm', 'textbf', 'mathbf', 'boxed', 'mbox', 'operatorname', 'overline', 'bar', 'vec',
  };

  static const String _sup = '⁰¹²³⁴⁵⁶⁷⁸⁹⁻';
  static const String _sub = '₀₁₂₃₄₅₆₇₈₉₋';
  /// Operando que no necesita parentesis en `a/b` (menos solo al inicio).
  static final RegExp _simple = RegExp(r'^-?[\w.,²³¹⁰⁴⁵⁶⁷⁸⁹]+$');
  static final RegExp _single = RegExp('^[A-Za-z0-9Ͱ-Ͽ]\$');
  static final RegExp _digits = RegExp(r'^-?\d+$');
  static final RegExp _array = RegExp(r'\\begin\{array\}\{[^}]*\}(.*?)\\end\{array\}', dotAll: true);
  static final RegExp _multiSpace = RegExp(r'[ \t]{2,}');

  /// Fugas prohibidas en texto plano ya formateado (ver `test/step_notes_audit_test.dart`).
  static const List<String> latexLeaks = [
    r'\frac', r'\left', r'\right', r'\cdot', r'\times', r'\sqrt', r'\textcolor', 'extcolor',
    r'\mid', r'\text{', r'\mathrm{', '^{', '_{',
  ];

  /// Valores corruptos que nunca deben aparecer en una nota (en crudo o formateada).
  static final RegExp _corrupt =
      RegExp(r'\$[1-9]|\\[12](?!\d)|\bnull\b|\bNaN\b|\bInfinity\b|Instance of');

  /// Primera fuga (grupo regex literal, valor corrupto o LaTeX crudo) de [text]; `null` si limpio.
  /// [raw] `true` audita el texto tal cual sale del solver (solo grupos/valores corruptos);
  /// `false` audita ademas LaTeX crudo (texto ya pasado por [toPlain]).
  static String? findLeak(String text, {bool raw = false}) {
    final m = _corrupt.firstMatch(text);
    if (m != null) return m.group(0);
    if (raw) return null;
    for (final k in latexLeaks) {
      if (text.contains(k)) return k;
    }
    return null;
  }

  /// Convierte [input] (texto con fragmentos LaTeX) a texto plano legible.
  static String toPlain(String input) {
    if (!input.contains(r'\') &&
        !input.contains('{') &&
        !input.contains('}') &&
        !input.contains('\t') &&
        !input.contains('\r') &&
        !input.contains('\f')) {
      return input;
    }
    var s = _restoreEscapes(input);
    s = s.replaceAllMapped(_array, (m) {
      final rows = m.group(1)!.split(r'\\').map((r) => r.trim()).where((r) => r.isNotEmpty);
      final cells = rows.map((r) => r.split('&').map((c) => c.trim()).join(' '));
      return '[${cells.join('; ')}]';
    });
    return _convert(s).replaceAll(_multiSpace, ' ').trim();
  }

  /// Rescata comandos cuyo `\` se perdio en un literal Dart no crudo (`'\times'` -> TAB + `imes`).
  static String _restoreEscapes(String s) {
    final tab = String.fromCharCode(9);
    final ff = String.fromCharCode(12);
    final cr = String.fromCharCode(13);
    return s
        .replaceAll('${cr}ight', r'\right')
        .replaceAll(cr, '')
        .replaceAll('${tab}ext', r'\text')
        .replaceAll('${tab}imes', r'\times')
        .replaceAll('${ff}rac', r'\frac');
  }

  static String _convert(String s) {
    final out = StringBuffer();
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == r'\') {
        i = _command(s, i, out);
      } else if (c == '^' && i + 1 < s.length && s[i + 1] == '{') {
        final g = _group(s, i + 1);
        out.write(_script(_convert(g.$1), _sup, '^'));
        i = g.$2;
      } else if (c == '_' && i + 1 < s.length && s[i + 1] == '{') {
        final g = _group(s, i + 1);
        out.write(_script(_convert(g.$1), _sub, '_'));
        i = g.$2;
      } else if (c == '{' || c == '}') {
        i++;
      } else {
        out.write(c);
        i++;
      }
    }
    return out.toString();
  }

  /// Procesa el comando que empieza en `s[i] == '\'`; devuelve el indice siguiente.
  static int _command(String s, int i, StringBuffer out) {
    var j = i + 1;
    if (j >= s.length) return j;
    if (!_isLetter(s.codeUnitAt(j))) {
      final sym = _symbols[s[j]];
      out.write(sym ?? s[j]);
      return j + 1;
    }
    while (j < s.length && _isLetter(s.codeUnitAt(j))) {
      j++;
    }
    final name = s.substring(i + 1, j);
    if (name == 'frac' || name == 'dfrac' || name == 'tfrac') {
      final a = _argAt(s, j);
      final b = _argAt(s, a.$2);
      out.write('${_wrap(_convert(a.$1))}/${_wrap(_convert(b.$1))}');
      return b.$2;
    }
    if (name == 'sqrt') {
      var k = j;
      var index = '';
      if (k < s.length && s[k] == '[') {
        final end = s.indexOf(']', k);
        if (end != -1) {
          index = _script(_convert(s.substring(k + 1, end)), _sup, '^');
          k = end + 1;
        }
      }
      final a = _argAt(s, k);
      out.write('$index√(${_convert(a.$1)})');
      return a.$2;
    }
    if (name == 'textcolor' || name == 'color') {
      final col = _argAt(s, j);
      if (name == 'color') return col.$2;
      final a = _argAt(s, col.$2);
      out.write(_convert(a.$1));
      return a.$2;
    }
    if (_wrappers.contains(name)) {
      final a = _argAt(s, j);
      out.write(_convert(a.$1));
      return a.$2;
    }
    if (name == 'begin' || name == 'end') {
      final a = _argAt(s, j);
      return a.$1 == 'array' && name == 'begin' ? _argAt(s, a.$2).$2 : a.$2;
    }
    if (name == 'phantom' || name == 'hphantom' || name == 'vphantom') return _argAt(s, j).$2;
    // Comando conocido -> simbolo; desconocido (sin, ln, lim...) -> su nombre sin barra.
    out.write(_symbols[name] ?? name);
    return j;
  }

  static bool _isLetter(int u) => (u >= 65 && u <= 90) || (u >= 97 && u <= 122);

  /// Argumento tras [i]: un grupo `{...}` balanceado o un unico caracter. `(contenido, indiceSiguiente)`.
  static (String, int) _argAt(String s, int i) {
    var k = i;
    while (k < s.length && s[k] == ' ') {
      k++;
    }
    if (k >= s.length) return ('', s.length);
    if (s[k] == '{') return _group(s, k);
    return (s[k], k + 1);
  }

  /// Grupo `{...}` que abre en [open]; tolera llaves sin cerrar (toma hasta el final).
  static (String, int) _group(String s, int open) {
    var depth = 0;
    for (var k = open; k < s.length; k++) {
      final ch = s[k];
      if (ch == r'\') {
        k++;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return (s.substring(open + 1, k), k + 1);
      }
    }
    return (s.substring(open + 1), s.length);
  }

  /// Exponente/subindice: digitos y `-` -> Unicode; compuesto -> `^(expr)`; vacio -> nada.
  static String _script(String inner, String table, String mark) {
    final t = inner.trim();
    if (t.isEmpty) return '';
    if (_digits.hasMatch(t)) {
      return t.split('').map((ch) => ch == '-' ? table[10] : table[int.parse(ch)]).join();
    }
    return _single.hasMatch(t) ? '$mark$t' : '$mark($t)';
  }

  static String _wrap(String s) => s.isEmpty || _simple.hasMatch(s) ? s : '($s)';
}
