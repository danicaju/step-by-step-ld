part of 'calculator_screen.dart';

extension _CalculatorScreenKeypress on _CalculatorScreenState {
  void _handleKeyPress(String key) {
    updateState(() {
      if (_handleKeyPressControl(key)) return;
      if (_handleKeyPressFunctions(key)) return;

      if (key == '=') {
        _isShiftActive = false;
        _isAlphaActive = false;

        // En Modo 7 (Sistemas de Inecuaciones)
        if (_calculatorMode == 7) {
          if (_isChoosingIneqSysUnknowns) {
            _isChoosingIneqSysUnknowns = false;
            if (_ineqSysUnknowns == 2) {
              _show2DRegionView = true;
            }
            return;
          }
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          _solveCurrentMode();
          return;
        }

        // En Modo 8 (Estadística 1-Var): el botón físico = calcula directamente los parámetros
        if (_calculatorMode == 8) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          _solveCurrentMode();
          return;
        }

        // En Modo 9 (Matrices): resuelve directamente o avanza pasos
        if (_calculatorMode == 9) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          _solveCurrentMode();
          return;
        }

        // En Modo 10 (Vectores)
        if (_calculatorMode == 10) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          _vectorAdvanceOnEquals();
          return;
        }

        // En Modo 11 (Complejos)
        if (_calculatorMode == 11) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          _complexAdvanceOnEquals();
          return;
        }

