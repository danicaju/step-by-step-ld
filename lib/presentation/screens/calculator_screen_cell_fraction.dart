part of 'calculator_screen.dart';

extension _CalculatorScreenCellFraction on _CalculatorScreenState {
  /// D-Pad dentro de una celda de coeficientes con fraccion (numerador ⇄ denominador).
  /// `true` si lo consume; si no, el D-Pad cambia de celda como siempre.
  bool _cellFracDpad(String dir) {
    final cells = _currentCellValues;
    final idx = _currentActiveIndex;
    if (idx >= cells.length) return false;
    final next = CellFractionEditor.dpad(cells[idx], _cw.x.cellNumEdit, dir);
    if (next == null) return false;
    _cw.x.cellNumEdit = next;
    return true;
  }
}
