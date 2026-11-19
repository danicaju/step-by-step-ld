part of 'calculator_screen.dart';

extension _CalculatorScreenKeypressHelpers on _CalculatorScreenState {
  void _setInequalitySign(InequalitySign sign, {bool insertIfMissing = true}) {
    _inequalitySign = sign;
    if (_calculatorMode == 7) {
      if (_activeResolution != null) {
        _activeResolution = null;
        _activeStepIndex = 0;
      }
      final cur = _ineqSysRowInputs[_ineqSysActiveRow];
      final pos = _ineqSysRowCursors[_ineqSysActiveRow].clamp(0, cur.length);
      final existing = RegExp(r'(<=|>=|[≤≥<>])');
      if (existing.hasMatch(cur)) {
        _ineqSysRowInputs[_ineqSysActiveRow] = cur.replaceFirst(existing, sign.symbol);
      } else if (insertIfMissing) {
        final (nextRaw, nextPos) = ExpressionParser.insertAtCursor(
          cur,
          pos,
          ' ${sign.symbol} ',
          keepLeadingZero: true,
        );
        _ineqSysRowInputs[_ineqSysActiveRow] = nextRaw;
        _ineqSysRowCursors[_ineqSysActiveRow] = nextPos;
      }
      return;
    }
    if (_calculatorMode == 6) {
      if (_activeResolution != null) {
        _activeResolution = null;
        _activeStepIndex = 0;
        _cursorPos = _rawInput.length;
      }
      final existing = RegExp(r'(<=|>=|[≤≥<>])');
      if (existing.hasMatch(_rawInput)) {
        _rawInput = _rawInput.replaceFirst(existing, sign.symbol);
        _cursorPos = _cursorPos.clamp(0, _rawInput.length);
      } else if (insertIfMissing && _rawInput != '0' && _rawInput.trim().isNotEmpty) {
        _applyRawInsertion(sign.symbol, keepLeadingZero: true);
      }
    }
  }

  void _cycleInequalitySign({bool backwards = false, bool insertIfMissing = false}) {
    const order = InequalitySign.values;
    final idx = order.indexOf(_inequalitySign);
    final nextIdx = backwards
        ? (idx - 1 + order.length) % order.length
        : (idx + 1) % order.length;
    _setInequalitySign(order[nextIdx], insertIfMissing: insertIfMissing);
  }

  void _clearActiveResolutionCursor() {
    _resetMultiStatement();
    _activeResolution = null;
    _activeStepIndex = 0;
    if (_calculatorMode == 2) {
      if (_eqActiveSide == 0) {
        _eqLeftCursorPos = _eqLeftRaw.length;
      } else {
        _eqRightCursorPos = _eqRightRaw.length;
      }
    } else if (_calculatorMode == 12 && _calculusActiveField == 0) {
      _calculusCursorPos = _calculusExprRaw.length;
    } else if (_calculatorMode == 7) {
      _ineqSysRowCursors[_ineqSysActiveRow] =
          _ineqSysRowInputs[_ineqSysActiveRow].length;
    } else {
      _cursorPos = _rawInput.length;
    }
  }

