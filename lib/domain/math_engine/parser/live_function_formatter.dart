/// Formateador LaTeX en vivo de funciones (`sin(`, `cos(`, `ln(`, `arcsin(`...).
///
/// Una sola pasada de izquierda a derecha: cada función abre y cierra su propio
/// bloque `\name\left( ... \right)` en línea, también cuando la entrada aún no
/// está cerrada (se cierra visualmente). Nunca reescanea texto ya emitido, por
/// lo que no aparecen `\\` (salto de línea) ni paréntesis planos huérfanos.
class LiveFunctionFormatter {
  const LiveFunctionFormatter._();

  /// Tokens ordenados de más largo a más corto (prefijos antes que sus sufijos).
  static const List<(String, String)> _tokens = [
    ('sin⁻¹(', r'\sin^{-1}'),
    ('cos⁻¹(', r'\cos^{-1}'),
    ('tan⁻¹(', r'\tan^{-1}'),
    ('arcsin(', r'\sin^{-1}'),
    ('arccos(', r'\cos^{-1}'),
    ('arctan(', r'\tan^{-1}'),
    ('asin(', r'\sin^{-1}'),
    ('acos(', r'\cos^{-1}'),
    ('atan(', r'\tan^{-1}'),
    ('sin(', r'\sin'),
    ('cos(', r'\cos'),
    ('tan(', r'\tan'),
    ('log(', r'\log'),
    ('ln(', r'\ln'),
    ('Abs(', r'\mathrm{Abs}'),
    ('sinh(', r'\sinh'),
    ('cosh(', r'\cosh'),
    ('tanh(', r'\tanh'),
    ('RanInt#(', r'\mathrm{RanInt}\#'),
    ('Pol(', r'\mathrm{Pol}'),
    ('Per(', r'\mathrm{Per}'),
    ('Rec(', r'\mathrm{Rec}'),
  ];

  static final RegExp _trigPower = RegExp(r'(sin|cos|tan)\^([0-9]+|\([0-9]+\))\(');

  static bool _isLetter(String ch) => RegExp(r'[A-Za-z\\]').hasMatch(ch);

  /// Cierre balanceado de [openIdx] ignorando `\left(` y `\right)` ya emitidos.
  static int? _findClose(String s, int openIdx) {
    var depth = 0;
    for (var i = openIdx; i < s.length; i++) {
      if (s.startsWith(r'\left(', i)) {
        i += 5;
        depth++;
        continue;
      }
      if (s.startsWith(r'\right)', i)) {
        i += 6;
        depth--;
        if (depth == 0) return i;
        continue;
      }
      final ch = s[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  static String format(String src, String cursor, String cursorBox) {
    final out = StringBuffer();
    var i = 0;
    while (i < src.length) {
      final prevIsLetter = i > 0 && _isLetter(src[i - 1]);
      String? latexFn;
      var tokenLen = 0;
      if (!prevIsLetter && src.startsWith('log_(', i)) {
        final openIdx = i + 4;
        final closeIdx = _findClose(src, openIdx);
        final innerRaw = closeIdx != null
            ? src.substring(openIdx + 1, closeIdx)
            : src.substring(openIdx + 1);
        out.write(_formatLogBase(innerRaw, cursor, cursorBox));
        i = closeIdx != null ? closeIdx + 1 : src.length;
        continue;
      }
      if (!prevIsLetter) {
        final pm = _trigPower.matchAsPrefix(src, i);
        if (pm != null) {
          final exp = pm.group(2)!.replaceAll('(', '').replaceAll(')', '');
          latexFn = '\\${pm.group(1)}^{$exp}';
          tokenLen = pm.end - i;
        } else {
          for (final (key, latex) in _tokens) {
            if (src.startsWith(key, i)) {
              latexFn = latex;
              tokenLen = key.length;
              break;
            }
          }
        }
      }
      if (latexFn == null) {
        out.write(src[i]);
        i++;
        continue;
      }
      final openIdx = i + tokenLen - 1;
      final closeIdx = _findClose(src, openIdx);
      final innerRaw = closeIdx != null
          ? src.substring(openIdx + 1, closeIdx)
          : src.substring(openIdx + 1);
      final rec = format(innerRaw, cursor, cursorBox);
      final body = rec == cursor ? cursorBox : (rec.isEmpty ? r'\square' : rec);
      out.write('$latexFn\\left($body\\right)');
      i = closeIdx != null ? closeIdx + 1 : src.length;
    }
    return out.toString();
  }

  static String _formatLogBase(String inner, String cursor, String cursorBox) {
    String slot(String x) {
      final f = format(x, cursor, cursorBox);
      return f == cursor ? cursorBox : (f.isEmpty ? r'\square' : f);
    }

    final parts = _splitTopLevel(inner);
    if (parts.length > 1) {
      final arg = slot(parts.sublist(1).join(','));
      return '\\log_{${slot(parts[0])}}\\left($arg\\right)';
    }
    final base = inner.isEmpty ? cursorBox : slot(inner);
    return '\\log_{$base}\\left(\\square\\right)';
  }

  static List<String> _splitTopLevel(String s) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < s.length; i++) {
      if (s.startsWith(r'\left(', i)) {
        depth++;
        i += 5;
      } else if (s.startsWith(r'\right)', i)) {
        depth--;
        i += 6;
      } else if (s[i] == '(') {
        depth++;
      } else if (s[i] == ')') {
        depth--;
      } else if (depth == 0 && s[i] == ',') {
        parts.add(s.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(s.substring(start));
    return parts;
  }
}
