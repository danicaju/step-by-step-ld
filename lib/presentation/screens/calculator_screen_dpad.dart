part of 'calculator_screen.dart';

extension _CalculatorScreenDpad on _CalculatorScreenState {
  void _handleDpadLeft() {
    if (LcdDropdownController.active?.handleDpad('left') ?? false) return;
    updateState(() {
      if (_lcdErrorDpadGuard(dismiss: true)) return;
      if (_isSetupOpen) {
        _setupDpad('left');
        return;
      }
      if (_cw.list != null) {
        _listDpad('left');
        return;
      }
      if (_cw.prop != null) {
        _propDpad('left');
        return;
      }
      if (_cw.resetOpen) {
        _resetDpad('left');
        return;
      }
      if (_cwEngBack()) return;
      if (_isMemViewOpen) {
        _memViewDpad('left');
        return;
      }
      if (_isMenuOpen) {
        _menuCursorIndex = menuMove(_menuCursorIndex, 'left');
        return;
      }
      if (_headerDpad('left')) return;
      if (_m5Dpad('left')) return;
      if (_extraDpad('left')) return;
      if (_calculatorMode == 4 &&
          !_polyIsNotableMode &&
          _isChoosingRuffiniDegree &&
          _activeResolution == null) {
        _ruffiniDegree = _ruffiniDegree > 2 ? _ruffiniDegree - 1 : 6;
        return;
      }
      if (_activeResolution != null) {
        if (_activeStepIndex > 0) {
          _activeStepIndex--;
        }
        return;
      }
      if (_calculatorMode == 7) {
        if (_isChoosingIneqSysUnknowns) {
          _ineqSysUnknowns = _ineqSysUnknowns == 1 ? 2 : 1;
          return;
        }
        if (_ineqSysRowInputs[_ineqSysActiveRow].isEmpty) {
          _flipIneqSysUnknowns();
          return;
        }
        if (_activeResolution == null) {
          final cur = _ineqSysRowInputs[_ineqSysActiveRow];
          final pos = _ineqSysRowCursors[_ineqSysActiveRow];
          final slotLeft = ExpressionParser.handleTwoSlotLeftArrow(cur, pos);
          if (slotLeft != null) {
            _ineqSysRowInputs[_ineqSysActiveRow] = slotLeft.$1;
            _ineqSysRowCursors[_ineqSysActiveRow] = slotLeft.$2;
          } else {
            _ineqSysRowCursors[_ineqSysActiveRow] =
                ExpressionParser.stepCursorLeft(cur, pos);
          }
        }
        return;
      }
      if (_calculatorMode == 8) {
        _statMoveDpad(dRow: 0, dCol: -1);
        return;
      }
      if (_calculatorMode == 9) {
        _matrixMoveDpad(dRow: 0, dCol: -1);
        return;
      }
      if (_calculatorMode == 10) {
        _vectorMoveDpad(dRow: 0, dCol: -1);
        return;
      }
      if (_calculatorMode == 11) {
        _complexMoveDpad(dRow: 0, dCol: -1);
        return;
      }
      if (_calculatorMode == 12) {
        _calculusMoveDpad(dRow: 0, dCol: -1);
        return;
      }
      if (_isCoefficientMode) {
        if (_currentActiveIndex > 0) {
          _currentActiveIndex--;
        }
        return;
      }
      if (_calculatorMode == 2) {
        if (_eqActiveSide == 0) {
          final slotLeft = ExpressionParser.handleTwoSlotLeftArrow(_eqLeftRaw, _eqLeftCursorPos);
          if (slotLeft != null) {
            _eqLeftRaw = slotLeft.$1;
            _eqLeftCursorPos = slotLeft.$2;
          } else {
            _eqLeftCursorPos =
                ExpressionParser.stepCursorLeft(_eqLeftRaw, _eqLeftCursorPos);
          }
        } else if (_eqRightCursorPos > 0) {
          final slotLeft = ExpressionParser.handleTwoSlotLeftArrow(_eqRightRaw, _eqRightCursorPos);
          if (slotLeft != null) {
            _eqRightRaw = slotLeft.$1;
            _eqRightCursorPos = slotLeft.$2;
          } else {
            _eqRightCursorPos =
                ExpressionParser.stepCursorLeft(_eqRightRaw, _eqRightCursorPos);
          }
        } else {
          // Salta al miembro izquierdo sin tocar el = central fijo
          _eqActiveSide = 0;
          _eqLeftCursorPos = _eqLeftRaw.length;
        }
        return;
      }
      // Modo escritura libre: desplazar _cursorPos hacia la izquierda
      final slotLeft = ExpressionParser.handleTwoSlotLeftArrow(_rawInput, _cursorPos);
      if (slotLeft != null) {
        _rawInput = slotLeft.$1;
        _cursorPos = slotLeft.$2;
      } else {
        _cursorPos = ExpressionParser.stepCursorLeft(_rawInput, _cursorPos);
      }
    });
  }

