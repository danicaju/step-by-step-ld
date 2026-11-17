part of 'calculator_screen.dart';

extension _CalculatorScreenToolbarsBasic on _CalculatorScreenState {
  List<Widget> _buildBasicModesToolbar() {
    return [
                // Barra interactiva contextual para Modos 2..11
                if (_calculatorMode == 2) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        key: const Key('eq_var_x'),
                        label: 'x  (incógnita)',
                        selected: false,
                        onTap: _insertVariableX,
                      ),
                      const SizedBox(width: 4),
                      _buildMethodTab(
                        key: const Key('eq_sign_equals'),
                        label: '⇄ Miembro (=)',
                        selected: _eqActiveSide == 1,
                        onTap: _insertEqualsInEquation,
                      ),
                    ],
                  ),
                ] else if (_calculatorMode == 4 && _polyIsNotableMode) ...[
                  // M3 y M4 (Ruffini) no tienen barra inferior: sus selectores viven en la cabecera LCD.
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        key: const Key('notable_var_x'),
                        label: 'x',
                        selected: false,
                        onTap: _insertVariableX,
                      ),
                    ],
                  ),
                ] else if (_calculatorMode == 5) ...[
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
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFE5A93C)),
                            ),
                            child: Text(
                              '${_selectedGraphPoint!.label}: (${_selectedGraphPoint!.x % 1 == 0 ? _selectedGraphPoint!.x.toInt() : _selectedGraphPoint!.x.toStringAsFixed(1)}, ${_selectedGraphPoint!.y % 1 == 0 ? _selectedGraphPoint!.y.toInt() : _selectedGraphPoint!.y.toStringAsFixed(1)})',
                              style: const TextStyle(
                                color: Color(0xFFE5A93C),
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
