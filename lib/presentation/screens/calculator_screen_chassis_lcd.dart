part of 'calculator_screen.dart';

extension _CalculatorScreenChassisLcd on _CalculatorScreenState {
  Widget _buildLcdPanel(
      {required String liveLatex, required String modeLabel}) {
    if (_isPoweredOff) return const LcdPoweredOff();
    if (_isMemViewOpen) return _buildMemoryViewer();
    if (_cw.resetOpen) return _buildResetView();
    if (_cw.list != null) return _buildListMenu();
    if (_cw.prop != null) {
      return _lcdErrorKind != null ? _buildLcdErrorScreen()! : _buildPropWidget();
    }
    final m5Graph = _buildM5Graph();
    if (m5Graph != null) return m5Graph;
    return (_lcdErrorKind != null && !_isMenuOpen && !_isSetupOpen)
        ? _buildLcdErrorScreen()!
        : _isMenuOpen || _isSetupOpen
            ? CasioLcdScreen(
                currentInputLatex: liveLatex,
                currentResolution: _activeResolution,
                activeStepIndex: _activeStepIndex,
                isShiftActive: _isShiftActive,
                isAlphaActive: _isAlphaActive,
                isMemoryActive: _memory.hasActiveM,
                lcdTheme: _lcdTheme,
                isOledDark: _isOledDark,
                showDecimalApprox: _showDecimalApprox,
                modeLabel: modeLabel,
                idleHint: _lcdIdleHint,
                customHeaderTitle: _lcdCustomHeaderTitle,
                isMenuOpen: _isMenuOpen,
                menuCursorIndex: _menuCursorIndex,
                onSelectMenuMode: _selectModeFromMenu,
                onMenuCursorChanged: (idx) {
                  updateState(() {
                    _menuCursorIndex = idx;
                  });
                },
                onToggleTheme: _toggleLcdTheme,
                isSoundMuted: _isSoundMuted,
                onToggleSound: _toggleSound,
                isRadMode: _angleUnit == AngleUnit.rad,
 angleLabel: _angleLabel,
 setupView: _isSetupOpen ? _buildSetupView() : null,
                onToggleAngleUnit: _toggleAngleUnit,
                isSetupOpen: _isSetupOpen,
                onSelectSetupOption: _handleSetupOption,
              )
            : (_calculatorMode == 5 &&
                    _showGraphView &&
                    _currentGraphAnalysis != null
                ? CasioGraphCanvas(
                    analysisResult: _currentGraphAnalysis!,
                    selectedPoint: _selectedGraphPoint,
                    onPointSelected: (point) {
                      updateState(() {
                        _selectedGraphPoint = point;
                      });
                    },
                  )
                : (_calculatorMode == 7 &&
                        _ineqSysUnknowns == 2 &&
                        _show2DRegionView &&
                        _currentFeasibleRegion != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: FeasibleRegionCanvas(
                          visualData: _currentFeasibleRegion!,
                          isOledDark: _isOledDark,
                        ),
                      )
                    : CasioLcdScreen(
                        key: _lcdBoundsKey,
                        currentInputLatex: liveLatex,
                        currentResolution: _activeResolution,
                        activeStepIndex: _activeStepIndex,
                        isShiftActive: _isShiftActive,
                        isAlphaActive: _isAlphaActive,
                        isMemoryActive: _memory.hasActiveM,
                        showDisp: _showDisp,
                        showSto: _cw.stoPending,
                        showIns: !_isInsertMode,
                        edgeFlags: _edgeFlags(),
                        resultOverrideLatex: _resultOverride,
                        calcVarLabel: _calcPromptVar,
                        lcdTheme: _lcdTheme,
                        isOledDark: _isOledDark,
                        showDecimalApprox: _showDecimalApprox,
                        modeLabel: modeLabel,
                        idleHint: _lcdIdleHint,
                        customHeaderTitle: _lcdCustomHeaderTitle,
                        customBodyView: _extraFormActive
                            ? _buildExtraForm()
                            : (_calculatorMode == 8
                                    ? CasioStatTableView(
                                        rows: _statRows,
                                        activeRow: _statActiveRow,
                                        activeCol: _statActiveCol,
                                        isOledDark: _isOledDark,
                                        onCellTap: (r, c) {
                                          updateState(() {
                                            _activeResolution = null;
                                            _statActiveRow = r;
                                            _statActiveCol = c;
                                          });
                                        },
                                      )
                                    : (_calculatorMode == 9
                                        ? CasioMatrixEditorView(
                                            rowsA: _matrixRowsA,
                                            colsA: _matrixColsA,
                                            rowsB: _matrixRowsB,
                                            colsB: _matrixColsB,
                                            activeMatrixTarget:
                                                _matrixActiveTarget,
                                            selectedOperation: _matrixOp,
                                            cellsA: _matrixCellsA,
                                            cellsB: _matrixCellsB,
                                            scalarK: _matrixScalarK,
                                            activeRow: _matrixActiveRow,
                                            activeCol: _matrixActiveCol,
                                            isOledDark: _isOledDark,
                                            onCellTap: (r, c) {
                                              updateState(() {
                                                _activeResolution = null;
                                                if (_matrixActiveTarget == 2) {
                                                  _matrixActiveTarget = 0;
                                                }
                                                _matrixActiveRow = r;
                                                _matrixActiveCol = c;
                                              });
                                            },
                                            onSwitchMatrixTarget: (target) {
                                              updateState(() {
                                                _activeResolution = null;
                                                _matrixActiveTarget = target;
                                              });
                                            },
                                            onUpdateDimensions:
                                                (target, rows, cols) {
                                              updateState(() {
                                                _activeResolution = null;
                                                if (target == 0) {
                                                  _matrixRowsA = rows;
                                                  _matrixColsA = cols;
                                                } else {
                                                  _matrixRowsB = rows;
                                                  _matrixColsB = cols;
                                                }
                                                _matrixActiveRow =
                                                    _matrixActiveRow
                                                        .clamp(0, rows - 1)
                                                        .toInt()
                                                        .toInt();
                                                _matrixActiveCol =
                                                    _matrixActiveCol
                                                        .clamp(0, cols - 1)
                                                        .toInt()
                                                        .toInt();
                                              });
                                            },
                                            onSelectOperation: _selectMatrixOp,
                                            operationsInHeader: true,
                                          )
                                        : (_calculatorMode == 10
                                            ? CasioVectorEditorView(
                                                dimension: _vectorDim,
                                                selectedOperation: _vectorOp,
                                                cellsU: _vecUCells,
                                                cellsV: _vecVCells,
                                                cellsW: _vecWCells,
                                                activeRow: _vectorActiveRow,
                                                activeCol: _vectorActiveCol,
                                                isOledDark: _isOledDark,
                                                onCellTap: (r, c) {
                                                  updateState(() {
                                                    _activeResolution = null;
                                                    _vectorActiveRow = r;
                                                    _vectorActiveCol = c;
                                                  });
                                                },
                                                onChangeDimension:
                                                    _setVectorDim,
                                                onSelectOperation:
                                                    _selectVectorOp,
                                                operationsInHeader: true,
                                              )
                                            : (_calculatorMode == 11
                                                ? CasioComplexEditorView(
                                                    selectedOperation:
                                                        _complexOp,
                                                    cells: _complexCells,
                                                    activeIndex:
                                                        _complexActiveIndex,
                                                    isOledDark: _isOledDark,
                                                    onCellTap: (idx) {
                                                      updateState(() {
                                                        _activeResolution =
                                                            null;
                                                        _complexActiveIndex =
                                                            idx;
                                                      });
                                                    },
                                                    onSelectOperation:
                                                        _selectComplexOp,
                                                    operationsInHeader: true,
                                                  )
                                                : (_calculatorMode == 7
                                                    ? (_activeResolution !=
                                                                null
                                                        ? null
                                                        : _buildInequalitySystemEditorView())
                                                    : (_calculatorMode == 12
                                                        ? CasioCalculusEditorView(
                                                            selectedOperation:
                                                                _calculusOp,
                                                            expressionRaw:
                                                                _calculusExprRaw,
                                                            expressionCursorPos:
                                                                _calculusCursorPos,
                                                            x0Raw:
                                                                _calculusX0Raw,
                                                            limitARaw:
                                                                _calculusLimitARaw,
                                                            limitBRaw:
                                                                _calculusLimitBRaw,
                                                            activeField:
                                                                _calculusActiveField,
                                                            isOledDark:
                                                                _isOledDark,
                                                            onSelectField:
                                                                (field) {
                                                              updateState(() {
                                                                _activeResolution =
                                                                    null;
                                                                _calculusActiveField =
                                                                    field;
                                                              });
                                                            },
                                                            onSelectOperation:
                                                                _selectCalculusOp,
                                                            operationsInHeader:
                                                                true,
                                                          )
                                                        : null)))))),
                        isMenuOpen: _isMenuOpen,
                        menuCursorIndex: _menuCursorIndex,
                        onSelectMenuMode: _selectModeFromMenu,
                        onMenuCursorChanged: (idx) {
                          updateState(() {
                            _menuCursorIndex = idx;
                          });
                        },
                        onToggleTheme: _toggleLcdTheme,
                        isSoundMuted: _isSoundMuted,
                        onToggleSound: _toggleSound,
                        isRadMode: _angleUnit == AngleUnit.rad,
 angleLabel: _angleLabel,
 setupView: _isSetupOpen ? _buildSetupView() : null,
                        onToggleAngleUnit: _toggleAngleUnit,
                        isSetupOpen: _isSetupOpen,
                        onSelectSetupOption: _handleSetupOption,
                        isCalcPromptActive: _isCalcPromptActive,
                        calcExpressionLatex: _isCalcPromptActive
                            ? ExpressionParser.rawToLiveLatex(
                                _calcExpressionRaw)
                            : null,
                        calcValueRaw: _calcValueRaw,
                        headerSelectors: _buildHeaderSelectors(),
                        supplementaryVisualView: _extraVisual() ??
                            ((_calculatorMode == 6 || _calculatorMode == 7) &&
                                    _activeIneqVisualData != null &&
                                    (_activeResolution == null ||
                                        _activeResolution!.steps.length <= 1 ||
                                        _activeStepIndex > 0)
                                ? NumberLineWidget(
                                    data: _activeIneqVisualData!,
                                    isOledDark: _isOledDark,
                                  )
                                : null),
                        coefficientView: _m5FormActive
                            ? _buildM5Form()
                            : _isCoefficientMode
                            ? CasioCoefficientView(
                                mode: _calculatorMode,
                                cellValues: _currentCellValues,
                                cellLabels: _currentCellLabels,
                                activeIndex: _currentActiveIndex,
                                isOledDark: _isOledDark,
                                notableTypeIndex: _identityType.index,
                                graphKind: _graphKind,
                                inequalitySignSymbol: _inequalitySign.symbol,
                                onCycleInequalitySign: () {
                                  updateState(() {
                                    _cycleInequalitySign();
                                  });
                                },
                                onCellTap: (idx) {
                                  updateState(() {
                                    _currentActiveIndex = idx;
                                  });
                                },
                              )
                            : null,
                      )));
  }
}
