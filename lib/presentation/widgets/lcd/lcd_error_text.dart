/// Mensaje de error ya limpio para la LCD: texto natural + pista de solucion.
class LcdErrorInfo {
  final String message;
  final String hint;
  const LcdErrorInfo(this.message, this.hint);
}

/// Quita los prefijos tecnicos de Dart y de los solvers antes de mostrar un error.
class LcdErrorText {
  const LcdErrorText._();

  static final RegExp _prefix = RegExp(
    r'^\s*(?:Error al (?:evaluar|resolver|compartir)|Error en [^:]{1,40}|'
    r'No se pudo evaluar la expresi[oó]n|Invalid argument\(s\)|Invalid argument|'
    r'Exception|FormatException|ArgumentError|ExMathError|ArsenalException|StateError|'
    r'Bad state|Unsupported operation|UnsupportedError|RangeError|Math ERROR|'
    r'Syntax ERROR|Sintaxis incompleta)\s*:\s*',
    caseSensitive: false,
  );
  static final RegExp _offset = RegExp(r'\s*\(at (?:offset|character) \d+\)\s*$');

  /// Version limpia del mensaje (idempotente). Vacio -> texto generico.
  static String clean(String raw) {
    var s = raw.trim();
    for (var i = 0; i < 8; i++) {
      final next = s.replaceFirst(_prefix, '');
      if (next == s) break;
      s = next;
    }
    s = s.replaceAll(_offset, '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? 'Operación no definida.' : capitalize(s);
  }

  /// Primera letra en mayuscula (los mensajes de error siempre empiezan por mayuscula).
  static String capitalize(String s) {
    final t = s.trimLeft();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  /// Error real de dominio logaritmico (no basta con que el texto nombre "logaritmos").
  static bool _isLogDomain(String l) {
    if (l.contains('dominio') && (l.contains('logar') || l.contains('log'))) return true;
    if (l.contains('argumento') && l.contains('log')) return true;
    if (RegExp(r'\b(ln|log)\s*\(').hasMatch(l)) return true;
    return RegExp(r'\blogaritmo\b').hasMatch(l) && !l.contains('logaritmos');
  }

  /// Mensaje limpio + pista de solucion segun el contenido.
  static LcdErrorInfo info(String raw, {required bool syntax}) {
    final msg = clean(raw);
    final l = msg.toLowerCase();
    String hint;
    if (l.contains('raíz') && (l.contains('negativo') || l.contains('par'))) {
      hint = 'Revisa el signo del radicando o cambia a Modo Complejos (M11).';
    } else if (l.contains('dividir') || l.contains('división') || l.contains('division') || l.contains('nula')) {
      hint = 'El divisor no puede valer 0. Cambia el denominador.';
    } else if (l.contains('no soportad') || l.contains('misma base')) {
      hint = 'Revisa la sintaxis o comprueba que las funciones escritas tengan argumentos válidos.';
    } else if (l.contains('base logar')) {
      hint = 'La base del logaritmo debe ser mayor que 0 y distinta de 1.';
    } else if (_isLogDomain(l)) {
      hint = 'El argumento del logaritmo debe ser mayor que 0.';
    } else if (syntax) {
      hint = 'Completa la expresión: cierra paréntesis y rellena los huecos.';
    } else {
      hint = 'Pulsa ◀ o ▶ para corregir lo escrito, o AC para empezar de nuevo.';
    }
    return LcdErrorInfo(msg, hint);
  }
}
