part of 'calculator_screen.dart';

extension _CalculatorScreenSolversBasic on _CalculatorScreenState {
  void _solveMode1() {
      if (_rawInput.trim().isEmpty || _rawInput == '0') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escribe una operación matemática.'),
            backgroundColor: Color(0xFFB91C1C),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      try {
        final finalizedInput = ExpressionParser.finalizeForEvaluation(_rawInput);
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
        _recordCurrentResolutionToHistory(res, 'M1: CALC & √');
      } on FormatException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sintaxis incompleta: ${e.message}'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al evaluar: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
      return;
    }


  void _solveMode2() {
      final lhsTrim = _eqLeftRaw.trim();
      final rhsTrim = _eqRightRaw.trim();
      if (lhsTrim.isEmpty || rhsTrim.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completa ambos miembros de la ecuación (ej: 2x^2 - 4x = x^2 - 3).',
            ),
            backgroundColor: Color(0xFFB91C1C),
          ),
        );
        return;
      }
      try {
        final fullEq = '$lhsTrim = $rhsTrim';
        final res = PolynomialEquationSolver.solveEquationString(fullEq);
        updateState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(res, 'M2: Ecuaciones');
      } on FormatException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en la ecuación: ${e.message}'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al resolver: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: const Color(0xFFB91C1C),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error en Sistema 4x4: $e'),
              backgroundColor: const Color(0xFFB91C1C),
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: const Color(0xFFB91C1C),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error en Sistema 3x3: $e'),
              backgroundColor: const Color(0xFFB91C1C),
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Escribe una identidad notable (ej: (2x + 3)^2 o (x - 4)^2).',
              ),
              backgroundColor: Color(0xFFB91C1C),
            ),
          );
          return;
        }
        try {
          final res = NotableIdentitiesSolver.solveExpressionString(_rawInput);
          updateState(() {
            _activeResolution = res;
          });
          _recordCurrentResolutionToHistory(res, 'M4: Identidades Notables');
        } on FormatException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error en la identidad: ${e.message}'),
              backgroundColor: const Color(0xFFB91C1C),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al resolver: $e'),
              backgroundColor: const Color(0xFFB91C1C),
            ),
          );
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

}