        // En Modo 12 (Cálculo: Derivada / Tangente / Barrow)
        if (_calculatorMode == 12) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          _calculusAdvanceOnEquals();
          return;
        }

        // En Modo 4: confirmar selección de grado si está en el menú inicial
        if (_calculatorMode == 4 && !_polyIsNotableMode && _isChoosingRuffiniDegree) {
          _isChoosingRuffiniDegree = false;
          _currentActiveIndex = 0;
          return;
        }

        // En modo coeficientes: avanza pasos si está resuelto, o confirma celda
        if (_isCoefficientMode) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          final cells = _currentCellValues;
          final idx = _currentActiveIndex;
          if (idx < cells.length - 1) {
            _currentActiveIndex = idx + 1;
          } else {
            // Última celda -> resolver
            _solveCurrentMode();
          }
          return;
        }

        // En Modos de Expresión (Modos 1, 2, 4 Notables y 6 lineal):
        if (_activeResolution != null) {
          if (_activeStepIndex < _activeResolution!.steps.length - 1) {
            _activeStepIndex++;
          } else {
            _activeStepIndex = 0;
          }
          return;
        }
        _solveCurrentMode();
        return;
      }

      // Mapeo alfabético con ALPHA sobre números (7->A, 8->B, 9->C, 4->D, 5->E, 6->F)
      String effectiveChar = key;
      if (_isAlphaActive) {
        _isAlphaActive = false;
        const alphaMap = {
          '7': 'A',
          '8': 'B',
          '9': 'C',
          '4': 'D',
          '5': 'E',
          '6': 'F',
          '1': 'X',
          '2': 'Y',
        };
        if (alphaMap.containsKey(key)) {
          effectiveChar = alphaMap[key]!;
        }
      }

      _isShiftActive = false;

      // ENTRADA EN MODO 4 (RUFFINI: atajo numérico de grado 2..6)
      if (_calculatorMode == 4 && !_polyIsNotableMode && _isChoosingRuffiniDegree) {
        if ('23456'.contains(effectiveChar)) {
          _ruffiniDegree = int.parse(effectiveChar);
          _isChoosingRuffiniDegree = false;
          _currentActiveIndex = 0;
          return;
        }
      }

      // ENTRADA EN MODO 7 (SISTEMAS DE INECUACIONES)
      if (_calculatorMode == 7) {
        if (_isChoosingIneqSysUnknowns) {
          if (effectiveChar == '1') {
            _ineqSysUnknowns = 1;
            _isChoosingIneqSysUnknowns = false;
            return;
          }
          if (effectiveChar == '2') {
            _ineqSysUnknowns = 2;
            _isChoosingIneqSysUnknowns = false;
            _show2DRegionView = true;
            return;
          }
        }
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
          _ineqSysRowCursors[_ineqSysActiveRow] =
              _ineqSysRowInputs[_ineqSysActiveRow].length;
        }
      }

      // ENTRADA EN MODO 8 (ESTADÍSTICA 1-VAR: tabla xi | fi)
      if (_calculatorMode == 8) {
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
        }
        _statInsertToken(effectiveChar);
        return;
      }

      // ENTRADA EN MODO 9 (MATRICES)
      if (_calculatorMode == 9) {
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
        }
        _matrixInsertToken(effectiveChar);
        return;
      }

      // ENTRADA EN MODO 10 (VECTORES 2D / 3D)
      if (_calculatorMode == 10) {
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
        }
        _vectorInsertToken(effectiveChar);
        return;
      }

      // ENTRADA EN MODO 11 (COMPLEJOS)
      if (_calculatorMode == 11) {
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
        }
        _complexInsertToken(effectiveChar);
        return;
      }

      // ENTRADA EN MODO 12 (CÁLCULO: campo auxiliar x0/a/b vs f(x))
      if (_calculatorMode == 12) {
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
          _calculusCursorPos = _calculusExprRaw.length;
        }
        if (_calculusActiveField != 0) {
          _calculusInsertAuxToken(effectiveChar);
          return;
        }
        // Si está enfocado f(x), continúa hacia _applyRawInsertion
      }

      // ENTRADA EN MODO COEFICIENTES (Modos 3, 4 Ruffini, 5 Gráficas, 6 cuadrática)
      if (_isCoefficientMode) {
        if (_activeResolution != null) {
          // Si el alumno empieza a teclear mientras ve los pasos, cerramos los pasos y volvemos a edición
          _activeResolution = null;
          _activeStepIndex = 0;
        }

        final cells = _currentCellValues;
        final idx = _currentActiveIndex;
        if (idx >= cells.length) {
          return;
        }

        cells[idx] = _appendTokenToNumericCell(cells[idx], effectiveChar);
        return;
      }

      // ENTRADA EN MODO EXPRESIÓN (Modo 1, Modo 2, Modo 4 Notables, Modo 6 y f(x) de Modo 11)
      if (_activeResolution != null) {
        _clearActiveResolutionCursor();
      }

      if (effectiveChar == '.' || effectiveChar == ',') {
        if (_calculatorMode == 2) {
          final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
          final sideCur = _eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos;
          final mcmDot = ExpressionParser.handleMcmMcdCommaOrDot(sideRaw, sideCur);
          if (mcmDot != null) {
            if (_eqActiveSide == 0) {
              _eqLeftRaw = mcmDot.$1;
              _eqLeftCursorPos = mcmDot.$2;
            } else {
              _eqRightRaw = mcmDot.$1;
              _eqRightCursorPos = mcmDot.$2;
            }
            _replayIndex = -1;
            return;
          }
          if (effectiveChar == ',') return;
        } else {
          final mcmDot = ExpressionParser.handleMcmMcdCommaOrDot(
            _rawInput,
            _cursorPos,
          );
          if (mcmDot != null) {
            _rawInput = mcmDot.$1;
            _cursorPos = mcmDot.$2;
            _replayIndex = -1;
            return;
          }
          if (effectiveChar == ',') return;
        }
      }

      if (effectiveChar == ')') {
        if (_calculatorMode == 2) {
          final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
          final sideCur = _eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos;
          final mcmClose = ExpressionParser.handleMcmMcdCloseParen(sideRaw, sideCur);
          if (mcmClose != null) {
            if (_eqActiveSide == 0) {
              _eqLeftRaw = mcmClose.$1;
              _eqLeftCursorPos = mcmClose.$2;
            } else {
              _eqRightRaw = mcmClose.$1;
              _eqRightCursorPos = mcmClose.$2;
            }
            _replayIndex = -1;
            return;
          }
        } else {
          final mcmClose = ExpressionParser.handleMcmMcdCloseParen(
            _rawInput,
            _cursorPos,
          );
          if (mcmClose != null) {
            _rawInput = mcmClose.$1;
            _cursorPos = mcmClose.$2;
            _replayIndex = -1;
            return;
          }
        }
      }

      final keepLeadingZero = effectiveChar == '.';
      _applyRawInsertion(effectiveChar, keepLeadingZero: keepLeadingZero);
    });
  }

  String _appendTokenToNumericCell(String current, String token) {
    if (token == '-') {
      return current.startsWith('-') ? current.substring(1) : '-$current';
    }
    if (token == '/') {
      if (current.isNotEmpty && current != '-' && !current.contains('/')) {
        return '$current/';
      }
      return current;
    }
    if (token == '.') {
      if (current.isNotEmpty && current != '-' && !current.contains('.')) {
        return '$current.';
      }
      return current;
    }
    if (RegExp(r'^[0-9]$').hasMatch(token)) {
      return '$current$token';
    }
    return current;
  }
}
