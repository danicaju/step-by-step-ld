part of 'calculator_screen.dart';

extension _CalculatorScreenHeaderSpecs on _CalculatorScreenState {
  static const _eqKinds = [
    '1.º Grado',
    '2.º Grado',
    'Bicuadrada',
    'Racional',
    'Irracional',
    'Exponencial',
    'Logarítmica',
  ];

  /// Desplegables de la cabecera de la LCD según el modo (M2..M12).
  List<_HeaderSpec> _headerSpecs() {
    if (_isMenuOpen || _isSetupOpen) return const [];
    switch (_calculatorMode) {
      case 2:
        return [
          _HeaderSpec(
            keyName: 'hdr_eq_kind',
            prefix: 'Tipo',
            value: _eqKind,
            items: [
              for (int i = 0; i < _eqKinds.length; i++)
                LcdDropdownItem(value: i, label: _eqKinds[i], key: Key('eq_kind_$i')),
            ],
            onSelect: (v) {
              _eqKind = v;
              _activeResolution = null;
              _activeStepIndex = 0;
            },
          ),
        ];
      case 3:
        return _systemSpecs();
      case 4:
        return _polySpecs();
      case 5:
        return [
          if (_m5.view == 0)
            _HeaderSpec(
              keyName: 'hdr_graph_kind',
              prefix: 'Tipo',
              value: _graphKind,
              items: [
                for (var k = 0; k < kM5KindLabels.length; k++)
                  LcdDropdownItem(value: k, label: kM5KindLabels[k], key: Key('graph_kind_$k')),
              ],
              onSelect: (v) {
                _graphKind = v;
                _graphActiveIndex = 0;
                _currentGraphAnalysis = null;
                _selectedGraphPoint = null;
                _m5.study = null;
                _rawInput = '0';
                _cursorPos = 1;
                _resetResolutionView();
              },
            ),
          _HeaderSpec(
            keyName: 'hdr_graph_view',
            prefix: 'Vista',
            value: _m5.view,
            items: const [
              LcdDropdownItem(value: 0, label: 'Estudio + Gráfica', key: Key('graph_view_0')),
              LcdDropdownItem(value: 1, label: 'Límites lim', key: Key('graph_view_1')),
              LcdDropdownItem(value: 2, label: 'Tabla f(x), g(x)', key: Key('graph_view_2')),
            ],
            onSelect: (v) {
              _m5.view = v;
              _m5.study = null;
              _lcdErrorKind = null;
              _currentGraphAnalysis = null;
              _selectedGraphPoint = null;
              _resetResolutionView();
            },
          ),
        ];
      case 6:
        return [
          _HeaderSpec(
            keyName: 'hdr_ineq_kind',
            prefix: 'Tipo',
            value: _ineqDegree,
            items: const [
              LcdDropdownItem(value: 1, label: '1.º Grado', key: Key('ineq_deg_1')),
              LcdDropdownItem(value: 2, label: '2.º Grado', key: Key('ineq_deg_2')),
              LcdDropdownItem(value: 3, label: 'Valor Absoluto / Racional', key: Key('ineq_deg_3')),
            ],
            onSelect: (v) {
              _ineqDegree = v;
              _resetResolutionView();
            },
          ),
          _signSpec('hdr_ineq_sign'),
        ];
      case 7:
        return [
          _HeaderSpec(
            keyName: 'hdr_ineqsys_unknowns',
            prefix: 'Incógnitas',
            value: _ineqSysUnknowns,
            items: const [
              LcdDropdownItem(value: 1, label: '1 Incógnita (x)', key: Key('ineqsys_unk_1')),
              LcdDropdownItem(value: 2, label: '2 Incógnitas (x, y)', key: Key('ineqsys_unk_2')),
            ],
            onSelect: (v) {
              _ineqSysUnknowns = v;
              _show2DRegionView = v == 2;
              _resetResolutionView();
            },
          ),
          _HeaderSpec(
            keyName: 'hdr_ineqsys_rows',
            prefix: 'Nº',
            value: _ineqSysRows,
            items: [
              for (final n in [2, 3, 4])
                LcdDropdownItem(value: n, label: '$n Inecuaciones', key: Key('ineqsys_rows_$n')),
            ],
            onSelect: (n) {
              _ineqSysRows = n;
              if (_ineqSysActiveRow >= n) _ineqSysActiveRow = n - 1;
              _resetResolutionView();
              _activeStepIndex = 0;
            },
          ),
          _signSpec('hdr_ineqsys_sign'),
        ];
      case 9:
        return [
          _HeaderSpec(
            keyName: 'hdr_matrix_op',
            prefix: 'Op',
            value: _matrixOp.index,
            items: [
              for (final o in MatrixOperation.values)
                LcdDropdownItem(value: o.index, label: o.shortLabel, key: Key('matrix_op_${o.name}')),
            ],
            onSelect: (i) => _selectMatrixOp(MatrixOperation.values[i]),
          ),
          for (final isRows in [true, false])
            _HeaderSpec(
              keyName: isRows ? 'hdr_matrix_rows' : 'hdr_matrix_cols',
              prefix: isRows ? 'F' : 'C',
              value: _matrixActiveTarget == 1
                  ? (isRows ? _matrixRowsB : _matrixColsB)
                  : (isRows ? _matrixRowsA : _matrixColsA),
              items: [
                for (int n = 1; n <= 4; n++)
                  LcdDropdownItem(value: n, label: '$n', key: Key('matrix_${isRows ? 'r' : 'c'}_$n')),
              ],
              onSelect: (n) {
                _activeResolution = null;
                final isB = _matrixActiveTarget == 1;
                if (isRows) {
                  isB ? _matrixRowsB = n : _matrixRowsA = n;
                } else {
                  isB ? _matrixColsB = n : _matrixColsA = n;
                }
                final rows = isB ? _matrixRowsB : _matrixRowsA;
                final cols = isB ? _matrixColsB : _matrixColsA;
                _matrixActiveRow = _matrixActiveRow.clamp(0, rows - 1);
                _matrixActiveCol = _matrixActiveCol.clamp(0, cols - 1);
              },
            ),
        ];
      case 8:
        return [
          _HeaderSpec(
            keyName: 'hdr_stat_kind',
            prefix: 'Tipo',
            value: _cw.x.m8View,
            items: const [
              LcdDropdownItem(value: 0, label: '1 Variable', key: Key('stat_kind_0')),
              LcdDropdownItem(value: 1, label: '2 Variables / Regresión', key: Key('stat_kind_1')),
              LcdDropdownItem(value: 2, label: 'Normal N(μ,σ)', key: Key('stat_kind_2')),
              LcdDropdownItem(value: 3, label: 'Binomial B(n,p)', key: Key('stat_kind_3')),
            ],
            onSelect: (v) {
              _cw.x.m8View = v;
              _cw.x.clearResults();
              _lcdErrorKind = null;
              _resetResolutionView();
            },
          ),
        ];
      case 10:
        return [
          _HeaderSpec(
            keyName: 'hdr_vector_view',
            prefix: 'Vista',
            value: _cw.x.m10View,
            items: const [
              LcdDropdownItem(value: 0, label: 'Vectores 3D', key: Key('vector_view_0')),
              LcdDropdownItem(value: 1, label: '6 Ecuaciones Recta', key: Key('vector_view_1')),
              LcdDropdownItem(value: 2, label: 'Triángulos', key: Key('vector_view_2')),
            ],
            onSelect: (v) {
              _cw.x.m10View = v;
              _cw.x.clearResults();
              _lcdErrorKind = null;
              _resetResolutionView();
            },
          ),
          if (_cw.x.m10View == 0)
          _HeaderSpec(
            keyName: 'hdr_vector_dim',
            prefix: 'Dim',
            value: _vectorDim,
            items: const [
              LcdDropdownItem(value: 2, label: '2D', key: Key('vector_dim_2')),
              LcdDropdownItem(value: 3, label: '3D', key: Key('vector_dim_3')),
            ],
            onSelect: _setVectorDim,
          ),
          if (_cw.x.m10View == 0)
          _HeaderSpec(
            keyName: 'hdr_vector_op',
            prefix: 'Operación',
            value: _vectorOp.index,
            items: [
              for (final o in VectorOperation.values)
                LcdDropdownItem(value: o.index, label: o.shortLabel, key: Key('vector_op_${o.name}')),
            ],
            onSelect: (i) => _selectVectorOp(VectorOperation.values[i]),
          ),
        ];
      case 11:
        return [
          _HeaderSpec(
            keyName: 'hdr_complex_op',
            prefix: 'Operación',
            value: _complexOp.index,
            items: [
              for (final o in ComplexOperation.values)
                LcdDropdownItem(value: o.index, label: o.shortLabel, key: Key('complex_op_${o.name}')),
            ],
            onSelect: (i) => _selectComplexOp(ComplexOperation.values[i]),
          ),
        ];
      case 12:
        const labels = {
          CalculusOperation.derivative: "Derivada f'(x)",
          CalculusOperation.tangentLine: 'Recta Tangente',
          CalculusOperation.indefiniteIntegral: 'Integral ∫f(x)dx',
          CalculusOperation.definiteIntegral: 'Definida ∫ₐᵇ Barrow',
        };
        return [
          _HeaderSpec(
            keyName: 'hdr_calculus_op',
            prefix: 'Operación',
            value: _calculusOp.index,
            items: [
              for (final o in CalculusOperation.values)
                LcdDropdownItem(value: o.index, label: labels[o]!, key: Key('calculus_op_${o.name}')),
            ],
            onSelect: (i) => _selectCalculusOp(CalculusOperation.values[i]),
          ),
        ];
      default:
        return const [];
    }
  }

