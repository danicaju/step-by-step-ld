/// Normalizador y blindaje de código LaTeX para flutter_math_fork en pantallas LCD Casio.
class LcdMathSanitizer {
  static String sanitizeForMathTex(String latex) {
    if (latex.isEmpty) return '0';
    String clean = latex.replaceAll('\r', '');
    // Normalizar superíndices unicode que no reconoce directamente flutter_math_fork
    clean = clean
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('⁴', '^4')
        .replaceAll('⁵', '^5')
        .replaceAll('⁶', '^6');
    // Normalizar tildes, caracteres no ASCII y guiones bajos en bloques \text{...} para blindar flutter_math_fork
    clean = clean.replaceAllMapped(RegExp(r'\\text\{([^}]+)\}'), (m) {
      final inner = m[1]!
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u')
          .replaceAll('Á', 'A')
          .replaceAll('É', 'E')
          .replaceAll('Í', 'I')
          .replaceAll('Ó', 'O')
          .replaceAll('Ú', 'U')
          .replaceAll('ñ', 'n')
          .replaceAll('Ñ', 'N')
          .replaceAll('¡', '')
          .replaceAll('¿', '')
          .replaceAll('_', ' ');
      return '\\text{$inner}';
    });

    // BLINDAJE CRÍTICO CONTRA CrNode EN flutter_math_fork:
    // Si la cadena contiene saltos de fila (\\ o \\[...pt] o \newline o \cr)
    // pero NO está envuelta en un entorno válido (aligned, array, matrix, cases),
    // flutter_math_fork genera un nodo temporal CrNode no resuelto que lanza UnsupportedError.
    final bool hasRowBreaks = clean.contains(r'\\') ||
        clean.contains(r'\newline') ||
        clean.contains(r'\cr');
    final bool hasEnvironment = clean.contains(r'\begin{array}') ||
        clean.contains(r'\begin{cases}') ||
        clean.contains(r'\begin{matrix}') ||
        clean.contains(r'\begin{aligned}') ||
        clean.contains(r'\begin{gathered}');

    if (hasRowBreaks && !hasEnvironment) {
      // Normalizar \newline o \cr a \\
      clean = clean.replaceAll(r'\newline', r'\\').replaceAll(r'\cr', r'\\');
      // Quitar posibles \\ finales sueltos que rompen el parser
      clean = clean.trim();
      while (clean.endsWith(r'\\')) {
        clean = clean.substring(0, clean.length - 2).trim();
      }
      if (clean.isNotEmpty) {
        clean = '\\begin{aligned} $clean \\end{aligned}';
      } else {
        clean = '0';
      }
    }

    return clean;
  }
}
