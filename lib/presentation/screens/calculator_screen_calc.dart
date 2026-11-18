part of 'calculator_screen.dart';

/// CALC en M1: pide `x?` (y `y?`), evalua y vuelve a preguntar con `=`.
extension _CalculatorScreenCalc on _CalculatorScreenState {
  /// Variables algebraicas `x`/`y` (minusculas) presentes en [expr]; las mayusculas son memorias.
  List<String> _calcVariablesIn(String expr) => [
        for (final v in M1SymbolicSolver.variablesIn(expr)) v.toUpperCase(),
      ]..sort();

  void _enterCalcPromptSync() {
    if (_calculatorMode != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La tecla CALC evalúa expresiones con x en el Modo 1 (Cálculo).'),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final candidate = ExpressionParser.finalizeForEvaluation(_rawInput);
    final vars = candidate == '0' ? <String>[] : _calcVariablesIn(candidate);
    if (vars.isEmpty) {
      _openMemoryViewer();
      return;
    }
    _beginCalcPrompt(candidate, vars);
  }

  void _beginCalcPrompt(String expr, List<String> vars) {
    _activeResolution = null;
    _activeStepIndex = 0;
    _showDecimalApprox = false;
    _isShiftActive = false;
    _isAlphaActive = false;
    _calcExpressionRaw = expr;
    _calcValueRaw = '';
    _cw.calcVars = vars;
    _cw.calcIdx = 0;
    _cw.calcValues.clear();
    _cw.calcResult = null;
    _isCalcPromptActive = true;
  }

  /// Etiqueta del prompt actual (`x`, `y`).
  String get _calcPromptVar =>
      _cw.calcIdx < _cw.calcVars.length ? _cw.calcVars[_cw.calcIdx].toLowerCase() : 'x';

  /// `=` sobre un resultado de CALC: vuelve a pedir `x?`.
  bool _reaskCalc() {
    final res = _activeResolution;
    if (_calculatorMode != 1 || res == null || !identical(res, _cw.calcResult)) return false;
    _beginCalcPrompt(_calcExpressionRaw, _cw.calcVars);
    return true;
  }

  void _submitCalcEvalSync() {
    final valRaw = _calcValueRaw.trim().isEmpty ? '0' : _calcValueRaw.trim();
    Rational? parsed;
    try {
      if (valRaw.contains('/')) {
        final parts = valRaw.split('/');
        if (parts.length == 2) {
          parsed = Rational(int.parse(parts[0]), int.parse(parts[1]));
        }
      } else if (valRaw.contains('.')) {
        parsed = Rational.fromDecimalString(valRaw);
      } else {
        parsed = Rational(int.parse(valRaw));
      }
    } catch (_) {
      parsed = null;
    }
    if (parsed == null) {
      _showLcdError('Introduce un número válido para $_calcPromptVar (ej: -3 o 1/2).');
      return;
    }
    _cw.calcValues[_cw.calcVars[_cw.calcIdx]] = parsed;
    if (_cw.calcIdx < _cw.calcVars.length - 1) {
      _cw.calcIdx++;
      _calcValueRaw = '';
      return;
    }
    _finishCalc();
  }

  void _finishCalc() {
    try {
      final vars = _cw.calcVars;
      final mem = _memory.getAllVariablesWithAns();
      for (final v in vars.skip(1)) {
        mem[v] = _cw.calcValues[v]!;
      }
      final ast = _parser.parse(_calcExpressionRaw);
      final res = CalcSolver.evaluateCalc(
        expr: ast,
        xValue: _cw.calcValues[vars.first]!,
        targetVariable: vars.first,
        memoryVars: mem,
      );
      final value = ClassWizKeyActions.rationalFromLatex(res.exactResultLatex);
      if (value != null) _memory.setAns(value);
      _isCalcPromptActive = false;
      _rawInput = _calcExpressionRaw;
      _cursorPos = _rawInput.length;
      _activeResolution = res;
      _activeStepIndex = res.steps.length - 1;
      _showDecimalApprox = false;
      _cw.calcResult = res;
      _recordCurrentResolutionToHistory(res, 'M1: CALC');
    } catch (e) {
      _showLcdError('No se pudo evaluar la expresión: $e');
    }
  }
}
