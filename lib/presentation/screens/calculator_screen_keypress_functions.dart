part of 'calculator_screen.dart';

extension _CalculatorScreenKeypressFunctions on _CalculatorScreenState {
  bool _handleKeyPressFunctions(String key) {
      if (key == 'M-') return _memMinus();
      if (key.startsWith(OptnTokenSections.keyPrefix)) {
        return _insertTokenKey(key.substring(OptnTokenSections.keyPrefix.length));
      }
      if (key == 'ANS') {
        _isShiftActive = false;
        _isAlphaActive = false;
        if (_supportsScientificFns) {
          if (_activeResolution != null) {
            _clearActiveResolutionCursor();
          }
          _applyRawInsertion('ANS');
        }
        return true;
      }

      // Tecla ÷ (con SHIFT ejecuta FACT)
      if (key == ':') {
        if (_isShiftActive) {
          _isShiftActive = false;
          _handleFactorize();
          return true;
        }
        if (_isAlphaActive && _calculatorMode == 1) {
          _isAlphaActive = false;
          if (_activeResolution != null) _clearActiveResolutionCursor();
          _applyRawInsertion('∶');
          return true;
        }
      }

      // Tecla × (con SHIFT inserta m.c.m., con ALPHA M.C.D.)
      if (key == '*') {
        if (_isShiftActive) {
          _isShiftActive = false;
          if (_supportsScientificFns) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('mcm(');
          }
          return true;
        }
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsScientificFns) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('mcd(');
          }
          return true;
        }
      }

      // Tecla x² (Normal: ^2 rapido, SHIFT: exponente libre ^( que retiene el cursor dentro, ALPHA: cubo ^3)
      if (key == '^2') {
        if (_isShiftActive) {
          _isShiftActive = false;
          if (_supportsExpressionInput) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
              _calculusCursorPos = _calculusExprRaw.length;
            }
            _applyRawInsertion(ExponentNavigationHelper.open, keepLeadingZero: false);
          }
          return true;
        }
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsExpressionInput) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
              _calculusCursorPos = _calculusExprRaw.length;
            }
            _applyRawInsertion(ExponentNavigationHelper.cube, keepLeadingZero: false);
          }
          return true;
        }
        if (_supportsExpressionInput) {
          if (_activeResolution != null) {
            _activeResolution = null;
            _activeStepIndex = 0;
            _cursorPos = _rawInput.length;
            _calculusCursorPos = _calculusExprRaw.length;
          }
          _applyRawInsertion(ExponentNavigationHelper.square, keepLeadingZero: false);
          return true;
        }
      }

      // Tecla √■ (Normal: √(, SHIFT: root(, ALPHA: ³√()
      if (key == '√') {
        if (_calculatorMode == 11 && !_isShiftActive && !_isAlphaActive) {
          _complexInsertToken('√');
          return true;
        }
        if (_isShiftActive) {
          _isShiftActive = false;
          if (_supportsScientificFns) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('root(');
          }
          return true;
        }
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsScientificFns) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('³√(');
          }
          return true;
        }
        if (_supportsScientificFns) {
          if (_activeResolution != null) {
            _activeResolution = null;
            _activeStepIndex = 0;
            _cursorPos = _rawInput.length;
          }
          _applyRawInsertion('√(');
          return true;
        }
      }

      // Tecla a/b (Fracción / con plantilla vacía \frac{\blacksquare}{\square} sin 0 inicial)
      if (key == '/') {
        if (_isShiftActive) {
          _isShiftActive = false;
          _showDecimalApprox = !_showDecimalApprox;
          return true;
        }
        _isAlphaActive = false;
        if (_calculatorMode == 7) {
          final cur = _ineqSysRowInputs[_ineqSysActiveRow];
          final pos = _ineqSysRowCursors[_ineqSysActiveRow];
          final (nextRaw, advancedPos) = FractionTemplate.insert(cur, pos);
          _ineqSysRowInputs[_ineqSysActiveRow] = nextRaw;
          _ineqSysRowCursors[_ineqSysActiveRow] = advancedPos;
          return true;
        }
        if (_calculatorMode == 9) {
          _matrixInsertToken('/');
          return true;
        }
        if (_calculatorMode == 10) {
          _vectorInsertToken('/');
          return true;
        }
        if (_calculatorMode == 11) {
          _complexInsertToken('/');
          return true;
        }
        if (_calculatorMode == 12 && _calculusActiveField != 0) {
          _calculusInsertAuxToken('/');
          return true;
        }
        if (_isCoefficientMode) {
          if (_activeResolution != null) {
            _activeResolution = null;
            _activeStepIndex = 0;
          }
          final cells = _currentCellValues;
          final idx = _currentActiveIndex;
          if (idx < cells.length) {
            // a/b abre la fraccion aunque la celda este vacia: primero el numerador.
            final (text, numEdit) = CellFractionEditor.slash(cells[idx], _cw.x.cellNumEdit);
            cells[idx] = text;
            _cw.x.cellNumEdit = numEdit;
          }
          return true;
        }
        if (_activeResolution != null) {
          _clearActiveResolutionCursor();
        }
        if (_calculatorMode == 2) {
          if (_eqActiveSide == 0 && _eqLeftRaw == '0') {
            _eqLeftRaw = '';
            _eqLeftCursorPos = 0;
          } else if (_eqActiveSide == 1 && _eqRightRaw == '0') {
            _eqRightRaw = '';
            _eqRightCursorPos = 0;
          }
          final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
          final sideCur =
              (_eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos)
                  .clamp(0, sideRaw.length);
          final (nextRaw, finalCur) = FractionTemplate.insert(sideRaw, sideCur);
          if (_eqActiveSide == 0) {
            _eqLeftRaw = nextRaw;
            _eqLeftCursorPos = finalCur;
          } else {
            _eqRightRaw = nextRaw;
            _eqRightCursorPos = finalCur;
          }
          return true;
        }
        if (_calculatorMode == 12 && _calculusActiveField == 0) {
          final cur = _calculusCursorPos.clamp(0, _calculusExprRaw.length);
          final (nextRaw, nextCur) = FractionTemplate.insert(_calculusExprRaw, cur);
          _calculusExprRaw = nextRaw;
          _calculusCursorPos = nextCur;
          return true;
        }
        final cur = _cursorPos.clamp(0, _rawInput.length);
        final (nextRaw, nextCur) = FractionTemplate.insert(_rawInput, cur);
        _rawInput = nextRaw;
        _cursorPos = nextCur;
        return true;
      }

      // Tecla ) (con ALPHA escribe variable X)
      if (key == ')') {
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsExpressionInput || _calculatorMode == 7) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
              _calculusCursorPos = _calculusExprRaw.length;
            }
            _applyRawInsertion('x');
          }
          return true;
        }
      }

      // Tecla ( (con ALPHA escribe variable Y)
      if (key == '(') {
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsScientificFns || _calculatorMode == 7) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('y');
          }
          return true;
        }
      }

      // Teclas científicas Fase 7A (CALC, °'", sin, cos, tan, log■□, ×10ˣ/%)
      if (key == 'CALC') {
        _isShiftActive = false;
        _isAlphaActive = false;
        _enterCalcPromptSync();
        return true;
      }

      if (key == 'DMS') {
        _isShiftActive = false;
        _isAlphaActive = false;
        _insertDmsSymbolSync();
        return true;
      }

      if (key == 'sin' || key == 'cos' || key == 'tan') {
        final bool isShift = _isShiftActive;
        _isShiftActive = false;
        _isAlphaActive = false;
        if (_supportsScientificFns) {
          if (_activeResolution != null) {
            _activeResolution = null;
            _activeStepIndex = 0;
            _cursorPos = _rawInput.length;
          }
          _applyRawInsertion(isShift ? '$key⁻¹(' : '$key(');
        }
        return true;
      }

      if (key == 'LOG') {
        final bool isShift = _isShiftActive;
        final bool isAlpha = _isAlphaActive;
        _isShiftActive = false;
        _isAlphaActive = false;
        if (_supportsScientificFns) {
          if (_activeResolution != null) {
            _activeResolution = null;
            _activeStepIndex = 0;
            _cursorPos = _rawInput.length;
          }
          if (isShift) {
            _applyRawInsertion('10^(');
          } else if (isAlpha) {
            _applyRawInsertion('ln(');
          } else {
            _applyRawInsertion('log_(');
          }
        }
        return true;
      }

      if (key == 'SCI10') {
        final bool isShift = _isShiftActive;
        final bool isAlpha = _isAlphaActive;
        _isShiftActive = false;
        _isAlphaActive = false;
        if (isAlpha && !isShift) return _insertTokenKey('ℯ');
        if (_supportsScientificFns) {
          if (_activeResolution != null) {
            _clearActiveResolutionCursor();
          }
          if (isShift) {
            _applyRawInsertion('%', keepLeadingZero: true);
          } else {
            final activeText = _calculatorMode == 2
                ? (_eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw)
                : _rawInput;
            final keepZero = activeText.isNotEmpty && activeText != '0';
            _applyRawInsertion(keepZero ? '*10^(' : '10^(', keepLeadingZero: keepZero);
          }
        }
        return true;
      }

      // Tecla M+
      if (key == 'M+') {
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsScientificFns) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('M');
          }
          return true;
        }
        final targetVal = _evaluator.lastEvaluatedRational ?? _memory.ans;
        _isShiftActive = false;
        final updated = _memory.mPlus(targetVal);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('M+ : ${targetVal.toLatex()} sumado a M. (M = ${updated.toLatex()})'),
            backgroundColor: const Color(0xFF1A2530),
            duration: const Duration(seconds: 2),
          ),
        );
        return true;
      }

      // SHIFT + 0 => π
      if (key == 'PI') {
        _isShiftActive = false;
        _isAlphaActive = false;
        if (_insertIntoCell('π')) return true;
        if (_supportsScientificFns) {
          if (_activeResolution != null) {
            _clearActiveResolutionCursor();
          }
          _applyRawInsertion('π');
        }
        return true;
      }

      // Tecla = (Confirmar / Resolver / Avanzar pasos)
    return false;
  }
}
