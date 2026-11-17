part of 'calculator_screen.dart';

/// Funciones SHIFT impresas en el teclado: `≈`, `OFF`, `Pol(`, `Rec(` e `INS`.
extension _CalculatorScreenKeypressHw on _CalculatorScreenState {
  bool get _hwFreeEditing =>
      !_isMenuOpen && !_isSetupOpen && !_isCalcPromptActive && _isMemViewOpen == false && !_cw.resetOpen && _cw.list == null && _cw.prop == null;

  /// Devuelve `true` si la pulsación fue consumida por el hardware (apagado o SHIFT+tecla).
  bool _handleKeyPressHw(String key) {
    if (_isPoweredOff) {
      if (key == 'AC') _powerOn();
      return true;
    }
    if (_handleClassWizHw(key)) return true;
    if (_isMemViewOpen) return _handleMemViewKey(key);
    if (!_isShiftActive || !_hwFreeEditing) return false;
    switch (key) {
      case 'AC':
        _powerOff();
        return true;
      case 'DEL':
        _isShiftActive = false;
        _isInsertMode = !_isInsertMode;
        return true;
      case '=':
        if (_calculatorMode != 1) return false;
        _isShiftActive = false;
        _solveApproximation();
        return true;
      case '+':
      case '-':
        if (_calculatorMode != 1) return false;
        _isShiftActive = false;
        _replayIndex = -1;
        _applyRawInsertion(key == '+' ? 'Pol(' : 'Rec(', keepLeadingZero: false);
        return true;
    }
    return false;
  }

  void _powerOff() {
    _isShiftActive = false;
    _isAlphaActive = false;
    _isPoweredOff = true;
  }

  void _powerOn() {
    _isPoweredOff = false;
    _isShiftActive = false;
    _isAlphaActive = false;
    _activeResolution = null;
    _activeStepIndex = 0;
    _showDecimalApprox = false;
    _lcdErrorKind = null;
    _rawInput = '0';
    _cursorPos = 1;
    _replayIndex = -1;
  }

  /// SHIFT + `=` (≈): resuelve y muestra directamente la aproximación decimal.
  void _solveApproximation() {
    if (_activeResolution == null) _solveMode1();
    final res = _activeResolution;
    if (res != null && res.steps.isNotEmpty) {
      _activeStepIndex = res.steps.length - 1;
      _showDecimalApprox = true;
    }
  }

  /// Resuelve `Pol(x,y)` / `Rec(r,θ)` si la entrada lo es. Devuelve la resolución o `null`.
  StepByStepResolution? _tryPolRec(String finalized) {
    final m = RegExp(r'^(Pol|Rec)\((.*)\)$').firstMatch(finalized.trim());
    if (m == null) return null;
    final parts = BalancedScan.splitTopLevel(m.group(2)!);
    if (parts.length != 2 || parts.any((p) => p.trim().isEmpty)) {
      throw const FormatException('Pol/Rec necesita dos argumentos separados por coma (usa ▶).');
    }
    final vars = _memory.getAllVariablesWithAns();
    final a = EvaluatorQuickEval.evalToRationalQuick(_parser.parse(parts[0].trim()), vars);
    final bNode = _parser.parse(parts[1].trim());
    final bD = EvaluatorQuickEval.evalToDoubleQuick(bNode, memoryVariables: vars);
    if (a == null || bD == null) {
      throw const FormatException('Los argumentos de Pol/Rec deben ser numéricos.');
    }
    final bRat = EvaluatorQuickEval.evalToRationalQuick(bNode, vars);
    final PolRecResult out;
    if (m.group(1) == 'Pol') {
      out = PolRecSolver.pol(a, bRat ?? Rational.fromDouble(bD, 100000), _angleUnit);
    } else {
      out = PolRecSolver.rec(a, bD, _angleUnit);
    }
    _memory.storeVariable('X', Rational.fromDouble(out.first, 100000));
    _memory.storeVariable('Y', Rational.fromDouble(out.second, 100000));
    return out.resolution;
  }
}
