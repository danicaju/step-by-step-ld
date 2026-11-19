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
        NotableIdentityType.cubeOfSum => '(A+B)³',
        NotableIdentityType.cubeOfDiff => '(A-B)³',
        NotableIdentityType.differenceOfSquares => 'A²-B² (factorizar)',
      };

  String _identityTemplate(NotableIdentityType t) => switch (t) {
        NotableIdentityType.squareOfSum => '( + )^2',
        NotableIdentityType.squareOfDiff => '( - )^2',
        NotableIdentityType.sumTimesDiff => '( + )( - )',
        NotableIdentityType.cubeOfSum => '( + )^3',
        NotableIdentityType.cubeOfDiff => '( - )^3',
        NotableIdentityType.differenceOfSquares => '',
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
                controller: _hdrCtrls.putIfAbsent(
                    specs[i].keyName, LcdDropdownController.new),
                boundsKey: _lcdBoundsKey,
                onChanged: (v) => updateState(() => specs[i].onSelect(v)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
