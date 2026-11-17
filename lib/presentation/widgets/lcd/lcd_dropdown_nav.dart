/// Logica pura de navegacion del menu desplegable de la LCD (1 o 2 columnas).
class LcdDropdownNav {
  LcdDropdownNav({required this.count, this.columns = 1, this.index = 0});

  final int count;
  final int columns;
  int index;

  int get rows => (count + columns - 1) ~/ columns;

  /// 2 columnas cuando todas las etiquetas son cortas (signos, dimensiones...).
  static int autoColumns(List<String> labels) =>
      labels.length >= 4 && labels.every((l) => l.length <= 6) ? 2 : 1;

  /// Indice 0-based de la opcion para las teclas `1`-`9`, o `null` si no aplica.
  static int? digitIndex(String key, int count) {
    if (key.length != 1) return null;
    final d = int.tryParse(key);
    if (d == null || d < 1 || d > 9 || d > count) return null;
    return d - 1;
  }

  /// Mueve el resaltado con ◀ ▶ ▲ ▼ ('left', 'right', 'up', 'down'). Devuelve `true` si cambio.
  bool move(String dir) {
    final before = index;
    if (columns <= 1) {
      switch (dir) {
        case 'up':
        case 'left':
          index = (index - 1 + count) % count;
        case 'down':
        case 'right':
          index = (index + 1) % count;
      }
      return index != before;
    }
    final col = index % columns;
    switch (dir) {
      case 'left':
        if (col > 0) index -= 1;
      case 'right':
        if (col < columns - 1 && index + 1 < count) index += 1;
      case 'up':
        if (index - columns >= 0) {
          index -= columns;
        } else {
          var last = col + (rows - 1) * columns;
          if (last >= count) last -= columns;
          index = last.clamp(0, count - 1);
        }
      case 'down':
        index = index + columns < count ? index + columns : col;
    }
    return index != before;
  }
}
