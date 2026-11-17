part of 'calculator_screen.dart';

extension _CalculatorScreenChassis on _CalculatorScreenState {
  Widget _buildCalculatorChassis({
    required String liveLatex,
    required String modeLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1E22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF22252C),
            Color(0xFF1C1E22),
            Color(0xFF16181C),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF252830),
          width: 3.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xCC000000),
            offset: Offset(0, 14),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Color(0x1EFFFFFF),
            offset: Offset(0, -1),
            blurRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: CustomPaint(
          painter: CarbonTexturePainter(),
          child: Padding(
            padding: const EdgeInsets.all(8.5),
            child: LayoutBuilder(
              builder: (context, chassisConstraints) {
                final double maxChassisH = chassisConstraints.maxHeight.isFinite
                    ? chassisConstraints.maxHeight
                    : 700.0;
                final bool isUltraCompact = maxChassisH < 400.0;
                final bool isCompactH = maxChassisH < 540.0;
                final double targetLcdH = isUltraCompact
                    ? (maxChassisH * 0.20).clamp(56.0, 90.0)
                    : isCompactH
                        ? (maxChassisH * 0.25).clamp(70.0, 140.0)
                        : (maxChassisH * 0.36).clamp(180.0, 290.0);
                final bool enforceKeyMinHeights = maxChassisH >= 745.0;
                final double? sciMinH = enforceKeyMinHeights ? 48.0 : null;
                final double? numMinH = enforceKeyMinHeights ? 56.0 : null;
                final double controlZoneH = isUltraCompact
                    ? 38.0
                    : isCompactH
                        ? 48.0
                        : 84.0;
                final double dpadW = isUltraCompact
                    ? 72.0
                    : isCompactH
                        ? 84.0
                        : 108.0;
                final double dpadH = isUltraCompact
                    ? 38.0
                    : isCompactH
                        ? 48.0
                        : 84.0;
                final double controlKeyVPad = isUltraCompact
                    ? 1.0
                    : isCompactH
                        ? 2.0
                        : 12.0;

                return Column(
                  children: [
                    // 1. Pantalla LCD Natural Textbook Display o Visor Gráfico (36%-40%, minHeight: 195 px)
                    SizedBox(
                      height: targetLcdH,
                      child: (_lcdErrorKind != null &&
                              !_isMenuOpen &&
                              !_isSetupOpen)
                          ? _buildLcdErrorScreen()!
                          : _isMenuOpen || _isSetupOpen
                              ? CasioLcdScreen(
                                  currentInputLatex: liveLatex,
                                  currentResolution: _activeResolution,
                                  activeStepIndex: _activeStepIndex,
                                  isShiftActive: _isShiftActive,
                                  isAlphaActive: _isAlphaActive,
                                  isMemoryActive: _memory.hasActiveM,
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
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: FeasibleRegionCanvas(
                                            visualData: _currentFeasibleRegion!,
                                            isOledDark: _isOledDark,
                                          ),
                                        )
                                      : CasioLcdScreen(
                                          currentInputLatex: liveLatex,
                                          currentResolution: _activeResolution,
                                          activeStepIndex: _activeStepIndex,
                                          isShiftActive: _isShiftActive,
                                          isAlphaActive: _isAlphaActive,
                                          isMemoryActive: _memory.hasActiveM,
                                          isOledDark: _isOledDark,
                                          showDecimalApprox: _showDecimalApprox,
                                          modeLabel: modeLabel,
                                          idleHint: _lcdIdleHint,
                                          customHeaderTitle:
                                              _lcdCustomHeaderTitle,
                                          customBodyView: (_calculatorMode ==
                                                      7 &&
                                                  _isChoosingIneqSysUnknowns)
                                              ? _buildIneqSysUnknownsSelector()
                                              : (_calculatorMode == 4 &&
                                                      !_polyIsNotableMode &&
                                                      _isChoosingRuffiniDegree)
                                                  ? _buildRuffiniDegreeSelector()
                                                  : (_calculatorMode == 8
                                                      ? CasioStatTableView(
                                                          rows: _statRows,
                                                          activeRow:
                                                              _statActiveRow,
                                                          activeCol:
                                                              _statActiveCol,
                                                          isOledDark:
                                                              _isOledDark,
                                                          onCellTap: (r, c) {
                                                            updateState(() {
                                                              _activeResolution =
                                                                  null;
                                                              _statActiveRow =
                                                                  r;
                                                              _statActiveCol =
                                                                  c;
                                                            });
                                                          },
                                                        )
                                                      : (_calculatorMode == 9
                                                          ? CasioMatrixEditorView(
                                                              rowsA:
                                                                  _matrixRowsA,
                                                              colsA:
                                                                  _matrixColsA,
                                                              rowsB:
                                                                  _matrixRowsB,
                                                              colsB:
                                                                  _matrixColsB,
                                                              activeMatrixTarget:
                                                                  _matrixActiveTarget,
                                                              selectedOperation:
                                                                  _matrixOp,
                                                              cellsA:
                                                                  _matrixCellsA,
                                                              cellsB:
                                                                  _matrixCellsB,
                                                              scalarK:
                                                                  _matrixScalarK,
                                                              activeRow:
                                                                  _matrixActiveRow,
                                                              activeCol:
                                                                  _matrixActiveCol,
                                                              isOledDark:
                                                                  _isOledDark,
                                                              onCellTap:
                                                                  (r, c) {
                                                                updateState(() {
                                                                  _activeResolution =
                                                                      null;
                                                                  if (_matrixActiveTarget ==
                                                                      2) {
                                                                    _matrixActiveTarget =
                                                                        0;
                                                                  }
                                                                  _matrixActiveRow =
                                                                      r;
                                                                  _matrixActiveCol =
                                                                      c;
                                                                });
                                                              },
                                                              onSwitchMatrixTarget:
                                                                  (target) {
                                                                updateState(() {
                                                                  _activeResolution =
                                                                      null;
                                                                  _matrixActiveTarget =
                                                                      target;
                                                                });
                                                              },
                                                              onUpdateDimensions:
                                                                  (target, rows,
                                                                      cols) {
                                                                updateState(() {
                                                                  _activeResolution =
                                                                      null;
                                                                  if (target ==
                                                                      0) {
                                                                    _matrixRowsA =
                                                                        rows;
                                                                    _matrixColsA =
                                                                        cols;
                                                                  } else {
                                                                    _matrixRowsB =
                                                                        rows;
                                                                    _matrixColsB =
                                                                        cols;
                                                                  }
                                                                  _matrixActiveRow = _matrixActiveRow
                                                                      .clamp(
                                                                          0,
                                                                          rows -
                                                                              1)
                                                                      .toInt()
                                                                      .toInt();
                                                                  _matrixActiveCol = _matrixActiveCol
                                                                      .clamp(
                                                                          0,
                                                                          cols -
                                                                              1)
                                                                      .toInt()
                                                                      .toInt();
                                                                });
                                                              },
                                                              onSelectOperation:
                                                                  _selectMatrixOp,
                                                              operationsInHeader:
                                                                  true,
                                                            )
                                                          : (_calculatorMode ==
                                                                  10
                                                              ? CasioVectorEditorView(
                                                                  dimension:
                                                                      _vectorDim,
                                                                  selectedOperation:
                                                                      _vectorOp,
                                                                  cellsU:
                                                                      _vecUCells,
                                                                  cellsV:
                                                                      _vecVCells,
                                                                  activeRow:
                                                                      _vectorActiveRow,
                                                                  activeCol:
                                                                      _vectorActiveCol,
                                                                  isOledDark:
                                                                      _isOledDark,
                                                                  onCellTap:
                                                                      (r, c) {
                                                                    updateState(
                                                                        () {
                                                                      _activeResolution =
                                                                          null;
                                                                      _vectorActiveRow =
                                                                          r;
                                                                      _vectorActiveCol =
                                                                          c;
                                                                    });
                                                                  },
                                                                  onChangeDimension:
                                                                      _setVectorDim,
                                                                  onSelectOperation:
                                                                      _selectVectorOp,
                                                                  operationsInHeader:
                                                                      true,
                                                                )
                                                              : (_calculatorMode ==
                                                                      11
                                                                  ? CasioComplexEditorView(
                                                                      selectedOperation:
                                                                          _complexOp,
                                                                      cells:
                                                                          _complexCells,
                                                                      activeIndex:
                                                                          _complexActiveIndex,
                                                                      isOledDark:
                                                                          _isOledDark,
                                                                      onCellTap:
                                                                          (idx) {
                                                                        updateState(
                                                                            () {
                                                                          _activeResolution =
                                                                              null;
                                                                          _complexActiveIndex =
                                                                              idx;
                                                                        });
                                                                      },
                                                                      onSelectOperation:
                                                                          _selectComplexOp,
                                                                      operationsInHeader:
                                                                          true,
                                                                    )
                                                                  : (_calculatorMode ==
                                                                          7
                                                                      ? (_isChoosingIneqSysUnknowns ||
                                                                              _activeResolution !=
                                                                                  null
                                                                          ? null
                                                                          : _buildInequalitySystemEditorView())
                                                                      : (_calculatorMode ==
                                                                              12
                                                                          ? CasioCalculusEditorView(
                                                                              selectedOperation: _calculusOp,
                                                                              expressionRaw: _calculusExprRaw,
                                                                              expressionCursorPos: _calculusCursorPos,
                                                                              x0Raw: _calculusX0Raw,
                                                                              limitARaw: _calculusLimitARaw,
                                                                              limitBRaw: _calculusLimitBRaw,
                                                                              activeField: _calculusActiveField,
                                                                              isOledDark: _isOledDark,
                                                                              onSelectField: (field) {
                                                                                updateState(() {
                                                                                  _activeResolution = null;
                                                                                  _calculusActiveField = field;
                                                                                });
                                                                              },
                                                                              onSelectOperation: _selectCalculusOp,
                                                                              operationsInHeader: true,
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
                                          isRadMode:
                                              _angleUnit == AngleUnit.rad,
                                          onToggleAngleUnit: _toggleAngleUnit,
                                          isSetupOpen: _isSetupOpen,
                                          onSelectSetupOption:
                                              _handleSetupOption,
                                          isCalcPromptActive:
                                              _isCalcPromptActive,
                                          calcExpressionLatex:
                                              _isCalcPromptActive
                                                  ? ExpressionParser
                                                      .rawToLiveLatex(
                                                          _calcExpressionRaw)
                                                  : null,
                                          calcValueRaw: _calcValueRaw,
                                          headerSelectors:
                                              _buildHeaderSelectors(),
                                          supplementaryVisualView:
                                              (_calculatorMode ==
                                                              6 ||
                                                          _calculatorMode ==
                                                              7) &&
                                                      _activeIneqVisualData !=
                                                          null &&
                                                      (_activeResolution ==
                                                              null ||
                                                          _activeResolution!
                                                                  .steps
                                                                  .length <=
                                                              1 ||
                                                          _activeStepIndex > 0)
                                                  ? NumberLineWidget(
                                                      data:
                                                          _activeIneqVisualData!,
                                                      isOledDark: _isOledDark,
                                                    )
                                                  : null,
                                          coefficientView: _isCoefficientMode
                                              ? CasioCoefficientView(
                                                  mode: _calculatorMode,
                                                  cellValues:
                                                      _currentCellValues,
                                                  cellLabels:
                                                      _currentCellLabels,
                                                  activeIndex:
                                                      _currentActiveIndex,
                                                  isOledDark: _isOledDark,
                                                  notableTypeIndex:
                                                      _identityType.index,
                                                  inequalitySignSymbol:
                                                      _inequalitySign.symbol,
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
                                        ))),
                    ),

                    // Barra interactiva contextual para Modos 2..12 (oculta si el MENU está abierto)
                    if (!_isMenuOpen) ...[
                      ..._buildBasicModesToolbar(),
                      ..._buildAdvancedModesToolbar(),
                    ],

                    const SizedBox(height: 6),

                    // Keypad ergonómico ClassWiz
                    Expanded(
                      child: CalculatorKeypadView(
                        controlZoneH: controlZoneH,
                        controlKeyVPad: controlKeyVPad,
                        dpadW: dpadW,
                        dpadH: dpadH,
                        sciMinH: sciMinH,
                        numMinH: numMinH,
                        isShiftActive: _isShiftActive,
                        isAlphaActive: _isAlphaActive,
                        isMenuOpen: _isMenuOpen,
                        isSetupOpen: _isSetupOpen,
                        onKeyPress: _handleKeyPress,
                        onDpadLeft: _handleDpadLeft,
                        onDpadRight: _handleDpadRight,
                        onDpadUp: _handleDpadUp,
                        onDpadDown: _handleDpadDown,
                        onDpadCenter: () => _handleKeyPress('='),
                        onOptnPressed: () {
                          if (_isShiftActive) {
                            updateState(() {
                              _isShiftActive = false;
                              _isAlphaActive = false;
                            });
                            if (_calculatorMode == 8) {
                              _openStatOptionsModal();
                            } else {
                              _openQuickOptnModal();
                            }
                          } else {
                            _handleKeyPress('CALC');
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
