part of 'calculator_screen.dart';

extension _CalculatorScreenDpadVertical on _CalculatorScreenState {
  void _handleDpadUp() {
    LcdBlink.markActivity();
    if (LcdDropdownController.active?.handleDpad('up') ?? false) return;
    updateState(() {
      if (_lcdErrorDpadGuard(dismiss: false)) return;
      if (_isSetupOpen) {
        _setupDpad('up');
        return;
      }
      if (_cw.list != null) {
        _listDpad('up');
        return;
      }
      if (_cw.prop != null) {
        _propDpad('up');
        return;
      }
      if (_cw.resetOpen) {
        _resetDpad('up');
        return;
      }
      if (_isMemViewOpen) {
        _memViewDpad('up');
        return;
      }
      if (_isMenuOpen) {
        _menuCursorIndex = menuMove(_menuCursorIndex, 'up');
        return;
      }
      if (_m5Dpad('up')) return;
      if (_extraDpad('up')) return;
      if (_calculatorMode == 4 &&
          !_polyIsNotableMode &&
          _isChoosingRuffiniDegree &&
          _activeResolution == null) {
        _ruffiniDegree = _ruffiniDegree > 2 ? _ruffiniDegree - 1 : 6;
        return;
      }
      if (_activeResolution != null) {
        if (_activeStepIndex > 0) {
          _activeStepIndex = 0;
        } else if (_supportsExpressionInput &&
            _calculatorMode != 11 &&
            _historyEntries.isNotEmpty) {
          // Casio Replay rápido desde el paso 1
          _activeResolution = null;
          _activeStepIndex = 0;
          _replayIndex = -1;
          _cycleHistoryReplayUp();
        }
        return;
      }
      if (_calculatorMode == 7) {
        if (_activeResolution == null && _ineqSysActiveRow > 0) {
          _ineqSysActiveRow--;
        }
        return;
      }
      if (_calculatorMode == 8) {
        _statMoveDpad(dRow: -1, dCol: 0);
        return;
      }
      if (_calculatorMode == 9) {
        _matrixMoveDpad(dRow: -1, dCol: 0);
        return;
      }
      if (_calculatorMode == 10) {
        _vectorMoveDpad(dRow: -1, dCol: 0);
        return;
      }
      if (_calculatorMode == 11) {
        _complexMoveDpad(dRow: -1, dCol: 0);
        return;
      }
      if (_calculatorMode == 12) {
        _calculusMoveDpad(dRow: -1, dCol: 0);
        return;
      }
      if (_isCoefficientMode) {
        if (_cellFracDpad('up')) return;
        if (_calculatorMode == 3 && _systemDim == 2) {
          if (_sysActiveIndex >= 3) {
            _sysActiveIndex -= 3;
          }
        } else if (_calculatorMode == 3 && _systemDim == 3) {
          if (_sys3ActiveIndex >= 4) {
            _sys3ActiveIndex -= 4;
          }
        } else if (_calculatorMode == 5 && _graphKind == 1) {
          if (_currentActiveIndex >= 2) _currentActiveIndex -= 2; // r,s -> p,q
        } else {
          if (_currentActiveIndex > 0) {
            _currentActiveIndex--;
          }
        }
        return;
      }
      if (_calculatorMode == 2) {
        final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
        final sideCur = _eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos;
        final jumped = ExpressionParser.jumpFractionUpDown(sideRaw, sideCur, isUp: true);
        if (jumped != null) {
          if (_eqActiveSide == 0) {
            _eqLeftCursorPos = jumped;
          } else {
            _eqRightCursorPos = jumped;
          }
        } else {
          _cycleHistoryReplayUp();
        }
        return;
      }
      // Modo escritura libre: saltar denominador -> numerador, ciclar desigualdad o Replay
      final jumped = ExpressionParser.jumpFractionUpDown(
        _rawInput,
        _cursorPos,
        isUp: true,
      );
      if (jumped != null) {
        _cursorPos = jumped;
      } else if (_calculatorMode == 6 && _replayIndex == -1) {
        _cycleInequalitySign(backwards: true);
      } else {
        _cycleHistoryReplayUp();
      }
    });
  }

