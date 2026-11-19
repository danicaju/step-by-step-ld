part of 'calculator_screen.dart';

extension _CalculatorScreenModeReset on _CalculatorScreenState {
  void _selectModeFromMenu(int mode) {
    if (mode >= 1 && mode <= 12) {
      updateState(() {
        _isMenuOpen = false;
        _resetFieldsForMode(mode);
      });
    }
  }

  void _setRuffiniDegree(int degree, {required bool enterTemplate}) {
    final safeDegree = degree.clamp(2, 6);
    _ruffiniDegree = safeDegree;
    _ruffiniValues = List<String>.filled(safeDegree + 2, '');
    _ruffiniLabels = [..._CalculatorScreenState._allRuffiniLabels.sublist(0, safeDegree + 1), 'r'];
    _ruffiniActiveIndex = 0;
    _isChoosingRuffiniDegree = !enterTemplate;
    _activeResolution = null;
    _activeStepIndex = 0;
  }

  void _resetFieldsForMode(int mode) {
    _calculatorMode = mode;
    _cw.prop = null;
    _activeStepIndex = 0;
    _showDecimalApprox = false;
    _isShiftActive = false;
    _isAlphaActive = false;
    _activeResolution = null;
    _isMenuOpen = false;
    _isSetupOpen = false;
    _isCalcPromptActive = false;
    _calcExpressionRaw = '';
    _calcValueRaw = '';

    // Al cambiar de modo, arranca 100 % limpio como en una Casio real
    _rawInput = '0';
    _cursorPos = 1;

    _eqLeftRaw = '';
    _eqLeftCursorPos = 0;
    _eqRightRaw = '';
    _eqRightCursorPos = 0;
    _eqActiveSide = 0;

    _systemDim = 2;
    for (int i = 0; i < _sysValues.length; i++) {
      _sysValues[i] = '';
    }
    _sysActiveIndex = 0;

    _polyIsNotableMode = false;
    _setRuffiniDegree(3, enterTemplate: true);

    for (int i = 0; i < _graphValues.length; i++) {
      _graphValues[i] = '';
    }
    for (int i = 0; i < _ratValues.length; i++) {
      _ratValues[i] = '';
    }
    _graphKind = 0;
    _graphActiveIndex = 0;
    _currentGraphAnalysis = null;
    _selectedGraphPoint = null;
    _showGraphView = true;
    _cw.m5.reset();
    _cw.x.reset();

    _ineqDegree = 1;
    _inequalitySign = InequalitySign.less;
    _activeIneqVisualData = null;

    _ineqSysUnknowns = 1;
    _ineqSysRows = 2;
    for (int i = 0; i < _ineqSysRowInputs.length; i++) {
      _ineqSysRowInputs[i] = '';
      _ineqSysRowCursors[i] = 0;
    }
    _ineqSysActiveRow = 0;
    _show2DRegionView = _ineqSysUnknowns == 2;
    _currentFeasibleRegion = null;

    _statRows = [(xi: '', fi: '')];
    _statActiveRow = 0;
    _statActiveCol = 0;

    _matrixDim = 3;
    _matrixActiveTarget = 0;
    _matrixOp = MatrixOperation.determinant;
    for (int i = 0; i < _matrixCellsA.length; i++) {
      _matrixCellsA[i] = '';
      _matrixCellsB[i] = '';
    }
    _matrixScalarK = '';
    _matrixActiveRow = 0;
    _matrixActiveCol = 0;

    for (int i = 0; i < _sys3Values.length; i++) {
      _sys3Values[i] = '';
    }
    _sys3ActiveIndex = 0;
    for (int i = 0; i < _sys4Values.length; i++) {
      _sys4Values[i] = '';
    }
    _sys4ActiveIndex = 0;

    _vectorDim = 3;
    _vectorOp = VectorOperation.dotAndAngle;
    for (int i = 0; i < _vecUCells.length; i++) {
      _vecUCells[i] = '';
      _vecVCells[i] = '';
      _vecWCells[i] = '';
    }
    _vectorActiveRow = 0;
    _vectorActiveCol = 0;

    _complexOp = ComplexOperation.add;
    for (int i = 0; i < _complexCells.length; i++) {
      _complexCells[i] = '';
    }
    _complexActiveIndex = 0;

    _calculusOp = CalculusOperation.derivative;
    _calculusExprRaw = '';
    _calculusCursorPos = 0;
    _calculusX0Raw = '';
    _calculusLimitARaw = '';
    _calculusLimitBRaw = '';
    _calculusActiveField = 0;
  }

  void _handleFactorize() {
    updateState(() {
      _isShiftActive = false;
      _isAlphaActive = false;
    });

    if (_cwSetView(CwView.factor)) return;
    int? n = int.tryParse(_rawInput.trim());
    if (n == null && _activeResolution != null) {
      n = int.tryParse(_activeResolution!.exactResultLatex.trim());
    }

    if (n != null && n > 0) {
      updateState(() {
        _activeResolution = RadicalAndFactorSolver.factorize(n!);
        _activeStepIndex = 0;
        _showDecimalApprox = false;
      });
      _recordCurrentResolutionToHistory(_activeResolution!, 'M1: FACT');
      return;
    }

    try {
      final ast = _parser.parse(_rawInput);
      final res = _evaluator.evaluate(ast);
      final parsedNum = int.tryParse(res.exactResultLatex);
      if (parsedNum != null && parsedNum > 0) {
        updateState(() {
          _activeResolution = RadicalAndFactorSolver.factorize(parsedNum);
          _activeStepIndex = 0;
          _showDecimalApprox = false;
        });
        _recordCurrentResolutionToHistory(_activeResolution!, 'M1: FACT');
        return;
      }
    } catch (_) {}

    _showLcdError('Escribe un número entero positivo (ej: 360) para descomponer con FACT.');
  }

