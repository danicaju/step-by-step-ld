part of 'calculator_screen.dart';

/// Edicion: deshacer tras AC/DEL, cierre automatico de parentesis y teclado fisico.
extension _CalculatorScreenEditing on _CalculatorScreenState {
  /// Modos cuya entrada vive en `_rawInput` / `_cursorPos`.
  bool get _usesRawEditor =>
      _calculatorMode == 1 || (_calculatorMode == 4 && _polyIsNotableMode) || _calculatorMode == 6;

  /// Se ejecuta antes de cada tecla: guarda el estado para `Undo` y cierra los `(` pendientes en `=`.
  void _editingHook(String key) {
    if (!_usesRawEditor || _isMenuOpen || _isSetupOpen || _isPoweredOff) return;
    switch (key) {
      case 'AC':
        _undoPillVisible = _undo.push(_rawInput, _cursorPos);
        return;
      case 'DEL':
      case '/':
      case '√':
      case 'LOG':
        _undo.push(_rawInput, _cursorPos);
      case '=':
        if (_activeResolution == null) _rawInput = GhostParenthesesHelper.closeAll(_rawInput);
    }
    _undoPillVisible = false;
  }

  /// Restaura el ultimo estado guardado (Ctrl+Z / Cmd+Z o pastilla DESHACER).
  void _undoEdit() {
    final snap = _undo.pop();
    if (snap == null) return;
    updateState(() {
      _rawInput = snap.expression;
      _cursorPos = snap.cursorIndex.clamp(0, snap.expression.length);
      _activeResolution = null;
      _activeStepIndex = 0;
      _showDecimalApprox = false;
      _lcdErrorKind = null;
      _undoPillVisible = false;
    });
  }

  void _handlePhysicalDpad(String dir) => switch (dir) {
        'left' => _handleDpadLeft(),
        'right' => _handleDpadRight(),
        'up' => _handleDpadUp(),
        _ => _handleDpadDown(),
      };
}
