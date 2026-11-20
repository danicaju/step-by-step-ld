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

  // ── Celdas numericas compartidas (M10, M11): tecla a/b, DEL y D-Pad dentro de la fraccion ──

  /// Tecla a/b sobre [cur]: con la celda vacia abre `■/■` en el numerador.
  String _cellSlash(String cur) {
    final (text, numEdit) = CellFractionEditor.slash(cur, _cw.x.cellNumEdit);
    _cw.x.cellNumEdit = numEdit;
    return text;
  }

  /// DEL sobre [cur]: nunca deja `/` suelta; con la fraccion vacia la elimina.
  String _cellBackspace(String cur) {
    final (text, numEdit) = CellFractionEditor.backspace(cur, _cw.x.cellNumEdit);
    _cw.x.cellNumEdit = numEdit;
    return text;
  }

  /// D-Pad dentro de la fraccion de [cur]; `true` si se consume (no cambia de celda).
  bool _cellDpadInside(String cur, int dRow, int dCol) {
    final dir = dCol < 0 ? 'left' : dCol > 0 ? 'right' : dRow < 0 ? 'up' : 'down';
    final next = CellFractionEditor.dpad(cur, _cw.x.cellNumEdit, dir);
    if (next == null) return false;
    _cw.x.cellNumEdit = next;
    return true;
  }

  // ── M9: celda activa (MatA / MatB / k) con fracciones a/b ──────────────────

  String get _matrixActiveText {
    if (_matrixActiveTarget == 2) return _matrixScalarK;
    final cells = _matrixActiveTarget == 1 ? _matrixCellsB : _matrixCellsA;
    return cells[_matrixActiveRow * 5 + _matrixActiveCol];
  }

  set _matrixActiveText(String v) {
    if (_matrixActiveTarget == 2) {
      _matrixScalarK = v;
      return;
    }
    final cells = _matrixActiveTarget == 1 ? _matrixCellsB : _matrixCellsA;
    cells[_matrixActiveRow * 5 + _matrixActiveCol] = v;
  }

  /// Tecla numerica o `a/b`: `/` abre la fraccion tambien con la celda vacia (numerador activo).
  void _matrixInsertToken(String token) {
    if (token == '/') {
      final (text, numEdit) = CellFractionEditor.slash(_matrixActiveText, _cw.x.cellNumEdit);
      _matrixActiveText = text;
      _cw.x.cellNumEdit = numEdit;
      return;
    }
    _matrixActiveText = _appendTokenToNumericCell(_matrixActiveText, token);
  }

  void _matrixBackspace() {
    final (text, numEdit) = CellFractionEditor.backspace(_matrixActiveText, _cw.x.cellNumEdit);
    _matrixActiveText = text;
    _cw.x.cellNumEdit = numEdit;
  }

  /// D-Pad en M9: primero navega dentro de la fraccion de la celda; despues, de celda en celda.
  void _matrixMoveDpad({required int dRow, required int dCol}) {
    final dir = dCol < 0 ? 'left' : dCol > 0 ? 'right' : dRow < 0 ? 'up' : 'down';
    final next = CellFractionEditor.dpad(_matrixActiveText, _cw.x.cellNumEdit, dir);
    if (next != null) {
      _cw.x.cellNumEdit = next;
      return;
    }
    final (oldTarget, oldRow, oldCol) = (_matrixActiveTarget, _matrixActiveRow, _matrixActiveCol);
    final curRows = _matrixActiveTarget == 0 ? _matrixRowsA : _matrixRowsB;
    final curCols = _matrixActiveTarget == 0 ? _matrixColsA : _matrixColsB;
    if (_matrixActiveTarget == 2) {
      if (dRow > 0 || dCol != 0) {
        _matrixActiveTarget = 0;
        _matrixActiveRow = 0;
        _matrixActiveCol = 0;
        _cw.x.cellNumEdit = true;
      }
      return;
    }
    if (dCol < 0) {
      if (_matrixActiveCol > 0) {
        _matrixActiveCol--;
      } else if (_matrixActiveRow > 0) {
        _matrixActiveRow--;
        _matrixActiveCol = curCols - 1;
      }
    } else if (dCol > 0) {
      if (_matrixActiveCol < curCols - 1) {
        _matrixActiveCol++;
      } else if (_matrixActiveRow < curRows - 1) {
        _matrixActiveRow++;
        _matrixActiveCol = 0;
      }
    }
    if (dRow < 0 && _matrixActiveRow > 0) {
      _matrixActiveRow--;
    } else if (dRow > 0 && _matrixActiveRow < curRows - 1) {
      _matrixActiveRow++;
    }
    // Se entra en la celda vecina por el numerador al avanzar y por el denominador al retroceder.
    if ((oldTarget, oldRow, oldCol) != (_matrixActiveTarget, _matrixActiveRow, _matrixActiveCol)) {
      _cw.x.cellNumEdit = dCol > 0 || dRow > 0;
    }
  }
}
