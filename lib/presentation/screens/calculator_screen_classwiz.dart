part of 'calculator_screen.dart';

/// Teclas ClassWiz de la fase CW-2: FACT, ° ' ", a b/c, ENG, STO y RESET.
extension _CalculatorScreenClassWiz on _CalculatorScreenState {
  /// Linea de resultado alternativa (o nota STO) para la resolucion actual.
  String? get _resultOverride {
    final res = _activeResolution;
    if (res == null || _calculatorMode != 1 || !identical(res, _cw.owner)) return null;
    if (_cw.note != null) return _cw.note;
    final r = ClassWizKeyActions.rationalFromLatex(res.exactResultLatex);
    final x = ClassWizKeyActions.numericValue(res.exactResultLatex, res.decimalApproxLatex);
    return switch (_cw.view) {
      CwView.normal => null,
      CwView.factor => r == null ? null : ClassWizKeyActions.factorLatex(r),
      CwView.dms => x == null ? null : ClassWizKeyActions.dmsLatex(x),
      CwView.fraction => r == null
          ? null
          : ClassWizKeyActions.fractionLatex(r, mixed: !CalculatorSettings.mixedFractions),
      CwView.eng => x == null ? null : ClassWizKeyActions.engLatex(x, _cw.engExp),
    };
  }

  /// Alterna la vista [v] del resultado. `false` si no aplica al resultado actual.
  bool _cwSetView(CwView v) {
    final res = _activeResolution;
    if (res == null || _calculatorMode != 1) return false;
    final r = ClassWizKeyActions.rationalFromLatex(res.exactResultLatex);
    final x = ClassWizKeyActions.numericValue(res.exactResultLatex, res.decimalApproxLatex);
    final applies = switch (v) {
      CwView.factor => r != null && ClassWizKeyActions.factorLatex(r) != null,
      CwView.dms => x != null,
      CwView.fraction => r != null && !r.isInteger,
      CwView.eng => x != null && x != 0,
      CwView.normal => true,
    };
    if (!applies) return false;
    if (!identical(_cw.owner, res)) {
      _cw.owner = res;
      _cw.view = CwView.normal;
    }
    _cw.note = null;
    if (v == CwView.eng) {
      final active = _cw.view == CwView.eng;
      _cw.engExp = active ? _cw.engExp + 3 : ClassWizKeyActions.engBaseExponent(x!);
      _cw.view = CwView.eng;
    } else {
      _cw.view = _cw.view == v ? CwView.normal : v;
    }
    _activeStepIndex = res.steps.length - 1;
    _showDecimalApprox = false;
    return true;
  }

  /// `◀` con el resultado en ENG: baja el exponente 3 posiciones.
  bool _cwEngBack() {
    final res = _activeResolution;
    if (res == null || _calculatorMode != 1) return false;
    if (!identical(_cw.owner, res) || _cw.view != CwView.eng) return false;
    _cw.engExp -= 3;
    return true;
  }

  /// Teclas ClassWiz de hardware. `true` si la pulsacion queda consumida.
  bool _handleClassWizHw(String key) {
    _cw.note = null;
    if (_cw.resetOpen) return _handleResetKey(key);
    if (_cw.list != null) return _handleListKey(key);
    if (_cw.prop != null) return _handlePropKey(key);
    if (_handleM5Key(key)) return true;
    if (_cw.stoPending) return _handleStoKey(key);
    if (!_isShiftActive || !_hwFreeEditing) return false;
    switch (key) {
      case '9':
        _openReset();
        return true;
      case '7':
      case '8':
        if (_calculatorMode != 1) return false;
        _openList(key == '7' ? 'const' : 'conv');
        return true;
      case '(':
        if (_calculatorMode != 1) return false;
        _isShiftActive = false;
        _cw.stoPending = true;
        return true;
      case '3':
        if (_calculatorMode != 1 || _activeResolution == null) return false;
        _isShiftActive = false;
        if (!_cwSetView(CwView.eng)) _applyRawInsertion('3');
        return true;
      case 'SD':
        _isShiftActive = false;
        _cwSetView(CwView.fraction);
        return true;
    }
    return false;
  }

  // ---- STO ----
  bool _handleStoKey(String key) {
    _isShiftActive = false;
    _isAlphaActive = false;
    if (key == 'AC') {
      _cw.stoPending = false;
      return true;
    }
    const names = {
      '7': 'A', '8': 'B', '9': 'C', '4': 'D', '5': 'E', '6': 'F',
      '1': 'X', '2': 'Y', 'ANS': 'M',
    };
    final name = names[key];
    if (name == null) return true;
    _cw.stoPending = false;
    if (_activeResolution == null) _solveCurrentMode();
    final res = _activeResolution;
    if (res == null) return true;
    _storeInMemory(name, _memory.ans);
    _cw.owner = res;
    _cw.view = CwView.normal;
    _cw.note = '\\text{Ans} \\rightarrow $name';
    _activeStepIndex = res.steps.length - 1;
    return true;
  }