  void _handleDpadDown() {
    LcdBlink.markActivity();
    if (LcdDropdownController.active?.handleDpad('down') ?? false) return;
    updateState(() {
      if (_lcdErrorDpadGuard(dismiss: false)) return;
      if (_isSetupOpen) {
        _setupDpad('down');
        return;
      }
      if (_cw.list != null) {
        _listDpad('down');
        return;
      }
      if (_cw.prop != null) {
        _propDpad('down');
        return;
      }
      if (_cw.resetOpen) {
        _resetDpad('down');
        return;
      }
      if (_isMemViewOpen) {
        _memViewDpad('down');
        return;
      }
      if (_isMenuOpen) {
        _menuCursorIndex = menuMove(_menuCursorIndex, 'down');
        return;
      }
      if (_m5Dpad('down')) return;
      if (_extraDpad('down')) return;
      if (_calculatorMode == 4 &&
          !_polyIsNotableMode &&
          _isChoosingRuffiniDegree &&
          _activeResolution == null) {
        _ruffiniDegree = _ruffiniDegree < 6 ? _ruffiniDegree + 1 : 2;
        return;
      }
      if (_activeResolution != null) {
        _activeStepIndex = _activeResolution!.steps.length - 1;
        return;
      }
      if (_calculatorMode == 7) {
        if (_activeResolution == null && _ineqSysActiveRow < _ineqSysRows - 1) {
          _ineqSysActiveRow++;
        }
        return;
      }
      if (_calculatorMode == 8) {
        _statMoveDpad(dRow: 1, dCol: 0);
        return;
      }
      if (_calculatorMode == 9) {
        _matrixMoveDpad(dRow: 1, dCol: 0);
        return;
      }
      if (_calculatorMode == 10) {
        _vectorMoveDpad(dRow: 1, dCol: 0);
        return;
      }
      if (_calculatorMode == 11) {
        _complexMoveDpad(dRow: 1, dCol: 0);
        return;
      }
      if (_calculatorMode == 12) {
        _calculusMoveDpad(dRow: 1, dCol: 0);
        return;
      }
      if (_isCoefficientMode) {
        if (_cellFracDpad('down')) return;
        if (_calculatorMode == 3 && _systemDim == 2) {
          if (_sysActiveIndex < 3) {
            _sysActiveIndex += 3;
          }
        } else if (_calculatorMode == 3 && _systemDim == 3) {
          if (_sys3ActiveIndex < 8) {
            _sys3ActiveIndex += 4;
          }
        } else if (_calculatorMode == 5 && _graphKind == 1) {
          if (_currentActiveIndex < 2) _currentActiveIndex += 2; // p,q -> r,s
        } else {
          if (_currentActiveIndex < _currentCellValues.length - 1) {
            _currentActiveIndex++;
          }
        }
        return;
      }
      if (_calculatorMode == 2) {
        final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
        final sideCur = _eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos;
        final jumped = ExpressionParser.jumpFractionUpDown(sideRaw, sideCur, isUp: false);
        if (jumped != null) {
          if (_eqActiveSide == 0) {
            _eqLeftCursorPos = jumped;
          } else {
            _eqRightCursorPos = jumped;
          }
        } else {
          _cycleHistoryReplayDown();
        }
        return;
      }
      // Modo escritura libre: saltar numerador -> denominador, ciclar desigualdad o Replay
      final jumped = ExpressionParser.jumpFractionUpDown(
        _rawInput,
        _cursorPos,
        isUp: false,
      );
      if (jumped != null) {
        _cursorPos = jumped;
      } else if (_calculatorMode == 6 && _replayIndex == -1) {
        _cycleInequalitySign();
      } else {
        _cycleHistoryReplayDown();
      }
    });
  }

}