  int _parseCoeffValue(String raw, {int defaultValue = 0}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') return defaultValue;
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length == 2) {
        final n = double.tryParse(parts[0]);
        final d = double.tryParse(parts[1]);
        if (n != null && d != null && d != 0) {
          return (n / d).round();
        }
      }
    }
    final d = double.tryParse(trimmed);
    if (d != null) return d.round();
    return defaultValue;
  }


  RationalVector _buildRationalVectorFromCells(List<String> cells, int dim) {
    return RationalVector.fromRationals(
      List.generate(dim, (i) {
        return _parseRationalCell(cells[i], defaultValue: Rational(0));
      }),
    );
  }

  RationalMatrix _buildRationalMatrixFromCells(
    List<String> cells,
    int dim, {
    int? rows,
    int? cols,
  }) {
    final int rCount = rows ?? (dim == 34 ? 3 : (dim == 45 ? 4 : dim));
    final int cCount = cols ?? (dim == 34 ? 4 : (dim == 45 ? 5 : dim));
    final int stride = cells.length >= 25 ? 5 : (dim <= 3 ? 3 : 4);
    return RationalMatrix.fromRationals(
      List.generate(rCount, (r) {
        return List.generate(cCount, (c) {
          final idx = r * stride + c;
          final val = idx < cells.length ? cells[idx] : '';
          return _parseRationalCell(
            val,
            defaultValue: Rational(0),
          );
        });
      }),
    );
  }

  Rational _parseRationalCell(String raw, {Rational? defaultValue}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      if (defaultValue != null) return defaultValue;
      throw const FormatException('Celda numérica incompleta.');
    }
    return _parseStatRational(trimmed);
  }

  /// Entero o decimal de un lado de una fraccion; `null` si esta vacio o mal escrito.
  Rational? _tryRationalPart(String t) {
    final v = t.trim();
    if (v.isEmpty || v == '-') return null;
    final i = int.tryParse(v);
    if (i != null) return Rational(i);
    try {
      return Rational.fromDecimalString(v);
    } catch (_) {
      return null;
    }
  }

  Rational _parseStatRational(String raw) {
    final s = raw.trim().replaceAll(',', '.');
    if (s.contains('/')) {
      final parts = s.split('/');
      if (parts.length == 2) {
        final n = _tryRationalPart(parts[0]);
        final d = _tryRationalPart(parts[1]);
        if (n != null && d != null && !d.isZero) return n / d;
      }
      throw FormatException('Fracción incompleta o no válida: $raw');
    }
    if (s.contains('.')) {
      return Rational.fromDecimalString(s);
    }
    final parsed = int.tryParse(s);
    if (parsed == null) {
      throw FormatException('Valor xᵢ no válido: $raw');
    }
    return Rational(parsed);
  }


  void _toggleAngleUnit() {
    updateState(() {
      _angleUnit = AngleUnit.values[(_angleUnit.index + 1) % AngleUnit.values.length];
      _isShiftActive = false;
      _isAlphaActive = false;
    });
  }

  void _handleSetupOption(int option) {
    updateState(() {
      if (option == 1) {
        _angleUnit = AngleUnit.deg;
      } else if (option == 2) {
        _angleUnit = AngleUnit.rad;
      } else if (option == 3) {
        _lcdTheme = _lcdTheme == LcdTheme.night ? LcdTheme.classic : LcdTheme.night;
      }
      _isSetupOpen = false;
      _isShiftActive = false;
      _isAlphaActive = false;
    });
  }

  void _insertDmsSymbolSync() {
    if (_cwSetView(CwView.dms)) return;
    if (_activeResolution != null && _evaluator.lastEvaluatedRational != null && !_isCoefficientMode) {
      final decVal = _evaluator.lastEvaluatedRational!.toDouble();
      final res = TrigAndAnglesSolver.solveDecimalToDms(
        decVal,
        originalLatex: _evaluator.lastEvaluatedRational!.toDecimalLatex(),
      );
      _activeResolution = res;
      _activeStepIndex = 0;
      _showDecimalApprox = false;
      return;
    }
    if (_isCoefficientMode) return;
    if (_activeResolution != null) {
      _activeResolution = null;
      _activeStepIndex = 0;
      _cursorPos = _rawInput.length;
    }
    final safePos = _cursorPos.clamp(0, _rawInput.length);
    final before = _rawInput.substring(0, safePos);
    int termStart = 0;
    for (int i = before.length - 1; i >= 0; i--) {
      if ('+-*:=(,'.contains(before[i])) {
        termStart = i + 1;
        break;
      }
    }
    final slice = before.substring(termStart);
    if (!slice.contains('°')) {
      _applyRawInsertion('°', keepLeadingZero: true);
    } else if (!slice.contains("'")) {
      _applyRawInsertion("'", keepLeadingZero: true);
    } else if (!slice.contains("''") && !slice.contains('"')) {
      _applyRawInsertion("''", keepLeadingZero: true);
    } else {
      _applyRawInsertion('°', keepLeadingZero: true);
    }
  }


  void _toggleLcdTheme() {
    updateState(() {
      _isShiftActive = false;
      _isAlphaActive = false;
      _lcdTheme = _lcdTheme == LcdTheme.night ? LcdTheme.classic : LcdTheme.night;
    });
  }

  void _toggleSound() {
    updateState(() {
      _isSoundMuted = KeyClickSound.toggleMute();
    });
  }
}
