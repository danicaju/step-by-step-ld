part of 'calculator_screen.dart';

extension _CalculatorScreenLcdError on _CalculatorScreenState {
  /// Muestra un error dentro de la LCD (en lugar de un banner/SnackBar rojo).
  void _showLcdError(String message) {
    final lower = message.toLowerCase();
    final isSyntax = lower.contains('sintaxis') ||
        lower.contains('incomplet') ||
        lower.startsWith('completa') ||
        lower.startsWith('escribe') ||
        lower.startsWith('introduce');
    updateState(() {
      _lcdErrorKind = isSyntax ? LcdErrorKind.syntax : LcdErrorKind.math;
      _lcdErrorMessage = message;
    });
  }

  /// ◀ / ▶ con error: cierra el aviso y deja la expresión intacta. Devuelve `true` si consumió.
  bool _dismissLcdErrorForEdit() {
    if (_lcdErrorKind == null) return false;
    _lcdErrorKind = null;
    _lcdErrorMessage = '';
    return true;
  }

  /// Guardia del D-Pad: con error activo ◀ ▶ lo cierran y ▲ ▼ se ignoran.
  bool _lcdErrorDpadGuard({required bool dismiss}) {
    if (_lcdErrorKind == null) return false;
    if (dismiss) _dismissLcdErrorForEdit();
    return true;
  }

  Widget? _buildLcdErrorScreen() {
    final kind = _lcdErrorKind;
    if (kind == null) return null;
    return LcdErrorScreen(kind: kind, message: _lcdErrorMessage, isOledDark: _isOledDark);
  }
}
