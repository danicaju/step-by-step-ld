part of 'calculator_screen.dart';

extension _CalculatorScreenViews on _CalculatorScreenState {
  String? get _lcdIdleHint {
    if (_calculatorMode == 2) {
      const hints = [
        'Ej: 3x - 5 = 7 - x',
        'Ej: 2x^2 - 4x = x^2 - 3',
        'Ej: x^4 - 5x^2 + 4 = 0',
        'Ej: (x+1)/(x-2) = 3',
        'Ej: √(x + 3) = x - 3',
        'Ej: 2^(x+1) = 8',
        'Ej: log_(2, x+1) = 3',
      ];
      return '${hints[_eqKind.clamp(0, hints.length - 1)]}  (◀ ▶ cambia de miembro, = resuelve)';
    }
    if (_calculatorMode == 3 && _systemDim == 3) {
      return 'Introduce x, y, z, d con = o D-Pad (vacío=0) y elige Gauss / Cramer';
    }
    if (_calculatorMode == 4) {
      if (_polyIsNotableMode) {
        return switch (_identityType) {
          NotableIdentityType.squareOfSum => 'Escribe (a + b)², ej: (2x + 3)², y pulsa =',
          NotableIdentityType.squareOfDiff => 'Escribe (a - b)², ej: (x - 4)², y pulsa =',
          NotableIdentityType.sumTimesDiff => 'Escribe (a + b)(a - b), ej: (x + 2)(x - 2), y pulsa =',
        };
      }
      return _isChoosingRuffiniDegree
          ? 'Elige grado (2.º–6.º): toca una tarjeta, pulsa 2..6 o ◀ ▶ + ='
          : 'Rellena ${_ruffiniDegree + 1} coef. (0 si falta grado) y pulsa =';
    }
    if (_calculatorMode == 6) {
      if (_ineqDegree == 1) {
        return 'Teclea inecuación lineal (ej: 3x - 5 > 7 + x) y pulsa =';
      } else if (_ineqDegree == 2) {
        return 'Escribe inecuación de 2.º grado (ej: 2x² + 5x > 4) y pulsa =';
      } else {
        return 'Teclea valor absoluto o racional (ej: |x - 5| < 3) y pulsa =';
      }
    }
    if (_calculatorMode == 7) {
      return _ineqSysUnknowns == 1
          ? 'Escribe inecuaciones con x y pulsa = (▲ ▼ para saltar fila)'
          : 'Escribe rectas con x, y y pulsa = para ver la región 2D';
    }
    if (_calculatorMode == 8) {
      return 'Introduce xi/fi, muévete con D-Pad ◀ ▶ ▲ ▼ y pulsa = para calcular';
    }
    if (_calculatorMode == 9) {
      return 'Rellena celdas (0 si vacío), muévete con D-Pad o = y elige operación en LCD';
    }
    if (_calculatorMode == 10) {
      return 'Elige 2D/3D y operación (|u|, u·v, u×v), edita u y v y pulsa =';
    }
    if (_calculatorMode == 11) {
      return 'Introduce z1 = a + bi y z2 = c + di (o módulo/ángulo en Polar) y pulsa =';
    }
    if (_calculatorMode == 12) {
      return 'Escribe P(x), elige f\'(x), recta tangente o ∫ (Barrow) y pulsa =';
    }
    return null;
  }

  String? get _lcdCustomHeaderTitle {
    if (_calculatorMode == 3) {
      if (_systemDim == 4) return 'SISTEMA 4×4 (${_systemMethod.displayName.toUpperCase()})';
      if (_systemDim == 3) return 'SISTEMA 3×3 (${_systemMethod.displayName.toUpperCase()})';
      return 'SISTEMA 2×2 (${_systemMethod.displayName.toUpperCase()})';
    }
    if (_calculatorMode == 4) {
      if (_polyIsNotableMode) {
        return switch (_identityType) {
          NotableIdentityType.squareOfSum => '(A + B)² = A² + 2AB + B²',
          NotableIdentityType.squareOfDiff => '(A - B)² = A² - 2AB + B²',
          NotableIdentityType.sumTimesDiff => '(A + B)(A - B) = A² - B²',
        };
      }
      return _isChoosingRuffiniDegree
          ? 'ELIGE GRADO DE P(x)'
          : 'RUFFINI GRADO $_ruffiniDegree';
    }
    if (_calculatorMode == 6) {
      return switch (_ineqDegree) {
        1 => 'INECUACIÓN 1.º GRADO',
        2 => 'INECUACIÓN 2.º GRADO',
        _ => 'VALOR ABSOLUTO / RACIONAL',
      };
    }
    if (_calculatorMode == 7) {
      return _ineqSysUnknowns == 1
          ? 'SISTEMA INECUACIONES 1D ($_ineqSysRows INEC.)'
          : 'REGIÓN FACTIBLE 2D ($_ineqSysRows INEC.)';
    }
    if (_calculatorMode == 8) {
      return 'ESTADÍSTICA 1-VAR';
    }
    if (_calculatorMode == 9) {
      return 'MATRICES $_matrixDim×$_matrixDim';
    }
    if (_calculatorMode == 10) {
      return 'VECTORES ${_vectorDim}D (${_vectorOp.shortLabel})';
    }
    if (_calculatorMode == 11) {
      return 'COMPLEJOS (${_complexOp.shortLabel})';
    }
    if (_calculatorMode == 12) {
      return 'DERIV. E INT. (${_calculusOp.shortLabel})';
    }
    return null;
  }

  Widget _buildIneqSysUnknownsSelector() {
    return IneqSysUnknownsSelectorView(
      isOledDark: _isOledDark,
      ineqSysUnknowns: _ineqSysUnknowns,
      onSelectUnknowns: (unk) {
        updateState(() {
          _ineqSysUnknowns = unk;
          _isChoosingIneqSysUnknowns = false;
          if (unk == 2) _show2DRegionView = true;
        });
      },
    );
  }

  void _flipIneqSysUnknowns() {
    _ineqSysUnknowns = _ineqSysUnknowns == 1 ? 2 : 1;
    _activeResolution = null;
    _activeIneqVisualData = null;
    _currentFeasibleRegion = null;
  }

  Widget _buildInequalitySystemEditorView() {
    return InequalitySystemEditorView(
      isOledDark: _isOledDark,
      ineqSysUnknowns: _ineqSysUnknowns,
      ineqSysRows: _ineqSysRows,
      ineqSysActiveRow: _ineqSysActiveRow,
      ineqSysRowInputs: _ineqSysRowInputs,
      ineqSysRowCursors: _ineqSysRowCursors,
      onToggleUnknowns: () {
        updateState(() {
          _ineqSysUnknowns = _ineqSysUnknowns == 1 ? 2 : 1;
          _activeResolution = null;
          _activeIneqVisualData = null;
          _currentFeasibleRegion = null;
        });
      },
      onChangeRows: (r) {
        updateState(() {
          _ineqSysRows = r;
          _activeResolution = null;
          _activeStepIndex = 0;
          _activeIneqVisualData = null;
          _currentFeasibleRegion = null;
          if (_ineqSysActiveRow >= r) {
            _ineqSysActiveRow = r - 1;
          }
        });
      },
      onSelectRow: (i) {
        updateState(() {
          _ineqSysActiveRow = i;
          _ineqSysRowCursors[i] = _ineqSysRowInputs[i].length;
        });
      },
    );
  }

  Widget _buildMethodTab({
    Key? key,
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return CalculatorMethodTab(
      key: key,
      label: label,
      icon: icon,
      selected: selected,
      onTap: onTap,
    );
  }
}
