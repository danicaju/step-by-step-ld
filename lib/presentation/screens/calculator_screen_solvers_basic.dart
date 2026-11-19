part of 'calculator_screen.dart';

extension _CalculatorScreenSolversBasic on _CalculatorScreenState {
  void _solveMode1() {
      if (_rawInput.contains('Ran')) {
        _rawInput = ClassWizKeyActions.substituteRandoms(_rawInput, _cw.random);
        _cursorPos = _rawInput.length;
      }
      if (ClassWizConstants.containsConstants(_rawInput)) {
        _solveConstants();
        return;
      }
      if (ClassWizRewrites.needsRewrite(_rawInput)) {
        _rawInput = ClassWizRewrites.prepare(_rawInput, _angleUnit);
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
      // Lo que tecleo el alumno: el enunciado de los pasos conserva sus fracciones verticales.
      final typedRaw = _rawInput;
      try {
        final symbolicRaw = M1SymbolicSolver.solve(_rawInput, memory: _memory.getAllVariablesWithAns());
        final symbolic = symbolicRaw == null ? null : _withTypedStatement(symbolicRaw, typedRaw);
        if (symbolic != null) {
          updateState(() {
            _activeResolution = symbolic;
          });
          _recordCurrentResolutionToHistory(symbolic, 'M1: ALGEBRA');
          return;
        }
        final iberia = CasioIberiaArsenal.routeInput(_rawInput);
        if (iberia != null) {
          updateState(() {
            _activeResolution = iberia;
          });
          _recordCurrentResolutionToHistory(iberia, 'M1: ARSENAL');
          return;
        }
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
        final extendedRaw = _tryExtendedMode1(finalizedInput);
        final extended = extendedRaw == null ? null : _withTypedStatement(extendedRaw, typedRaw);
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
        final res = _withTypedStatement(
          _evaluator.evaluate(
            ast,
            memoryVariables: _memory.getAllVariablesWithAns(),
            angleUnit: _angleUnit,
          ),
          typedRaw,
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
      } on ArsenalException catch (e) {
        _showLcdError(e.message);
      } on ExMathError catch (e) {
        _showLcdError(_mathErrorText(e));
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
        } on ExMathError catch (m) {
          _showLcdError(_mathErrorText(m));
        } on FormatException {
          _showLcdError('Sintaxis incompleta: ${e.message}');
        } on ExtUnsupported {
          _showLcdError('Sintaxis incompleta: ${e.message}');
        }
      } on ArgumentError catch (e) {
        _showLcdError('Math ERROR: ${e.message ?? 'operación no definida.'}');
      } on StateError {
        _showLcdError('Math ERROR: operación no definida.');
      } catch (e) {
        _showLcdError('Math ERROR: $e');
      }
      return;
    }

  /// Texto limpio de un `ExMathError` (sin el nombre generico `Math ERROR`).
  String _mathErrorText(ExMathError e) =>
      e.message == 'Math ERROR' ? 'Math ERROR: operación no definida.' : 'Math ERROR: ${e.message}';

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
        final solved = PolynomialEquationSolver.solveEquationString(
          fullEq,
          angle: _angleUnit,
        );
        final typedL = _typedStatementTex(_eqLeftRaw);
        final typedR = _typedStatementTex(_eqRightRaw);
        final typedEq = (typedL == null && typedR == null)
            ? null
            : '${typedL ?? ExpressionParser.rawToLiveLatex(lhsTrim)} = '
                '${typedR ?? ExpressionParser.rawToLiveLatex(rhsTrim)}';
        final res = typedEq == null ? solved : solved.withOriginalInput(typedEq);
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
      // Coeficientes racionales (a/b en las celdas): se quitan los denominadores, sin redondear.
      final List<Rational> r1, r2;
      try {
        Rational q(int i, int def) => _parseRationalCell(_sysValues[i], defaultValue: Rational(def));
        r1 = [q(0, 1), q(1, 1), q(2, 0)];
        r2 = [q(3, 1), q(4, -1), q(5, 0)];
      } on FormatException catch (e) {
        _showLcdError(e.message);
        return;
      }
      final res = System2x2Fractions.solve(row1: r1, row2: r2, method: _systemMethod);
      updateState(() {
        _activeResolution = res;
        _storeSystemLines(r1, r2, res);
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
      final coeffs = <Rational>[];
      final coeffCount = _ruffiniValues.length - 1; // la ultima celda es la raiz r
      try {
        for (int i = 0; i < coeffCount; i++) {
          coeffs.add(_parseRationalCell(
            _ruffiniValues[i],
            defaultValue: Rational(i == 0 ? 1 : 0),
          ));
        }
      } on FormatException catch (e) {
        _showLcdError(e.message);
        return;
      }
      if (coeffs.first.isZero) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El coeficiente principal "a" no puede ser 0.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
      // Con la celda `r` rellena se divide entre (x - r); vacia, se factoriza.
      final rootRaw = _ruffiniValues.last.trim();
      final StepByStepResolution res;
      if (rootRaw.isEmpty) {
        res = RuffiniSolver.factorizeRational(coeffs);
      } else {
        try {
          final root = _parseRationalCell(rootRaw);
          if (!root.isInteger || coeffs.any((c) => !c.isInteger)) {
            _showLcdError('Ruffini divide con coeficientes y raíz r enteros. Para fracciones usa la división en caja.');
            return;
          }
          res = RuffiniDivision.divide([for (final c in coeffs) c.numerator], root.numerator);
        } on FormatException catch (e) {
          _showLcdError(e.message);
          return;
        }
      }
      updateState(() {
        _activeResolution = res;
      });
      _recordCurrentResolutionToHistory(
        res,
        rootRaw.isEmpty ? 'M4: Regla de Ruffini ($_ruffiniDegree.º)' : 'M4: Ruffini: división entre (x - r)',
      );
      return;
    }


  void _solveMode5() {
      if (!_m5FormActive) {
        _solveMode5Free();
        return;
      }
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
      final raw = '($p*x+($q))/($r*x+($s))';
      if (RationalHyperbolaStudy.isHyperbola(p, q, r, s)) {
        final base = LimitsAsymptotesSolver.study(raw);
        final res = RationalHyperbolaStudy.analyze(p, q, r, s);
        updateState(() {
          _m5.study = StudyResult(base.model, base.domain, base.asymptotes, res);
          _currentGraphAnalysis = null;
          _selectedGraphPoint = null;
          _activeResolution = res;
          _activeStepIndex = 0;
          _showGraphView = true;
        });
        _recordCurrentResolutionToHistory(res, 'M5: Funcion racional');
        return;
      }
      final res = RationalFunctionSolver.analyze(raw);
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
