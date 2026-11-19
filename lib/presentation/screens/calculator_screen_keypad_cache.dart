part of 'calculator_screen.dart';

/// Teclado: instancia cacheada (Flutter omite el subarbol si no cambia) y accion de CALC/OPTN.
extension _CalculatorScreenKeypadCache on _CalculatorScreenState {
  /// Reutiliza el mismo `CalculatorKeypadView` mientras no cambien SHIFT, ALPHA, menus, tema ni medidas;
  /// asi pulsar un digito no reconstruye las ~40 teclas.
  Widget _cachedKeypad({
    required double controlZoneH,
    required double controlKeyVPad,
    required double dpadW,
    required double dpadH,
    double? sciMinH,
    double? numMinH,
  }) {
    final Object key = (
      _isShiftActive,
      _isAlphaActive,
      _isMenuOpen,
      _isSetupOpen,
      ThemeController.current.id,
      controlZoneH,
      controlKeyVPad,
      dpadW,
      dpadH,
      sciMinH,
      numMinH,
    );
    final cached = _keypadWidget;
    if (cached != null && _keypadKey == key) return cached;
    _keypadKey = key;
    return _keypadWidget = CalculatorKeypadView(
      controlZoneH: controlZoneH,
      controlKeyVPad: controlKeyVPad,
      dpadW: dpadW,
      dpadH: dpadH,
      sciMinH: sciMinH,
      numMinH: numMinH,
      isShiftActive: _isShiftActive,
      isAlphaActive: _isAlphaActive,
      isMenuOpen: _isMenuOpen,
      isSetupOpen: _isSetupOpen,
      onKeyPress: _handleKeyPress,
      onDpadLeft: _handleDpadLeft,
      onDpadRight: _handleDpadRight,
      onDpadUp: _handleDpadUp,
      onDpadDown: _handleDpadDown,
      onDpadCenter: _onDpadCenter,
      onOptnPressed: _onOptnPressed,
    );
  }

  void _onDpadCenter() => _handleKeyPress('=');

  void _onOptnPressed() {
    if (_isShiftActive) {
      updateState(() {
        _isShiftActive = false;
        _isAlphaActive = false;
      });
      if (_calculatorMode == 8) {
        // M8 no usa OPTN: la tabla se gestiona en pantalla.
      } else if (const [1, 9, 10].contains(_calculatorMode)) {
        updateState(() => _openList('optn'));
      } else {
        _openQuickOptnModal();
      }
    } else if (_isAlphaActive && _calculatorMode == 2) {
      _insertEqualsInEquation();
    } else if (_isAlphaActive && _calculatorMode == 1) {
      updateState(() {
        _isAlphaActive = false;
        if (_activeResolution != null) _clearActiveResolutionCursor();
        _applyRawInsertion('=');
      });
    } else {
      _handleKeyPress('CALC');
    }
  }
}
