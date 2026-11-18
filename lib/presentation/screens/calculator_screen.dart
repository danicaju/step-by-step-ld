import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/math_engine/core/calculator_memory.dart';
import '../../domain/math_engine/core/rational.dart';
import '../../domain/math_engine/models/step_resolution.dart';
import '../../domain/math_engine/parser/expression_parser.dart';
import '../../domain/math_engine/solvers/calc_solver.dart';
import '../../domain/math_engine/solvers/calculus_solver.dart';
import '../../domain/math_engine/solvers/complex_solver.dart';
import '../../domain/math_engine/solvers/exact/extended_calc_solver.dart';
import '../../domain/math_engine/solvers/function_graph_solver.dart';
import '../../domain/math_engine/solvers/rational_function_solver.dart';
import '../../domain/math_engine/solvers/inequality_solver.dart';
import '../../domain/math_engine/solvers/linear_system_solver.dart';
import '../../domain/math_engine/solvers/matrix_solver.dart';
import '../../domain/math_engine/solvers/notable_identities_solver.dart';
import '../../domain/math_engine/solvers/polynomial_equation_solver.dart';
import '../../domain/math_engine/solvers/radical_and_factor_solver.dart';
import '../../domain/math_engine/solvers/ruffini_solver.dart';
import '../../domain/math_engine/solvers/statistics_solver.dart';
import '../../domain/math_engine/solvers/step_evaluator.dart';
import '../../domain/math_engine/solvers/trig_and_angles_solver.dart';
import '../../domain/math_engine/solvers/vector_solver.dart';
import '../../domain/services/class_history_service.dart';
import '../utils/goodnotes_exporter.dart';
import '../utils/key_click_sound.dart';
import '../widgets/ai_tutor_sheet.dart';
import '../widgets/casio_calculus_editor_view.dart';
import '../widgets/casio_coefficient_view.dart';
import '../widgets/casio_complex_editor_view.dart';
import '../widgets/casio_graph_canvas.dart';
import '../widgets/casio_lcd_screen.dart';
import '../widgets/lcd/lcd_dropdown_selector.dart';
import '../widgets/lcd/lcd_error_screen.dart';
import '../widgets/lcd/lcd_palette.dart';
import '../widgets/lcd/lcd_powered_off.dart';
import '../widgets/lcd/lcd_memory_viewer.dart';
import '../widgets/lcd/lcd_menu_navigation.dart';
import '../../domain/math_engine/parser/balanced_scan.dart';
import '../../domain/math_engine/functions/function_family_study_solver.dart';
import '../../domain/math_engine/solvers/complex/pol_rec_solver.dart';
import '../widgets/lcd/lcd_setup_menu.dart';
import '../../domain/math_engine/core/calculator_settings.dart';
import '../widgets/casio_matrix_editor_view.dart';
import '../widgets/casio_stat_table_view.dart';
import '../widgets/casio_vector_editor_view.dart';
import '../widgets/class_history_sheet.dart';
import '../widgets/feasible_region_canvas.dart';
import '../widgets/number_line_painter.dart';
import '../widgets/windows_side_panel.dart';
import '../../domain/math_engine/solvers/linear_inequality_2d_solver.dart';
import '../widgets/calculator_bezel_widgets.dart';
import '../widgets/calculator_keypad_view.dart';
import '../widgets/modes/calculator_method_tab.dart';
import '../widgets/modes/probability_distribution_widget.dart';
import '../widgets/modes/inequality_system_editor_view.dart';
import 'classwiz_state.dart';
import '../widgets/solar_panel.dart';
import '../utils/cell_fraction_editor.dart';

