part of 'calculator_screen.dart';

extension _CalculatorScreenToolbarsAdvanced on _CalculatorScreenState {
  List<Widget> _buildAdvancedModesToolbar() {
    return [
      if (_calculatorMode == 7) ...[
                  if (_activeResolution != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (_activeResolution != null) ...[
                          _buildMethodTab(
                            key: const Key('ineq_sys_edit_btn'),
                            label: 'Editar Sistema',
                            selected: false,
                            onTap: () {
                              updateState(() {
                                _activeResolution = null;
                                _show2DRegionView = false;
                              });
                            },
                          ),
                          if (_ineqSysUnknowns == 2 && _currentFeasibleRegion != null) ...[
                            const SizedBox(width: 4),
                            _buildMethodTab(
                              key: const Key('ineq_sys_2d_toggle_btn'),
                              label: _show2DRegionView ? 'Ver Pasos' : 'Ver Plano 2D',
                              selected: _show2DRegionView,
                              onTap: () {
                                updateState(() {
                                  _show2DRegionView = !_show2DRegionView;
                                });
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ] else if (_calculatorMode == 8 && _activeResolution != null) ...[
                  // Sin OPTN: la fila se anade dentro de la tabla (+ Añadir fila).
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        key: const Key('stat_edit_btn'),
                        label: 'Tabla',
                        selected: false,
                        onTap: () {
                          updateState(() {
                            _activeResolution = null;
                            _activeStepIndex = 0;
                          });
                        },
                      ),
                    ],
                  ),
                ] else if (_calculatorMode == 9) ...[
                  if (_activeResolution != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _buildMethodTab(
                          key: const Key('matrix_edit_btn'),
                          label: 'Editar Matriz',
                          selected: false,
                          onTap: () {
                            updateState(() {
                              _activeResolution = null;
                              _activeStepIndex = 0;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ] else if (_calculatorMode == 10 && _activeResolution != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                          key: const Key('vector_edit_btn'),
                          label: 'Editar',
                          selected: false,
                          onTap: () {
                            updateState(() {
                              _activeResolution = null;
                              _activeStepIndex = 0;
                            });
                          },
                        )
                    ],
                  ),
                ] else if (_calculatorMode == 11 && _activeResolution != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                          key: const Key('complex_edit_btn'),
                          label: 'Editar',
                          selected: false,
                          onTap: () {
                            updateState(() {
                              _activeResolution = null;
                              _activeStepIndex = 0;
                            });
                          },
                        ),
                    ],
                  ),
                ] else if (_calculatorMode == 12 && _activeResolution != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (_activeResolution != null) ...[
                        _buildMethodTab(
                          key: const Key('calculus_edit_btn'),
                          label: 'Editar',
                          selected: false,
                          onTap: () {
                            updateState(() {
                              _activeResolution = null;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ],
    ];
  }
}
