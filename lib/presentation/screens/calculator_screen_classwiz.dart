part of 'calculator_screen.dart';

/// Teclas ClassWiz de la fase CW-2: FACT, ° ' ", a b/c, ENG, STO y RESET.
extension _CalculatorScreenClassWiz on _CalculatorScreenState {
  /// Linea de resultado alternativa (o nota STO) para la resolucion actual.
  String? get _resultOverride {
    final res = _activeResolution;
    if (res == null || _calculatorMode != 1 || !identical(res, _cw.owner)) return null;
    if (_cw.note != null) return _cw.note;
    final r = ClassWizKeyActions.rationalFromLatex(res.exactResultLatex);
    final x = ClassWizKeyActions.numericValue(res.exactResultLatex, res.decimalApproxLatex);
    return switch (_cw.view) {
      CwView.normal => null,
      CwView.factor => r == null ? null : ClassWizKeyActions.factorLatex(r),
      CwView.dms => x == null ? null : ClassWizKeyActions.dmsLatex(x),
      CwView.fraction => r == null
          ? null
          : ClassWizKeyActions.fractionLatex(r, mixed: !CalculatorSettings.mixedFractions),
      CwView.eng => x == null ? null : ClassWizKeyActions.engLatex(x, _cw.engExp),
    };
  }

  /// Alterna la vista [v] del resultado. `false` si no aplica al resultado actual.
  bool _cwSetView(CwView v) {
    final res = _activeResolution;
    if (res == null || _calculatorMode != 1) return false;
    final r = ClassWizKeyActions.rationalFromLatex(res.exactResultLatex);
    final x = ClassWizKeyActions.numericValue(res.exactResultLatex, res.decimalApproxLatex);
    final applies = switch (v) {
      CwView.factor => r != null && ClassWizKeyActions.factorLatex(r) != null,
      CwView.dms => x != null,
      CwView.fraction => r != null && !r.isInteger,
      CwView.eng => x != null && x != 0,
      CwView.normal => true,
    };
    if (!applies) return false;
    if (!identical(_cw.owner, res)) {
      _cw.owner = res;
      _cw.view = CwView.normal;
    }
    _cw.note = null;
    if (v == CwView.eng) {
      final active = _cw.view == CwView.eng;
      _cw.engExp = active ? _cw.engExp + 3 : ClassWizKeyActions.engBaseExponent(x!);
      _cw.view = CwView.eng;
    } else {
      _cw.view = _cw.view == v ? CwView.normal : v;
    }
    _activeStepIndex = res.steps.length - 1;
    _showDecimalApprox = false;
    return true;
  }

  /// `◀` con el resultado en ENG: baja el exponente 3 posiciones.
  bool _cwEngBack() {
    final res = _activeResolution;
    if (res == null || _calculatorMode != 1) return false;
    if (!identical(_cw.owner, res) || _cw.view != CwView.eng) return false;
    _cw.engExp -= 3;
    return true;
  }

  /// Teclas ClassWiz de hardware. `true` si la pulsacion queda consumida.
  bool _handleClassWizHw(String key) {
    _cw.note = null;
    if (_cw.resetOpen) return _handleResetKey(key);
    if (_cw.stoPending) return _handleStoKey(key);
    if (!_isShiftActive || !_hwFreeEditing) return false;
    switch (key) {
      case '9':
        _openReset();
        return true;
      case '(':
        if (_calculatorMode != 1) return false;
        _isShiftActive = false;
        _cw.stoPending = true;
        return true;
      case '3':
        if (_calculatorMode != 1 || _activeResolution == null) return false;
        _isShiftActive = false;
        if (!_cwSetView(CwView.eng)) _applyRawInsertion('3');
        return true;
      case 'SD':
        _isShiftActive = false;
        _cwSetView(CwView.fraction);
        return true;
    }
    return false;
  }

  // ---- STO ----
  bool _handleStoKey(String key) {
    _isShiftActive = false;
    _isAlphaActive = false;
    if (key == 'AC') {
      _cw.stoPending = false;
      return true;
    }
    const names = {
      '7': 'A', '8': 'B', '9': 'C', '4': 'D', '5': 'E', '6': 'F',
      '1': 'X', '2': 'Y', 'ANS': 'M',
    };
    final name = names[key];
    if (name == null) return true;
    _cw.stoPending = false;
    if (_activeResolution == null) _solveCurrentMode();
    final res = _activeResolution;
    if (res == null) return true;
    _storeInMemory(name, _memory.ans);
    _cw.owner = res;
    _cw.view = CwView.normal;
    _cw.note = '\\text{Ans} \\rightarrow $name';
    _activeStepIndex = res.steps.length - 1;
    return true;
  }

  // ---- RESET ----
  void _openReset() {
    _isShiftActive = false;
    _isAlphaActive = false;
    _cw.resetOpen = true;
    _cw.resetStage = 0;
    _cw.resetChoice = 0;
  }

  bool _handleResetKey(String key) {
    _isShiftActive = false;
    _isAlphaActive = false;
    final n = int.tryParse(key);
    if (key == 'AC') {
      _cw.resetOpen = false;
    } else if (_cw.resetStage == 0) {
      if (n != null && n >= 1 && n <= 3) {
        _cw.resetChoice = n - 1;
        _cw.resetStage = 1;
      } else if (key == '=') {
        _cw.resetStage = 1;
      }
    } else if (key == '=') {
      _applyReset();
    }
    return true;
  }

  void _resetDpad(String dir) {
    if (_cw.resetStage != 0 || (dir != 'up' && dir != 'down')) return;
    _cw.resetChoice = (_cw.resetChoice + (dir == 'down' ? 1 : 2)) % 3;
  }

  void _applyReset() {
    final c = _cw.resetChoice;
    if (c != 1) {
      CalculatorSettings.reset();
      _angleUnit = AngleUnit.deg;
      _lcdTheme = LcdTheme.classic;
    }
    if (c != 0) _memory.resetAll();
    if (c == 2) _resetFieldsForMode(1);
    _cw.resetOpen = false;
  }

  Widget _buildResetView() => LcdResetView(
        theme: _lcdTheme,
        stage: _cw.resetStage,
        choice: _cw.resetChoice,
        onTapOption: (i) => updateState(() {
          _cw.resetChoice = i;
          _cw.resetStage = 1;
        }),
      );
}
