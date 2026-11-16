part of 'calculator_screen.dart';

extension _CalculatorScreenKeypressControl on _CalculatorScreenState {
  bool _handleKeyPressControl(String key) {
      // Modificadores SHIFT y ALPHA
      if (key == 'SHIFT') {
        _isShiftActive = !_isShiftActive;
        _isAlphaActive = false;
        return true;
      }
      if (key == 'ALPHA') {
        _isAlphaActive = !_isAlphaActive;
        _isShiftActive = false;
        return true;
      }

      // Tecla MENU / MODE / SETUP (SHIFT + MODE abre SETUP con DEG/RAD/OLED; MODE abre menú con prioridad absoluta)
      if (key == 'MENU' || key == 'MODE') {
        if (_isShiftActive) {
          _isShiftActive = false;
          _isMenuOpen = false;
          _isSetupOpen = !_isSetupOpen;
          return true;
        }
        if (_isSetupOpen) {
          _isSetupOpen = false;
          return true;
        }
        _isMenuOpen = !_isMenuOpen;
        if (_isMenuOpen) {
          _menuCursorIndex = CasioLcdScreen.menuIndexForMode(_calculatorMode);
          _activeResolution = null;
          _activeStepIndex = 0;
          _showDecimalApprox = false;
          _showGraphView = false;
          _show2DRegionView = false;
          _currentFeasibleRegion = null;
          _currentGraphAnalysis = null;
          _isCalcPromptActive = false;
          _isChoosingIneqSysUnknowns = false;
        }
        return true;
      }

      // Si el menú SETUP (SHIFT + MODE) está abierto en la LCD
      if (_isSetupOpen) {
        if (key == 'AC') {
          _isSetupOpen = false;
          return true;
        }
        final opt = int.tryParse(key);
        if (opt != null && opt >= 1 && opt <= 3) {
          _isSetupOpen = false;
          if (opt == 1) {
            _angleUnit = AngleUnit.deg;
          } else if (opt == 2) {
            _angleUnit = AngleUnit.rad;
          } else if (opt == 3) {
            _isOledDark = !_isOledDark;
          }
          return true;
        }
        return true;
      }

      // Si el prompt interactivo CALC (x = ?) está activo
      if (_isCalcPromptActive) {
        if (key == 'AC') {
          _isCalcPromptActive = false;
          _calcValueRaw = '';
          return true;
        }
        if (key == 'DEL') {
          if (_calcValueRaw.isNotEmpty) {
            _calcValueRaw = _calcValueRaw.substring(0, _calcValueRaw.length - 1);
          } else {
            _isCalcPromptActive = false;
          }
          return true;
        }
        if (key == '=') {
          _submitCalcEvalSync();
          return true;
        }
        if (key == '-' && _calcValueRaw.isEmpty) {
          _calcValueRaw = '-';
          return true;
        }
        if ((key == '/' || key == '.') &&
            _calcValueRaw.isNotEmpty &&
            _calcValueRaw != '-' &&
            !_calcValueRaw.contains(key)) {
          _calcValueRaw += key;
          return true;
        }
        if (RegExp(r'^[0-9]$').hasMatch(key)) {
          _calcValueRaw += key;
          return true;
        }
        return true;
      }

      // Si el Menú ClassWiz está abierto en la LCD, las teclas numéricas y = / AC navegan y seleccionan
      if (_isMenuOpen) {
        if (key == 'AC') {
          _isMenuOpen = false;
          _isAlphaActive = false;
          _isShiftActive = false;
          return true;
        }
        if (key == '=') {
          final targetMode = CasioLcdScreen.menuModeIdAt(_menuCursorIndex);
          _isMenuOpen = false;
          _isAlphaActive = false;
          _isShiftActive = false;
          _resetFieldsForMode(targetMode);
          return true;
        }
        final parsedMode = int.tryParse(key);
        if (parsedMode != null) {
          // Si pulsa 2..9, salta directamente a ese modo
          if (parsedMode >= 2 && parsedMode <= 9) {
            _isMenuOpen = false;
            _isAlphaActive = false;
            _isShiftActive = false;
            _resetFieldsForMode(parsedMode);
            return true;
          }
          // Si pulsa 1: sitúa el cursor en el modo 1. Si vuelve a pulsar 0, 1 o 2, entra a 10, 11 o 12.
          if (parsedMode == 1) {
            if (_menuCursorIndex == CasioLcdScreen.menuIndexForMode(1)) {
              // Ya estaba en 1 y volvió a pulsar 1 -> Modo 11
              _isMenuOpen = false;
              _isAlphaActive = false;
              _isShiftActive = false;
              _resetFieldsForMode(11);
              return true;
            }
            _menuCursorIndex = CasioLcdScreen.menuIndexForMode(1);
            return true;
          }
          if (parsedMode == 0 && _menuCursorIndex == CasioLcdScreen.menuIndexForMode(1)) {
            _isMenuOpen = false;
            _isAlphaActive = false;
            _isShiftActive = false;
            _resetFieldsForMode(10);
            return true;
          }
          if (parsedMode == 2 && _menuCursorIndex == CasioLcdScreen.menuIndexForMode(1)) {
            _isMenuOpen = false;
            _isAlphaActive = false;
            _isShiftActive = false;
            _resetFieldsForMode(12);
            return true;
          }
        }
        return true;
      }

      // Selector previo de grado de polinomio en Modo 4 (Ruffini grado 2..6)
      if (_calculatorMode == 4 && !_polyIsNotableMode && _isChoosingRuffiniDegree) {
        if (key == 'AC') {
          _isShiftActive = false;
          _isAlphaActive = false;
          _ruffiniDegree = 3;
          return true;
        }
        if (key == '=') {
          _isShiftActive = false;
          _isAlphaActive = false;
          _setRuffiniDegree(_ruffiniDegree, enterTemplate: true);
          return true;
        }
        if (!_isShiftActive && !_isAlphaActive) {
          final deg = int.tryParse(key);
          if (deg != null && deg >= 2 && deg <= 6) {
            _setRuffiniDegree(deg, enterTemplate: true);
            return true;
          }
        }
        _isShiftActive = false;
        _isAlphaActive = false;
        return true;
      }

      // Tecla S⬄D (alternar exacto y decimal)
      if (key == 'SD') {
        _showDecimalApprox = !_showDecimalApprox;
        return true;
      }

      // Tecla AC (All Clear Definitivo en todos los modos)
      if (key == 'AC') {
        _activeResolution = null;
        _activeStepIndex = 0;
        _isShiftActive = false;
        _isAlphaActive = false;
        _showDecimalApprox = false;
        _replayIndex = -1;

        if (_calculatorMode == 2) {
          _eqLeftRaw = '';
          _eqLeftCursorPos = 0;
          _eqRightRaw = '';
          _eqRightCursorPos = 0;
          _eqActiveSide = 0;
        } else if (_calculatorMode == 7) {
          _activeResolution = null;
          _activeStepIndex = 0;
          _activeIneqVisualData = null;
          _currentFeasibleRegion = null;
          if (_ineqSysRowInputs[_ineqSysActiveRow].isNotEmpty) {
            _ineqSysRowInputs[_ineqSysActiveRow] = '';
            _ineqSysRowCursors[_ineqSysActiveRow] = 0;
          } else {
            final allEmpty = _ineqSysRowInputs.every((r) => r.isEmpty);
            for (int i = 0; i < _ineqSysRowInputs.length; i++) {
              _ineqSysRowInputs[i] = '';
              _ineqSysRowCursors[i] = 0;
            }
            _ineqSysActiveRow = 0;
            if (allEmpty) {
              _isChoosingIneqSysUnknowns = true;
            }
          }
        } else if (_calculatorMode == 8) {
          _statRows = [(xi: '', fi: '')];
          _statActiveRow = 0;
          _statActiveCol = 0;
        } else if (_calculatorMode == 9) {
          for (int i = 0; i < _matrixCellsA.length; i++) {
            _matrixCellsA[i] = '';
            _matrixCellsB[i] = '';
          }
          _matrixScalarK = '';
          _matrixActiveTarget = 0;
          _matrixActiveRow = 0;
          _matrixActiveCol = 0;
        } else if (_calculatorMode == 10) {
          for (int i = 0; i < _vecUCells.length; i++) {
            _vecUCells[i] = '';
            _vecVCells[i] = '';
          }
          _vectorActiveRow = 0;
          _vectorActiveCol = 0;
        } else if (_calculatorMode == 11) {
          for (int i = 0; i < _complexCells.length; i++) {
            _complexCells[i] = '';
          }
          _complexActiveIndex = 0;
        } else if (_calculatorMode == 12) {
          _calculusExprRaw = '';
          _calculusCursorPos = 0;
          _calculusX0Raw = '';
          _calculusLimitARaw = '';
          _calculusLimitBRaw = '';
          _calculusActiveField = 0;
        } else if (_isCoefficientMode) {
          final cells = _currentCellValues;
          for (int i = 0; i < cells.length; i++) {
            cells[i] = '';
          }
          _currentActiveIndex = 0;
          if (_calculatorMode == 5) {
            _currentGraphAnalysis = null;
            _selectedGraphPoint = null;
            _showGraphView = false;
          } else if (_calculatorMode == 6) {
            _inequalitySign = InequalitySign.less;
          }
        } else {
          _rawInput = '0';
          _cursorPos = 1;
          if (_calculatorMode == 6) {
            _inequalitySign = InequalitySign.less;
          }
        }
        return true;
      }

      // Tecla DEL (Comportamiento fiel a Casio con borrado en _cursorPos)
      if (key == 'DEL') {
        // Si hay una resolución activa, DEL sale de la vista de pasos y devuelve a la plantilla editable
        if (_activeResolution != null) {
          _clearActiveResolutionCursor();
          return true;
        }

        if (_calculatorMode == 7) {
          final cur = _ineqSysRowInputs[_ineqSysActiveRow];
          final pos = _ineqSysRowCursors[_ineqSysActiveRow];
          final (nextRaw, nextPos) = ExpressionParser.deleteAtCursor(
            cur,
            pos,
            emptyResult: '',
            emptyCursor: 0,
          );
          _ineqSysRowInputs[_ineqSysActiveRow] = nextRaw;
          _ineqSysRowCursors[_ineqSysActiveRow] = nextPos;
          return true;
        }
        if (_calculatorMode == 8) {
          _statBackspace();
          return true;
        }
        if (_calculatorMode == 9) {
          _matrixBackspace();
          return true;
        }
        if (_calculatorMode == 10) {
          _vectorBackspace();
          return true;
        }
        if (_calculatorMode == 11) {
          _complexBackspace();
          return true;
        }
        if (_calculatorMode == 12) {
          _calculusBackspace();
          return true;
        }

        // Si se está editando en modo coeficientes
        if (_isCoefficientMode) {
          final cells = _currentCellValues;
          final idx = _currentActiveIndex;
          if (idx < cells.length && cells[idx].isNotEmpty) {
            cells[idx] = cells[idx].substring(0, cells[idx].length - 1);
          }
          return true;
        }

        // En Modo 2 (Ecuaciones con = central fijo), DEL nunca borra el signo =
        if (_calculatorMode == 2) {
          if (_eqActiveSide == 0) {
            if (_eqLeftRaw.isNotEmpty && _eqLeftCursorPos > 0) {
              final (nextRaw, nextPos) = ExpressionParser.deleteAtCursor(
                _eqLeftRaw,
                _eqLeftCursorPos,
                emptyResult: '',
                emptyCursor: 0,
              );
              _eqLeftRaw = nextRaw;
              _eqLeftCursorPos = nextPos;
            }
          } else {
            if (_eqRightCursorPos == 0) {
              _eqActiveSide = 0;
              _eqLeftCursorPos = _eqLeftRaw.length;
            } else {
              final (nextRaw, nextPos) = ExpressionParser.deleteAtCursor(
                _eqRightRaw,
                _eqRightCursorPos,
                emptyResult: '',
                emptyCursor: 0,
              );
              _eqRightRaw = nextRaw;
              _eqRightCursorPos = nextPos;
            }
          }
          _replayIndex = -1;
          return true;
        }

        // Si se está editando en modo expresión (Modos 1, 4 Notables y 6 lineal)
        final (nextRaw, nextPos) =
            ExpressionParser.deleteAtCursor(_rawInput, _cursorPos);
        _rawInput = nextRaw;
        _cursorPos = nextPos;
        _replayIndex = -1;
        return true;
      }

      // Tecla ANS
    return false;
  }
}
