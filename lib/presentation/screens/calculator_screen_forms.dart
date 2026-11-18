part of 'calculator_screen.dart';

/// Vistas nuevas con formulario: M4 (caja, fracciones), M8 (Normal, Binomial), M10 (recta, triangulos).
extension _CalculatorScreenForms on _CalculatorScreenState {
  ExtraViewsState get _x => _cw.x;

  ModeFormState? get _extraForm => switch (_calculatorMode) {
        4 => _x.m4View == 2 ? _x.box : (_x.m4View == 3 ? _x.frac : null),
        8 => _x.m8View == 2 ? _x.normal : (_x.m8View == 3 ? _x.bin : null),
        10 => _x.m10View == 1 ? _x.line : (_x.m10View == 2 ? _x.tri : null),
        _ => null,
      };

  bool get _extraFormActive => _extraForm != null;

  Widget _buildExtraForm() {
    final f = _extraForm!;
    if (_calculatorMode == 4) {
      void onFocus(int i) => updateState(() => f.focus = i);
      return _x.m4View == 2
          ? BoxDivisionInputWidget(form: f, theme: _lcdTheme, onFocus: onFocus)
          : FractionInputWidget(form: f, theme: _lcdTheme, onFocus: onFocus);
    }
    if (_calculatorMode == 8) {
      return ProbabilityDistributionWidget(
        form: f,
        theme: _lcdTheme,
        binomial: _x.m8View == 3,
        onFocus: (i) => updateState(() => f.focus = i),
      );
    }
    return ModeFormWidget(
      form: f,
      theme: _lcdTheme,
      keyPrefix: 'xform',
      onFocus: (i) => updateState(() => f.focus = i),
    );
  }

  /// Visual del resultado (caja, campana o croquis) en el ultimo paso.
  Widget? _extraVisual() {
    final res = _activeResolution;
    if (res == null) return null;
    final x = _x;
    // La caja espanola se dibuja en TODOS los pasos (es el grueso de la explicacion).
    if (_calculatorMode == 4 && x.boxResult != null && identical(res, x.boxResult!.resolution)) {
      return SpanishBoxDivisionView(result: x.boxResult!, stage: _activeStepIndex, isOledDark: _isOledDark);
    }
    if (_activeStepIndex != res.steps.length - 1) return null;
    if (_calculatorMode == 8 && x.normalResult != null && identical(res, x.normalResult!.resolution)) {
      return GaussianBellView(result: x.normalResult!);
    }
    if (_calculatorMode == 10 && x.triResult != null && identical(res, x.triResult!.resolution)) {
      return TriangleSketchView(solution: x.triResult!.solutions.first);
    }
    return null;
  }

  /// Reparto (sobre 10) del alto de la LCD para el visual: la caja ocupa casi todo.
  int get _extraVisualFlex => _calculatorMode == 4 && _x.m4View == 2 ? 8 : 6;

  bool _extraDpad(String dir) {
    final f = _extraForm;
    if (f == null || _activeResolution != null) return false;
    f.dpad(dir);
    return true;
  }

  bool _handleExtraKey(String key) {
    final f = _extraForm;
    if (f == null || _isShiftActive || _headerFocus >= 0 || _lcdErrorKind != null) return false;
    final alpha = _isAlphaActive;
    _isAlphaActive = false;
    final res = _activeResolution;
    switch (key) {
      case '=':
        if (res != null) {
          _activeStepIndex = _activeStepIndex < res.steps.length - 1 ? _activeStepIndex + 1 : 0;
        } else if (f.advance()) {
          _solveExtra();
        }
        return true;
      case 'AC':
        _resetResolutionView();
        _x.clearResults();
        f.clear();
        return true;
      case 'DEL':
        if (res != null) {
          _resetResolutionView();
          return true;
        }
    }
    if (res != null) _resetResolutionView();
    return f.key(key, alpha: alpha);
  }

  String _t(ModeFormState f, int i) => f.text(i);

  void _solveExtra() {
    final x = _x;
    try {
      final StepByStepResolution res;
      final String label;
      switch (_calculatorMode) {
        case 4:
          if (x.m4View == 2) {
            final r = SpanishBoxDivisionSolver.divideText(_t(x.box, 0), _t(x.box, 1));
            x.boxResult = r;
            res = r.resolution;
            label = 'M4: División en caja';
          } else {
            final op = FractionOp.values[x.frac.selector];
            res = AlgebraicFractionSolver.operate(
              op,
              _t(x.frac, 0),
              _t(x.frac, 1),
              op == FractionOp.simplify ? '' : _t(x.frac, 2),
              op == FractionOp.simplify ? '' : _t(x.frac, 3),
            ).resolution;
            label = 'M4: Fracciones algebraicas';
          }
        case 10:
          if (x.m10View == 1) {
            Rational n(int i) => ProportionSolver.parseQuantity(_t(x.line, i));
            res = switch (x.line.selector) {
              0 => LineEquationsSolver.fromPoints(n(0), n(1), n(2), n(3)).resolution,
              1 => LineEquationsSolver.fromPointVector(n(0), n(1), n(2), n(3)).resolution,
              _ => LineEquationsSolver.fromPointSlope(n(0), n(1), n(2)).resolution,
            };
            label = 'M10: Ecuaciones de la recta';
          } else {
            double? v(int i) => _t(x.tri, i).trim().isEmpty ? null : ProportionSolver.parseQuantity(_t(x.tri, i)).toDouble();
            final r = TriangleSolver.solve(sides: [v(0), v(1), v(2)], angles: [v(3), v(4), v(5)]);
            x.triResult = r;
            res = r.resolution;
            label = 'M10: Triángulos';
          }
        default:
          if (x.m8View == 2) {
            final f = x.normal;
            final op = NormalOp.values[f.selector];
            final r = ProbabilityDistributionSolver.normal(
              mu: _t(f, 0),
              sigma: _t(f, 1),
              a: _t(f, 2),
              b: op == NormalOp.between ? _t(f, 3) : null,
              op: op,
            );
            x.normalResult = r;
            res = r.resolution;
            label = 'M8: Normal';
          } else {
            final f = x.bin;
            res = ProbabilityDistributionSolver.binomial(
              n: _t(f, 0),
              p: _t(f, 1),
              k: _t(f, 2),
              op: BinomialOp.values[f.selector],
            ).resolution;
            label = 'M8: Binomial';
          }
      }
      _activeResolution = res;
      _activeStepIndex = 0;
      _showDecimalApprox = false;
      _recordCurrentResolutionToHistory(res, label);
    } on ArsenalException catch (e) {
      _showLcdError(e.message);
    } on FormatException catch (e) {
      _showLcdError(e.message);
    } catch (_) {
      _showLcdError('Sintaxis incompleta: revisa los datos.');
    }
  }
}
