part of 'calculator_screen.dart';

extension _CalculatorScreenModeCells on _CalculatorScreenState {
  void _matrixInsertToken(String token) {
    if (_matrixActiveTarget == 2) {
      _matrixScalarK = _appendTokenToNumericCell(_matrixScalarK, token);
      return;
    }
    final cells = _matrixActiveTarget == 1 ? _matrixCellsB : _matrixCellsA;
    final idx = _matrixActiveRow * 5 + _matrixActiveCol;
    cells[idx] = _appendTokenToNumericCell(cells[idx], token);
  }

  void _matrixBackspace() {
    if (_matrixActiveTarget == 2) {
      if (_matrixScalarK.isNotEmpty) {
        _matrixScalarK = _matrixScalarK.substring(0, _matrixScalarK.length - 1);
      }
      return;
    }
    final cells = _matrixActiveTarget == 1 ? _matrixCellsB : _matrixCellsA;
    final idx = _matrixActiveRow * 5 + _matrixActiveCol;
    if (cells[idx].isNotEmpty) {
      cells[idx] = cells[idx].substring(0, cells[idx].length - 1);
    }
  }



  void _matrixMoveDpad({required int dRow, required int dCol}) {
    final curRows = _matrixActiveTarget == 0 ? _matrixRowsA : _matrixRowsB;
    final curCols = _matrixActiveTarget == 0 ? _matrixColsA : _matrixColsB;
    if (_matrixActiveTarget == 2) {
      if (dRow > 0 || dCol != 0) {
        _matrixActiveTarget = 0;
        _matrixActiveRow = 0;
        _matrixActiveCol = 0;
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
  }

  int _vectorRowCount(VectorOperation op) =>
      op.needsThirdVector ? 3 : (op.needsSecondVector ? 2 : 1);

  List<String> get _vectorActiveCells => switch (_vectorActiveRow) {
        1 => _vecVCells,
        2 => _vecWCells,
        _ => _vecUCells,
      };

  void _vectorInsertToken(String token) {
    final cells = _vectorActiveCells;
    cells[_vectorActiveCol] = _appendTokenToNumericCell(
      cells[_vectorActiveCol],
      token,
    );
  }

  void _vectorBackspace() {
    final cells = _vectorActiveCells;
    final cur = cells[_vectorActiveCol];
    if (cur.isNotEmpty) {
      cells[_vectorActiveCol] = cur.substring(0, cur.length - 1);
    }
  }

  void _vectorAdvanceOnEquals() {
    if (_vectorActiveCol < _vectorDim - 1) {
      _vectorActiveCol++;
      return;
    }
    if (_vectorActiveRow < _vectorRowCount(_vectorOp) - 1) {
      _vectorActiveRow++;
      _vectorActiveCol = 0;
      return;
    }
    _solveCurrentMode();
  }

  void _vectorMoveDpad({required int dRow, required int dCol}) {
    if (dCol < 0) {
      if (_vectorActiveCol > 0) {
        _vectorActiveCol--;
      } else if (_vectorActiveRow > 0) {
        _vectorActiveRow--;
        _vectorActiveCol = _vectorDim - 1;
      }
    } else if (dCol > 0) {
      if (_vectorActiveCol < _vectorDim - 1) {
        _vectorActiveCol++;
      } else if (_vectorActiveRow < _vectorRowCount(_vectorOp) - 1) {
        _vectorActiveRow++;
        _vectorActiveCol = 0;
      }
    }
    if (dRow < 0 && _vectorActiveRow > 0) {
      _vectorActiveRow--;
    } else if (dRow > 0 &&
        _vectorActiveRow < _vectorRowCount(_vectorOp) - 1) {
      _vectorActiveRow++;
    }
  }

  void _setVectorDim(int dim) {
    updateState(() {
      _activeResolution = null;
      _vectorDim = dim;
      if (dim == 2 &&
          (_vectorOp == VectorOperation.crossAndArea ||
              _vectorOp.needsThirdVector)) {
        _vectorOp = VectorOperation.dotAndAngle;
      }
      _vectorActiveCol = _vectorActiveCol.clamp(0, dim - 1);
    });
  }

  void _selectComplexOp(ComplexOperation op) {
    final hasZ1 =
        _complexCells[0].trim().isNotEmpty || _complexCells[1].trim().isNotEmpty;
    final hasZ2 =
        _complexCells[2].trim().isNotEmpty || _complexCells[3].trim().isNotEmpty;
    updateState(() {
      _complexOp = op;
      if (!op.needsSecondComplex && _complexActiveIndex > 1) {
        _complexActiveIndex = 0;
      } else if (op.needsSecondComplex && hasZ1 && !hasZ2) {
        _complexActiveIndex = 2;
      }
    });
    if (!op.needsSecondComplex && hasZ1) {
      _solveCurrentMode();
    } else if (op.needsSecondComplex && hasZ1 && hasZ2) {
      _solveCurrentMode();
    }
  }

  void _complexInsertToken(String token) {
    if (token == '√') {
      // Radical en la celda (solo a+bi → r_α): `√3`, `2√3`, `-√3`. Una sola raiz por celda.
      final cur = _complexCells[_complexActiveIndex];
      if (_complexOp == ComplexOperation.toPolar && !cur.contains('√') && !cur.contains('/') && !cur.contains('.')) {
        _complexCells[_complexActiveIndex] = '$cur√';
      }
      return;
    }
    _complexCells[_complexActiveIndex] = _appendTokenToNumericCell(
      _complexCells[_complexActiveIndex],
      token,
    );
  }

  void _complexBackspace() {
    final cur = _complexCells[_complexActiveIndex];
    if (cur.isNotEmpty) {
      _complexCells[_complexActiveIndex] = cur.substring(0, cur.length - 1);
    }
  }

  void _complexAdvanceOnEquals() {
    final maxIdx = _complexOp.lastCellIndex;
    if (_complexActiveIndex < maxIdx) {
      _complexActiveIndex++;
    } else {
      _solveCurrentMode();
    }
  }

  void _complexMoveDpad({required int dRow, required int dCol}) {
    final maxIdx = _complexOp.lastCellIndex;
    if (dCol < 0 && _complexActiveIndex > 0) {
      _complexActiveIndex--;
    } else if (dCol > 0 && _complexActiveIndex < maxIdx) {
      _complexActiveIndex++;
    }
    if (_complexOp.needsSecondComplex) {
      if (dRow < 0 && _complexActiveIndex >= 2) {
        _complexActiveIndex -= 2;
      } else if (dRow > 0 && _complexActiveIndex < 2) {
        _complexActiveIndex += 2;
      }
    }
  }

  void _calculusInsertAuxToken(String token) {
    if (_calculusActiveField == 1) {
      if (_calculusOp == CalculusOperation.tangentLine) {
        _calculusX0Raw = _appendTokenToNumericCell(_calculusX0Raw, token);
      } else if (_calculusOp == CalculusOperation.definiteIntegral) {
        _calculusLimitARaw = _appendTokenToNumericCell(_calculusLimitARaw, token);
      }
    } else if (_calculusActiveField == 2 &&
        _calculusOp == CalculusOperation.definiteIntegral) {
      _calculusLimitBRaw = _appendTokenToNumericCell(_calculusLimitBRaw, token);
    }
  }

  void _calculusBackspace() {
    if (_calculusActiveField == 1) {
      if (_calculusOp == CalculusOperation.tangentLine &&
          _calculusX0Raw.isNotEmpty) {
        _calculusX0Raw =
            _calculusX0Raw.substring(0, _calculusX0Raw.length - 1);
      } else if (_calculusOp == CalculusOperation.definiteIntegral &&
          _calculusLimitARaw.isNotEmpty) {
        _calculusLimitARaw =
            _calculusLimitARaw.substring(0, _calculusLimitARaw.length - 1);
      }
      return;
    }
    if (_calculusActiveField == 2 &&
        _calculusOp == CalculusOperation.definiteIntegral &&
        _calculusLimitBRaw.isNotEmpty) {
      _calculusLimitBRaw =
          _calculusLimitBRaw.substring(0, _calculusLimitBRaw.length - 1);
      return;
    }
    if (_calculusExprRaw.isEmpty) return;
    final (nextRaw, nextPos) =
        ExpressionParser.deleteAtCursor(_calculusExprRaw, _calculusCursorPos);
    if (nextRaw == '0' && _calculusExprRaw.length <= 1) {
      _calculusExprRaw = '';
      _calculusCursorPos = 0;
    } else {
      _calculusExprRaw = nextRaw;
      _calculusCursorPos = nextPos;
    }
  }

  void _calculusAdvanceOnEquals() {
    if (_calculusOp == CalculusOperation.tangentLine &&
        _calculusActiveField == 0) {
      _calculusActiveField = 1;
      return;
    }
    if (_calculusOp == CalculusOperation.definiteIntegral) {
      if (_calculusActiveField < 2) {
        _calculusActiveField++;
        return;
      }
    }
    _solveCurrentMode();
  }

  void _calculusMoveDpad({required int dRow, required int dCol}) {
    if (_calculusActiveField == 0) {
      if (dCol < 0) {
        final fl = ExpressionParser.handleTwoSlotLeftArrow(
            _calculusExprRaw, _calculusCursorPos);
        _calculusCursorPos = fl != null
            ? fl.$2
            : ExpressionParser.stepCursorLeft(_calculusExprRaw, _calculusCursorPos);
      } else if (dCol > 0) {
        final fr = ExpressionParser.handleFractionRightArrow(
            _calculusExprRaw, _calculusCursorPos);
        if (fr != null) {
          _calculusExprRaw = fr.$1;
          _calculusCursorPos = fr.$2;
        } else {
          _calculusCursorPos = ExpressionParser.stepCursorRight(
              _calculusExprRaw, _calculusCursorPos);
        }
      } else if (dRow != 0 &&
          ExpressionParser.jumpFractionUpDown(
                  _calculusExprRaw, _calculusCursorPos, isUp: dRow < 0) !=
              null) {
        _calculusCursorPos = ExpressionParser.jumpFractionUpDown(
            _calculusExprRaw, _calculusCursorPos, isUp: dRow < 0)!;
      } else if (dRow > 0 &&
          (_calculusOp == CalculusOperation.tangentLine ||
              _calculusOp == CalculusOperation.definiteIntegral)) {
        _calculusActiveField = 1;
      }
      return;
    }

    if (dRow < 0) {
      _calculusActiveField = 0;
      return;
    }
    if (_calculusOp == CalculusOperation.definiteIntegral) {
      if (dCol > 0 && _calculusActiveField == 1) {
        _calculusActiveField = 2;
      } else if (dCol < 0 && _calculusActiveField == 2) {
        _calculusActiveField = 1;
      }
    }
  }


  void _statInsertToken(String token) {
    if (_statActiveRow >= _statRows.length) return;
    final row = _statRows[_statActiveRow];
    if (_statActiveCol == 0) {
      String cur = row.xi;
      if (token == '-') {
        cur = cur.startsWith('-') ? cur.substring(1) : '-$cur';
      } else if (token == '/' || token == '.') {
        if (cur.isNotEmpty && cur != '-' && !cur.contains(token)) {
          cur += token;
        }
      } else if (RegExp(r'^[0-9]$').hasMatch(token)) {
        cur += token;
      }
      _statRows[_statActiveRow] = (xi: cur, fi: row.fi);
    } else {
      String cur = row.fi;
      if (_cw.x.m8View == 1) {
        // 2 variables: la columna y admite signo, decimales y fracciones.
        if (token == '-') {
          cur = cur.startsWith('-') ? cur.substring(1) : '-$cur';
        } else if (token == '/' || token == '.') {
          if (cur.isNotEmpty && cur != '-' && !cur.contains(token)) cur += token;
        } else if (RegExp(r'^[0-9]$').hasMatch(token)) {
          cur += token;
        }
      } else if (RegExp(r'^[0-9]$').hasMatch(token)) {
        cur += token;
      }
      _statRows[_statActiveRow] = (xi: row.xi, fi: cur);
    }
  }

  void _statBackspace() {
    if (_statActiveRow >= _statRows.length) return;
    final row = _statRows[_statActiveRow];
    if (_statActiveCol == 0) {
      if (row.xi.isNotEmpty) {
        _statRows[_statActiveRow] = (
          xi: row.xi.substring(0, row.xi.length - 1),
          fi: row.fi,
        );
        return;
      }
    } else {
      if (row.fi.isNotEmpty) {
        _statRows[_statActiveRow] = (
          xi: row.xi,
          fi: row.fi.substring(0, row.fi.length - 1),
        );
        return;
      }
    }
    if (row.xi.isEmpty && row.fi.isEmpty && _statRows.length > 1) {
      _statRows.removeAt(_statActiveRow);
      if (_statActiveRow >= _statRows.length) {
        _statActiveRow = _statRows.length - 1;
      }
    }
  }

  /// `+ Añadir fila` inline: nueva fila vacia al final y foco en su xi.
  void _statAddRow() {
    updateState(() {
      _activeResolution = null;
      _statRows.add((xi: '', fi: ''));
      _statActiveRow = _statRows.length - 1;
      _statActiveCol = 0;
    });
  }

  /// `− Quitar fila` inline: borra la fila activa (siempre quedan 2 como minimo).
  void _statRemoveRow() {
    if (_statRows.length <= 2) return;
    updateState(() {
      _activeResolution = null;
      _statRows.removeAt(_statActiveRow.clamp(0, _statRows.length - 1));
      _statActiveRow = _statActiveRow.clamp(0, _statRows.length - 1);
    });
  }

  void _statMoveDpad({required int dRow, required int dCol}) {
    if (dCol != 0) {
      _statActiveCol = (_statActiveCol + dCol).clamp(0, 1);
    }
    if (dRow < 0 && _statActiveRow > 0) {
      _statActiveRow--;
    } else if (dRow > 0) {
      if (_statActiveRow < _statRows.length - 1) {
        _statActiveRow++;
      } else if (_statRows[_statActiveRow].xi.trim().isNotEmpty) {
        _statRows.add((xi: '', fi: ''));
        _statActiveRow = _statRows.length - 1;
      }
    }
  }
}
