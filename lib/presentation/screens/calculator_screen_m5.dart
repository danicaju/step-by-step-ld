part of 'calculator_screen.dart';

/// M5 ampliado: Estudio + Grafica de f(x) libre, Limites `lim` y TABLE f(x), g(x).
extension _CalculatorScreenM5 on _CalculatorScreenState {
  M5State get _m5 => _cw.m5;

  /// Vista de formulario (Limites o TABLE): la entrada va por las casillas, no por `_rawInput`.
  bool get _m5FormActive => _calculatorMode == 5 && _m5.isForm;

  /// ¿M5 usa el editor de expresiones en vez de las celdas de coeficientes?
  bool get _m5Custom => _calculatorMode == 5;

  /// `f(x) =` + expresion libre con LaTeX en vivo y cursor.
  String _m5FreeLatex(bool showLiveCursor) =>
      r'f(x) = \;' +
      ExpressionParser.rawToLiveLatex(
        _rawInput,
        cursorPos: showLiveCursor ? _cursorPos : null,
        overwrite: !_isInsertMode,
      );

  Widget _buildM5Form() {
    if (_m5.view == 1) {
      return LimitFormWidget(
        form: _m5.limit,
        theme: _lcdTheme,
        onFocus: (i) => updateState(() => _m5.limit.focus = i),
      );
    }
    return FunctionTableWidget(
      form: _m5.table,
      theme: _lcdTheme,
      onFocus: (i) => updateState(() => _m5.table.focus = i),
    );
  }

  /// Visor universal para el estudio de una f(x) libre (`null` si no aplica).
  Widget? _buildM5Graph() {
    final st = _m5.study;
    if (_calculatorMode != 5 || !_showGraphView || st == null) return null;
    if (_lcdErrorKind != null || _isMenuOpen || _isSetupOpen) return null;
    if (!identical(_activeResolution, st.resolution)) return null;
    return UniversalGraphView(
      model: st.model,
      asymptotes: st.asymptotes,
      info: _m5.info,
      degrees: _m5.deg,
      panX: _m5.panX,
      panY: _m5.panY,
    );
  }

  /// D-Pad en los formularios de M5. `true` si lo consumio.
  bool _m5Dpad(String dir) {
    final st = _m5.study;
    if (_calculatorMode == 5 && _m5.view == 0 && _showGraphView && st != null && identical(_activeResolution, st.resolution)) {
      // Grafica visible: el D-Pad desplaza el visor (los pasos avanzan con `=`).
      const step = 0.15;
      switch (dir) {
        case 'left':
          _m5.panX = (_m5.panX - step).clamp(-20.0, 20.0);
        case 'right':
          _m5.panX = (_m5.panX + step).clamp(-20.0, 20.0);
        case 'up':
          _m5.panY = (_m5.panY + step).clamp(-20.0, 20.0);
        default:
          _m5.panY = (_m5.panY - step).clamp(-20.0, 20.0);
      }
      return true;
    }
    if (!_m5FormActive || _activeResolution != null) return false;
    if (_m5.view == 1) {
      _m5.limit.dpad(dir);
    } else {
      _m5.table.dpad(dir);
    }
    return true;
  }

  /// Teclado fisico en los formularios de M5. `true` si consumio la pulsacion.
  bool _handleM5Key(String key) {
    if (!_m5FormActive || _lcdErrorKind != null) return false;
    final m = _m5;
    if (_isShiftActive) {
      // SHIFT + x² = exponente libre; el resto de SHIFT+tecla sigue su camino normal.
      if (key != '^2' || (m.view == 2 && m.table.showRows)) return false;
      _isShiftActive = false;
      return m.view == 1 ? m.limit.key('^(') : m.table.key('^(');
    }
    final alpha = _isAlphaActive;
    _isAlphaActive = false;
    final res = _activeResolution;
    switch (key) {
      case '=':
        if (res != null) {
          _activeStepIndex = _activeStepIndex < res.steps.length - 1 ? _activeStepIndex + 1 : 0;
        } else if (m.view == 1) {
          m.limit.focus == 0 ? m.limit.focus = 1 : _solveM5Limit();
        } else if (m.table.showRows) {
          m.table.showRows = false;
        } else if (m.table.focus < 4) {
          m.table.focus++;
        } else {
          _solveM5Table();
        }
        return true;
      case 'AC':
        _resetResolutionView();
        m.view == 1 ? m.limit.clear() : m.table.clear();
        return true;
      case 'DEL':
        if (res != null) {
          _resetResolutionView();
          return true;
        }
        if (m.view == 2 && m.table.showRows) {
          m.table.showRows = false;
          return true;
        }
    }
    if (m.view == 2 && m.table.showRows) return true;
    if (res != null) _resetResolutionView();
    return m.view == 1 ? m.limit.key(key, alpha: alpha) : m.table.key(key, alpha: alpha);
  }

  void _solveM5Limit() {
    final f = _m5.limit;
    try {
      final LimitPoint pt;
      switch (f.mode) {
        case 3:
          pt = const LimitPoint.plusInfinity();
        case 4:
          pt = const LimitPoint.minusInfinity();
        default:
          final a = FunctionTable.parseNumber(f.a, 'el punto a');
          pt = LimitPoint.at(a, side: f.mode == 1 ? LimSide.left : (f.mode == 2 ? LimSide.right : LimSide.both));
      }
      final (_, res) = LimitsAsymptotesSolver.limit(f.f, pt);
      _activeResolution = res;
      _activeStepIndex = 0;
      _showDecimalApprox = false;
      _recordCurrentResolutionToHistory(res, 'M5: Límites');
    } on TableConfigException catch (e) {
      _showLcdError(e.message);
    } on FormatException catch (e) {
      _showLcdError(e.message);
    } catch (_) {
      _showLcdError('Sintaxis incompleta: la función no es válida.');
    }
  }

  void _solveM5Table() {
    final t = _m5.table;
    try {
      final f = FunctionModel.parse(t.cells[0]);
      final g = t.cells[1].trim().isEmpty ? null : FunctionModel.parse(t.cells[1]);
      t.rows = FunctionTable.build(
        f: f,
        g: g,
        start: FunctionTable.parseNumber(t.cells[2], 'Inicio'),
        end: FunctionTable.parseNumber(t.cells[3], 'Fin'),
        step: FunctionTable.parseNumber(t.cells[4], 'Paso'),
      );
      t.scroll = 0;
      t.showRows = true;
    } on TableConfigException catch (e) {
      _showLcdError(e.message);
    } on FormatException catch (e) {
      _showLcdError(e.message);
    } catch (_) {
      _showLcdError('Sintaxis incompleta: la función no es válida.');
    }
  }

  /// Estudio + Grafica de una f(x) libre escrita con el editor de expresiones.
  void _solveMode5Free() {
    try {
      final fs = FunctionFamilyStudySolver.study(
        _rawInput,
        expectedKind: _graphKind + 1,
        degrees: _angleUnit == AngleUnit.deg,
      );
      final st = fs.result;
      updateState(() {
        _m5.study = st;
        _m5.info = fs.info;
        _m5.deg = fs.degrees;
        _m5.panX = _m5.panY = 0;
        _currentGraphAnalysis = null;
        _selectedGraphPoint = null;
        _activeResolution = st.resolution;
        _activeStepIndex = 0;
        _showGraphView = true;
      });
      _recordCurrentResolutionToHistory(st.resolution, 'M5: f(x)');
    } on FormatException catch (e) {
      _showLcdError(e.message);
    } catch (_) {
      _showLcdError('Sintaxis incompleta: la función no es válida.');
    }
  }
}
