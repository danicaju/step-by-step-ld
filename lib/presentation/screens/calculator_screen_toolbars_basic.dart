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
                ] else if (_calculatorMode == 3) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        key: const Key('sys_dim_2'),
                        label: '2 Ec.',
                        selected: _systemDim == 2,
                        onTap: () {
                          updateState(() {
                            _systemDim = 2;
                            _sysActiveIndex = 0;
                            _activeResolution = null;
                            _activeStepIndex = 0;
                          });
                        },
                      ),
                      const SizedBox(width: 3),
                      _buildMethodTab(
                        key: const Key('sys_dim_3'),
                        label: '3 Ec.',
                        selected: _systemDim == 3,
                        onTap: () {
                          updateState(() {
                            _systemDim = 3;
                            _sys3ActiveIndex = 0;
                            _activeResolution = null;
                            _activeStepIndex = 0;
                          });
                        },
                      ),
                      const SizedBox(width: 3),
                      _buildMethodTab(
                        key: const Key('sys_dim_4'),
                        label: '4 Ec.',
                        selected: _systemDim == 4,
                        onTap: () {
                          updateState(() {
                            _systemDim = 4;
                            _sys4ActiveIndex = 0;
                            _activeResolution = null;
                            _activeStepIndex = 0;
                          });
                        },
                      ),
                      if (_systemDim == 2) ...[
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: 'Sustitución',
                          selected:
                              _systemMethod == SystemResolutionMethod.sustitucion,
                          onTap: () {
                            updateState(() {
                              _systemMethod = SystemResolutionMethod.sustitucion;
                              if (_activeResolution != null) {
                                _solveCurrentMode();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: 'Igualación',
                          selected:
                              _systemMethod == SystemResolutionMethod.igualacion,
                          onTap: () {
                            updateState(() {
                              _systemMethod = SystemResolutionMethod.igualacion;
                              if (_activeResolution != null) {
                                _solveCurrentMode();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: 'Reducción',
                          selected:
                              _systemMethod == SystemResolutionMethod.reduccion,
                          onTap: () {
                            updateState(() {
                              _systemMethod = SystemResolutionMethod.reduccion;
                              if (_activeResolution != null) {
                                _solveCurrentMode();
                              }
                            });
                          },
                        ),
                      ] else ...[
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: 'Reducción',
                          selected:
                              _systemMethod == SystemResolutionMethod.reduccion,
                          onTap: () {
                            updateState(() {
                              _systemMethod = SystemResolutionMethod.reduccion;
                              if (_activeResolution != null) {
                                _solveCurrentMode();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: 'Sustitución',
                          selected:
                              _systemMethod == SystemResolutionMethod.sustitucion,
                          onTap: () {
                            updateState(() {
                              _systemMethod = SystemResolutionMethod.sustitucion;
                              if (_activeResolution != null) {
                                _solveCurrentMode();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          key: const Key('sys3_solve_btn'),
                          label: 'Resolver',
                          selected: false,
                          onTap: _solveCurrentMode,
                        ),
                      ],
                    ],
                  ),
                ] else if (_calculatorMode == 4) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        key: const Key('poly_tab_ruffini'),
                        label: 'Ruffini',
                        selected: !_polyIsNotableMode,
                        onTap: () {
                          updateState(() {
                            _polyIsNotableMode = false;
                            _activeResolution = null;
                            _activeStepIndex = 0;
                          });
                        },
                      ),
                      const SizedBox(width: 3),
                      _buildMethodTab(
                        key: const Key('poly_tab_notables'),
                        label: 'Notables',
                        selected: _polyIsNotableMode,
                        onTap: () {
                          updateState(() {
                            _polyIsNotableMode = true;
                            _activeResolution = null;
                            _activeStepIndex = 0;
                            _identityType = NotableIdentityType.squareOfSum;
                            _rawInput = '( + )^2';
                            _cursorPos = 1;
                            _replayIndex = -1;
                          });
                        },
                      ),
                      if (!_polyIsNotableMode) ...[
                        for (int deg = 2; deg <= 6; deg++) ...[
                          const SizedBox(width: 3),
                          _buildMethodTab(
                            key: Key('ruffini_tab_$deg'),
                            label: '$deg.º',
                            selected:
                                !_isChoosingRuffiniDegree && _ruffiniDegree == deg,
                            onTap: () {
                              updateState(() {
                                _setRuffiniDegree(deg, enterTemplate: true);
                              });
                            },
                          ),
                        ],
                      ] else ...[
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          key: const Key('notable_var_x'),
                          label: 'x',
                          selected: false,
                          onTap: _insertVariableX,
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: '(A+B)²',
                          selected:
                              _identityType == NotableIdentityType.squareOfSum,
                          onTap: () {
                            updateState(() {
                              _identityType = NotableIdentityType.squareOfSum;
                              _activeResolution = null;
                              _activeStepIndex = 0;
                              if (_rawInput == '0' || _activeResolution != null || _rawInput.contains('(')) {
                                _rawInput = '( + )^2';
                                _cursorPos = 1;
                                _replayIndex = -1;
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: '(A-B)²',
                          selected:
                              _identityType == NotableIdentityType.squareOfDiff,
                          onTap: () {
                            updateState(() {
                              _identityType = NotableIdentityType.squareOfDiff;
                              _activeResolution = null;
                              _activeStepIndex = 0;
                              if (_rawInput == '0' || _activeResolution != null || _rawInput.contains('(')) {
                                _rawInput = '( - )^2';
                                _cursorPos = 1;
                                _replayIndex = -1;
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: '(A+B)(A-B)',
                          selected:
                              _identityType == NotableIdentityType.sumTimesDiff,
                          onTap: () {
                            updateState(() {
                              _identityType = NotableIdentityType.sumTimesDiff;
                              _activeResolution = null;
                              _activeStepIndex = 0;
                              if (_rawInput == '0' || _activeResolution != null || _rawInput.contains('(')) {
                                _rawInput = '( + )( - )';
                                _cursorPos = 1;
                                _replayIndex = -1;
                              }
                            });
                          },
                        ),
                      ],
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
                                  Border.all(color: const Color(0xFF3B82F6)),
                            ),
                            child: Text(
                              '${_selectedGraphPoint!.label}: (${_selectedGraphPoint!.x % 1 == 0 ? _selectedGraphPoint!.x.toInt() : _selectedGraphPoint!.x.toStringAsFixed(1)}, ${_selectedGraphPoint!.y % 1 == 0 ? _selectedGraphPoint!.y.toInt() : _selectedGraphPoint!.y.toStringAsFixed(1)})',
                              style: const TextStyle(
                                color: Color(0xFF93C5FD),
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
