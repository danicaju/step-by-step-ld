part of 'calculator_screen.dart';

/// Menú SETUP completo (SHIFT + MODE): estado, teclas, D-Pad y aplicación de ajustes.
extension _CalculatorScreenSetup on _CalculatorScreenState {
  String get _angleLabel => const ['DEG', 'RAD', 'GRA'][_angleUnit.index];

  void _openSetup() {
    _setupRow = 0;
    _setupSubCursor = -1;
    _setupDigitsFor = null;
    _isSetupOpen = true;
  }

  List<String> _setupCurrentValues() => [
        _angleLabel.toLowerCase() == 'deg' ? 'DEG' : _angleLabel,
        CalculatorSettings.numberFormatLabel,
        CalculatorSettings.mixedFractions ? 'ab/c' : 'd/c',
        CalculatorSettings.decimalComma ? 'Coma' : 'Punto',
        const ['Clásica', 'Papel', 'Nocturno'][_lcdTheme.index],
        CalculatorSettings.mathOutput == MathOutputMode.mathO ? 'MathO' : 'DecimalO',
        CalculatorSettings.digitSeparator ? 'Sí' : 'No',
        '',
      ];

  int _setupCurrentOption(int row) => switch (row) {
        0 => _angleUnit.index,
        1 => CalculatorSettings.numberFormat.index,
        2 => CalculatorSettings.mixedFractions ? 1 : 0,
        3 => CalculatorSettings.decimalComma ? 1 : 0,
        4 => _lcdTheme.index,
        5 => CalculatorSettings.mathOutput.index,
        6 => CalculatorSettings.digitSeparator ? 1 : 0,
        _ => 0,
      };

  Widget _buildSetupView() {
    return LcdSetupMenuView(
      theme: _lcdTheme,
      focusRow: _setupRow,
      subCursor: _setupSubCursor,
      digitsPrompt: _setupDigitsFor == null
          ? null
          : (_setupDigitsFor == NumberFormatMode.fix ? 'Fix' : 'Sci'),
      currentValues: _setupCurrentValues(),
      currentOption: _setupCurrentOption(_setupRow),
      onTapRow: (r) => updateState(() {
        _setupRow = r;
        _setupSubCursor = _setupCurrentOption(r);
      }),
      onTapOption: (i) => updateState(() => _applySetupChoice(_setupRow, i)),
      onTapDigit: (d) => updateState(() => _applySetupDigits(d)),
    );
  }

  void _closeSetup() {
    _isSetupOpen = false;
    _setupSubCursor = -1;
    _setupDigitsFor = null;
  }

  void _applySetupDigits(int d) {
    CalculatorSettings.numberFormat = _setupDigitsFor!;
    CalculatorSettings.digits = d;
    _closeSetup();
  }

  void _applySetupChoice(int row, int idx) {
    switch (row) {
      case 0:
        _angleUnit = AngleUnit.values[idx];
      case 1:
        if (idx == 0) {
          CalculatorSettings.numberFormat = NumberFormatMode.norm;
        } else {
          _setupDigitsFor = NumberFormatMode.values[idx];
          return;
        }
      case 2:
        CalculatorSettings.mixedFractions = idx == 1;
      case 3:
        CalculatorSettings.decimalComma = idx == 1;
      case 4:
        _lcdTheme = LcdTheme.values[idx];
      case 5:
        CalculatorSettings.mathOutput = MathOutputMode.values[idx];
      case 6:
        CalculatorSettings.digitSeparator = idx == 1;
      case 7:
        if (idx == 0) {
          _memory.resetAll();
        } else {
          CalculatorSettings.reset();
          _angleUnit = AngleUnit.deg;
          _lcdTheme = LcdTheme.classic;
        }
    }
    _activeResolution = null;
    _closeSetup();
  }

  /// Teclado físico con SETUP abierto. Siempre consume la pulsación.
  bool _handleSetupKey(String key) {
    _isShiftActive = false;
    _isAlphaActive = false;
    final n = int.tryParse(key);
    if (_setupDigitsFor != null) {
      if (key == 'AC') {
        _setupDigitsFor = null;
      } else if (n != null) {
        _applySetupDigits(n);
      }
      return true;
    }
    if (_setupSubCursor >= 0) {
      final count = kSetupRowOptions[_setupRow].length;
      if (key == 'AC') {
        _setupSubCursor = -1;
      } else if (key == '=') {
        _applySetupChoice(_setupRow, _setupSubCursor);
      } else if (n != null && n >= 1 && n <= count) {
        _applySetupChoice(_setupRow, n - 1);
      }
      return true;
    }
    if (key == 'AC') {
      _closeSetup();
    } else if (key == '=') {
      _setupSubCursor = _setupCurrentOption(_setupRow);
    } else if (n != null && n >= 1 && n <= 8) {
      _setupRow = n - 1;
      _setupSubCursor = _setupCurrentOption(_setupRow);
    }
    return true;
  }

  /// D-Pad con SETUP abierto (▲▼ mueven fila/opción, ◀▶ cambian de página).
  void _setupDpad(String dir) {
    if (_setupDigitsFor != null) return;
    final vertical = dir == 'up' || dir == 'down';
    final step = dir == 'down' || dir == 'right' ? 1 : -1;
    if (_setupSubCursor >= 0) {
      if (!vertical) return;
      final count = kSetupRowOptions[_setupRow].length;
      _setupSubCursor = (_setupSubCursor + step + count) % count;
      return;
    }
    if (vertical) {
      _setupRow = (_setupRow + step + 8) % 8;
    } else {
      final next = ((_setupRow ~/ 3 + step + 3) % 3) * 3 + _setupRow % 3;
      _setupRow = next < 8 ? next : 7;
    }
  }

  /// MathI/DecimalO: tras `=` en M1 muestra directamente el resultado decimal.
  void _applyDecimalOutputPreference() {
    if (CalculatorSettings.mathOutput != MathOutputMode.decimalO) return;
    final res = _activeResolution;
    if (res == null || res.steps.isEmpty) return;
    updateState(() {
      _activeStepIndex = res.steps.length - 1;
      _showDecimalApprox = true;
    });
  }
}
