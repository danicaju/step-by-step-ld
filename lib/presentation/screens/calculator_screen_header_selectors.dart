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

  /// Desplegables que se muestran en la cabecera de la LCD según el modo (M3, M4, M6).
  List<_HeaderSpec> _headerSpecs() {
    if (_isMenuOpen) return const [];
    switch (_calculatorMode) {
      case 3:
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
                LcdDropdownItem(value: n, label: '$n Ec.', key: Key('sys_dim_$n')),
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
              for (final m in methods) LcdDropdownItem(value: m.index, label: labels[m]!),
            ],
            onSelect: (i) {
              _systemMethod = SystemResolutionMethod.values[i];
              if (_activeResolution != null) _solveCurrentMode();
            },
          ),
        ];
      case 4:
        return [
          _HeaderSpec(
            keyName: 'hdr_poly_kind',
            prefix: 'Tipo',
            value: _polyIsNotableMode ? 1 : 0,
            items: const [
              LcdDropdownItem(value: 0, label: 'Ruffini', key: Key('poly_tab_ruffini')),
              LcdDropdownItem(value: 1, label: 'Notables', key: Key('poly_tab_notables')),
            ],
            onSelect: (v) {
              _polyIsNotableMode = v == 1;
              _activeResolution = null;
              _activeStepIndex = 0;
              if (v == 1) {
                _identityType = NotableIdentityType.squareOfSum;
                _rawInput = '( + )^2';
                _cursorPos = 1;
                _replayIndex = -1;
              }
            },
          ),
          if (!_polyIsNotableMode)
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
          else
            _HeaderSpec(
              keyName: 'hdr_poly_identity',
              prefix: 'Identidad',
              value: _identityType.index,
              items: [
                for (final t in NotableIdentityType.values)
                  LcdDropdownItem(value: t.index, label: _identityLabel(t)),
              ],
              onSelect: (i) {
                _identityType = NotableIdentityType.values[i];
                _activeResolution = null;
                _activeStepIndex = 0;
                _rawInput = _identityTemplate(_identityType);
                _cursorPos = 1;
                _replayIndex = -1;
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
              LcdDropdownItem(value: 3, label: 'Valor Absoluto', key: Key('ineq_deg_3')),
            ],
            onSelect: (v) {
              _ineqDegree = v;
              _resetResolutionView();
            },
          ),
        ];
      default:
        return const [];
    }
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
      child: Wrap(
        spacing: 4,
        runSpacing: 3,
        children: [
          for (int i = 0; i < specs.length; i++)
            LcdDropdownSelector<int>(
              widgetKey: Key(specs[i].keyName),
              prefix: specs[i].prefix,
              value: specs[i].value,
              items: specs[i].items,
              isOledDark: _isOledDark,
              height: 22,
              fontSize: 10.5,
              isHighlighted: _headerFocus == i,
              onChanged: (v) => updateState(() {
                _headerFocus = -1;
                specs[i].onSelect(v);
              }),
            ),
        ],
      ),
    );
  }

  /// ¿Está el cursor en la primera celda/fila, de modo que ▲ debe subir a la cabecera?
  bool _headerCanEnter() {
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