  void _handleDpadRight() {
    if (LcdDropdownController.active?.handleDpad('right') ?? false) return;
    updateState(() {
      if (_lcdErrorDpadGuard(dismiss: true)) return;
      if (_isSetupOpen) {
        _setupDpad('right');
        return;
      }
      if (_cw.list != null) {
        _listDpad('right');
        return;
      }
      if (_cw.prop != null) {
        _propDpad('right');
        return;
      }
      if (_cw.resetOpen) {
        _resetDpad('right');
        return;
      }
      if (_isMemViewOpen) {
        _memViewDpad('right');
        return;
      }
      if (_isMenuOpen) {
        _menuCursorIndex = menuMove(_menuCursorIndex, 'right');
        return;
      }
      if (_headerDpad('right')) return;
      if (_m5Dpad('right')) return;
      if (_extraDpad('right')) return;
      if (_calculatorMode == 4 &&
          !_polyIsNotableMode &&
          _isChoosingRuffiniDegree &&
          _activeResolution == null) {
        _ruffiniDegree = _ruffiniDegree < 6 ? _ruffiniDegree + 1 : 2;
        return;
      }
      if (_activeResolution != null) {
        if (_activeStepIndex < _activeResolution!.steps.length - 1) {
          _activeStepIndex++;
        }
        return;
      }
      if (_calculatorMode == 7) {
        if (_isChoosingIneqSysUnknowns) {
          _ineqSysUnknowns = _ineqSysUnknowns == 1 ? 2 : 1;
          return;
        }
        if (_ineqSysRowInputs[_ineqSysActiveRow].isEmpty) {
          _flipIneqSysUnknowns();
          return;
        }
        if (_activeResolution == null) {
          final cur = _ineqSysRowInputs[_ineqSysActiveRow];
          final pos = _ineqSysRowCursors[_ineqSysActiveRow];
          final fracRight = ExpressionParser.handleFractionRightArrow(cur, pos) ??
              ExpressionParser.handlePowerRightArrow(cur, pos);
          if (fracRight != null) {
            _ineqSysRowInputs[_ineqSysActiveRow] = fracRight.$1;
            _ineqSysRowCursors[_ineqSysActiveRow] = fracRight.$2;
          } else {
            final mcmRight = ExpressionParser.handleMcmMcdRightArrow(cur, pos);
            final slotRight = mcmRight ??
                ExpressionParser.handleTwoSlotRightArrow(cur, pos);
            final blockRight = slotRight ??
                ExpressionParser.handleStructuredBlockRightArrow(cur, pos);
            if (blockRight != null) {
              _ineqSysRowInputs[_ineqSysActiveRow] = blockRight.$1;
              _ineqSysRowCursors[_ineqSysActiveRow] = blockRight.$2;
            } else {
              _ineqSysRowCursors[_ineqSysActiveRow] =
                  ExpressionParser.stepCursorRight(cur, pos);
            }
          }
        }
        return;
      }
      if (_calculatorMode == 8) {
        _statMoveDpad(dRow: 0, dCol: 1);
        return;
      }
      if (_calculatorMode == 9) {
        _matrixMoveDpad(dRow: 0, dCol: 1);
        return;
      }
      if (_calculatorMode == 10) {
        _vectorMoveDpad(dRow: 0, dCol: 1);
        return;
      }
      if (_calculatorMode == 11) {
        _complexMoveDpad(dRow: 0, dCol: 1);
        return;
      }
      if (_calculatorMode == 12) {
        _calculusMoveDpad(dRow: 0, dCol: 1);
        return;
      }
      if (_isCoefficientMode) {
        final maxIdx = (_calculatorMode == 6 && _ineqDegree == 2)
            ? 3
            : _currentCellValues.length - 1;
        if (_currentActiveIndex < maxIdx) {
          _currentActiveIndex++;
        }
        return;
      }
      if (_calculatorMode == 2) {
        final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
        final sideCur = _eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos;
        final fracRight = ExpressionParser.handleFractionRightArrow(sideRaw, sideCur) ??
            ExpressionParser.handlePowerRightArrow(sideRaw, sideCur);
        if (fracRight != null) {
          if (_eqActiveSide == 0) {
            _eqLeftRaw = fracRight.$1;
            _eqLeftCursorPos = fracRight.$2;
          } else {
            _eqRightRaw = fracRight.$1;
            _eqRightCursorPos = fracRight.$2;
          }
          _replayIndex = -1;
          return;
        }
        final mcmRight = ExpressionParser.handleMcmMcdRightArrow(sideRaw, sideCur);
        final slotRight = mcmRight ?? ExpressionParser.handleTwoSlotRightArrow(sideRaw, sideCur);
        final blockRight = slotRight ?? ExpressionParser.handleStructuredBlockRightArrow(sideRaw, sideCur);
        if (blockRight != null) {
          if (_eqActiveSide == 0) {
            _eqLeftRaw = blockRight.$1;
            _eqLeftCursorPos = blockRight.$2;
          } else {
            _eqRightRaw = blockRight.$1;
            _eqRightCursorPos = blockRight.$2;
          }
          _replayIndex = -1;
        } else if (_eqActiveSide == 0 && _eqLeftCursorPos >= _eqLeftRaw.length) {
          _eqActiveSide = 1;
          _eqRightCursorPos = 0;
        } else {
          final stepped = ExpressionParser.stepCursorRight(sideRaw, sideCur);
          if (_eqActiveSide == 0) {
            _eqLeftCursorPos = stepped;
          } else {
            _eqRightCursorPos = stepped;
          }
        }
        return;
      }
      // Modo escritura libre: salir de fracción con ' ', o en mcm/mcd o log_/root abre hueco; si no, desplaza _cursorPos
      final fracRight = ExpressionParser.handleFractionRightArrow(
        _rawInput,
        _cursorPos,
      ) ?? ExpressionParser.handlePowerRightArrow(
        _rawInput,
        _cursorPos,
      );
      if (fracRight != null) {
        _rawInput = fracRight.$1;
        _cursorPos = fracRight.$2;
        _replayIndex = -1;
      } else {
        final mcmRight = ExpressionParser.handleMcmMcdRightArrow(
          _rawInput,
          _cursorPos,
        );
      if (mcmRight != null) {
        _rawInput = mcmRight.$1;
        _cursorPos = mcmRight.$2;
        _replayIndex = -1;
      } else {
        final slotRight = ExpressionParser.handleTwoSlotRightArrow(
          _rawInput,
          _cursorPos,
        );
        if (slotRight != null) {
          _rawInput = slotRight.$1;
          _cursorPos = slotRight.$2;
          _replayIndex = -1;
        } else {
          final blockRight = ExpressionParser.handleStructuredBlockRightArrow(
            _rawInput,
            _cursorPos,
          );
          if (blockRight != null) {
            _rawInput = blockRight.$1;
            _cursorPos = blockRight.$2;
            _replayIndex = -1;
          } else {
            _cursorPos = ExpressionParser.stepCursorRight(_rawInput, _cursorPos);
          }
        }
      }
    }
    });
  }

}
