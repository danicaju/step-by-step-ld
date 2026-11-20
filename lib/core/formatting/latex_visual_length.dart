// Medida visual aproximada de una formula LaTeX (en "caracteres").
import 'latex_scan_utils.dart';

const Map<String, double> _funcWidth = {
  'sin': 3.3, 'cos': 3.3, 'tan': 3.3, 'cot': 3.3, 'sec': 3.3, 'csc': 3.3, 'ln': 2.3,
  'log': 3.3, 'exp': 3.3, 'arctan': 6.3, 'arcsin': 6.3, 'arccos': 6.3, 'lim': 3.3,
  'max': 3.3, 'min': 3.3, 'det': 3.3, 'sinh': 4.3, 'cosh': 4.3, 'tanh': 4.3, 'gcd': 3.3,
};

/// Anchura visual aproximada (en "caracteres"): ignora `\left`, `\right`, llaves y
/// espacios; fracciones = max(num, den), raices = contenido + signo, indices x0,7.
double visualLength(String latex) => _Vis(latex).run();

class _Vis {
  final String s;
  int i = 0;
  _Vis(this.s);

  double run() => _seq(false);

  double _group() {
    while (i < s.length && s[i] == ' ') {
      i++;
    }
    if (i < s.length && s[i] == '{') {
      i++;
      return _seq(true);
    }
    return _atom();
  }

  double _atom() {
    if (i >= s.length) return 0;
    if (s[i] == r'\') {
      final before = i;
      final w = _command();
      return i > before ? w : 0;
    }
    i++;
    return 1;
  }

  double _command() {
    if (i + 1 >= s.length) {
      i = s.length;
      return 0;
    }
    final n = s[i + 1];
    if (!latexIsLetter(n)) {
      i += 2;
      return switch (n) {
        ',' => 0.3,
        ';' || ' ' || '{' || '}' || '|' => 0.5,
        ':' => 0.4,
        _ => 0,
      };
    }
    var j = i + 1;
    while (j < s.length && latexIsLetter(s[j])) {
      j++;
    }
    final name = s.substring(i + 1, j);
    i = j;
    switch (name) {
      case 'frac' || 'dfrac' || 'tfrac':
        final a = _group(), b = _group();
        return (a > b ? a : b) + 0.6;
      case 'sqrt':
        if (i < s.length && s[i] == '[') {
          final close = s.indexOf(']', i);
          i = close < 0 ? s.length : close + 1;
        }
        return _group() + 1.5;
      case 'left' || 'right':
        i = latexSkipDelim(s, i);
        return 0.5;
      case 'begin' || 'end':
        i = latexSkipGroup(s, i);
        return 0;
      case 'color':
        _group();
        return 0;
      case 'textcolor':
        _group();
        return _group();
      case 'quad':
        return 2;
      case 'qquad':
        return 4;
      case 'displaystyle' || 'textstyle':
        return 0;
      default:
        if (_funcWidth.containsKey(name)) return _funcWidth[name]!;
        if (name == 'vec' || name == 'bar' || name == 'hat' || name == 'overline') return _group();
        if (name == 'text' || name == 'mathrm' || name == 'textbf' || name == 'operatorname') {
          return _group();
        }
        return name == 'int' || name == 'sum' ? 1.2 : 1;
    }
  }

  double _seq(bool inGroup) {
    var total = 0.0, rowMax = 0.0;
    while (i < s.length) {
      final c = s[i];
      if (c == '}') {
        i++;
        if (inGroup) break;
        continue;
      }
      if (c == '{') {
        i++;
        total += _seq(true);
      } else if (c == '^' || c == '_') {
        i++;
        total += _group() * 0.7;
      } else if (c == r'\') {
        if (i + 1 < s.length && s[i + 1] == r'\') {
          rowMax = rowMax > total ? rowMax : total;
          total = 0;
          i += 2;
        } else {
          total += _command();
        }
      } else {
        i++;
        total += switch (c) {
          ' ' || '&' || '\n' || '\t' => 0,
          '+' || '-' || '=' => 1.6,
          '(' || ')' || ',' => 0.7,
          '.' || '|' => 0.5,
          _ => 1,
        };
      }
    }
    return rowMax > total ? rowMax : total;
  }
}