  void _applyRawInsertion(String token, {bool keepLeadingZero = false}) {
    if (_calculatorMode == 7) {
      var cur = _ineqSysRowInputs[_ineqSysActiveRow];
      var pos = _ineqSysRowCursors[_ineqSysActiveRow];
      final isOperator = '+-*/:=<>≤≥'.contains(token);
      if (isOperator && pos == cur.length && !cur.endsWith(' ')) {
        final isFractionEnd = RegExp(r'/[0-9a-zA-Zπ.]+$').hasMatch(cur);
        final isPowerEnd = RegExp(r'\^[0-9a-zA-Zπ.]+$|\^\([^)]+\)$').hasMatch(cur);
        if (isFractionEnd || isPowerEnd) {
          cur = '$cur ';
          pos = cur.length;
        }
      }
      final (nextRaw, nextPos) = ExpressionParser.insertAtCursor(
        cur,
        pos,
        token,
        keepLeadingZero: true,
      );
      _ineqSysRowInputs[_ineqSysActiveRow] = nextRaw;
      _ineqSysRowCursors[_ineqSysActiveRow] = nextPos;
      return;
    }
    if (_calculatorMode == 2) {
      final isOperator = '+-*/:=<>≤≥'.contains(token);
      if (_eqActiveSide == 0) {
        var raw = _eqLeftRaw;
        var pos = _eqLeftCursorPos;
        if (isOperator && pos == raw.length && !raw.endsWith(' ')) {
          final isFractionEnd = RegExp(r'/[0-9a-zA-Zπ.]+$').hasMatch(raw);
          final isPowerEnd = RegExp(r'\^[0-9a-zA-Zπ.]+$|\^\([^)]+\)$').hasMatch(raw);
          if (isFractionEnd || isPowerEnd) {
            raw = '$raw ';
            pos = raw.length;
          }
        }
        final (nextRaw, nextPos) = ExpressionParser.insertAtCursor(
          raw,
          pos,
          token,
          keepLeadingZero: true,
        );
        _eqLeftRaw = nextRaw;
        _eqLeftCursorPos = nextPos;
      } else {
        var raw = _eqRightRaw;
        var pos = _eqRightCursorPos;
        if (isOperator && pos == raw.length && !raw.endsWith(' ')) {
          final isFractionEnd = RegExp(r'/[0-9a-zA-Zπ.]+$').hasMatch(raw);
          final isPowerEnd = RegExp(r'\^[0-9a-zA-Zπ.]+$|\^\([^)]+\)$').hasMatch(raw);
          if (isFractionEnd || isPowerEnd) {
            raw = '$raw ';
            pos = raw.length;
          }
        }
        final (nextRaw, nextPos) = ExpressionParser.insertAtCursor(
          raw,
          pos,
          token,
          keepLeadingZero: true,
        );
        _eqRightRaw = nextRaw;
        _eqRightCursorPos = nextPos;
      }
      return;
    }
    if (_calculatorMode == 12 && _calculusActiveField == 0) {
      final base = _calculusExprRaw.isEmpty ? '0' : _calculusExprRaw;
      final cur = _calculusExprRaw.isEmpty ? 1 : _calculusCursorPos;
      final (nextRaw, nextPos) = ExpressionParser.insertAtCursor(
        base,
        cur,
        token,
        keepLeadingZero: keepLeadingZero,
      );
      _calculusExprRaw = nextRaw;
      _calculusCursorPos = nextPos;
      return;
    }
    final isOperator = '+-*/:=<>≤≥'.contains(token);
    if (isOperator && _cursorPos == _rawInput.length && !_rawInput.endsWith(' ')) {
      final isFractionEnd = RegExp(r'/[0-9a-zA-Zπ.]+$').hasMatch(_rawInput);
      final isPowerEnd = RegExp(r'\^[0-9a-zA-Zπ.]+$|\^\([^)]+\)$').hasMatch(_rawInput);
      if (isFractionEnd || isPowerEnd) {
        _rawInput = '$_rawInput ';
        _cursorPos = _rawInput.length;
      }
    }
    // Conservar espacio si el usuario acaba de salir de una fracción con ▶
    if (_rawInput.endsWith(' ') && _cursorPos == _rawInput.length) {
      if (!'+-*^/()=<>≤≥'.contains(token)) {
        _rawInput = _rawInput.substring(0, _rawInput.length - 1);
        _cursorPos = _rawInput.length;
      }
    }
    final (nextRaw, nextPos) = ExpressionParser.insertAtCursor(
      _rawInput,
      _cursorPos,
      token,
      keepLeadingZero: keepLeadingZero,
      overwrite: !_isInsertMode,
    );
    _rawInput = nextRaw;
    _cursorPos = nextPos;
  }

  void _insertEqualsInEquation() {
    if (_calculatorMode == 2) {
      updateState(() {
        _isShiftActive = false;
        _isAlphaActive = false;
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
        }
        _eqActiveSide = _eqActiveSide == 0 ? 1 : 0;
      });
      return;
    }
    if (_rawInput.contains('=') && _activeResolution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La ecuación ya contiene un signo =.'),
          backgroundColor: Color(0xFFB45309),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    updateState(() {
      _isShiftActive = false;
      _isAlphaActive = false;
      if (_activeResolution != null) {
        _clearActiveResolutionCursor();
      }
      if (_rawInput.contains('=')) return;
      _applyRawInsertion('=', keepLeadingZero: true);
    });
  }

  void _restoreMode2EquationString(String rawEq) {
    final eqIdx = rawEq.indexOf('=');
    if (eqIdx >= 0) {
      _eqLeftRaw = rawEq.substring(0, eqIdx).trim();
      _eqRightRaw = rawEq.substring(eqIdx + 1).trim();
      _eqLeftCursorPos = _eqLeftRaw.length;
      _eqRightCursorPos = _eqRightRaw.length;
      _eqActiveSide = 1;
    } else {
      _eqLeftRaw = rawEq.trim();
      _eqLeftCursorPos = _eqLeftRaw.length;
      _eqRightRaw = '';
      _eqRightCursorPos = 0;
      _eqActiveSide = 0;
    }
  }

}