  // ---- RESET ----
  void _openReset() {
    _isShiftActive = false;
    _isAlphaActive = false;
    _cw.resetOpen = true;
    _cw.resetStage = 0;
    _cw.resetChoice = 0;
  }

  bool _handleResetKey(String key) {
    _isShiftActive = false;
    _isAlphaActive = false;
    final n = int.tryParse(key);
    if (key == 'AC') {
      _cw.resetOpen = false;
    } else if (_cw.resetStage == 0) {
      if (n != null && n >= 1 && n <= 3) {
        _cw.resetChoice = n - 1;
        _cw.resetStage = 1;
      } else if (key == '=') {
        _cw.resetStage = 1;
      }
    } else if (key == '=') {
      _applyReset();
    }
    return true;
  }

  void _resetDpad(String dir) {
    if (_cw.resetStage != 0 || (dir != 'up' && dir != 'down')) return;
    _cw.resetChoice = (_cw.resetChoice + (dir == 'down' ? 1 : 2)) % 3;
  }

  void _applyReset() {
    final c = _cw.resetChoice;
    if (c != 1) {
      CalculatorSettings.reset();
      _angleUnit = AngleUnit.deg;
      _lcdTheme = LcdTheme.classic;
    }
    if (c != 0) _memory.resetAll();
    if (c == 2) _resetFieldsForMode(1);
    _cw.resetOpen = false;
  }

  Widget _buildResetView() => LcdResetView(
        theme: _lcdTheme,
        stage: _cw.resetStage,
        choice: _cw.resetChoice,
        onTapOption: (i) => updateState(() {
          _cw.resetChoice = i;
          _cw.resetStage = 1;
        }),
      );
}

/// Menus de lista en la LCD: OPTN (M1/M9/M10), CONST (SHIFT+7) y CONV (SHIFT+8).
extension _CalculatorScreenListMenu on _CalculatorScreenState {
  static const List<LcdListItem> _hypItems = [
    LcdListItem('sinh(', 'sinh', detail: 'seno hiperbólico'),
    LcdListItem('cosh(', 'cosh', detail: 'coseno hiperb.'),
    LcdListItem('tanh(', 'tanh', detail: 'tangente hiperb.'),
  ];
  static const List<LcdListItem> _sufItems = [
    LcdListItem('#k', 'k', detail: '×10³'),
    LcdListItem('#M', 'M', detail: '×10⁶'),
    LcdListItem('#G', 'G', detail: '×10⁹'),
    LcdListItem('#m', 'm', detail: '×10⁻³'),
    LcdListItem('#u', 'µ', detail: '×10⁻⁶'),
    LcdListItem('#n', 'n', detail: '×10⁻⁹'),
  ];
  static const List<LcdListItem> _angItems = [
    LcdListItem('°', '°', detail: 'grados'),
    LcdListItem('#r', 'r', detail: 'radianes'),
    LcdListItem('#g', 'g', detail: 'gradianes'),
  ];
  static const List<LcdListItem> _othItems = [
    LcdListItem('Abs(', '|x|'),
    LcdListItem('!', 'n!'),
    LcdListItem('nCr', 'nCr'),
    LcdListItem('nPr', 'nPr'),
    LcdListItem('ℯ', 'ℯ'),
    LcdListItem('Ran#', 'Ran#'),
    LcdListItem('RanInt#(', 'RanInt#('),
  ];

  /// Abre el menu [kind] (`optn`, `const`, `conv`) en la LCD.
  void _openList(String kind) {
    _isShiftActive = false;
    _isAlphaActive = false;
    switch (kind) {
      case 'const':
        _setList('const', 'CONST', [
          for (final c in ClassWizConstants.all)
            LcdListItem(c.token, '${c.plain}  ${c.name}',
                detail: ClassWizConstants.plainValue(c.value)),
        ]);
      case 'conv':
        _setList('conv', 'CONV', [
          for (var i = 0; i < UnitConversions.all.length; i++)
            LcdListItem('$i', UnitConversions.all[i].label),
        ]);
      default:
        if (_calculatorMode == 9) {
          _setList('optn', 'OPTN · Matrices', const [
            LcdListItem('MatA', 'MatA'),
            LcdListItem('MatB', 'MatB'),
            LcdListItem('Trn', 'Trn', detail: 'transpuesta'),
          ]);
        } else if (_calculatorMode == 10) {
          _setList('optn', 'OPTN · Vectores', const [
            LcdListItem('VctA', 'VctA', detail: 'u'),
            LcdListItem('VctB', 'VctB', detail: 'v'),
          ]);
        } else {
          _setList('optn', 'OPTN', const [
            LcdListItem('hyp', 'Funciones Hiperbólicas'),
            LcdListItem('suf', 'Sufijos Ingeniería'),
            LcdListItem('ang', 'Unidades Angulares'),
            LcdListItem('oth', 'Otras funciones'),
            LcdListItem('exp', 'Exportar / Copiar'),
            LcdListItem('ibr', 'Arsenal Iberia'),
          ]);
        }
    }
  }

