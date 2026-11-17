part of 'calculator_screen.dart';

/// Multi-sentencia de M1: `A=5 ∶ 2A+1` (ALPHA + ÷ inserta `∶`). `=` evalua todas
/// en orden y avanza una a una mostrando el indicador `Disp`.
extension _CalculatorScreenMultiStmt on _CalculatorScreenState {
  static const String _stmtSep = '∶';
  static final RegExp _assignRe = RegExp(r'^([A-FXY])\s*=\s*(.+)$');

  bool get _showDisp =>
      _multiStmtResults.length > 1 &&
      _activeResolution != null &&
      _multiStmtIndex < _multiStmtResults.length - 1;

  void _resetMultiStatement() {
    _multiStmtResults = const [];
    _multiStmtIndex = 0;
  }

  /// Resuelve la entrada como secuencia de sentencias. `false` si no aplica.
  bool _solveMultiStatement() {
    final full = _rawInput;
    final parts = full
        .split(_stmtSep)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return false;
    if (parts.length == 1 && !_assignRe.hasMatch(parts.first)) {
      _rawInput = parts.first;
      _cursorPos = _rawInput.length;
      return false;
    }
    final results = <StepByStepResolution>[];
    _historySuppressed = true;
    try {
      for (final part in parts) {
        final m = _assignRe.firstMatch(part);
        _rawInput = m != null ? m.group(2)! : part;
        _cursorPos = _rawInput.length;
        _activeResolution = null;
        _solveMode1();
        final res = _activeResolution;
        if (_lcdErrorKind != null || res == null) {
          _rawInput = full;
          _cursorPos = full.length;
          return true;
        }
        results.add(res);
        if (m != null) _memory.storeVariable(m.group(1)!, _memory.ans);
      }
    } finally {
      _historySuppressed = false;
    }
    _rawInput = full;
    _cursorPos = full.length;
    _multiStmtResults = results;
    _multiStmtIndex = 0;
    _activeResolution = results.first;
    _activeStepIndex = 0;
    final last = _activeResolution;
    _activeResolution = results.last;
    _recordCurrentResolutionToHistory(results.last, 'M1: CALCULAR');
    _activeResolution = last;
    return true;
  }

  /// `=` con `Disp`: salta a la siguiente sentencia. `false` si era la ultima.
  bool _advanceMultiStatement() {
    if (_calculatorMode != 1 || _activeResolution == null) return false;
    if (!_showDisp) return false;
    _multiStmtIndex++;
    _activeResolution = _multiStmtResults[_multiStmtIndex];
    _activeStepIndex = 0;
    _showDecimalApprox = false;
    _applyDecimalOutputPreference();
    return true;
  }
}