  /// Desplegable `Signo` (< ≤ > ≥) de M6/M7: reemplaza el signo existente o lo inserta en el cursor.
  _HeaderSpec _signSpec(String keyName) {
    return _HeaderSpec(
      keyName: keyName,
      prefix: 'Signo',
      value: _inequalitySign.index,
      items: [
        for (final s in InequalitySign.values)
          LcdDropdownItem(value: s.index, label: s.symbol, key: Key('ineq_sign_${s.name}')),
      ],
      onSelect: (i) => _setInequalitySign(InequalitySign.values[i], insertIfMissing: true),
    );
  }

  List<_HeaderSpec> _systemSpecs() {
    final methods = _systemDim == 2
        ? SystemResolutionMethod.values
        : const [SystemResolutionMethod.reduccion, SystemResolutionMethod.sustitucion];
    const labels = {
      SystemResolutionMethod.sustitucion: 'Sustitución',
      SystemResolutionMethod.igualacion: 'Igualación',
      SystemResolutionMethod.reduccion: 'Reducción',
    };
    return [
      _HeaderSpec(
        keyName: 'hdr_sys_size',
        prefix: 'Tamaño',
        value: _systemDim,
        items: [
          for (final n in [2, 3, 4])
            LcdDropdownItem(value: n, label: '$n Ecuaciones', key: Key('sys_dim_$n')),
        ],
        onSelect: (n) {
          _systemDim = n;
          if (n == 2) _sysActiveIndex = 0;
          if (n == 3) _sys3ActiveIndex = 0;
          if (n == 4) _sys4ActiveIndex = 0;
          _activeResolution = null;
          _activeStepIndex = 0;
        },
      ),
      _HeaderSpec(
        keyName: 'hdr_sys_method',
        prefix: 'Método',
        value: methods.contains(_systemMethod) ? _systemMethod.index : methods.first.index,
        items: [
          for (final m in methods)
            LcdDropdownItem(value: m.index, label: labels[m]!, key: Key('sys_method_${m.name}')),
        ],
        onSelect: (i) {
          _systemMethod = SystemResolutionMethod.values[i];
          if (_activeResolution != null) _solveCurrentMode();
        },
      ),
    ];
  }

