part of 'calculator_screen.dart';

/// Especificación de un desplegable de la cabecera LCD (valor entero + ítems).
class _HeaderSpec {
  final String keyName;
  final String prefix;
  final List<LcdDropdownItem<int>> items;
  final int value;
  final void Function(int) onSelect;

  const _HeaderSpec({
    required this.keyName,
    required this.prefix,
    required this.items,
    required this.value,
    required this.onSelect,
  });
}

extension _CalculatorScreenHeaderSelectors on _CalculatorScreenState {
  void _resetResolutionView() {
    _activeResolution = null;
    _activeStepIndex = 0;
    _activeIneqVisualData = null;
    _currentFeasibleRegion = null;
  }

  String _identityLabel(NotableIdentityType t) => switch (t) {
        NotableIdentityType.squareOfSum => '(A+B)²',
        NotableIdentityType.squareOfDiff => '(A-B)²',
        NotableIdentityType.sumTimesDiff => '(A+B)(A-B)',
      };

  String _identityTemplate(NotableIdentityType t) => switch (t) {
        NotableIdentityType.squareOfSum => '( + )^2',
        NotableIdentityType.squareOfDiff => '( - )^2',
        NotableIdentityType.sumTimesDiff => '( + )( - )',
      };

  Widget? _buildHeaderSelectors() {
    final specs = _headerSpecs();
    if (specs.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 2),
      child: SingleChildScrollView(
        key: const Key('lcd_header_scroll'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < specs.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              LcdDropdownSelector<int>(
                widgetKey: Key(specs[i].keyName),
                prefix: specs[i].prefix,
                value: specs[i].value,
                items: specs[i].items,
                isOledDark: _isOledDark,
                height: 22,
                fontSize: 10.5,
                isHighlighted: _headerFocus == i,
                controller: _hdrCtrls.putIfAbsent(
                    specs[i].keyName, LcdDropdownController.new),
                boundsKey: _lcdBoundsKey,
                onChanged: (v) => updateState(() {
                  _headerFocus = -1;
                  specs[i].onSelect(v);
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ¿Está el cursor en la primera celda/fila, de modo que ▲ debe subir a la cabecera?
  bool _headerCanEnter() {
    if (_m5FormActive) return _m5.atTop;
    if (_extraFormActive) return _extraForm!.atTop;
    if (_calculatorMode == 8) return _statActiveRow == 0 && _activeResolution == null;
    if (_isCoefficientMode) {
      if (_calculatorMode == 3 && _systemDim == 2) return _sysActiveIndex < 3;
      if (_calculatorMode == 3 && _systemDim == 3) return _sys3ActiveIndex < 4;
      return _currentActiveIndex == 0;
    }
    return ExpressionParser.jumpFractionUpDown(_rawInput, _cursorPos, isUp: true) == null;
  }

  /// D-Pad sobre la cabecera. ▲ entra desde la primera fila; con foco, ◀ ▶ cambian el valor,
  /// ▲ ▼ mueven entre desplegables y ▼ del último devuelve el foco al cuerpo.
  /// Devuelve `true` si consumió la pulsación.
  bool _headerDpad(String dir) {
    final specs = _headerSpecs();
    if (specs.isEmpty) {
      _headerFocus = -1;
      return false;
    }
    if (_headerFocus < 0) {
      if (dir == 'up' && _headerCanEnter()) {
        _headerFocus = 0;
        return true;
      }
      return false;
    }
    final focus = _headerFocus.clamp(0, specs.length - 1);
    final spec = specs[focus];
    switch (dir) {
      case 'left':
      case 'right':
        final idx = spec.items.indexWhere((it) => it.value == spec.value);
        final n = spec.items.length;
        final next = (idx + (dir == 'right' ? 1 : -1) + n) % n;
        spec.onSelect(spec.items[next].value);
      case 'up':
        _headerFocus = focus > 0 ? focus - 1 : 0;
      case 'down':
        _headerFocus = focus + 1 < specs.length ? focus + 1 : -1;
    }
    return true;
  }
}
