/// Navegación 2D del MENU ClassWiz: 3 páginas de 4 tarjetas (rejilla 2x2).
///
/// El índice va de 0 a 11: página = índice ~/ 4, fila = (índice % 4) ~/ 2,
/// columna = índice % 2.
const int kMenuItemsPerPage = 4;
const int kMenuPages = 3;

/// Mueve el foco del menú. [dir]: `left`, `right`, `up`, `down`.
///
/// - ◀ ▶ cambian de columna; al pasar del borde saltan de página (a la columna opuesta).
/// - ▲ ▼ cambian de fila dentro de la página (envuelven).
int menuMove(int index, String dir) {
  final page = index ~/ kMenuItemsPerPage;
  final pos = index % kMenuItemsPerPage;
  final row = pos ~/ 2;
  final col = pos % 2;
  int at(int p, int r, int c) =>
      ((p + kMenuPages) % kMenuPages) * kMenuItemsPerPage + r * 2 + c;
  switch (dir) {
    case 'left':
      return col == 1 ? at(page, row, 0) : at(page - 1, row, 1);
    case 'right':
      return col == 0 ? at(page, row, 1) : at(page + 1, row, 0);
    case 'up':
    case 'down':
      return at(page, 1 - row, col);
  }
  return index;
}
