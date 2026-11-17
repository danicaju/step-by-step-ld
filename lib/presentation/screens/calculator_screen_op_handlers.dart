part of 'calculator_screen.dart';

/// Selección de operación de M9, M10 y M12 (compartida por la cabecera LCD).
extension _CalculatorScreenOpHandlers on _CalculatorScreenState {
  void _selectMatrixOp(MatrixOperation op) {
    final hasMatA = _matrixCellsA.any((c) => c.trim().isNotEmpty);
    final hasMatB = _matrixCellsB.any((c) => c.trim().isNotEmpty);
    updateState(() {
      _activeResolution = null;
      _matrixOp = op;
      if (!op.needsMatrixB && op != MatrixOperation.scalarMultiply) {
        _matrixActiveTarget = 0;
      } else if (op == MatrixOperation.scalarMultiply && _matrixScalarK.trim().isEmpty) {
        _matrixActiveTarget = 2;
      } else if (op.needsMatrixB && hasMatA && !hasMatB) {
        _matrixActiveTarget = 1;
        _matrixActiveRow = 0;
        _matrixActiveCol = 0;
      }
    });
  }

  void _selectVectorOp(VectorOperation op) {
    final hasU = _vecUCells.any((c) => c.trim().isNotEmpty);
    final hasV = _vecVCells.any((c) => c.trim().isNotEmpty);
    updateState(() {
      _vectorOp = op;
      if (op == VectorOperation.crossAndArea || op.needsThirdVector) {
        _vectorDim = 3;
      }
      if (_vectorActiveRow >= _vectorRowCount(op)) _vectorActiveRow = 0;
      if (!op.needsSecondVector) {
        _vectorActiveRow = 0;
      } else if (hasU && !hasV) {
        _vectorActiveRow = 1;
        _vectorActiveCol = 0;
      }
    });
    final hasW = _vecWCells.any((c) => c.trim().isNotEmpty);
    if ((!op.needsSecondVector && hasU) ||
        (op.needsSecondVector && !op.needsThirdVector && hasU && hasV) ||
        (op.needsThirdVector && hasU && hasV && hasW)) {
      _solveCurrentMode();
    }
  }

  void _selectCalculusOp(CalculusOperation op) {
    updateState(() {
      _activeResolution = null;
      _calculusOp = op;
      if (op != CalculusOperation.tangentLine && op != CalculusOperation.definiteIntegral) {
        _calculusActiveField = 0;
      } else if (op == CalculusOperation.tangentLine && _calculusActiveField > 1) {
        _calculusActiveField = 1;
      }
    });
  }
}