  List<_HeaderSpec> _polySpecs() {
    return [
      _HeaderSpec(
        keyName: 'hdr_poly_kind',
        prefix: 'Tipo',
        value: _cw.x.m4View >= 2 ? _cw.x.m4View : (_polyIsNotableMode ? 1 : 0),
        items: const [
          LcdDropdownItem(value: 0, label: 'Ruffini', key: Key('poly_tab_ruffini')),
          LcdDropdownItem(value: 1, label: 'Notables', key: Key('poly_tab_notables')),
          LcdDropdownItem(value: 2, label: 'División Caja P(x):Q(x)', key: Key('poly_tab_box')),
          LcdDropdownItem(value: 3, label: 'Fracciones Algebraicas', key: Key('poly_tab_frac')),
        ],
        onSelect: (v) {
          _cw.x.m4View = v >= 2 ? v : 0;
          _cw.x.clearResults();
          _lcdErrorKind = null;
          _polyIsNotableMode = v == 1;
          _activeResolution = null;
          _activeStepIndex = 0;
          if (v == 1) {
            _identityType = NotableIdentityType.squareOfSum;
            _rawInput = '( + )^2';
            _cursorPos = 1;
          }
        },
      ),
      if (_cw.x.m4View < 2 && !_polyIsNotableMode)
        _HeaderSpec(
          keyName: 'hdr_poly_degree',
          prefix: 'Grado',
          value: _isChoosingRuffiniDegree ? 0 : _ruffiniDegree,
          items: [
            for (int d = 2; d <= 6; d++)
              LcdDropdownItem(value: d, label: '$d.º', key: Key('ruffini_tab_$d')),
          ],
          onSelect: (d) => _setRuffiniDegree(d, enterTemplate: true),
        )
      else if (_cw.x.m4View < 2)
        _HeaderSpec(
          keyName: 'hdr_poly_identity',
          prefix: 'Identidad',
          value: _identityType.index,
          items: [
            for (final t in NotableIdentityType.values)
              LcdDropdownItem(value: t.index, label: _identityLabel(t), key: Key('identity_${t.name}')),
          ],
          onSelect: (i) {
            _identityType = NotableIdentityType.values[i];
            _activeResolution = null;
            _activeStepIndex = 0;
            _rawInput = _identityTemplate(_identityType);
            _cursorPos = _rawInput.isEmpty ? 0 : 1;
          },
        ),
    ];
  }
}
