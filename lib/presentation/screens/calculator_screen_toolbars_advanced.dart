part of 'calculator_screen.dart';

extension _CalculatorScreenToolbarsAdvanced on _CalculatorScreenState {
  List<Widget> _buildAdvancedModesToolbar() {
    return [
      if (_calculatorMode == 6) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        key: const Key('ineq_var_x'),
                        label: 'x',
                        selected: false,
                        onTap: _insertVariableX,
                      ),
                      for (final s in InequalitySign.values) ...[
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          key: Key('ineq_sign_${s.name}'),
                          label: s.symbol,
                          selected: _inequalitySign == s,
                          onTap: () {
                            updateState(() {
                              _setInequalitySign(s, insertIfMissing: true);
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ] else if (_calculatorMode == 7) ...[
                  if (!_isChoosingIneqSysUnknowns) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (_activeResolution != null) ...[
                          _buildMethodTab(
                            key: const Key('ineq_sys_edit_btn'),
                            label: '✎ Editar Sistema',
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
                        ] else ...[
                          _buildMethodTab(
                            key: const Key('ineq_sys_var_x'),
                            label: 'x',
                            selected: false,
                            onTap: _insertVariableX,
                          ),
                          if (_ineqSysUnknowns == 2) ...[
                            const SizedBox(width: 3),
                            _buildMethodTab(
                              key: const Key('ineq_sys_var_y'),
                              label: 'y',
                              selected: false,
                              onTap: _insertVariableY,
                            ),
                          ],
                          for (final s in InequalitySign.values) ...[
                            const SizedBox(width: 3),
                            _buildMethodTab(
                              key: Key('ineq_sys_sign_${s.name}'),
                              label: s.symbol,
                              selected: _inequalitySign == s,
                              onTap: () {
                                updateState(() {
                                  _setInequalitySign(s, insertIfMissing: true);
                                });
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ] else if (_calculatorMode == 8) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (_activeResolution != null)
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
                        )
                      else
                        _buildMethodTab(
                          key: const Key('stat_add_row_btn'),
                          label: '+ Fila',
                          selected: false,
                          onTap: () {
                            updateState(() {
                              _statRows.add((xi: '', fi: ''));
                              _statActiveRow = _statRows.length - 1;
                              _statActiveCol = 0;
                            });
                          },
                        ),
                      const SizedBox(width: 4),
                      _buildMethodTab(
                        key: const Key('stat_optn_btn'),
                        label: 'OPTN',
                        selected: false,
                        onTap: _openStatOptionsModal,
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
                          label: '✎ Editar Matriz',
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
                ] else if (_calculatorMode == 10) ...[
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
                ] else if (_calculatorMode == 11) ...[
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
                ] else if (_calculatorMode == 12) ...[
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
                      ] else ...[
                        _buildMethodTab(
                          key: const Key('calculus_x_btn'),
                          label: 'x',
                          selected: false,
                          onTap: () {
                            updateState(() {
                              if (_calculusActiveField != 0) {
                                _calculusActiveField = 0;
                              }
                              _activeResolution = null;
                              _applyRawInsertion('x');
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
