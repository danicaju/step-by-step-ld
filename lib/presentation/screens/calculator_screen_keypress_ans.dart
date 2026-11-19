part of 'calculator_screen.dart';

/// Continuidad natural tras `=` en M1: un operador binario encadena con `Ans`;
/// cualquier otra tecla de contenido empieza una expresión limpia.
extension _CalculatorScreenKeypressAns on _CalculatorScreenState {
  static const Set<String> _ansBinaryKeys = {'+', '-', '*', ':', '^2'};
  static const Set<String> _ansFreshKeys = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '(', '/', 'sin',
    'cos', 'tan', 'LOG', '√', 'PI', 'SCI10',
  };

  /// Prepara el búfer antes de insertar `key`. Devuelve `true` si lo ha cambiado.
  bool _prepareAfterEquals(String key) {
    if (_calculatorMode != 1 || _activeResolution == null) return false;
    if (_isShiftActive || _isAlphaActive || _isMenuOpen || _isSetupOpen) return false;
    if (_isCalcPromptActive || _isMemViewOpen) return false;
    final binary = _ansBinaryKeys.contains(key);
    if (!binary && !_ansFreshKeys.contains(key)) return false;
    _resetMultiStatement();
    _activeResolution = null;
    _activeStepIndex = 0;
    _showDecimalApprox = false;
    if (binary) {
      _rawInput = 'ANS';
      _cursorPos = 3;
    } else {
      _rawInput = '0';
      _cursorPos = 1;
    }
    return true;
  }
}