part 'calculator_screen_optn.dart';
part 'calculator_screen_lcd_error.dart';
part 'calculator_screen_setup.dart';
part 'calculator_screen_labels.dart';
part 'calculator_screen_menu_keys.dart';
part 'calculator_screen_memory_view.dart';
part 'calculator_screen_keypress_hw.dart';
part 'calculator_screen_op_handlers.dart';
part 'calculator_screen_header_specs.dart';
part 'calculator_screen_header_selectors.dart';
part 'calculator_screen_toolbars_basic.dart';
part 'calculator_screen_toolbars_advanced.dart';
part 'calculator_screen_solvers_basic.dart';
part 'calculator_screen_solvers_advanced.dart';
part 'calculator_screen_mode_cells.dart';
part 'calculator_screen_dpad.dart';
part 'calculator_screen_dpad_vertical.dart';
part 'calculator_screen_cell_fraction.dart';
part 'calculator_screen_statement.dart';
part 'calculator_screen_history.dart';
part 'calculator_screen_mode_reset.dart';
part 'calculator_screen_keypress_helpers.dart';
part 'calculator_screen_keypress_control.dart';
part 'calculator_screen_keypress_functions.dart';
part 'calculator_screen_keypress_ans.dart';
part 'calculator_screen_replay.dart';
part 'calculator_screen_classwiz.dart';
part 'calculator_screen_calc.dart';
part 'calculator_screen_memkeys.dart';
part 'calculator_screen_multistmt.dart';
part 'calculator_screen_keypress.dart';
part 'calculator_screen_m5.dart';
part 'calculator_screen_forms.dart';
part 'calculator_screen_chassis.dart';
part 'calculator_screen_chassis_lcd.dart';
part 'calculator_screen_views.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  void updateState(VoidCallback fn) => setState(fn);
  final StepEvaluator _evaluator = StepEvaluator();
  final ExpressionParser _parser = ExpressionParser();
  final CalculatorMemoryManager _memory = CalculatorMemoryManager();
  final ClassHistoryService _historyService = ClassHistoryService();
  bool _isShiftActive = false;
  bool _isAlphaActive = false;
  bool _showDecimalApprox = false;
  List<StepByStepResolution> _multiStmtResults = const [];
  int _multiStmtIndex = 0;
  final ClassWizState _cw = ClassWizState();
  bool _historySuppressed = false;
  LcdTheme _lcdTheme = LcdTheme.classic;
  bool get _isOledDark => _lcdTheme == LcdTheme.night;
  bool _isSoundMuted = KeyClickSound.isMuted;
  bool _isMenuOpen = false;
  bool _isPoweredOff = false;
  bool _isInsertMode = true;
  bool _isMemViewOpen = false;
  bool _menuPendingOne = false;
  Timer? _menuOneTimer;
  int _memCursor = 0;
  int _setupRow = 0;
  int _setupSubCursor = -1;
  NumberFormatMode? _setupDigitsFor;
  int _eqKind = 0; // tipo de ecuación elegido en la cabecera LCD (M2)
  LcdErrorKind? _lcdErrorKind;
  String _lcdErrorMessage = '';
  bool _isSetupOpen = false;
  AngleUnit _angleUnit = AngleUnit.deg;
  bool _isCalcPromptActive = false;
  String _calcExpressionRaw = '';
  String _calcValueRaw = '';
  int _menuCursorIndex = 0;
  List<ClassHistoryEntry> _historyEntries = [];
  int _sidePanelTabIndex = 0; // 0: Historial, 1: Desglose / Pizarra

  // Los 12 modos (3 paginas de 4) se listan en lcd/lcd_mode_menu.dart.
  int _calculatorMode = 1;

  // Estado Modo 1, Modo 4 Notables y Modo 6 Lineal (Expresión con cursor activo y Replay)
  // Arranca limpia en '0' como una Casio física recién encendida (PROHIBIDO presets)
  String _rawInput = '0';
  int _cursorPos = 1;
  int _replayIndex = -1;
  String _draftBeforeReplay = '0';

  // Estado Modo 2 (Ecuaciones libres 1.º y 2.º Grado con signo = central fijo)
  String _eqLeftRaw = '';
  int _eqLeftCursorPos = 0;
  String _eqRightRaw = '';
  int _eqRightCursorPos = 0;
  int _eqActiveSide = 0; // 0 = miembro izquierdo, 1 = miembro derecho

  // Estado Modo 3 (Sistemas Unificados: 2x2, 3x3 y 4x4)
  int _systemDim = 2; // 2, 3 o 4
  final List<String> _sysValues = ['', '', '', '', '', ''];
  final List<String> _sysLabels = ['a₁', 'b₁', 'c₁', 'a₂', 'b₂', 'c₂'];
  int _sysActiveIndex = 0;
  final List<String> _sys4Values = List<String>.filled(20, '');
  final List<String> _sys4Labels = [
    'a₁', 'b₁', 'c₁', 'd₁', 'e₁',
    'a₂', 'b₂', 'c₂', 'd₂', 'e₂',
    'a₃', 'b₃', 'c₃', 'd₃', 'e₃',
    'a₄', 'b₄', 'c₄', 'd₄', 'e₄',
  ];
  int _sys4ActiveIndex = 0;
  SystemResolutionMethod _systemMethod = SystemResolutionMethod.sustitucion;

  // Estado Modo 4 (Polinomios: Regla de Ruffini grado 2..6 o Identidades Notables)
  bool _polyIsNotableMode = false;
  final GlobalKey _lcdBoundsKey = GlobalKey();
  final Map<String, LcdDropdownController> _hdrCtrls = {};
  int _headerFocus = -1; // foco D-Pad en desplegables de cabecera LCD (-1 = ninguno)
  static const List<String> _allRuffiniLabels = [
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
  ];
  int _ruffiniDegree = 3;
  bool _isChoosingRuffiniDegree = false;
  List<String> _ruffiniValues = ['', '', '', ''];
  List<String> _ruffiniLabels = ['a', 'b', 'c', 'd'];
  int _ruffiniActiveIndex = 0;
  NotableIdentityType _identityType = NotableIdentityType.squareOfDiff;

  // Estado Modo 5 (Gráficas de Parábolas)
  final List<String> _graphValues = ['', '', ''];
  final List<String> _graphLabels = ['a', 'b', 'c'];
  int _graphActiveIndex = 0;
  int _graphKind = 0; // 0 = cuadratica, 1 = racional (px+q)/(rx+s)
  final List<String> _ratValues = ['', '', '', ''];
  final List<String> _ratLabels = ['p', 'q', 'r', 's'];
  bool _showGraphView = true;
  FunctionAnalysisResult? _currentGraphAnalysis;
  NotablePoint? _selectedGraphPoint;

  // Estado Modo 6 (Inecuaciones individuales: 1 = 1.º Grado, 2 = 2.º Grado, 3 = Valor Absoluto / Racional)
  int _ineqDegree = 1;
  InequalitySign _inequalitySign = InequalitySign.less;
  Inequality1DVisualData? _activeIneqVisualData;

  // Estado Modo 7 (Sistemas de Inecuaciones: 1D o 2D)
  int _ineqSysUnknowns = 1; // 1 = 1 Incóg. (x), 2 = 2 Incóg. (x, y)
  int _ineqSysRows = 2; // 2, 3 o 4 inecuaciones
  final List<String> _ineqSysRowInputs = ['', '', '', ''];
  final List<int> _ineqSysRowCursors = [0, 0, 0, 0];
  int _ineqSysActiveRow = 0;
  bool _show2DRegionView = true;
  FeasibleRegion2DVisualData? _currentFeasibleRegion;

  // Estado Modo 8 (Estadística 1-Var: tabla xi | fi)
  List<({String xi, String fi})> _statRows = [(xi: '', fi: '')];
  int _statActiveRow = 0;
  int _statActiveCol = 0; // 0 = x_i, 1 = f_i

  // Estado Modo 9 (Matrices: libre m x n)
  int _matrixDim = 3;
  int _matrixRowsA = 3;
  int _matrixColsA = 3;
  int _matrixRowsB = 3;
  int _matrixColsB = 3;
  int _matrixActiveTarget = 0; // 0 = MatA, 1 = MatB, 2 = escalar k
  MatrixOperation _matrixOp = MatrixOperation.determinant;
  final List<String> _matrixCellsA = List<String>.filled(25, '');
  final List<String> _matrixCellsB = List<String>.filled(25, '');
  String _matrixScalarK = '';
  int _matrixActiveRow = 0;
  int _matrixActiveCol = 0;

  // Estado Modo 3 - Sistemas Lineales 3x3 (Gauss / Cramer)
  final List<String> _sys3Values = List<String>.filled(12, '');
  final List<String> _sys3Labels = [
    'a₁', 'b₁', 'c₁', 'd₁',
    'a₂', 'b₂', 'c₂', 'd₂',
    'a₃', 'b₃', 'c₃', 'd₃',
  ];
  int _sys3ActiveIndex = 0;

  // Estado Modo 9 (Vectores 2D / 3D: Módulo, u·v, u×v)
  int _vectorDim = 3; // 2 o 3
  VectorOperation _vectorOp = VectorOperation.dotAndAngle;
  final List<String> _vecUCells = List<String>.filled(3, '');
  final List<String> _vecVCells = List<String>.filled(3, '');
  final List<String> _vecWCells = List<String>.filled(3, '');
  int _vectorActiveRow = 0; // 0 = u, 1 = v, 2 = w
  int _vectorActiveCol = 0; // 0 = x, 1 = y, 2 = z

  // Estado Modo 10 (Números Complejos: Binómica ⬄ Polar)
  ComplexOperation _complexOp = ComplexOperation.add;
  final List<String> _complexCells = List<String>.filled(4, '');
  int _complexActiveIndex = 0;

  // Estado Modo 12 (Derivadas, Tangente e Integrales por Barrow)
  CalculusOperation _calculusOp = CalculusOperation.derivative;
  String _calculusExprRaw = '';
  int _calculusCursorPos = 0;
  String _calculusX0Raw = '';
  String _calculusLimitARaw = '';
  String _calculusLimitBRaw = '';
  int _calculusActiveField = 0; // 0 = f(x), 1 = x0 o a, 2 = b

  // Resolución paso a paso activa
  StepByStepResolution? _activeResolution;
  int _activeStepIndex = 0;

  @override

  void initState() {
    super.initState();
    _loadHistoryFromStorage();
    // Arranca limpia en 0, sin evaluar resoluciones precargadas
  }

  @override
  void dispose() {
    _menuOneTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showLiveCursor =
        !_isMenuOpen &&
        _activeResolution == null &&
        _supportsExpressionInput;
    final String liveLatex;
    if (_calculatorMode == 2) {
      final String leftTex = _eqLeftRaw.isEmpty
          ? (showLiveCursor && _eqActiveSide == 0
              ? r'\textcolor{#1A2530}{\blacksquare}'
              : r'\square')
          : ExpressionParser.rawToLiveLatex(
              _eqLeftRaw,
              cursorPos: (showLiveCursor && _eqActiveSide == 0)
                  ? _eqLeftCursorPos
                  : null,
            );
      final String rightTex = _eqRightRaw.isEmpty
          ? (showLiveCursor && _eqActiveSide == 1
              ? r'\textcolor{#1A2530}{\blacksquare}'
              : r'\square')
          : ExpressionParser.rawToLiveLatex(
              _eqRightRaw,
              cursorPos: (showLiveCursor && _eqActiveSide == 1)
                  ? _eqRightCursorPos
                  : null,
            );
      liveLatex = '$leftTex = $rightTex';
    } else if (_calculatorMode == 5 && _m5Custom && !_m5FormActive) {
      liveLatex = _m5FreeLatex(showLiveCursor);
    } else if (_calculatorMode == 1 ||
        (_calculatorMode == 4 && _polyIsNotableMode) ||
        _calculatorMode == 6) {
      liveLatex = ExpressionParser.rawToLiveLatex(
        _rawInput,
        cursorPos: showLiveCursor ? _cursorPos : null,
        overwrite: !_isInsertMode,
      );
    } else {
      liveLatex = _rawInput;
    }

    final modeLabel = _modeLabelText();

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        toolbarHeight: 46,
        titleSpacing: 12,
        backgroundColor: const Color(0xFF141619),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SolarPanel(),
              const SizedBox(width: 10),
              Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'STEP-BY-STEP LD',
                style: TextStyle(
                  color: Color(0xFFF1F5F9),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'NATURAL-V.P.A.M. // STEP ENGINE',
                style: TextStyle(
                  color: Color(0xFFE5A93C),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  fontSize: 8.5,
                ),
              ),
            ],
          ),
            ],
          ),
        ),
        actions: [
          HeaderBezelButton(
            key: const Key('appbar_export_png'),
            label: 'PNG',
            tooltip: 'EXPORTAR PNG',
            accentColor: const Color(0xFF94A3B8),
            onPressed: _openStickerExport,
          ),
          const SizedBox(width: 6),
          HeaderBezelButton(
            key: const Key('appbar_copy_latex'),
            label: 'TEX',
            tooltip: 'COPIAR LaTeX',
            accentColor: const Color(0xFF94A3B8),
            onPressed: _copyLatexToClipboardShortcut,
          ),
          const SizedBox(width: 6),
          HeaderBezelButton(
            key: const Key('appbar_history'),
            label: 'HIST',
            tooltip: 'HISTORIAL',
            accentColor: const Color(0xFFE5A93C),
            onPressed: _openHistorySheet,
          ),
          const SizedBox(width: 10),
        ],
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final orientation = MediaQuery.of(context).orientation;
            final bool isLandscape = constraints.maxWidth >= 560 &&
                (orientation == Orientation.landscape || constraints.maxWidth > constraints.maxHeight);
            final bool isWideDesktop = constraints.maxWidth >= 760;

            if (!isLandscape && !isWideDesktop) {
              // Modo Compacto / Móvil (< 760 px y portrait): chasis centrado hasta 430 px ocupando el alto
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: _buildCalculatorChassis(
                      liveLatex: liveLatex,
                      modeLabel: modeLabel,
                    ),
                  ),
                ),
              );
            }

            // Modo Expandido / Horizontal (>= 760 px o Landscape)
            // Divide la pantalla en 2 columnas equilibradas:
            // Izquierda (~60-62%): calculadora completa adaptada al alto disponible
            // Derecha (~38%): WindowsSidePanel con historial en vivo y pasos
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWideDesktop ? 1120 : double.infinity),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Columna Izquierda (~60-62%)
                      Expanded(
                        flex: 62,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: _buildCalculatorChassis(
                            liveLatex: liveLatex,
                            modeLabel: modeLabel,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Columna Derecha (~38%)
                      Expanded(
                        flex: 38,
                        child: WindowsSidePanel(
                          activeTabIndex: _sidePanelTabIndex,
                          onTabChanged: (index) {
                            updateState(() {
                              _sidePanelTabIndex = index;
                            });
                          },
                          historyEntries: _historyEntries,
                          historyService: _historyService,
                          onSelectHistoryEntry: _selectHistoryEntry,
                          onToggleFavorite: _toggleFavoriteInHistory,
                          onDeleteHistoryEntry: _deleteEntryFromHistory,
                          activeResolution: _activeResolution,
                          activeStepIndex: _activeStepIndex,
                          onSelectStep: (stepIdx) {
                            updateState(() {
                              _activeStepIndex = stepIdx;
                            });
                          },
                          graphAnalysis:
                              _calculatorMode == 5 ? _currentGraphAnalysis : null,
                          onExportSticker: _openStickerExport,
                          onCopyLatex: _copyLatexToClipboardShortcut,
                          onOpenAiTutor: _openAiTutor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

}
