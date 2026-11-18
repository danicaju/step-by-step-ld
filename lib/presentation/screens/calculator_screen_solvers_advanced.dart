part of 'calculator_screen.dart';

extension _CalculatorScreenSolversAdvanced on _CalculatorScreenState {
  void _solveCurrentMode() {
    updateState(() {
      _isShiftActive = false;
      _isAlphaActive = false;
      _showDecimalApprox = false;
      _activeStepIndex = 0;
    });

    switch (_calculatorMode) {
      case 1:
        _solveMode1();
        _applyDecimalOutputPreference();
        break;
      case 2:
        _solveMode2();
        break;
      case 3:
        _solveMode3();
        break;
      case 4:
        _solveMode4();
        break;
      case 5:
        _solveMode5();
        break;
      case 6:
        _solveMode6();
        break;
      case 7:
        _solveMode7();
        break;
      case 8:
        _solveMode8();
        break;
      case 9:
        _solveMode9();
        break;
      case 10:
        _solveMode10();
        break;
      case 11:
        _solveMode11();
        break;
      case 12:
        _solveMode12();
        break;
    }
  }

  void _solveMode6() {
      final trimmed = _rawInput.trim();
      if (trimmed.isEmpty || trimmed == '0') {
        final hint = _ineqDegree == 2
            ? 'Escribe una inecuación de 2.º grado (ej: 2x^2 + 5x > 4 o x^2 - 4 <= 0).'
            : (_ineqDegree == 3
                ? 'Escribe una inecuación con valor absoluto o racional (ej: |x - 5| < 3 o (x-2)/(x+1) >= 0).'
                : 'Escribe una inecuación de 1.º grado (ej: 3x - 5 >= 7 - x).');
        _showLcdError(hint);
        return;
      }
      try {
        final res = InequalitySolver.solveString(
          _rawInput,
          fallbackSign: _inequalitySign,
        );
        final visual = InequalitySolver.getVisualData(res);
        updateState(() {
          _activeResolution = res;
          _activeIneqVisualData = visual;
          _currentFeasibleRegion = null;
        });
        _recordCurrentResolutionToHistory(res, switch (_ineqDegree) {
          2 => 'M6: Inecuaciones 2.º Grado',
          3 => 'M6: Valor Absoluto / Racional',
          _ => 'M6: Inecuaciones 1.º Grado',
        });
      } on FormatException catch (e) {
        _showLcdError('Error en inecuación: ${e.message}');
      } catch (e) {
        _showLcdError('Error al resolver: $e');
      }
      return;
    }


  void _solveMode7() {
      final activeRows = _ineqSysRowInputs
          .take(_ineqSysRows)
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s != '0')
          .toList();

      if (activeRows.isEmpty) {
        _showLcdError('Introduce las inecuaciones del sistema en las filas de la llave.');
        return;
      }

