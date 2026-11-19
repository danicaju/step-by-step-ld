/// Marcas LaTeX del cursor de la LCD (Dart puro, sin Flutter).
///
/// El cursor de insercion es `\lcdcursor`: un nodo de `flutter_math_fork` de ANCHO
/// ESTRICTAMENTE CERO (ver `lcd_cursor.dart`). Un `\rule` o `\mid` ocupa espacio
/// horizontal (y `\mid` ademas anade margenes de relacion), lo que desplazaba los
/// digitos al parpadear o mover el cursor.
abstract final class LcdCursor {
  /// Color de tinta del cursor (marcador que reconocen el parpadeo y el tema oscuro).
  static const String ink = '#1A2530';
  static const String inkOnDark = '#C8D6CD';

  /// Comando TeX del nodo de ancho cero.
  static const String command = r'\lcdcursor';

  /// Cursor de insercion visible (barra fina de ancho cero).
  static const String bar = '\\textcolor{$ink}{$command}';

  /// Mismo cursor apagado: conserva alto y baseline, asi el parpadeo no mueve nada.
  static const String barOff = '\\phantom{$command}';

  /// Cursor de sobrescritura (bloque): ocupa una celda como un caracter.
  static const String box = '\\textcolor{$ink}{\\blacksquare}';
  static const String boxOff = '\\phantom{\\blacksquare}';

  /// Aplica el estado del parpadeo y el tema al LaTeX.
  static String applyBlink(String latex, {required bool on, required bool dark}) {
    if (!latex.contains(ink)) return latex;
    var out = latex;
    if (!on) {
      out = out.replaceAll(bar, barOff).replaceAll(box, boxOff);
    }
    if (dark) out = out.replaceAll(ink, inkOnDark);
    return out;
  }

  /// Quita cualquier marca de cursor de [latex] (tests y exportaciones).
  static String strip(String latex) => latex
      .replaceAll(bar, '')
      .replaceAll(box, '')
      .replaceAll(barOff, '')
      .replaceAll(boxOff, '');
}
