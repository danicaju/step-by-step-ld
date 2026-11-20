import 'balanced_scan.dart';

/// Convierte LaTeX de entrada (`\sqrt[3]{8}`, `\log_{2}(8)`, `\sin^{-1}(x)`,
/// `\frac{a}{b}`, `e^{2}`...) a la sintaxis de texto plano del buffer de la
/// calculadora (`root(3,8)`, `log_(2,8)`, `asin(x)`, `((a)/(b))`, `e^(2)`).
///
/// Si la cadena no contiene `\` ni `{` se devuelve tal cual.
class LatexNormalizer {
  const LatexNormalizer._();

  static final RegExp _invPow = RegExp(r'\\?(sinh|cosh|tanh|sin|cos|tan)\^\{-1\}');
  static final RegExp _fnPow = RegExp(r'\\?(sinh|cosh|tanh|sin|cos|tan)\^\{(\d+)\}');
  static final RegExp _fnCmd = RegExp(
    r'\\(asinh|acosh|atanh|arcsin|arccos|arctan|sinh|cosh|tanh|sin|cos|tan|ln|log)(?![A-Za-z])',
  );

  static String toPlain(String src) {
    if (!src.contains(r'\') && !src.contains('{')) return src;
    var s = src
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '')
        .replaceAll(r'\,', '')
        .replaceAll(r'\!', '')
        .replaceAll(r'\ ', '');
    s = _frac(s);
    s = _sqrt(s);
    s = _logBase(s);
    s = s.replaceAllMapped(_invPow, (m) => 'a${m[1]}');
    s = s.replaceAllMapped(_fnPow, (m) => '${m[1]}^${m[2]}');
    s = s.replaceAllMapped(_fnCmd, (m) => m[1]!);
    return s
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\cdot', '*')
        .replaceAll(r'\times', '*')
        .replaceAll(r'\div', '/')
        .replaceAll('{', '(')
        .replaceAll('}', ')');
  }

  /// Contenido y fin (exclusivo) del grupo que abre en [from] si es [open].
  static (String, int)? _group(String s, int from, String open) {
    if (from >= s.length || s[from] != open) return null;
    final close = BalancedScan.findClose(s, from);
    if (close == null) return null;
    return (s.substring(from + 1, close), close + 1);
  }

  static String _frac(String s) {
    var out = s;
    while (true) {
      final i = out.indexOf(r'\frac');
      if (i < 0) return out;
      final a = _group(out, i + 5, '{');
      final b = a == null ? null : _group(out, a.$2, '{');
      if (a == null || b == null) return out.replaceFirst(r'\frac', '');
      out = '${out.substring(0, i)}((${a.$1})/(${b.$1}))${out.substring(b.$2)}';
    }
  }

  static String _sqrt(String s) {
    var out = s;
    while (true) {
      final i = out.indexOf(r'\sqrt');
      if (i < 0) return out;
      var at = i + 5;
      final idx = _group(out, at, '[');
      if (idx != null) at = idx.$2;
      final rad = _group(out, at, '{');
      if (rad == null) {
        out = out.replaceFirst(r'\sqrt', '√');
        continue;
      }
      final text = idx == null ? '√(${rad.$1})' : 'root(${idx.$1},${rad.$1})';
      out = '${out.substring(0, i)}$text${out.substring(rad.$2)}';
    }
  }

  static String _logBase(String s) {
    var out = s;
    var from = 0;
    while (true) {
      final i = out.indexOf(r'\log_', from);
      if (i < 0) return out;
      var at = i + 5;
      String base;
      final g = _group(out, at, '{');
      if (g != null) {
        base = g.$1;
        at = g.$2;
      } else if (at < out.length) {
        base = out[at];
        at += 1;
      } else {
        return out.replaceFirst(r'\log_', 'log');
      }
      final arg = _group(out, at, '(');
      if (arg == null) {
        out = '${out.substring(0, i)}log_($base)${out.substring(at)}';
        from = i + 4;
        continue;
      }
      out = '${out.substring(0, i)}log_($base,${arg.$1})${out.substring(arg.$2)}';
    }
  }
}