      if (_ineqSysUnknowns == 1) {
        // Sistemas 1D: Intersección y rayado sobre la recta real
        try {
          final outcome = InequalitySolver.solveSystem1D(activeRows);
          updateState(() {
            _activeResolution = outcome.resolution;
            _activeIneqVisualData = outcome.visualData;
            _currentFeasibleRegion = null;
          });
          _recordCurrentResolutionToHistory(
            outcome.resolution,
            'M7: Sistema Inecuaciones 1D ($_ineqSysRows Inec.)',
          );
        } catch (e) {
          _showLcdError('Error al resolver sistema 1D: $e');
        }
        return;
      } else {
        // Sistemas 2D: Región factible en el plano cartesiano
        try {
          final outcome = LinearInequality2DSolver.solveSystem2D(activeRows);
          updateState(() {
            _activeResolution = outcome.resolution;
            _currentFeasibleRegion = outcome.visualData;
            _activeIneqVisualData = null;
            _show2DRegionView = true;
          });
          _recordCurrentResolutionToHistory(
            outcome.resolution,
            'M7: Región Factible 2D ($_ineqSysRows Inec.)',
          );
        } catch (e) {
          _showLcdError('Error al calcular región factible 2D: $e');
        }
        return;
      }
    }


  void _solveMode8TwoVar() {
    try {
      final pts = <TwoVarPoint>[];
      for (int i = 0; i < _statRows.length; i++) {
        final row = _statRows[i];
        if (row.xi.trim().isEmpty && row.fi.trim().isEmpty) continue;
        if (row.xi.trim().isEmpty || row.fi.trim().isEmpty) {
          throw FormatException('Falta x o y en la fila ${i + 1}.');
        }
        pts.add(TwoVarPoint(_parseStatRational(row.xi.trim()), _parseStatRational(row.fi.trim())));
      }
      final res = StatisticsTwoVarSolver.analyze(pts).resolution;
      updateState(() {
        _activeResolution = res;
      });
      _recordCurrentResolutionToHistory(res, 'M8: Regresión 2 variables');
    } on FormatException catch (e) {
      _showLcdError(e.message);
    } catch (e) {
      _showLcdError('Error en Estadística: $e');
    }
  }

  void _solveMode8() {
      if (_cw.x.m8View == 1) {
        _solveMode8TwoVar();
        return;
      }
      final points = <StatDataPoint>[];
      try {
        for (int i = 0; i < _statRows.length; i++) {
          final row = _statRows[i];
          final xiRaw = row.xi.trim();
          final fiRaw = row.fi.trim();
          if (xiRaw.isEmpty && fiRaw.isEmpty) continue;
          if (xiRaw.isEmpty) {
            throw FormatException('Falta el valor xᵢ en la fila ${i + 1}.');
          }
          final Rational xiVal = _parseStatRational(xiRaw);
          final int fiVal = fiRaw.isEmpty
              ? 1
              : (int.tryParse(fiRaw) ??
                  (throw FormatException('Frecuencia fᵢ no válida en fila ${i + 1}.')));
          if (fiVal <= 0) {
            throw FormatException('fᵢ debe ser mayor que 0 en fila ${i + 1}.');
          }
          points.add(StatDataPoint(xiVal, fiVal));
        }
        if (points.isEmpty) {
          throw const FormatException('Introduce al menos un dato xᵢ en la tabla.');
        }
        final res = StatisticsOneVarSolver.solve(points);
        updateState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(res, 'M8: Estadística 1-Var');
      } on FormatException catch (e) {
        _showLcdError(e.message);
      } catch (e) {
        _showLcdError('Error en Estadística: $e');
      }
      return;
    }


  void _solveMode9() {
      try {
        final int rCountA = _matrixRowsA;
        final int cCountA = _matrixColsA;
        final matA = _buildRationalMatrixFromCells(
          _matrixCellsA,
          _matrixDim,
          rows: rCountA,
          cols: cCountA,
        );
        final int rCountB = _matrixRowsB;
        final int cCountB = _matrixColsB;
        final matB = _matrixOp.needsMatrixB
            ? (_matrixOp == MatrixOperation.cramer
                ? _buildRationalMatrixFromCells(_matrixCellsB, _matrixDim, rows: rCountA, cols: 1)
                : _buildRationalMatrixFromCells(_matrixCellsB, _matrixDim, rows: rCountB, cols: cCountB))
            : null;
        final scalarVal = _matrixOp == MatrixOperation.scalarMultiply
            ? _parseRationalCell(_matrixScalarK, defaultValue: Rational(1))
            : null;
        final res = MatrixSolver.solve(
          operation: _matrixOp,
          a: matA,
          b: matB,
          scalar: scalarVal,
        );
        updateState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(
          res,
          'M9: Matrices (${_matrixOp.shortLabel})',
        );
      } on FormatException catch (e) {
        _showLcdError(e.message);
      } catch (e) {
        _showLcdError('Error en Matrices: $e');
      }
      return;
    }


  void _solveMode10() {
      try {
        final u = _buildRationalVectorFromCells(_vecUCells, _vectorDim);
        final v = _vectorOp.needsSecondVector
            ? _buildRationalVectorFromCells(_vecVCells, _vectorDim)
            : null;
        final w = _vectorOp.needsThirdVector
            ? _buildRationalVectorFromCells(_vecWCells, _vectorDim)
            : null;
        final res = VectorSolver.solve(
          operation: _vectorOp,
          u: u,
          v: v,
          w: w,
        );
        updateState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(
          res,
          'M10: Vectores (${_vectorOp.shortLabel})',
        );
      } on FormatException catch (e) {
        _showLcdError(e.message);
      } catch (e) {
        _showLcdError('Error en Vectores: $e');
      }
      return;
    }


  void _solveMode11() {
      try {
        final a1 = _parseRationalCell(_complexCells[0], defaultValue: Rational(0));
        final b1 = _parseRationalCell(_complexCells[1], defaultValue: Rational(0));
        final a2 = _parseRationalCell(_complexCells[2], defaultValue: Rational(0));
        final b2 = _parseRationalCell(_complexCells[3], defaultValue: Rational(0));
        final z1 = RationalComplex(a1, b1);
        final z2 = RationalComplex(a2, b2);

        final res = _complexOp == ComplexOperation.fromPolar
            ? ComplexSolver.solve(
                operation: ComplexOperation.fromPolar,
                z1: z1,
                polarModulus: a1,
                polarAngleDegrees: b1.toDouble(),
              )
            : ComplexSolver.solve(
                operation: _complexOp,
                z1: z1,
                z2: _complexOp.needsSecondComplex ? z2 : null,
              );
        updateState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(
          res,
          'M11: Complejos (${_complexOp.shortLabel})',
        );
      } on FormatException catch (e) {
        _showLcdError(e.message);
      } catch (e) {
        _showLcdError('Error en Complejos: $e');
      }
      return;
    }


  void _solveMode12() {
      try {
        final expr = _calculusExprRaw.trim().isEmpty
            ? '0'
            : ExpressionParser.finalizeForEvaluation(_calculusExprRaw.trim());
        final x0 = _parseRationalCell(_calculusX0Raw, defaultValue: Rational(0));
        final limA = _parseRationalCell(_calculusLimitARaw, defaultValue: Rational(0));
        final limB = _parseRationalCell(_calculusLimitBRaw, defaultValue: Rational(1));

        final res = CalculusSolver.solve(
          operation: _calculusOp,
          expressionRaw: expr,
          tangentX0: x0,
          integralLowerA: limA,
          integralUpperB: limB,
        );
        updateState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(
          res,
          'M12: Cálculo (${_calculusOp.shortLabel})',
        );
      } on FormatException catch (e) {
        _showLcdError(e.message);
      } on ExtUnsupported catch (e) {
        _showLcdError(e.message);
      } catch (e) {
        _showLcdError('Error en Cálculo: $e');
      }
      return;
    }
}
