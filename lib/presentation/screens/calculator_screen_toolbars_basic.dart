part of 'calculator_screen.dart';

extension _CalculatorScreenToolbarsBasic on _CalculatorScreenState {
  List<Widget> _buildBasicModesToolbar() {
    return [
                // Barra interactiva contextual para Modos 2..11
                // M2, M3, M4 y M6 no tienen barra inferior: x/y/= van por ALPHA y los selectores en la cabecera LCD.
                // M5: el conmutador Pasos/Grafica solo existe cuando ya hay un resultado (tras `=`).
                if (_calculatorMode == 5 &&
                    _activeResolution != null &&
                    _lcdErrorKind == null &&
                    _m5.view == 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        key: const Key('mode5_view_toggle'),
                        icon: _showGraphView
                            ? Icons.format_list_numbered_rounded
                            : Icons.show_chart_rounded,
                        label: _showGraphView ? 'Ver Pasos' : 'Ver Gráfica',
                        selected: true,
                        onTap: () {
                          updateState(() {
                            _showGraphView = !_showGraphView;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      if (_selectedGraphPoint != null)
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: ThemeController.current.isDefault ? const Color(0xFF1E293B) : ThemeController.current.funcKey,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ThemeController.current.legendShift),
                            ),
                            child: Text(
                              '${_selectedGraphPoint!.label}: (${_selectedGraphPoint!.x % 1 == 0 ? _selectedGraphPoint!.x.toInt() : _selectedGraphPoint!.x.toStringAsFixed(1)}, ${_selectedGraphPoint!.y % 1 == 0 ? _selectedGraphPoint!.y.toInt() : _selectedGraphPoint!.y.toStringAsFixed(1)})',
                              style: TextStyle(
                                color: ThemeController.current.isDefault ? const Color(0xFFE5A93C) : ThemeController.current.funcKeyText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
    ];
  }
}