  void _setList(String kind, String title, List<LcdListItem> items, {LcdListState? parent}) {
    _cw.list = LcdListState(kind, title, items, parent: parent);
  }

  /// Teclado fisico con el menu abierto. Siempre consume la pulsacion.
  bool _handleListKey(String key) {
    final l = _cw.list!;
    _isShiftActive = false;
    _isAlphaActive = false;
    final n = int.tryParse(key);
    if (key == 'AC') {
      _cw.list = l.parent;
    } else if (key == '=') {
      _listSelect(l.items[l.cursor]);
    } else if (n != null && n >= 1 && n <= LcdListMenu.perPage) {
      final idx = (l.cursor ~/ LcdListMenu.perPage) * LcdListMenu.perPage + n - 1;
      if (idx < l.items.length) {
        l.cursor = idx;
        _listSelect(l.items[idx]);
      }
    }
    return true;
  }

  void _listDpad(String dir) {
    final l = _cw.list!;
    final len = l.items.length;
    const per = LcdListMenu.perPage;
    switch (dir) {
      case 'up':
        l.cursor = (l.cursor - 1 + len) % len;
      case 'down':
        l.cursor = (l.cursor + 1) % len;
      case 'left':
        l.cursor = ((l.cursor ~/ per - 1) * per).clamp(0, len - 1);
      case 'right':
        final next = (l.cursor ~/ per + 1) * per;
        if (next < len) l.cursor = next;
    }
  }

  void _listSelect(LcdListItem item) {
    final l = _cw.list!;
    switch (l.kind) {
      case 'optn':
        _optnSelect(item);
      case 'conv':
        _cw.list = null;
        _applyConversion(int.parse(item.id));
      default:
        _cw.list = null;
        _insertListToken(item.id);
    }
  }

  void _insertListToken(String token) {
    if (token.startsWith('prop:')) {
      _openProportion(int.parse(token.substring(5)));
      return;
    }
    if (_activeResolution != null) _clearActiveResolutionCursor();
    _applyRawInsertion(token);
  }

  void _optnSelect(LcdListItem item) {
    final l = _cw.list!;
    switch (item.id) {
      case 'hyp':
        _setList('sub', 'Hiperbólicas', _hypItems, parent: l);
      case 'suf':
        _setList('sub', 'Sufijos', _sufItems, parent: l);
      case 'ang':
        _setList('sub', 'Unidades angulares', _angItems, parent: l);
      case 'ibr':
        _setList('sub', 'Arsenal Iberia', _ibrItems, parent: l);
      case 'oth':
        _setList('sub', 'Otras funciones', _othItems, parent: l);
      case 'exp':
        _cw.list = null;
        _openQuickOptnModal();
      case 'MatA' || 'MatB':
        _cw.list = null;
        _activeResolution = null;
        _matrixActiveTarget = item.id == 'MatA' ? 0 : 1;
        _matrixActiveRow = 0;
        _matrixActiveCol = 0;
      case 'Trn':
        _cw.list = null;
        _selectMatrixOp(MatrixOperation.transpose);
      case 'VctA' || 'VctB':
        _cw.list = null;
        _activeResolution = null;
        _vectorActiveRow = item.id == 'VctA' ? 0 : 1;
        _vectorActiveCol = 0;
      default:
        _cw.list = null;
        _insertListToken(item.id);
    }
  }

  Widget _buildListMenu() {
    final l = _cw.list!;
    return LcdListMenu(
      theme: _lcdTheme,
      title: l.title,
      items: l.items,
      cursor: l.cursor,
      onTapItem: (i) => updateState(() {
        l.cursor = i;
        _listSelect(l.items[i]);
      }),
    );
  }

  /// CONV: convierte el valor actual (resultado, expresion o Ans) con [index].
  void _applyConversion(int index) {
    if (_activeResolution == null && _rawInput.trim() != '0') _solveCurrentMode();
    final res = _activeResolution;
    final value = (res == null ? null : ClassWizKeyActions.rationalFromLatex(res.exactResultLatex)) ??
        _memory.ans;
    final out = UnitConversions.all[index].solve(value);
    _activeResolution = out;
    _activeStepIndex = out.steps.length - 1;
    _showDecimalApprox = false;
    _memory.setAns(ClassWizKeyActions.rationalFromLatex(out.exactResultLatex) ?? value);
    _recordCurrentResolutionToHistory(out, 'M1: CONV');
  }

  /// Expresiones con constantes fisicas (`&c`, `&h`...): evaluacion en `double`.
  void _solveConstants() {
    try {
      final res = ClassWizConstants.solve(_rawInput, ans: _memory.ans.toDouble());
      updateState(() {
        _activeResolution = res;
        _activeStepIndex = 0;
      });
      _recordCurrentResolutionToHistory(res, 'M1: CONST');
    } on FormatException catch (e) {
      _showLcdError('Sintaxis incompleta: ${e.message}');
    }
  }
}
