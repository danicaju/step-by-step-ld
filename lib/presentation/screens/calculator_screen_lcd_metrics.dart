part of 'calculator_screen.dart';

extension _CalculatorScreenLcdMetrics on _CalculatorScreenState {
  /// Alto minimo (sin barra de estado) que necesita el cuerpo de la LCD en el modo actual.
  /// Por debajo de ese alto la LCD hace scroll vertical en vez de desbordar; `null` = automatico.
  double? _lcdBodyMinHeight() {
    if (_activeResolution != null) return null;
    if (_extraFormActive) return 190;
    switch (_calculatorMode) {
      case 8:
        return 70 + 34.0 * _statRows.length.clamp(2, 12);
      case 9:
        final rows = _matrixActiveTarget == 1 ? _matrixRowsB : _matrixRowsA;
        return 52 + 52.0 * rows;
      case 10:
        return 78 + 50.0 * _vectorDim;
      case 11:
        return 150;
      case 12:
        return 190;
    }
    return null;
  }
}
