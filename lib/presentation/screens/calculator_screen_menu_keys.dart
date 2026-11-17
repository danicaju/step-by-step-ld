part of 'calculator_screen.dart';

/// Teclado físico con el MENU abierto: `=` entra al modo enfocado y `1`-`9` entran directamente.
extension _CalculatorScreenMenuKeys on _CalculatorScreenState {
  void _enterMenuMode(int mode) {
    _menuOneTimer?.cancel();
    _menuPendingOne = false;
    _isMenuOpen = false;
    _isAlphaActive = false;
    _isShiftActive = false;
    _resetFieldsForMode(mode);
  }

  /// Siempre consume la pulsación.
  bool _handleMenuKey(String key) {
    if (key == 'AC') {
      _menuOneTimer?.cancel();
      _menuPendingOne = false;
      _isMenuOpen = false;
      _isAlphaActive = false;
      _isShiftActive = false;
      return true;
    }
    if (key == '=') {
      _enterMenuMode(CasioLcdScreen.menuModeIdAt(_menuCursorIndex));
      return true;
    }
    final n = int.tryParse(key);
    if (n == null) return true;
    // Segundo dígito tras un `1`: 10, 11 o 12.
    if (_menuPendingOne && n <= 2) {
      _enterMenuMode(10 + n);
      return true;
    }
    _menuOneTimer?.cancel();
    _menuPendingOne = false;
    if (n >= 2 && n <= 9) {
      _enterMenuMode(n);
    } else if (n == 1) {
      // `1` entra a M1 salvo que llegue enseguida un 0, 1 o 2 (M10, M11, M12).
      _menuCursorIndex = CasioLcdScreen.menuIndexForMode(1);
      _menuPendingOne = true;
      _menuOneTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted || !_menuPendingOne || !_isMenuOpen) return;
        updateState(() => _enterMenuMode(1));
      });
    }
    return true;
  }
}
