part of 'calculator_screen.dart';

/// Entrada universal `tok:<texto>`: OPTN, atajos del teclado fisico y celdas insertan
/// funciones y constantes (`sinh(`, `arcsin(`, `ℯ`, `root(`...) por el mismo canal.
extension _CalculatorScreenOptnTokens on _CalculatorScreenState {
  /// Inserta [token] en el editor activo del modo. Siempre consume la tecla.
  ///
  /// Los formularios (M3 libre, M5 limites/tabla, triangulos...) ya recibieron la
  /// tecla antes en `_handleExtraKey` / `_handleM5Key`.
  bool _insertTokenKey(String token) {
    _isShiftActive = false;
    _isAlphaActive = false;
    if (_insertIntoCell(token)) return true;
    if (!_supportsScientificFns) return true;
    if (_activeResolution != null) _clearActiveResolutionCursor();
    if (token == 'ℯ^(') {
      _applyRawInsertion('ℯ');
      _applyRawInsertion(ExponentNavigationHelper.open, keepLeadingZero: false);
    } else {
      _applyRawInsertion(token);
    }
    return true;
  }

  /// Funciones y constantes en las celdas numericas de M9, M10 (vectores) y M11.
  /// En los formularios de M10 (rectas, triangulos) la tecla ya la gestiono `_handleExtraKey`.
  bool _insertIntoCell(String token) {
    if (_calculatorMode < 9 || _calculatorMode > 11) return false;
    if (_activeResolution != null) {
      _activeResolution = null;
      _activeStepIndex = 0;
    }
    if (_extraFormActive) return true;
    switch (_calculatorMode) {
      case 9:
        _matrixInsertToken(token);
      case 10:
        _vectorInsertToken(token);
      default:
        _complexInsertToken(token);
    }
    return true;
  }

  /// Rotulo corto de una seccion de OPTN como entrada de la lista LCD.
  List<LcdListItem> _optnSectionItems(OptnTokenSection s) => [
        for (final t in s.items) LcdListItem(t.token, t.label, detail: t.detail),
      ];

  /// Botones de token del menu rapido (modos sin lista LCD): una fila por seccion.
  List<Widget> _optnTokenButtons(BuildContext ctx, {Set<String> skip = const {}}) {
    final hw = ThemeController.current;
    return [
      for (final s in OptnTokenSections.all) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(
            s.title,
            style: TextStyle(color: hw.panelText, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in s.items.where((t) => !skip.contains(t.token)))
              OutlinedButton(
                key: Key('optn_insert_${t.token}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: hw.panelAccentText,
                  side: BorderSide(color: hw.panelAccentText),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleKeyPress(OptnTokenSections.keyFor(t.token));
                },
                child: Text(t.label),
              ),
          ],
        ),
      ],
    ];
  }
}
