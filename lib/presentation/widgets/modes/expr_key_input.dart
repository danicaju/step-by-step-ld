/// Edicion lineal de una expresion f(x) con el teclado fisico (sin TextField).
///
/// `ALPHA + )` escribe `x`. Las funciones abren parentesis y `DEL` las borra enteras.
class ExprKeyInput {
  const ExprKeyInput._();

  static const List<String> _fns = ['sin(', 'cos(', 'tan(', 'log(', 'ln(', '√('];

  static const Map<String, String> _tokens = {
    'sin': 'sin(',
    'cos': 'cos(',
    'tan': 'tan(',
    'LOG': 'log(',
    'log': 'log(',
    'ln': 'ln(',
    '√': '√(',
    '^2': '^2',
    '^': '^',
    '^(': '^(',
    '/': '/',
    '*': '*',
    '+': '+',
    '-': '-',
    '(': '(',
    ')': ')',
    '.': '.',
    'x': 'x',
    'X': 'x',
  };

  /// Texto resultante de aplicar [key] sobre [cur]; `null` si la tecla no edita expresiones.
  static String? apply(String cur, String key, {bool alpha = false}) {
    if (key == 'DEL') {
      for (final f in _fns) {
        if (cur.endsWith(f)) return cur.substring(0, cur.length - f.length);
      }
      return cur.isEmpty ? cur : cur.substring(0, cur.length - 1);
    }
    if (alpha && key == ')') return '${cur}x';
    if (RegExp(r'^[0-9]$').hasMatch(key)) return '$cur$key';
    final t = _tokens[key];
    return t == null ? null : '$cur$t';
  }

  /// Variante numerica (celdas `a`, Inicio, Fin, Paso): `0-9 . - /`.
  static String? applyNumber(String cur, String key) {
    if (key == 'DEL') return cur.isEmpty ? cur : cur.substring(0, cur.length - 1);
    if (RegExp(r'^[0-9]$').hasMatch(key)) return '$cur$key';
    if (key == '.' && !cur.contains('.') && !cur.contains('/')) return cur.isEmpty || cur == '-' ? '${cur}0.' : '$cur.';
    if (key == '-') return cur.startsWith('-') ? cur.substring(1) : '-$cur';
    if (key == '/' && cur.isNotEmpty && cur != '-' && !cur.contains('/')) return '$cur/';
    return null;
  }
}
