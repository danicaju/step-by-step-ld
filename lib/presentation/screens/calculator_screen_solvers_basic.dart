part of 'calculator_screen.dart';

extension _CalculatorScreenSolversBasic on _CalculatorScreenState {
  void _solveMode1() {
      if (_rawInput.contains('Ran')) {
        _rawInput = ClassWizKeyActions.substituteRandoms(_rawInput, _cw.random);
        _cursorPos = _rawInput.length;
      }
      if ((_rawInput.contains('∶') || _rawInput.contains('=')) &&
          _solveMultiStatement()) {
        return;
      }
      if (_rawInput.trim().isEmpty || _rawInput == '0') {
        _showLcdError('Escribe una operación matemática.');
        return;
      }
      try {
        final finalizedInput = ExpressionParser.finalizeForEvaluation(_rawInput);
        final polRec = _tryPolRec(finalizedInput);
        if (polRec != null) {
          updateState(() {
            _rawInput = finalizedInput;
            _cursorPos = finalizedInput.length;
            _activeResolution = polRec;
          });
          _recordCurrentResolutionToHistory(polRec, 'M1: CALCULAR');
          return;
        }
        final extended = _tryExtendedMode1(finalizedInput);
        if (extended != null) {
          updateState(() {
            _rawInput = finalizedInput;
            _cursorPos = finalizedInput.length;
            _activeResolution = extended;
          });
          _recordCurrentResolutionToHistory(extended, 'M1: CALCULAR');
          return;
        }
        final ast = _parser.parse(finalizedInput);
        final res = _evaluator.evaluate(
          ast,
          memoryVariables: _memory.getAllVariablesWithAns(),
          angleUnit: _angleUnit,
        );
        if (_evaluator.lastEvaluatedRational != null) {
          _memory.setAns(_evaluator.lastEvaluatedRational!);
        }
        updateState(() {
          _rawInput = finalizedInput;
          _cursorPos = finalizedInput.length;
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(res, 'M1: CALCULAR');
      } on ExMathError {
        _showLcdError('Math ERROR: operación no definida.');
      } on FormatException catch (e) {
        // El motor clasico no entiende la expresion: se reintenta con el extendido.
        final fin = ExpressionParser.finalizeForEvaluation(_rawInput);
        try {
          final (res, ans) = ExtendedCalcSolver.solveWithAns(
            fin,
            angle: _angleUnit,
            memory: _memory.getAllVariablesWithAns(),
          );
          _memory.setAns(ans);
          updateState(() {
            _rawInput = fin;
            _cursorPos = fin.length;
            _activeResolution = res;
          });
          _recordCurrentResolutionToHistory(res, 'M1: CALCULAR');
        } on ExMathError {
          _showLcdError('Math ERROR: operación no definida.');
        } on FormatException {
          _showLcdError('Sintaxis incompleta: ${e.message}');
        } on ExtUnsupported {
          _showLcdError('Sintaxis incompleta: ${e.message}');
        }
      } catch (e) {
        _showLcdError('Error al evaluar: $e');
      }
      return;
    }

  /// Motor exacto extendido de M1; `null` si debe resolverlo el motor clasico.
  StepByStepResolution? _tryExtendedMode1(String input) {
    if (!ExtendedCalcSolver.needsExtended(input)) return null;
    try {
      final (res, ans) = ExtendedCalcSolver.solveWithAns(
        input,
        angle: _angleUnit,
        memory: _memory.getAllVariablesWithAns(),
      );
      _memory.setAns(ans);
      return res;
    } on ExtUnsupported {
      return null;
    }
  }


  void _solveMode2() {
      final lhsTrim = ExpressionParser.finalizeForEvaluation(_eqLeftRaw.trim());
      final rhsTrim = ExpressionParser.finalizeForEvaluation(_eqRightRaw.trim());
      if (lhsTrim.isEmpty || rhsTrim.isEmpty) {
        _showLcdError('Completa ambos miembros de la ecuación (ej: 2x^2 - 4x = x^2 - 3).');
        return;
      }
      try {
        final fullEq = '$lhsTrim = $rhsTrim';
        final res = PolynomialEquationSolver.solveEquationString(
          fullEq,
          angle: _angleUnit,
        );
        updateState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(res, 'M2: Ecuaciones');
      } on FormatException catch (e) {
        _showLcdError('Error en la ecuación: ${e.message}');
      } catch (e) {
        _showLcdError('Error al resolver: $e');
      }
      return;
    }


  void _solveMode3() {
      if (_systemDim == 4) {
        try {
          final augmentedRows = List.generate(4, (r) {
            return List.generate(5, (c) {
              return _parseRationalCell(
                _sys4Values[r * 5 + c],
                defaultValue: Rational(0),
              );
            });
          });
          final res = LinearSystemSolver.solveNxN(
            augmentedRows: augmentedRows,
            method: _systemMethod,
          );
          updateState(() {
            _activeResolution = res;
          });
          _recordCurrentResolutionToHistory(
            res,
            'M3: Sist. 4x4 (${_systemMethod.displayName})',
          );
        } on FormatException catch (e) {
          _showLcdError(e.message);
        } catch (e) {
          _showLcdError('Error en Sistema 4x4: $e');
        }
        return;
      }
      if (_systemDim == 3) {
        try {
          final augmentedRows = List.generate(3, (r) {
            return List.generate(4, (c) {
              return _parseRationalCell(
                _sys3Values[r * 4 + c],
                defaultValue: Rational(0),
              );
            });
          });
          final res = LinearSystemSolver.solveNxN(
            augmentedRows: augmentedRows,
            method: _systemMethod,
          );
          updateState(() {
            _activeResolution = res;
          });
          _recordCurrentResolutionToHistory(
            res,
            'M3: Sist. 3x3 (${_systemMethod.displayName})',
          );
        } on FormatException catch (e) {
          _showLcdError(e.message);
        } catch (e) {
          _showLcdError('Error en Sistema 3x3: $e');
        }
        return;
      }
      final a1 = _parseCoeffValue(_sysValues[0], defaultValue: 1);
      final b1 = _parseCoeffValue(_sysValues[1], defaultValue: 1);
      final c1 = _parseCoeffValue(_sysValues[2], defaultValue: 0);
      final a2 = _parseCoeffValue(_sysValues[3], defaultValue: 1);
      final b2 = _parseCoeffValue(_sysValues[4], defaultValue: -1);
      final c2 = _parseCoeffValue(_sysValues[5], defaultValue: 0);
      final res = LinearSystemSolver.solve(
        a1: a1,
        b1: b1,
        c1: c1,
        a2: a2,
        b2: b2,
        c2: c2,
        method: _systemMethod,
      );
      updateState(() {
        _activeResolution = res;
      });
      _recordCurrentResolutionToHistory(res, 'M3: Sistemas 2x2');
      return;
    }


  void _solveMode4() {
      if (_polyIsNotableMode) {
        if (_rawInput.trim().isEmpty || _rawInput == '0') {
          _showLcdError('Escribe una identidad notable (ej: (2x + 3)^2 o (x - 4)^2).');
          return;
        }
        try {
          final res = NotableIdentitiesSolver.solveExpressionString(_rawInput);
          updateState(() {
            _activeResolution = res;
          });
          _recordCurrentResolutionToHistory(res, 'M4: Identidades Notables');
        } on FormatException catch (e) {
          _showLcdError('Error en la identidad: ${e.message}');
        } catch (e) {
          _showLcdError('Error al resolver: $e');
        }
        return;
      }

      if (_isChoosingRuffiniDegree) {
        updateState(() {
          _setRuffiniDegree(_ruffiniDegree, enterTemplate: true);
        });
        return;
      }
      final coeffs = <int>[];
      for (int i = 0; i < _ruffiniValues.length; i++) {
        coeffs.add(
          _parseCoeffValue(_ruffiniValues[i], defaultValue: i == 0 ? 1 : 0),
        );
      }
      if (coeffs.first == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El coeficiente principal "a" no puede ser 0.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
      final res = RuffiniSolver.factorize(coeffs);
      updateState(() {
        _activeResolution = res;
      });
      _recordCurrentResolutionToHistory(
        res,
        'M4: Regla de Ruffini ($_ruffiniDegree.º)',
      );
      return;
    }


  void _solveMode5() {
      if (_graphKind == 1) {
        _solveMode5Rational();
        return;
      }
      final a = _parseCoeffValue(_graphValues[0], defaultValue: 1);
      final b = _parseCoeffValue(_graphValues[1], defaultValue: 0);
      final c = _parseCoeffValue(_graphValues[2], defaultValue: 0);
      if (a == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El coeficiente "a" no puede ser 0 para una parábola.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
      final analysis = FunctionGraphSolver.analyzeQuadratic(a: a, b: b, c: c);
      updateState(() {
        _currentGraphAnalysis = analysis;
        _activeResolution = analysis.resolution;
        _selectedGraphPoint = analysis.notablePoints.firstOrNull;
      });
      _recordCurrentResolutionToHistory(analysis.resolution, 'M5: Gráficas');
      return;
    }


  void _solveMode5Rational() {
    final p = _parseCoeffValue(_ratValues[0], defaultValue: 1);
    final q = _parseCoeffValue(_ratValues[1], defaultValue: 0);
    final r = _parseCoeffValue(_ratValues[2], defaultValue: 1);
    final s = _parseCoeffValue(_ratValues[3], defaultValue: 0);
    try {
      final res = RationalFunctionSolver.analyze('($p*x+($q))/($r*x+($s))');
      updateState(() {
        _currentGraphAnalysis = null;
        _selectedGraphPoint = null;
        _activeResolution = res;
      });
      _recordCurrentResolutionToHistory(res, 'M5: Funcion racional');
    } on FormatException catch (e) {
      _showLcdError(e.message);
    } catch (e) {
      _showLcdError('Error en la funcion racional: $e');
    }
  }
}
