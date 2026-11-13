import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/math_engine/core/calculator_memory.dart';
import '../../domain/math_engine/core/rational.dart';
import '../../domain/math_engine/models/step_resolution.dart';
import '../../domain/math_engine/parser/expression_parser.dart';
import '../../domain/math_engine/solvers/calc_solver.dart';
import '../../domain/math_engine/solvers/calculus_solver.dart';
import '../../domain/math_engine/solvers/complex_solver.dart';
import '../../domain/math_engine/solvers/function_graph_solver.dart';
import '../../domain/math_engine/solvers/inequality_solver.dart';
import '../../domain/math_engine/solvers/linear_system_solver.dart';
import '../../domain/math_engine/solvers/matrix_solver.dart';
import '../../domain/math_engine/solvers/notable_identities_solver.dart';
import '../../domain/math_engine/solvers/polynomial_equation_solver.dart';
import '../../domain/math_engine/solvers/radical_and_factor_solver.dart';
import '../../domain/math_engine/solvers/ruffini_solver.dart';
import '../../domain/math_engine/solvers/statistics_solver.dart';
import '../../domain/math_engine/solvers/step_evaluator.dart';
import '../../domain/math_engine/solvers/system_3x3_solver.dart';
import '../../domain/math_engine/solvers/trig_and_angles_solver.dart';
import '../../domain/math_engine/solvers/vector_solver.dart';
import '../../domain/services/class_history_service.dart';
import '../utils/goodnotes_exporter.dart';
import '../utils/key_click_sound.dart';
import '../widgets/ai_tutor_sheet.dart';
import '../widgets/casio_calculus_editor_view.dart';
import '../widgets/casio_coefficient_view.dart';
import '../widgets/casio_complex_editor_view.dart';
import '../widgets/casio_dpad.dart';
import '../widgets/casio_graph_canvas.dart';
import '../widgets/casio_lcd_screen.dart';
import '../widgets/casio_matrix_editor_view.dart';
import '../widgets/casio_physical_key.dart';
import '../widgets/casio_stat_table_view.dart';
import '../widgets/casio_vector_editor_view.dart';
import '../widgets/class_history_sheet.dart';
import '../widgets/windows_side_panel.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final StepEvaluator _evaluator = StepEvaluator();
  final ExpressionParser _parser = ExpressionParser();
  final CalculatorMemoryManager _memory = CalculatorMemoryManager();
  final ClassHistoryService _historyService = ClassHistoryService();

  bool _isShiftActive = false;
  bool _isAlphaActive = false;
  bool _showDecimalApprox = false;
  bool _isOledDark = false;
  bool _isSoundMuted = KeyClickSound.isMuted;
  bool _isMenuOpen = false;
  bool _isSetupOpen = false;
  AngleUnit _angleUnit = AngleUnit.deg;
  bool _isCalcPromptActive = false;
  String _calcExpressionRaw = '';
  String _calcValueRaw = '';
  int _menuCursorIndex = 0;
  List<ClassHistoryEntry> _historyEntries = [];
  int _sidePanelTabIndex = 0; // 0: Historial, 1: Desglose / Pizarra

  // Modos de la Calculadora (Paginados 2x2 en 3 páginas del MENU):
  // 1: Cálculo simbólico, raíces, trigonometría, logaritmos y FACT
  // 2: Ecuaciones unificadas (1.º y 2.º grado libres con = central fijo)
  // 3: Sistemas de ecuaciones (2x2 y 3x3 unificados)
  // 4: Polinomios (Regla de Ruffini grado 2..6 e Identidades Notables)
  // 5: Estudio Analítico y Gráfica de Funciones (Parábolas)
  // 6: Inecuaciones de 1.º y 2.º Grado (<, ≤, >, ≥) con tabla de signos
  // 7: Estadística 1-Variable (tabla xi, fi editable)
  // 8: Matrices 2x2 y 3x3 (Sarrus, Inversa, Adjunta, A·B, A+B)
  // 9: Vectores 2D / 3D (Módulo, u·v, ángulo, u×v)
  // 10: Números Complejos (Binómica ⬄ Polar)
  // 11: Derivadas, Tangente e Integrales Definidas (Regla de Barrow)
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

  // Estado Modo 3 (Sistemas Unificados: 2x2 y 3x3)
  int _systemDim = 2; // 2 o 3
  final List<String> _sysValues = ['', '', '', '', '', ''];
  final List<String> _sysLabels = ['a₁', 'b₁', 'c₁', 'a₂', 'b₂', 'c₂'];
  int _sysActiveIndex = 0;
  SystemResolutionMethod _systemMethod = SystemResolutionMethod.sustitucion;

  // Estado Modo 4 (Polinomios: Regla de Ruffini grado 2..6 o Identidades Notables)
  bool _polyIsNotableMode = false;
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
  bool _showGraphView = true;
  FunctionAnalysisResult? _currentGraphAnalysis;
  NotablePoint? _selectedGraphPoint;

  // Estado Modo 6 (Inecuaciones 1.º y 2.º Grado)
  int _ineqDegree = 1; // 1 = expresión lineal, 2 = plantilla cuadrática
  InequalitySign _inequalitySign = InequalitySign.less;
  final List<String> _ineqQuadValues = ['', '', ''];
  final List<String> _ineqQuadLabels = ['a', 'b', 'c'];
  int _ineqQuadActiveIndex = 0; // 0..2 coeficientes, 3 selector de signo

  // Estado Modo 7 (Estadística 1-Var: tabla xi | fi)
  List<({String xi, String fi})> _statRows = [(xi: '', fi: '')];
  int _statActiveRow = 0;
  int _statActiveCol = 0; // 0 = x_i, 1 = f_i

  // Estado Modo 8 (Matrices 2x2 / 3x3)
  int _matrixDim = 3; // 2 o 3
  int _matrixActiveTarget = 0; // 0 = MatA, 1 = MatB, 2 = escalar k
  MatrixOperation _matrixOp = MatrixOperation.determinant;
  final List<String> _matrixCellsA = List<String>.filled(9, '');
  final List<String> _matrixCellsB = List<String>.filled(9, '');
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
  System3x3Method _sys3Method = System3x3Method.gauss;

  // Estado Modo 9 (Vectores 2D / 3D: Módulo, u·v, u×v)
  int _vectorDim = 3; // 2 o 3
  VectorOperation _vectorOp = VectorOperation.dotAndAngle;
  final List<String> _vecUCells = List<String>.filled(3, '');
  final List<String> _vecVCells = List<String>.filled(3, '');
  int _vectorActiveRow = 0; // 0 = u, 1 = v
  int _vectorActiveCol = 0; // 0 = x, 1 = y, 2 = z

  // Estado Modo 10 (Números Complejos: Binómica ⬄ Polar)
  ComplexOperation _complexOp = ComplexOperation.add;
  final List<String> _complexCells = List<String>.filled(4, '');
  int _complexActiveIndex = 0;

  // Estado Modo 11 (Derivadas, Tangente e Integrales por Barrow)
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

  Future<void> _loadHistoryFromStorage() async {
    try {
      final entries = await _historyService.getEntries();
      if (mounted) {
        setState(() {
          _historyEntries = entries;
        });
      }
    } catch (_) {
      // Resiliente en entornos sin plugin nativo inicializado
    }
  }

  bool get _isCoefficientMode =>
      _calculatorMode == 3 ||
      (_calculatorMode == 4 &&
          !_polyIsNotableMode &&
          !_isChoosingRuffiniDegree) ||
      _calculatorMode == 5 ||
      (_calculatorMode == 6 && _ineqDegree == 2);

  /// Modos con celdas estructuradas donde solo entran tokens numéricos (`0-9`, `-`, `/`, `.`).
  bool get _isGridOrStructuredMode =>
      _calculatorMode == 7 ||
      _calculatorMode == 8 ||
      _calculatorMode == 9 ||
      _calculatorMode == 10 ||
      (_calculatorMode == 11 && _calculusActiveField != 0);

  /// Verdadero cuando el cursor activo edita una expresión simbólica (`f(x)`, Modo 1, 2, 4 Notables, 6 lineal).
  bool get _supportsExpressionInput =>
      !_isCoefficientMode && !_isGridOrStructuredMode;

  /// Verdadero solo en modos de expresión general con funciones científicas (`sin`, `log`, `√`, `mcm`).
  bool get _supportsScientificFns =>
      _supportsExpressionInput && _calculatorMode != 11;

  List<String> get _currentCellValues {
    switch (_calculatorMode) {
      case 3:
        return _systemDim == 3 ? _sys3Values : _sysValues;
      case 4:
        return _ruffiniValues;
      case 5:
        return _graphValues;
      case 6:
        return _ineqDegree == 2 ? _ineqQuadValues : [];
      default:
        return [];
    }
  }

  List<String> get _currentCellLabels {
    switch (_calculatorMode) {
      case 3:
        return _systemDim == 3 ? _sys3Labels : _sysLabels;
      case 4:
        return _ruffiniLabels;
      case 5:
        return _graphLabels;
      case 6:
        return _ineqDegree == 2 ? _ineqQuadLabels : [];
      default:
        return [];
    }
  }

  int get _currentActiveIndex {
    switch (_calculatorMode) {
      case 3:
        return _systemDim == 3 ? _sys3ActiveIndex : _sysActiveIndex;
      case 4:
        return _ruffiniActiveIndex;
      case 5:
        return _graphActiveIndex;
      case 6:
        return _ineqQuadActiveIndex;
      default:
        return 0;
    }
  }

  set _currentActiveIndex(int val) {
    switch (_calculatorMode) {
      case 3:
        if (_systemDim == 3) {
          _sys3ActiveIndex = val;
        } else {
          _sysActiveIndex = val;
        }
        break;
      case 4:
        _ruffiniActiveIndex = val;
        break;
      case 5:
        _graphActiveIndex = val;
        break;
      case 6:
        _ineqQuadActiveIndex = val;
        break;
    }
  }

  String _getStudentTagForMode(int mode) {
    switch (mode) {
      case 1:
        return '1.º-2.º ESO';
      case 2:
        return '2.º-4.º ESO';
      case 3:
        return '3.º ESO-Bach.';
      case 4:
        return '3.º-4.º ESO';
      case 5:
        return '3.º-4.º ESO';
      case 6:
        return '4.º ESO-Bach.';
      case 7:
        return '2.º-4.º ESO';
      case 8:
      case 9:
      case 10:
      case 11:
        return '1.º-2.º Bach. / EBAU';
      default:
        return 'General';
    }
  }

  void _recordCurrentResolutionToHistory(
      StepByStepResolution res, String modeName) {
    final String? savedRawExpr;
    if (_calculatorMode == 2) {
      savedRawExpr = '${_eqLeftRaw.trim()} = ${_eqRightRaw.trim()}';
    } else if (_isCoefficientMode ||
        _calculatorMode == 7 ||
        _calculatorMode == 8 ||
        _calculatorMode == 9 ||
        _calculatorMode == 10) {
      savedRawExpr = null;
    } else if (_calculatorMode == 11) {
      savedRawExpr = _calculusExprRaw;
    } else {
      savedRawExpr = _rawInput;
    }

    final entry = ClassHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      modeName: modeName,
      studentTag: _getStudentTagForMode(_calculatorMode),
      resolution: res,
      rawExpression: savedRawExpr,
      calculatorMode: _calculatorMode,
    );

    final isRecentDup = _historyEntries.isNotEmpty &&
        _historyEntries.first.resolution.originalInputLatex ==
            res.originalInputLatex &&
        _historyEntries.first.modeName == modeName &&
        DateTime.now().difference(_historyEntries.first.timestamp).inSeconds < 3;

    if (!isRecentDup) {
      setState(() {
        _historyEntries = [
          entry,
          ..._historyEntries.take(ClassHistoryService.maxStoredEntries - 1),
        ];
      });
    }

    _persistHistoryEntry(entry);
  }

  Future<void> _persistHistoryEntry(ClassHistoryEntry entry) async {
    try {
      await _historyService.addEntry(entry);
      await _loadHistoryFromStorage();
    } catch (_) {}
  }

  String _entryToEditableRaw(ClassHistoryEntry entry) {
    if (entry.rawExpression != null && entry.rawExpression!.isNotEmpty) {
      return entry.rawExpression!;
    }
    return _latexToEditableRaw(entry.resolution.originalInputLatex);
  }

  String _latexToEditableRaw(String latex) {
    String out = latex
        .replaceAll(r'\cdot', '*')
        .replaceAll(r'\times', '*')
        .replaceAll(' ', '');
    out = out.replaceAllMapped(
      RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'),
      (m) => '${m[1]}/${m[2]}',
    );
    out = out.replaceAllMapped(
      RegExp(r'\\sqrt\[3\]\{([^}]+)\}'),
      (m) => '³√(${m[1]})',
    );
    out = out.replaceAllMapped(
      RegExp(r'\\sqrt\{([^}]+)\}'),
      (m) => '√(${m[1]})',
    );
    return out.isEmpty ? '0' : out;
  }

  void _selectModeFromMenu(int mode) {
    if (mode >= 1 && mode <= 11) {
      setState(() {
        _isMenuOpen = false;
        _resetFieldsForMode(mode);
      });
    }
  }

  void _setRuffiniDegree(int degree, {required bool enterTemplate}) {
    final safeDegree = degree.clamp(2, 6);
    _ruffiniDegree = safeDegree;
    _ruffiniValues = List<String>.filled(safeDegree + 1, '');
    _ruffiniLabels = _allRuffiniLabels.sublist(0, safeDegree + 1);
    _ruffiniActiveIndex = 0;
    _isChoosingRuffiniDegree = !enterTemplate;
    _activeResolution = null;
    _activeStepIndex = 0;
  }

  void _resetFieldsForMode(int mode) {
    _calculatorMode = mode;
    _activeStepIndex = 0;
    _showDecimalApprox = false;
    _isShiftActive = false;
    _isAlphaActive = false;
    _activeResolution = null;
    _replayIndex = -1;
    _isMenuOpen = false;
    _isSetupOpen = false;
    _isCalcPromptActive = false;
    _calcExpressionRaw = '';
    _calcValueRaw = '';

    // Al cambiar de modo, arranca 100 % limpio como en una Casio real
    _rawInput = '0';
    _cursorPos = 1;
    _draftBeforeReplay = '0';

    _eqLeftRaw = '';
    _eqLeftCursorPos = 0;
    _eqRightRaw = '';
    _eqRightCursorPos = 0;
    _eqActiveSide = 0;

    _systemDim = 2;
    for (int i = 0; i < _sysValues.length; i++) {
      _sysValues[i] = '';
    }
    _sysActiveIndex = 0;

    _polyIsNotableMode = false;
    _setRuffiniDegree(3, enterTemplate: mode != 4);

    for (int i = 0; i < _graphValues.length; i++) {
      _graphValues[i] = '';
    }
    _graphActiveIndex = 0;
    _currentGraphAnalysis = null;
    _selectedGraphPoint = null;
    _showGraphView = true;

    _ineqDegree = 1;
    _inequalitySign = InequalitySign.less;
    for (int i = 0; i < _ineqQuadValues.length; i++) {
      _ineqQuadValues[i] = '';
    }
    _ineqQuadActiveIndex = 0;

    _statRows = [(xi: '', fi: '')];
    _statActiveRow = 0;
    _statActiveCol = 0;

    _matrixDim = 3;
    _matrixActiveTarget = 0;
    _matrixOp = MatrixOperation.determinant;
    for (int i = 0; i < _matrixCellsA.length; i++) {
      _matrixCellsA[i] = '';
      _matrixCellsB[i] = '';
    }
    _matrixScalarK = '';
    _matrixActiveRow = 0;
    _matrixActiveCol = 0;

    for (int i = 0; i < _sys3Values.length; i++) {
      _sys3Values[i] = '';
    }
    _sys3ActiveIndex = 0;

    _vectorDim = 3;
    _vectorOp = VectorOperation.dotAndAngle;
    for (int i = 0; i < _vecUCells.length; i++) {
      _vecUCells[i] = '';
      _vecVCells[i] = '';
    }
    _vectorActiveRow = 0;
    _vectorActiveCol = 0;

    _complexOp = ComplexOperation.add;
    for (int i = 0; i < _complexCells.length; i++) {
      _complexCells[i] = '';
    }
    _complexActiveIndex = 0;

    _calculusOp = CalculusOperation.derivative;
    _calculusExprRaw = '';
    _calculusCursorPos = 0;
    _calculusX0Raw = '';
    _calculusLimitARaw = '';
    _calculusLimitBRaw = '';
    _calculusActiveField = 0;
  }

  void _handleFactorize() {
    setState(() {
      _isShiftActive = false;
      _isAlphaActive = false;
    });

    int? n = int.tryParse(_rawInput.trim());
    if (n == null && _activeResolution != null) {
      n = int.tryParse(_activeResolution!.exactResultLatex.trim());
    }

    if (n != null && n > 0) {
      setState(() {
        _activeResolution = RadicalAndFactorSolver.factorize(n!);
        _activeStepIndex = 0;
        _showDecimalApprox = false;
      });
      _recordCurrentResolutionToHistory(_activeResolution!, 'M1: FACT');
      return;
    }

    try {
      final ast = _parser.parse(_rawInput);
      final res = _evaluator.evaluate(ast);
      final parsedNum = int.tryParse(res.exactResultLatex);
      if (parsedNum != null && parsedNum > 0) {
        setState(() {
          _activeResolution = RadicalAndFactorSolver.factorize(parsedNum);
          _activeStepIndex = 0;
          _showDecimalApprox = false;
        });
        _recordCurrentResolutionToHistory(_activeResolution!, 'M1: FACT');
        return;
      }
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Escribe un número entero positivo (ej: 360) para descomponer con FACT.',
        ),
        backgroundColor: Color(0xFFD97706),
        duration: Duration(seconds: 2),
      ),
    );
  }

  int _parseCoeffValue(String raw, {int defaultValue = 0}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') return defaultValue;
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length == 2) {
        final n = double.tryParse(parts[0]);
        final d = double.tryParse(parts[1]);
        if (n != null && d != null && d != 0) {
          return (n / d).round();
        }
      }
    }
    final d = double.tryParse(trimmed);
    if (d != null) return d.round();
    return defaultValue;
  }

  void _solveCurrentMode() {
    setState(() {
      _isShiftActive = false;
      _isAlphaActive = false;
      _showDecimalApprox = false;
      _activeStepIndex = 0;
    });

    if (_calculatorMode == 1) {
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
        setState(() {
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

    if (_calculatorMode == 2) {
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
        setState(() {
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

    if (_calculatorMode == 3) {
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
          final res = System3x3Solver.solve(
            augmentedRows: augmentedRows,
            method: _sys3Method,
          );
          setState(() {
            _activeResolution = res;
          });
          _recordCurrentResolutionToHistory(
            res,
            'M3: Sist. 3x3 (${_sys3Method.displayName})',
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
      setState(() {
        _activeResolution = res;
      });
      _recordCurrentResolutionToHistory(res, 'M3: Sistemas 2x2');
      return;
    }

    if (_calculatorMode == 4) {
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
          setState(() {
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
        setState(() {
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
      setState(() {
        _activeResolution = res;
      });
      _recordCurrentResolutionToHistory(
        res,
        'M4: Regla de Ruffini ($_ruffiniDegree.º)',
      );
      return;
    }

    if (_calculatorMode == 5) {
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
      setState(() {
        _currentGraphAnalysis = analysis;
        _activeResolution = analysis.resolution;
        _selectedGraphPoint = analysis.notablePoints.firstOrNull;
      });
      _recordCurrentResolutionToHistory(analysis.resolution, 'M5: Gráficas');
      return;
    }

    if (_calculatorMode == 6) {
      if (_ineqDegree == 1) {
        final trimmed = _rawInput.trim();
        if (trimmed.isEmpty || trimmed == '0') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Escribe una inecuación (ej: -2x + 4 < 10).'),
              backgroundColor: Color(0xFFB91C1C),
            ),
          );
          return;
        }
        try {
          final res = InequalitySolver.solveString(
            _rawInput,
            fallbackSign: _inequalitySign,
          );
          setState(() {
            _activeResolution = res;
          });
          _recordCurrentResolutionToHistory(res, 'M6: Inecuaciones');
        } on FormatException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error en inecuación: ${e.message}'),
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
      } else {
        final a = _parseCoeffValue(_ineqQuadValues[0], defaultValue: 1);
        final b = _parseCoeffValue(_ineqQuadValues[1], defaultValue: 0);
        final c = _parseCoeffValue(_ineqQuadValues[2], defaultValue: 0);
        final res = InequalitySolver.solveQuadratic(
          a: a,
          b: b,
          c: c,
          sign: _inequalitySign,
        );
        setState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(res, 'M6: Inecuaciones 2.º Grado');
        return;
      }
    }

    if (_calculatorMode == 7) {
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
        setState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(res, 'M7: Estadística 1-Var');
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
            content: Text('Error en Estadística: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
      return;
    }

    if (_calculatorMode == 8) {
      try {
        final matA = _buildRationalMatrixFromCells(_matrixCellsA, _matrixDim);
        final matB = _matrixOp.needsMatrixB
            ? _buildRationalMatrixFromCells(_matrixCellsB, _matrixDim)
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
        setState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(
          res,
          'M8: Matrices (${_matrixOp.shortLabel})',
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
            content: Text('Error en Matrices: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
      return;
    }

    if (_calculatorMode == 9) {
      try {
        final u = _buildRationalVectorFromCells(_vecUCells, _vectorDim);
        final v = _vectorOp.needsSecondVector
            ? _buildRationalVectorFromCells(_vecVCells, _vectorDim)
            : null;
        final res = VectorSolver.solve(
          operation: _vectorOp,
          u: u,
          v: v,
        );
        setState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(
          res,
          'M9: Vectores (${_vectorOp.shortLabel})',
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
            content: Text('Error en Vectores: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
      return;
    }

    if (_calculatorMode == 10) {
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
        setState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(
          res,
          'M10: Complejos (${_complexOp.shortLabel})',
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
            content: Text('Error en Complejos: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
      return;
    }

    if (_calculatorMode == 11) {
      try {
        final expr = _calculusExprRaw.trim().isEmpty ? '0' : _calculusExprRaw.trim();
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
        setState(() {
          _activeResolution = res;
        });
        _recordCurrentResolutionToHistory(
          res,
          'M11: Cálculo (${_calculusOp.shortLabel})',
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
            content: Text('Error en Cálculo: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
      return;
    }
  }

  RationalVector _buildRationalVectorFromCells(List<String> cells, int dim) {
    return RationalVector.fromRationals(
      List.generate(dim, (i) {
        return _parseRationalCell(cells[i], defaultValue: Rational(0));
      }),
    );
  }

  RationalMatrix _buildRationalMatrixFromCells(List<String> cells, int dim) {
    return RationalMatrix.fromRationals(
      List.generate(dim, (r) {
        return List.generate(dim, (c) {
          return _parseRationalCell(
            cells[r * 3 + c],
            defaultValue: Rational(0),
          );
        });
      }),
    );
  }

  Rational _parseRationalCell(String raw, {Rational? defaultValue}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      if (defaultValue != null) return defaultValue;
      throw const FormatException('Celda numérica incompleta.');
    }
    return _parseStatRational(trimmed);
  }

  Rational _parseStatRational(String raw) {
    final s = raw.trim().replaceAll(',', '.');
    if (s.contains('/')) {
      final parts = s.split('/');
      if (parts.length == 2) {
        final n = int.tryParse(parts[0]);
        final d = int.tryParse(parts[1]);
        if (n != null && d != null && d != 0) {
          return Rational(n, d);
        }
      }
      throw FormatException('Fracción no válida: $raw');
    }
    if (s.contains('.')) {
      return Rational.fromDecimalString(s);
    }
    final parsed = int.tryParse(s);
    if (parsed == null) {
      throw FormatException('Valor xᵢ no válido: $raw');
    }
    return Rational(parsed);
  }

  void _setInequalitySign(InequalitySign sign, {bool insertIfMissing = true}) {
    _inequalitySign = sign;
    if (_calculatorMode == 6 && _ineqDegree == 1) {
      if (_activeResolution != null) {
        _activeResolution = null;
        _activeStepIndex = 0;
        _cursorPos = _rawInput.length;
      }
      final existing = RegExp(r'(<=|>=|[≤≥<>])');
      if (existing.hasMatch(_rawInput)) {
        _rawInput = _rawInput.replaceFirst(existing, sign.symbol);
        _cursorPos = _cursorPos.clamp(0, _rawInput.length);
      } else if (insertIfMissing && _rawInput != '0' && _rawInput.trim().isNotEmpty) {
        _applyRawInsertion(sign.symbol, keepLeadingZero: true);
      }
    } else if (_calculatorMode == 6 && _ineqDegree == 2 && _activeResolution != null) {
      _solveCurrentMode();
    }
  }

  void _cycleInequalitySign({bool backwards = false, bool insertIfMissing = false}) {
    const order = InequalitySign.values;
    final idx = order.indexOf(_inequalitySign);
    final nextIdx = backwards
        ? (idx - 1 + order.length) % order.length
        : (idx + 1) % order.length;
    _setInequalitySign(order[nextIdx], insertIfMissing: insertIfMissing);
  }

  void _clearActiveResolutionCursor() {
    _activeResolution = null;
    _activeStepIndex = 0;
    if (_calculatorMode == 2) {
      if (_eqActiveSide == 0) {
        _eqLeftCursorPos = _eqLeftRaw.length;
      } else {
        _eqRightCursorPos = _eqRightRaw.length;
      }
    } else if (_calculatorMode == 11 && _calculusActiveField == 0) {
      _calculusCursorPos = _calculusExprRaw.length;
    } else {
      _cursorPos = _rawInput.length;
    }
  }

  void _applyRawInsertion(String token, {bool keepLeadingZero = false}) {
    if (_calculatorMode == 2) {
      _replayIndex = -1;
      if (_eqActiveSide == 0) {
        final (nextRaw, nextPos) = ExpressionParser.insertAtCursor(
          _eqLeftRaw,
          _eqLeftCursorPos,
          token,
          keepLeadingZero: true,
        );
        _eqLeftRaw = nextRaw;
        _eqLeftCursorPos = nextPos;
      } else {
        final (nextRaw, nextPos) = ExpressionParser.insertAtCursor(
          _eqRightRaw,
          _eqRightCursorPos,
          token,
          keepLeadingZero: true,
        );
        _eqRightRaw = nextRaw;
        _eqRightCursorPos = nextPos;
      }
      return;
    }
    if (_calculatorMode == 11 && _calculusActiveField == 0) {
      final base = _calculusExprRaw.isEmpty ? '0' : _calculusExprRaw;
      final cur = _calculusExprRaw.isEmpty ? 1 : _calculusCursorPos;
      final (nextRaw, nextPos) = ExpressionParser.insertAtCursor(
        base,
        cur,
        token,
        keepLeadingZero: keepLeadingZero,
      );
      _calculusExprRaw = nextRaw;
      _calculusCursorPos = nextPos;
      return;
    }
    _replayIndex = -1;
    final (nextRaw, nextPos) = ExpressionParser.insertAtCursor(
      _rawInput,
      _cursorPos,
      token,
      keepLeadingZero: keepLeadingZero,
    );
    _rawInput = nextRaw;
    _cursorPos = nextPos;
  }

  void _insertVariableX() {
    setState(() {
      _isShiftActive = false;
      _isAlphaActive = false;
      if (_activeResolution != null) {
        _clearActiveResolutionCursor();
      }
      _applyRawInsertion('x');
    });
  }

  void _insertEqualsInEquation() {
    if (_calculatorMode == 2) {
      setState(() {
        _isShiftActive = false;
        _isAlphaActive = false;
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
        }
        _eqActiveSide = _eqActiveSide == 0 ? 1 : 0;
      });
      return;
    }
    if (_rawInput.contains('=') && _activeResolution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La ecuación ya contiene un signo =.'),
          backgroundColor: Color(0xFFB45309),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _isShiftActive = false;
      _isAlphaActive = false;
      if (_activeResolution != null) {
        _clearActiveResolutionCursor();
      }
      if (_rawInput.contains('=')) return;
      _applyRawInsertion('=', keepLeadingZero: true);
    });
  }

  void _restoreMode2EquationString(String rawEq) {
    final eqIdx = rawEq.indexOf('=');
    if (eqIdx >= 0) {
      _eqLeftRaw = rawEq.substring(0, eqIdx).trim();
      _eqRightRaw = rawEq.substring(eqIdx + 1).trim();
      _eqLeftCursorPos = _eqLeftRaw.length;
      _eqRightCursorPos = _eqRightRaw.length;
      _eqActiveSide = 1;
    } else {
      _eqLeftRaw = rawEq.trim();
      _eqLeftCursorPos = _eqLeftRaw.length;
      _eqRightRaw = '';
      _eqRightCursorPos = 0;
      _eqActiveSide = 0;
    }
  }

  void _cycleHistoryReplayUp() {
    if (_historyEntries.isEmpty) return;
    if (_replayIndex == -1) {
      _draftBeforeReplay = _calculatorMode == 2
          ? '$_eqLeftRaw = $_eqRightRaw'
          : _rawInput;
      _replayIndex = 0;
    } else if (_replayIndex < _historyEntries.length - 1) {
      _replayIndex++;
    } else {
      return;
    }
    final restored = _entryToEditableRaw(_historyEntries[_replayIndex]);
    if (_calculatorMode == 2) {
      _restoreMode2EquationString(restored);
    } else {
      _rawInput = restored;
      _cursorPos = _rawInput.length;
    }
  }

  void _cycleHistoryReplayDown() {
    if (_replayIndex < 0) return;
    if (_replayIndex > 0) {
      _replayIndex--;
      final restored = _entryToEditableRaw(_historyEntries[_replayIndex]);
      if (_calculatorMode == 2) {
        _restoreMode2EquationString(restored);
      } else {
        _rawInput = restored;
        _cursorPos = _rawInput.length;
      }
    } else {
      _replayIndex = -1;
      if (_calculatorMode == 2) {
        _restoreMode2EquationString(_draftBeforeReplay);
      } else {
        _rawInput = _draftBeforeReplay.isEmpty ? '0' : _draftBeforeReplay;
        _cursorPos = _rawInput.length;
      }
    }
  }

  void _toggleAngleUnit() {
    setState(() {
      _angleUnit = _angleUnit == AngleUnit.deg ? AngleUnit.rad : AngleUnit.deg;
      _isShiftActive = false;
      _isAlphaActive = false;
    });
  }

  void _handleSetupOption(int option) {
    setState(() {
      if (option == 1) {
        _angleUnit = AngleUnit.deg;
      } else if (option == 2) {
        _angleUnit = AngleUnit.rad;
      } else if (option == 3) {
        _isOledDark = !_isOledDark;
      }
      _isSetupOpen = false;
      _isShiftActive = false;
      _isAlphaActive = false;
    });
  }

  void _enterCalcPromptSync() {
    if (_calculatorMode != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La tecla CALC evalúa expresiones con x en el Modo 1 (Cálculo).'),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final candidate = ExpressionParser.finalizeForEvaluation(_rawInput);
    if (candidate == '0' || !RegExp(r'[A-Za-z]').hasMatch(candidate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe primero una expresión con la variable x (ej: -x^2 - 2x) antes de pulsar CALC.'),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _activeResolution = null;
    _activeStepIndex = 0;
    _showDecimalApprox = false;
    _isShiftActive = false;
    _isAlphaActive = false;
    _calcExpressionRaw = candidate;
    _calcValueRaw = '';
    _isCalcPromptActive = true;
  }

  void _submitCalcEvalSync() {
    final valRaw = _calcValueRaw.trim().isEmpty ? '0' : _calcValueRaw.trim();
    Rational? parsedX;
    try {
      if (valRaw.contains('/')) {
        final parts = valRaw.split('/');
        if (parts.length == 2) {
          parsedX = Rational(int.parse(parts[0]), int.parse(parts[1]));
        }
      } else if (valRaw.contains('.')) {
        parsedX = Rational.fromDecimalString(valRaw);
      } else {
        parsedX = Rational(int.parse(valRaw));
      }
    } catch (_) {
      parsedX = null;
    }
    if (parsedX == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce un número válido para x (ej: -3 o 1/2).'),
          backgroundColor: Color(0xFFB91C1C),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final ast = _parser.parse(_calcExpressionRaw);
      final res = CalcSolver.evaluateCalc(
        expr: ast,
        xValue: parsedX,
        memoryVars: _memory.getAllVariablesWithAns(),
      );
      _memory.setAns(parsedX);
      _isCalcPromptActive = false;
      _rawInput = _calcExpressionRaw;
      _cursorPos = _rawInput.length;
      _activeResolution = res;
      _activeStepIndex = 0;
      _showDecimalApprox = false;
      _recordCurrentResolutionToHistory(res, 'M1: CALC');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo evaluar la expresión: $e'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    }
  }

  void _insertDmsSymbolSync() {
    if (_activeResolution != null && _evaluator.lastEvaluatedRational != null && !_isCoefficientMode) {
      final decVal = _evaluator.lastEvaluatedRational!.toDouble();
      final res = TrigAndAnglesSolver.solveDecimalToDms(
        decVal,
        originalLatex: _evaluator.lastEvaluatedRational!.toDecimalLatex(),
      );
      _activeResolution = res;
      _activeStepIndex = 0;
      _showDecimalApprox = false;
      return;
    }
    if (_isCoefficientMode) return;
    if (_activeResolution != null) {
      _activeResolution = null;
      _activeStepIndex = 0;
      _cursorPos = _rawInput.length;
    }
    final safePos = _cursorPos.clamp(0, _rawInput.length);
    final before = _rawInput.substring(0, safePos);
    int termStart = 0;
    for (int i = before.length - 1; i >= 0; i--) {
      if ('+-*:=(,'.contains(before[i])) {
        termStart = i + 1;
        break;
      }
    }
    final slice = before.substring(termStart);
    if (!slice.contains('°')) {
      _applyRawInsertion('°', keepLeadingZero: true);
    } else if (!slice.contains("'")) {
      _applyRawInsertion("'", keepLeadingZero: true);
    } else if (!slice.contains("''") && !slice.contains('"')) {
      _applyRawInsertion("''", keepLeadingZero: true);
    } else {
      _applyRawInsertion('°', keepLeadingZero: true);
    }
  }

  void _handleKeyPress(String key) {
    setState(() {
      // Modificadores SHIFT y ALPHA
      if (key == 'SHIFT') {
        _isShiftActive = !_isShiftActive;
        _isAlphaActive = false;
        return;
      }
      if (key == 'ALPHA') {
        _isAlphaActive = !_isAlphaActive;
        _isShiftActive = false;
        return;
      }

      // Tecla MENU / MODE / SETUP (SHIFT + MODE abre SETUP con DEG/RAD/OLED; MODE abre menú 4x2)
      if (key == 'MENU' || key == 'MODE') {
        if (_isShiftActive) {
          _isShiftActive = false;
          _isMenuOpen = false;
          _isSetupOpen = !_isSetupOpen;
          return;
        }
        if (_isSetupOpen) {
          _isSetupOpen = false;
          return;
        }
        _isMenuOpen = !_isMenuOpen;
        if (_isMenuOpen) {
          _menuCursorIndex = CasioLcdScreen.menuIndexForMode(_calculatorMode);
        }
        return;
      }

      // Si el menú SETUP (SHIFT + MODE) está abierto en la LCD
      if (_isSetupOpen) {
        if (key == 'AC') {
          _isSetupOpen = false;
          return;
        }
        final opt = int.tryParse(key);
        if (opt != null && opt >= 1 && opt <= 3) {
          _isSetupOpen = false;
          if (opt == 1) {
            _angleUnit = AngleUnit.deg;
          } else if (opt == 2) {
            _angleUnit = AngleUnit.rad;
          } else if (opt == 3) {
            _isOledDark = !_isOledDark;
          }
          return;
        }
        return;
      }

      // Si el prompt interactivo CALC (x = ?) está activo
      if (_isCalcPromptActive) {
        if (key == 'AC') {
          _isCalcPromptActive = false;
          _calcValueRaw = '';
          return;
        }
        if (key == 'DEL') {
          if (_calcValueRaw.isNotEmpty) {
            _calcValueRaw = _calcValueRaw.substring(0, _calcValueRaw.length - 1);
          } else {
            _isCalcPromptActive = false;
          }
          return;
        }
        if (key == '=') {
          _submitCalcEvalSync();
          return;
        }
        if (key == '-' && _calcValueRaw.isEmpty) {
          _calcValueRaw = '-';
          return;
        }
        if ((key == '/' || key == '.') &&
            _calcValueRaw.isNotEmpty &&
            _calcValueRaw != '-' &&
            !_calcValueRaw.contains(key)) {
          _calcValueRaw += key;
          return;
        }
        if (RegExp(r'^[0-9]$').hasMatch(key)) {
          _calcValueRaw += key;
          return;
        }
        return;
      }

      // Si el Menú ClassWiz está abierto en la LCD, las teclas numéricas y = / AC navegan y seleccionan
      if (_isMenuOpen) {
        if (key == 'AC') {
          _isMenuOpen = false;
          _isAlphaActive = false;
          _isShiftActive = false;
          return;
        }
        if (key == '=') {
          final targetMode = CasioLcdScreen.menuModeIdAt(_menuCursorIndex);
          _isMenuOpen = false;
          _isAlphaActive = false;
          _isShiftActive = false;
          _resetFieldsForMode(targetMode);
          return;
        }
        final parsedMode = int.tryParse(key);
        if (parsedMode != null && parsedMode >= 1 && parsedMode <= 9) {
          _isMenuOpen = false;
          _isAlphaActive = false;
          _isShiftActive = false;
          _resetFieldsForMode(parsedMode);
          return;
        }
        return;
      }

      // Selector previo de grado de polinomio en Modo 4 (Ruffini grado 2..6)
      if (_calculatorMode == 4 && !_polyIsNotableMode && _isChoosingRuffiniDegree) {
        if (key == 'AC') {
          _isShiftActive = false;
          _isAlphaActive = false;
          _ruffiniDegree = 3;
          return;
        }
        if (key == '=') {
          _isShiftActive = false;
          _isAlphaActive = false;
          _setRuffiniDegree(_ruffiniDegree, enterTemplate: true);
          return;
        }
        if (!_isShiftActive && !_isAlphaActive) {
          final deg = int.tryParse(key);
          if (deg != null && deg >= 2 && deg <= 6) {
            _setRuffiniDegree(deg, enterTemplate: true);
            return;
          }
        }
        _isShiftActive = false;
        _isAlphaActive = false;
        return;
      }

      // Tecla S⬄D (alternar exacto y decimal)
      if (key == 'SD') {
        _showDecimalApprox = !_showDecimalApprox;
        return;
      }

      // Tecla AC (All Clear Definitivo en todos los modos)
      if (key == 'AC') {
        _activeResolution = null;
        _activeStepIndex = 0;
        _isShiftActive = false;
        _isAlphaActive = false;
        _showDecimalApprox = false;
        _replayIndex = -1;

        if (_calculatorMode == 2) {
          _eqLeftRaw = '';
          _eqLeftCursorPos = 0;
          _eqRightRaw = '';
          _eqRightCursorPos = 0;
          _eqActiveSide = 0;
        } else if (_calculatorMode == 7) {
          _statRows = [(xi: '', fi: '')];
          _statActiveRow = 0;
          _statActiveCol = 0;
        } else if (_calculatorMode == 8) {
          for (int i = 0; i < _matrixCellsA.length; i++) {
            _matrixCellsA[i] = '';
            _matrixCellsB[i] = '';
          }
          _matrixScalarK = '';
          _matrixActiveTarget = 0;
          _matrixActiveRow = 0;
          _matrixActiveCol = 0;
        } else if (_calculatorMode == 9) {
          for (int i = 0; i < _vecUCells.length; i++) {
            _vecUCells[i] = '';
            _vecVCells[i] = '';
          }
          _vectorActiveRow = 0;
          _vectorActiveCol = 0;
        } else if (_calculatorMode == 10) {
          for (int i = 0; i < _complexCells.length; i++) {
            _complexCells[i] = '';
          }
          _complexActiveIndex = 0;
        } else if (_calculatorMode == 11) {
          _calculusExprRaw = '';
          _calculusCursorPos = 0;
          _calculusX0Raw = '';
          _calculusLimitARaw = '';
          _calculusLimitBRaw = '';
          _calculusActiveField = 0;
        } else if (_isCoefficientMode) {
          final cells = _currentCellValues;
          for (int i = 0; i < cells.length; i++) {
            cells[i] = '';
          }
          _currentActiveIndex = 0;
          if (_calculatorMode == 5) {
            _currentGraphAnalysis = null;
            _selectedGraphPoint = null;
            _showGraphView = false;
          } else if (_calculatorMode == 6) {
            _inequalitySign = InequalitySign.less;
          }
        } else {
          _rawInput = '0';
          _cursorPos = 1;
          if (_calculatorMode == 6) {
            _inequalitySign = InequalitySign.less;
          }
        }
        return;
      }

      // Tecla DEL (Comportamiento fiel a Casio con borrado en _cursorPos)
      if (key == 'DEL') {
        // Si hay una resolución activa, DEL sale de la vista de pasos y devuelve a la plantilla editable
        if (_activeResolution != null) {
          _clearActiveResolutionCursor();
          return;
        }

        if (_calculatorMode == 7) {
          _statBackspace();
          return;
        }
        if (_calculatorMode == 8) {
          _matrixBackspace();
          return;
        }
        if (_calculatorMode == 9) {
          _vectorBackspace();
          return;
        }
        if (_calculatorMode == 10) {
          _complexBackspace();
          return;
        }
        if (_calculatorMode == 11) {
          _calculusBackspace();
          return;
        }

        // Si se está editando en modo coeficientes
        if (_isCoefficientMode) {
          final cells = _currentCellValues;
          final idx = _currentActiveIndex;
          if (idx < cells.length && cells[idx].isNotEmpty) {
            cells[idx] = cells[idx].substring(0, cells[idx].length - 1);
          }
          return;
        }

        // En Modo 2 (Ecuaciones con = central fijo), DEL nunca borra el signo =
        if (_calculatorMode == 2) {
          if (_eqActiveSide == 0) {
            if (_eqLeftRaw.isNotEmpty && _eqLeftCursorPos > 0) {
              final (nextRaw, nextPos) = ExpressionParser.deleteAtCursor(
                _eqLeftRaw,
                _eqLeftCursorPos,
                emptyResult: '',
                emptyCursor: 0,
              );
              _eqLeftRaw = nextRaw;
              _eqLeftCursorPos = nextPos;
            }
          } else {
            if (_eqRightCursorPos == 0) {
              _eqActiveSide = 0;
              _eqLeftCursorPos = _eqLeftRaw.length;
            } else {
              final (nextRaw, nextPos) = ExpressionParser.deleteAtCursor(
                _eqRightRaw,
                _eqRightCursorPos,
                emptyResult: '',
                emptyCursor: 0,
              );
              _eqRightRaw = nextRaw;
              _eqRightCursorPos = nextPos;
            }
          }
          _replayIndex = -1;
          return;
        }

        // Si se está editando en modo expresión (Modos 1, 4 Notables y 6 lineal)
        final (nextRaw, nextPos) =
            ExpressionParser.deleteAtCursor(_rawInput, _cursorPos);
        _rawInput = nextRaw;
        _cursorPos = nextPos;
        _replayIndex = -1;
        return;
      }

      // Tecla ANS
      if (key == 'ANS') {
        _isShiftActive = false;
        _isAlphaActive = false;
        if (_supportsScientificFns) {
          if (_activeResolution != null) {
            _clearActiveResolutionCursor();
          }
          _applyRawInsertion('ANS');
        }
        return;
      }

      // Tecla ÷ (con SHIFT ejecuta FACT)
      if (key == ':') {
        if (_isShiftActive) {
          _isShiftActive = false;
          _handleFactorize();
          return;
        }
      }

      // Tecla × (con SHIFT inserta m.c.m., con ALPHA M.C.D.)
      if (key == '*') {
        if (_isShiftActive) {
          _isShiftActive = false;
          if (_supportsScientificFns) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('mcm(');
          }
          return;
        }
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsScientificFns) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('mcd(');
          }
          return;
        }
      }

      // Tecla x² (Normal: ^2, SHIFT: exponente libre ^(, ALPHA: cubo ^3)
      if (key == '^2') {
        if (_isShiftActive) {
          _isShiftActive = false;
          if (_supportsExpressionInput) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
              _calculusCursorPos = _calculusExprRaw.length;
            }
            _applyRawInsertion('^(', keepLeadingZero: true);
          }
          return;
        }
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsExpressionInput) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
              _calculusCursorPos = _calculusExprRaw.length;
            }
            _applyRawInsertion('^3', keepLeadingZero: true);
          }
          return;
        }
        if (_supportsExpressionInput) {
          if (_activeResolution != null) {
            _activeResolution = null;
            _activeStepIndex = 0;
            _cursorPos = _rawInput.length;
            _calculusCursorPos = _calculusExprRaw.length;
          }
          _applyRawInsertion('^2', keepLeadingZero: true);
          return;
        }
      }

      // Tecla √■ (Normal: √(, SHIFT: root(, ALPHA: ³√()
      if (key == '√') {
        if (_isShiftActive) {
          _isShiftActive = false;
          if (_supportsScientificFns) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('root(');
          }
          return;
        }
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsScientificFns) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('³√(');
          }
          return;
        }
        if (_supportsScientificFns) {
          if (_activeResolution != null) {
            _activeResolution = null;
            _activeStepIndex = 0;
            _cursorPos = _rawInput.length;
          }
          _applyRawInsertion('√(');
          return;
        }
      }

      // Tecla a/b (Fracción / con plantilla vacía \frac{\blacksquare}{\square} sin 0 inicial)
      if (key == '/') {
        if (_isShiftActive) {
          _isShiftActive = false;
          _showDecimalApprox = !_showDecimalApprox;
          return;
        }
        _isAlphaActive = false;
        if (_calculatorMode == 8) {
          _matrixInsertToken('/');
          return;
        }
        if (_calculatorMode == 9) {
          _vectorInsertToken('/');
          return;
        }
        if (_calculatorMode == 10) {
          _complexInsertToken('/');
          return;
        }
        if (_calculatorMode == 11 && _calculusActiveField != 0) {
          _calculusInsertAuxToken('/');
          return;
        }
        if (_isCoefficientMode) {
          final cells = _currentCellValues;
          final idx = _currentActiveIndex;
          if (idx < cells.length) {
            final cur = cells[idx];
            if (cur.isNotEmpty && cur != '-' && !cur.contains('/')) {
              cells[idx] += '/';
            }
          }
          return;
        }
        if (_activeResolution != null) {
          _clearActiveResolutionCursor();
        }
        _replayIndex = -1;
        if (_calculatorMode == 2) {
          if (_eqActiveSide == 0 && _eqLeftRaw == '0') {
            _eqLeftRaw = '';
            _eqLeftCursorPos = 0;
          } else if (_eqActiveSide == 1 && _eqRightRaw == '0') {
            _eqRightRaw = '';
            _eqRightCursorPos = 0;
          }
          final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
          final sideCur =
              (_eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos)
                  .clamp(0, sideRaw.length);
          final stayInNum =
              sideRaw.isEmpty || sideCur == 0 || '+-*(,;'.contains(sideRaw[sideCur - 1]);
          final (nextRaw, advancedPos) = ExpressionParser.insertAtCursor(
            sideRaw,
            sideCur,
            '/',
            keepLeadingZero: true,
          );
          final finalCur = stayInNum ? sideCur : advancedPos;
          if (_eqActiveSide == 0) {
            _eqLeftRaw = nextRaw;
            _eqLeftCursorPos = finalCur;
          } else {
            _eqRightRaw = nextRaw;
            _eqRightCursorPos = finalCur;
          }
          return;
        }
        if (_calculatorMode == 11 && _calculusActiveField == 0) {
          if (_calculusExprRaw.isEmpty || _calculusExprRaw == '0') {
            _calculusExprRaw = '/';
            _calculusCursorPos = 0;
          } else {
            final cur = _calculusCursorPos.clamp(0, _calculusExprRaw.length);
            final stayInNum =
                cur == 0 || '+-*(,;'.contains(_calculusExprRaw[cur - 1]);
            final (nextRaw, advancedPos) = ExpressionParser.insertAtCursor(
              _calculusExprRaw,
              cur,
              '/',
              keepLeadingZero: true,
            );
            _calculusExprRaw = nextRaw;
            _calculusCursorPos = stayInNum ? cur : advancedPos;
          }
          return;
        }
        if (_rawInput.isEmpty || _rawInput == '0') {
          _rawInput = '/';
          _cursorPos = 0;
        } else {
          final cur = _cursorPos.clamp(0, _rawInput.length);
          final stayInNum = cur == 0 || '+-*(,;='.contains(_rawInput[cur - 1]);
          final (nextRaw, advancedPos) = ExpressionParser.insertAtCursor(
            _rawInput,
            cur,
            '/',
            keepLeadingZero: true,
          );
          _rawInput = nextRaw;
          _cursorPos = stayInNum ? cur : advancedPos;
        }
        return;
      }

      // Tecla ) (con ALPHA escribe variable X)
      if (key == ')') {
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsExpressionInput) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
              _calculusCursorPos = _calculusExprRaw.length;
            }
            _applyRawInsertion('x');
          }
          return;
        }
      }

      // Tecla ( (con ALPHA escribe variable Y)
      if (key == '(') {
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsScientificFns) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('y');
          }
          return;
        }
      }

      // Teclas científicas Fase 7A (CALC, °'", sin, cos, tan, log■□, ×10ˣ/%)
      if (key == 'CALC') {
        _isShiftActive = false;
        _isAlphaActive = false;
        _enterCalcPromptSync();
        return;
      }

      if (key == 'DMS') {
        _isShiftActive = false;
        _isAlphaActive = false;
        _insertDmsSymbolSync();
        return;
      }

      if (key == 'sin' || key == 'cos' || key == 'tan') {
        final bool isShift = _isShiftActive;
        _isShiftActive = false;
        _isAlphaActive = false;
        if (_supportsScientificFns) {
          if (_activeResolution != null) {
            _activeResolution = null;
            _activeStepIndex = 0;
            _cursorPos = _rawInput.length;
          }
          _applyRawInsertion(isShift ? '$key⁻¹(' : '$key(');
        }
        return;
      }

      if (key == 'LOG') {
        final bool isShift = _isShiftActive;
        final bool isAlpha = _isAlphaActive;
        _isShiftActive = false;
        _isAlphaActive = false;
        if (_supportsScientificFns) {
          if (_activeResolution != null) {
            _activeResolution = null;
            _activeStepIndex = 0;
            _cursorPos = _rawInput.length;
          }
          if (isShift) {
            _applyRawInsertion('10^(');
          } else if (isAlpha) {
            _applyRawInsertion('ln(');
          } else {
            _applyRawInsertion('log_(');
          }
        }
        return;
      }

      if (key == 'SCI10') {
        final bool isShift = _isShiftActive;
        _isShiftActive = false;
        _isAlphaActive = false;
        if (_supportsScientificFns) {
          if (_activeResolution != null) {
            _clearActiveResolutionCursor();
          }
          if (isShift) {
            _applyRawInsertion('%', keepLeadingZero: true);
          } else {
            final activeText = _calculatorMode == 2
                ? (_eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw)
                : _rawInput;
            final keepZero = activeText.isNotEmpty && activeText != '0';
            _applyRawInsertion(keepZero ? '*10^(' : '10^(', keepLeadingZero: keepZero);
          }
        }
        return;
      }

      // Tecla M+
      if (key == 'M+') {
        if (_isAlphaActive) {
          _isAlphaActive = false;
          if (_supportsScientificFns) {
            if (_activeResolution != null) {
              _activeResolution = null;
              _activeStepIndex = 0;
              _cursorPos = _rawInput.length;
            }
            _applyRawInsertion('M');
          }
          return;
        }
        final targetVal = _evaluator.lastEvaluatedRational ?? _memory.ans;
        if (_isShiftActive) {
          _isShiftActive = false;
          final updated = _memory.mMinus(targetVal);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('M- : ${targetVal.toLatex()} restado de M. (M = ${updated.toLatex()})'),
              backgroundColor: const Color(0xFF0F766E),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          final updated = _memory.mPlus(targetVal);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('M+ : ${targetVal.toLatex()} sumado a M. (M = ${updated.toLatex()})'),
              backgroundColor: const Color(0xFF0F766E),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Tecla = (Confirmar / Resolver / Avanzar pasos)
      if (key == '=') {
        _isShiftActive = false;
        _isAlphaActive = false;

        // En Modo 7 (Estadística 1-Var): confirma celda y baja a la siguiente fila, o avanza pasos si ya está resuelto
        if (_calculatorMode == 7) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          _statAdvanceRowOnEquals();
          return;
        }

        // En Modo 8 (Matrices): avanza por celdas (y de MatA a MatB si aplica) hasta resolver
        if (_calculatorMode == 8) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          _matrixAdvanceOnEquals();
          return;
        }

        // En Modo 9 (Vectores): avanza coordenadas hasta resolver
        if (_calculatorMode == 9) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          _vectorAdvanceOnEquals();
          return;
        }

        // En Modo 10 (Complejos): avanza casillas binómicas/polares hasta resolver
        if (_calculatorMode == 10) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          _complexAdvanceOnEquals();
          return;
        }

        // En Modo 11 (Cálculo: Derivada / Tangente / Barrow)
        if (_calculatorMode == 11) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          _calculusAdvanceOnEquals();
          return;
        }

        // En modo coeficientes: avanza pasos si está resuelto, o confirma celda
        if (_isCoefficientMode) {
          if (_activeResolution != null) {
            if (_activeStepIndex < _activeResolution!.steps.length - 1) {
              _activeStepIndex++;
            } else {
              _activeStepIndex = 0;
            }
            return;
          }
          final cells = _currentCellValues;
          final idx = _currentActiveIndex;
          if (idx < cells.length - 1) {
            _currentActiveIndex = idx + 1;
          } else {
            // Última celda -> resolver
            _solveCurrentMode();
          }
          return;
        }

        // En Modos de Expresión (Modos 1, 2, 4 Notables y 6 lineal):
        if (_activeResolution != null) {
          if (_activeStepIndex < _activeResolution!.steps.length - 1) {
            _activeStepIndex++;
          } else {
            _activeStepIndex = 0;
          }
          return;
        }
        _solveCurrentMode();
        return;
      }

      // Mapeo alfabético con ALPHA sobre números (7->A, 8->B, 9->C, 4->D, 5->E, 6->F)
      String effectiveChar = key;
      if (_isAlphaActive) {
        _isAlphaActive = false;
        const alphaMap = {
          '7': 'A',
          '8': 'B',
          '9': 'C',
          '4': 'D',
          '5': 'E',
          '6': 'F',
          '1': 'X',
          '2': 'Y',
        };
        if (alphaMap.containsKey(key)) {
          effectiveChar = alphaMap[key]!;
        }
      }

      _isShiftActive = false;

      // ENTRADA EN MODO 7 (ESTADÍSTICA 1-VAR: tabla xi | fi)
      if (_calculatorMode == 7) {
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
        }
        _statInsertToken(effectiveChar);
        return;
      }

      // ENTRADA EN MODO 8 (MATRICES 2x2 / 3x3)
      if (_calculatorMode == 8) {
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
        }
        _matrixInsertToken(effectiveChar);
        return;
      }

      // ENTRADA EN MODO 9 (VECTORES 2D / 3D)
      if (_calculatorMode == 9) {
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
        }
        _vectorInsertToken(effectiveChar);
        return;
      }

      // ENTRADA EN MODO 10 (COMPLEJOS)
      if (_calculatorMode == 10) {
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
        }
        _complexInsertToken(effectiveChar);
        return;
      }

      // ENTRADA EN MODO 11 (CÁLCULO: campo auxiliar x0/a/b vs f(x))
      if (_calculatorMode == 11) {
        if (_activeResolution != null) {
          _activeResolution = null;
          _activeStepIndex = 0;
          _calculusCursorPos = _calculusExprRaw.length;
        }
        if (_calculusActiveField != 0) {
          _calculusInsertAuxToken(effectiveChar);
          return;
        }
        // Si está enfocado f(x), continúa hacia _applyRawInsertion
      }

      // ENTRADA EN MODO COEFICIENTES (Modos 3, 4 Ruffini, 5 Gráficas, 6 cuadrática)
      if (_isCoefficientMode) {
        if (_activeResolution != null) {
          // Si el alumno empieza a teclear mientras ve los pasos, cerramos los pasos y volvemos a edición
          _activeResolution = null;
          _activeStepIndex = 0;
        }

        final cells = _currentCellValues;
        final idx = _currentActiveIndex;
        if (idx >= cells.length) {
          return;
        }

        cells[idx] = _appendTokenToNumericCell(cells[idx], effectiveChar);
        return;
      }

      // ENTRADA EN MODO EXPRESIÓN (Modo 1, Modo 2, Modo 4 Notables, Modo 6 y f(x) de Modo 11)
      if (_activeResolution != null) {
        _clearActiveResolutionCursor();
      }

      if (effectiveChar == '.' || effectiveChar == ',') {
        if (_calculatorMode == 2) {
          final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
          final sideCur = _eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos;
          final mcmDot = ExpressionParser.handleMcmMcdCommaOrDot(sideRaw, sideCur);
          if (mcmDot != null) {
            if (_eqActiveSide == 0) {
              _eqLeftRaw = mcmDot.$1;
              _eqLeftCursorPos = mcmDot.$2;
            } else {
              _eqRightRaw = mcmDot.$1;
              _eqRightCursorPos = mcmDot.$2;
            }
            _replayIndex = -1;
            return;
          }
          if (effectiveChar == ',') return;
        } else {
          final mcmDot = ExpressionParser.handleMcmMcdCommaOrDot(
            _rawInput,
            _cursorPos,
          );
          if (mcmDot != null) {
            _rawInput = mcmDot.$1;
            _cursorPos = mcmDot.$2;
            _replayIndex = -1;
            return;
          }
          if (effectiveChar == ',') return;
        }
      }

      if (effectiveChar == ')') {
        if (_calculatorMode == 2) {
          final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
          final sideCur = _eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos;
          final mcmClose = ExpressionParser.handleMcmMcdCloseParen(sideRaw, sideCur);
          if (mcmClose != null) {
            if (_eqActiveSide == 0) {
              _eqLeftRaw = mcmClose.$1;
              _eqLeftCursorPos = mcmClose.$2;
            } else {
              _eqRightRaw = mcmClose.$1;
              _eqRightCursorPos = mcmClose.$2;
            }
            _replayIndex = -1;
            return;
          }
        } else {
          final mcmClose = ExpressionParser.handleMcmMcdCloseParen(
            _rawInput,
            _cursorPos,
          );
          if (mcmClose != null) {
            _rawInput = mcmClose.$1;
            _cursorPos = mcmClose.$2;
            _replayIndex = -1;
            return;
          }
        }
      }

      final keepLeadingZero = effectiveChar == '.' ||
          effectiveChar == '+' ||
          effectiveChar == '*' ||
          effectiveChar == ':' ||
          effectiveChar == '/' ||
          effectiveChar == '^2';
      _applyRawInsertion(effectiveChar, keepLeadingZero: keepLeadingZero);
    });
  }

  String _appendTokenToNumericCell(String current, String token) {
    if (token == '-') {
      return current.startsWith('-') ? current.substring(1) : '-$current';
    }
    if (token == '/') {
      if (current.isNotEmpty && current != '-' && !current.contains('/')) {
        return '$current/';
      }
      return current;
    }
    if (token == '.') {
      if (current.isNotEmpty && current != '-' && !current.contains('.')) {
        return '$current.';
      }
      return current;
    }
    if (RegExp(r'^[0-9]$').hasMatch(token)) {
      return '$current$token';
    }
    return current;
  }

  void _matrixInsertToken(String token) {
    if (_matrixActiveTarget == 2) {
      _matrixScalarK = _appendTokenToNumericCell(_matrixScalarK, token);
      return;
    }
    final cells = _matrixActiveTarget == 1 ? _matrixCellsB : _matrixCellsA;
    final idx = _matrixActiveRow * 3 + _matrixActiveCol;
    cells[idx] = _appendTokenToNumericCell(cells[idx], token);
  }

  void _matrixBackspace() {
    if (_matrixActiveTarget == 2) {
      if (_matrixScalarK.isNotEmpty) {
        _matrixScalarK = _matrixScalarK.substring(0, _matrixScalarK.length - 1);
      }
      return;
    }
    final cells = _matrixActiveTarget == 1 ? _matrixCellsB : _matrixCellsA;
    final idx = _matrixActiveRow * 3 + _matrixActiveCol;
    if (cells[idx].isNotEmpty) {
      cells[idx] = cells[idx].substring(0, cells[idx].length - 1);
    }
  }

  void _matrixAdvanceOnEquals() {
    if (_matrixActiveTarget == 2) {
      _matrixActiveTarget = 0;
      _solveCurrentMode();
      return;
    }
    if (_matrixActiveCol < _matrixDim - 1) {
      _matrixActiveCol++;
      return;
    }
    if (_matrixActiveRow < _matrixDim - 1) {
      _matrixActiveRow++;
      _matrixActiveCol = 0;
      return;
    }
    if (_matrixOp.needsMatrixB && _matrixActiveTarget == 0) {
      _matrixActiveTarget = 1;
      _matrixActiveRow = 0;
      _matrixActiveCol = 0;
      return;
    }
    _solveCurrentMode();
  }

  void _matrixMoveDpad({required int dRow, required int dCol}) {
    if (_matrixActiveTarget == 2) {
      if (dRow > 0 || dCol != 0) {
        _matrixActiveTarget = 0;
        _matrixActiveRow = 0;
        _matrixActiveCol = 0;
      }
      return;
    }
    if (dCol < 0) {
      if (_matrixActiveCol > 0) {
        _matrixActiveCol--;
      } else if (_matrixActiveRow > 0) {
        _matrixActiveRow--;
        _matrixActiveCol = _matrixDim - 1;
      }
    } else if (dCol > 0) {
      if (_matrixActiveCol < _matrixDim - 1) {
        _matrixActiveCol++;
      } else if (_matrixActiveRow < _matrixDim - 1) {
        _matrixActiveRow++;
        _matrixActiveCol = 0;
      }
    }
    if (dRow < 0 && _matrixActiveRow > 0) {
      _matrixActiveRow--;
    } else if (dRow > 0 && _matrixActiveRow < _matrixDim - 1) {
      _matrixActiveRow++;
    }
  }

  void _vectorInsertToken(String token) {
    final cells = _vectorActiveRow == 1 ? _vecVCells : _vecUCells;
    cells[_vectorActiveCol] = _appendTokenToNumericCell(
      cells[_vectorActiveCol],
      token,
    );
  }

  void _vectorBackspace() {
    final cells = _vectorActiveRow == 1 ? _vecVCells : _vecUCells;
    final cur = cells[_vectorActiveCol];
    if (cur.isNotEmpty) {
      cells[_vectorActiveCol] = cur.substring(0, cur.length - 1);
    }
  }

  void _vectorAdvanceOnEquals() {
    if (_vectorActiveCol < _vectorDim - 1) {
      _vectorActiveCol++;
      return;
    }
    if (_vectorOp.needsSecondVector && _vectorActiveRow == 0) {
      _vectorActiveRow = 1;
      _vectorActiveCol = 0;
      return;
    }
    _solveCurrentMode();
  }

  void _vectorMoveDpad({required int dRow, required int dCol}) {
    if (dCol < 0) {
      if (_vectorActiveCol > 0) {
        _vectorActiveCol--;
      } else if (_vectorOp.needsSecondVector && _vectorActiveRow == 1) {
        _vectorActiveRow = 0;
        _vectorActiveCol = _vectorDim - 1;
      }
    } else if (dCol > 0) {
      if (_vectorActiveCol < _vectorDim - 1) {
        _vectorActiveCol++;
      } else if (_vectorOp.needsSecondVector && _vectorActiveRow == 0) {
        _vectorActiveRow = 1;
        _vectorActiveCol = 0;
      }
    }
    if (dRow < 0 && _vectorActiveRow > 0) {
      _vectorActiveRow = 0;
    } else if (dRow > 0 &&
        _vectorOp.needsSecondVector &&
        _vectorActiveRow == 0) {
      _vectorActiveRow = 1;
    }
  }

  void _setVectorDim(int dim) {
    setState(() {
      _activeResolution = null;
      _vectorDim = dim;
      if (dim == 2 && _vectorOp == VectorOperation.crossAndArea) {
        _vectorOp = VectorOperation.dotAndAngle;
      }
      _vectorActiveCol = _vectorActiveCol.clamp(0, dim - 1);
    });
  }

  void _selectComplexOp(ComplexOperation op) {
    final hasZ1 =
        _complexCells[0].trim().isNotEmpty || _complexCells[1].trim().isNotEmpty;
    final hasZ2 =
        _complexCells[2].trim().isNotEmpty || _complexCells[3].trim().isNotEmpty;
    setState(() {
      _complexOp = op;
      if (!op.needsSecondComplex && _complexActiveIndex > 1) {
        _complexActiveIndex = 0;
      } else if (op.needsSecondComplex && hasZ1 && !hasZ2) {
        _complexActiveIndex = 2;
      }
    });
    if (!op.needsSecondComplex && hasZ1) {
      _solveCurrentMode();
    } else if (op.needsSecondComplex && hasZ1 && hasZ2) {
      _solveCurrentMode();
    }
  }

  void _complexInsertToken(String token) {
    _complexCells[_complexActiveIndex] = _appendTokenToNumericCell(
      _complexCells[_complexActiveIndex],
      token,
    );
  }

  void _complexBackspace() {
    final cur = _complexCells[_complexActiveIndex];
    if (cur.isNotEmpty) {
      _complexCells[_complexActiveIndex] = cur.substring(0, cur.length - 1);
    }
  }

  void _complexAdvanceOnEquals() {
    final maxIdx = _complexOp.needsSecondComplex ? 3 : 1;
    if (_complexActiveIndex < maxIdx) {
      _complexActiveIndex++;
    } else {
      _solveCurrentMode();
    }
  }

  void _complexMoveDpad({required int dRow, required int dCol}) {
    final maxIdx = _complexOp.needsSecondComplex ? 3 : 1;
    if (dCol < 0 && _complexActiveIndex > 0) {
      _complexActiveIndex--;
    } else if (dCol > 0 && _complexActiveIndex < maxIdx) {
      _complexActiveIndex++;
    }
    if (_complexOp.needsSecondComplex) {
      if (dRow < 0 && _complexActiveIndex >= 2) {
        _complexActiveIndex -= 2;
      } else if (dRow > 0 && _complexActiveIndex < 2) {
        _complexActiveIndex += 2;
      }
    }
  }

  void _calculusInsertAuxToken(String token) {
    if (_calculusActiveField == 1) {
      if (_calculusOp == CalculusOperation.tangentLine) {
        _calculusX0Raw = _appendTokenToNumericCell(_calculusX0Raw, token);
      } else if (_calculusOp == CalculusOperation.definiteIntegral) {
        _calculusLimitARaw = _appendTokenToNumericCell(_calculusLimitARaw, token);
      }
    } else if (_calculusActiveField == 2 &&
        _calculusOp == CalculusOperation.definiteIntegral) {
      _calculusLimitBRaw = _appendTokenToNumericCell(_calculusLimitBRaw, token);
    }
  }

  void _calculusBackspace() {
    if (_calculusActiveField == 1) {
      if (_calculusOp == CalculusOperation.tangentLine &&
          _calculusX0Raw.isNotEmpty) {
        _calculusX0Raw =
            _calculusX0Raw.substring(0, _calculusX0Raw.length - 1);
      } else if (_calculusOp == CalculusOperation.definiteIntegral &&
          _calculusLimitARaw.isNotEmpty) {
        _calculusLimitARaw =
            _calculusLimitARaw.substring(0, _calculusLimitARaw.length - 1);
      }
      return;
    }
    if (_calculusActiveField == 2 &&
        _calculusOp == CalculusOperation.definiteIntegral &&
        _calculusLimitBRaw.isNotEmpty) {
      _calculusLimitBRaw =
          _calculusLimitBRaw.substring(0, _calculusLimitBRaw.length - 1);
      return;
    }
    if (_calculusExprRaw.isEmpty) return;
    final (nextRaw, nextPos) =
        ExpressionParser.deleteAtCursor(_calculusExprRaw, _calculusCursorPos);
    if (nextRaw == '0' && _calculusExprRaw.length <= 1) {
      _calculusExprRaw = '';
      _calculusCursorPos = 0;
    } else {
      _calculusExprRaw = nextRaw;
      _calculusCursorPos = nextPos;
    }
  }

  void _calculusAdvanceOnEquals() {
    if (_calculusOp == CalculusOperation.tangentLine &&
        _calculusActiveField == 0) {
      _calculusActiveField = 1;
      return;
    }
    if (_calculusOp == CalculusOperation.definiteIntegral) {
      if (_calculusActiveField < 2) {
        _calculusActiveField++;
        return;
      }
    }
    _solveCurrentMode();
  }

  void _calculusMoveDpad({required int dRow, required int dCol}) {
    if (_calculusActiveField == 0) {
      if (dCol < 0) {
        _calculusCursorPos =
            ExpressionParser.stepCursorLeft(_calculusExprRaw, _calculusCursorPos);
      } else if (dCol > 0) {
        _calculusCursorPos =
            ExpressionParser.stepCursorRight(_calculusExprRaw, _calculusCursorPos);
      } else if (dRow > 0 &&
          (_calculusOp == CalculusOperation.tangentLine ||
              _calculusOp == CalculusOperation.definiteIntegral)) {
        _calculusActiveField = 1;
      }
      return;
    }

    if (dRow < 0) {
      _calculusActiveField = 0;
      return;
    }
    if (_calculusOp == CalculusOperation.definiteIntegral) {
      if (dCol > 0 && _calculusActiveField == 1) {
        _calculusActiveField = 2;
      } else if (dCol < 0 && _calculusActiveField == 2) {
        _calculusActiveField = 1;
      }
    }
  }

  void _handleDpadLeft() {
    setState(() {
      if (_isMenuOpen) {
        final count = CasioLcdScreen.menuItemCount;
        _menuCursorIndex = (_menuCursorIndex - 1 + count) % count;
        return;
      }
      if (_calculatorMode == 4 &&
          !_polyIsNotableMode &&
          _isChoosingRuffiniDegree &&
          _activeResolution == null) {
        _ruffiniDegree = _ruffiniDegree > 2 ? _ruffiniDegree - 1 : 6;
        return;
      }
      if (_activeResolution != null) {
        if (_activeStepIndex > 0) {
          _activeStepIndex--;
        }
        return;
      }
      if (_calculatorMode == 7) {
        _statMoveDpad(dRow: 0, dCol: -1);
        return;
      }
      if (_calculatorMode == 8) {
        _matrixMoveDpad(dRow: 0, dCol: -1);
        return;
      }
      if (_calculatorMode == 9) {
        _vectorMoveDpad(dRow: 0, dCol: -1);
        return;
      }
      if (_calculatorMode == 10) {
        _complexMoveDpad(dRow: 0, dCol: -1);
        return;
      }
      if (_calculatorMode == 11) {
        _calculusMoveDpad(dRow: 0, dCol: -1);
        return;
      }
      if (_isCoefficientMode) {
        if (_currentActiveIndex > 0) {
          _currentActiveIndex--;
        }
        return;
      }
      if (_calculatorMode == 2) {
        if (_eqActiveSide == 0) {
          _eqLeftCursorPos =
              ExpressionParser.stepCursorLeft(_eqLeftRaw, _eqLeftCursorPos);
        } else if (_eqRightCursorPos > 0) {
          _eqRightCursorPos =
              ExpressionParser.stepCursorLeft(_eqRightRaw, _eqRightCursorPos);
        } else {
          // Salta al miembro izquierdo sin tocar el = central fijo
          _eqActiveSide = 0;
          _eqLeftCursorPos = _eqLeftRaw.length;
        }
        return;
      }
      // Modo escritura libre: desplazar _cursorPos hacia la izquierda
      _cursorPos = ExpressionParser.stepCursorLeft(_rawInput, _cursorPos);
    });
  }

  void _handleDpadRight() {
    setState(() {
      if (_isMenuOpen) {
        final count = CasioLcdScreen.menuItemCount;
        _menuCursorIndex = (_menuCursorIndex + 1) % count;
        return;
      }
      if (_calculatorMode == 4 &&
          !_polyIsNotableMode &&
          _isChoosingRuffiniDegree &&
          _activeResolution == null) {
        _ruffiniDegree = _ruffiniDegree < 6 ? _ruffiniDegree + 1 : 2;
        return;
      }
      if (_activeResolution != null) {
        if (_activeStepIndex < _activeResolution!.steps.length - 1) {
          _activeStepIndex++;
        }
        return;
      }
      if (_calculatorMode == 7) {
        _statMoveDpad(dRow: 0, dCol: 1);
        return;
      }
      if (_calculatorMode == 8) {
        _matrixMoveDpad(dRow: 0, dCol: 1);
        return;
      }
      if (_calculatorMode == 9) {
        _vectorMoveDpad(dRow: 0, dCol: 1);
        return;
      }
      if (_calculatorMode == 10) {
        _complexMoveDpad(dRow: 0, dCol: 1);
        return;
      }
      if (_calculatorMode == 11) {
        _calculusMoveDpad(dRow: 0, dCol: 1);
        return;
      }
      if (_isCoefficientMode) {
        final maxIdx = (_calculatorMode == 6 && _ineqDegree == 2)
            ? 3
            : _currentCellValues.length - 1;
        if (_currentActiveIndex < maxIdx) {
          _currentActiveIndex++;
        }
        return;
      }
      if (_calculatorMode == 2) {
        final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
        final sideCur = _eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos;
        final mcmRight = ExpressionParser.handleMcmMcdRightArrow(sideRaw, sideCur);
        final slotRight = mcmRight ?? ExpressionParser.handleTwoSlotRightArrow(sideRaw, sideCur);
        if (slotRight != null) {
          if (_eqActiveSide == 0) {
            _eqLeftRaw = slotRight.$1;
            _eqLeftCursorPos = slotRight.$2;
          } else {
            _eqRightRaw = slotRight.$1;
            _eqRightCursorPos = slotRight.$2;
          }
          _replayIndex = -1;
        } else if (_eqActiveSide == 0 && _eqLeftCursorPos >= _eqLeftRaw.length) {
          _eqActiveSide = 1;
          _eqRightCursorPos = 0;
        } else {
          final stepped = ExpressionParser.stepCursorRight(sideRaw, sideCur);
          if (_eqActiveSide == 0) {
            _eqLeftCursorPos = stepped;
          } else {
            _eqRightCursorPos = stepped;
          }
        }
        return;
      }
      // Modo escritura libre: en mcm/mcd o log_(base,arg)/root(n,x) abre hueco con ',' o cierra; si no, desplaza _cursorPos
      final mcmRight = ExpressionParser.handleMcmMcdRightArrow(
        _rawInput,
        _cursorPos,
      );
      if (mcmRight != null) {
        _rawInput = mcmRight.$1;
        _cursorPos = mcmRight.$2;
        _replayIndex = -1;
      } else {
        final slotRight = ExpressionParser.handleTwoSlotRightArrow(
          _rawInput,
          _cursorPos,
        );
        if (slotRight != null) {
          _rawInput = slotRight.$1;
          _cursorPos = slotRight.$2;
          _replayIndex = -1;
        } else {
          _cursorPos = ExpressionParser.stepCursorRight(_rawInput, _cursorPos);
        }
      }
    });
  }

  void _handleDpadUp() {
    setState(() {
      if (_isMenuOpen) {
        final count = CasioLcdScreen.menuItemCount;
        _menuCursorIndex = (_menuCursorIndex - 2 + count) % count;
        return;
      }
      if (_calculatorMode == 4 &&
          !_polyIsNotableMode &&
          _isChoosingRuffiniDegree &&
          _activeResolution == null) {
        _ruffiniDegree = _ruffiniDegree > 2 ? _ruffiniDegree - 1 : 6;
        return;
      }
      if (_activeResolution != null) {
        if (_activeStepIndex > 0) {
          _activeStepIndex = 0;
        } else if (_supportsExpressionInput &&
            _calculatorMode != 11 &&
            _historyEntries.isNotEmpty) {
          // Casio Replay rápido desde el paso 1
          _activeResolution = null;
          _activeStepIndex = 0;
          _replayIndex = -1;
          _cycleHistoryReplayUp();
        }
        return;
      }
      if (_calculatorMode == 7) {
        _statMoveDpad(dRow: -1, dCol: 0);
        return;
      }
      if (_calculatorMode == 8) {
        _matrixMoveDpad(dRow: -1, dCol: 0);
        return;
      }
      if (_calculatorMode == 9) {
        _vectorMoveDpad(dRow: -1, dCol: 0);
        return;
      }
      if (_calculatorMode == 10) {
        _complexMoveDpad(dRow: -1, dCol: 0);
        return;
      }
      if (_calculatorMode == 11) {
        _calculusMoveDpad(dRow: -1, dCol: 0);
        return;
      }
      if (_isCoefficientMode) {
        if (_calculatorMode == 3 && _systemDim == 2) {
          if (_sysActiveIndex >= 3) {
            _sysActiveIndex -= 3;
          }
        } else if (_calculatorMode == 3 && _systemDim == 3) {
          if (_sys3ActiveIndex >= 4) {
            _sys3ActiveIndex -= 4;
          }
        } else if (_calculatorMode == 6 && _ineqDegree == 2 && _currentActiveIndex == 3) {
          _cycleInequalitySign(backwards: true);
        } else {
          if (_currentActiveIndex > 0) {
            _currentActiveIndex--;
          }
        }
        return;
      }
      if (_calculatorMode == 2) {
        final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
        final sideCur = _eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos;
        final jumped = ExpressionParser.jumpFractionUpDown(sideRaw, sideCur, isUp: true);
        if (jumped != null) {
          if (_eqActiveSide == 0) {
            _eqLeftCursorPos = jumped;
          } else {
            _eqRightCursorPos = jumped;
          }
        } else {
          _cycleHistoryReplayUp();
        }
        return;
      }
      // Modo escritura libre: saltar denominador -> numerador, ciclar desigualdad o Replay
      final jumped = ExpressionParser.jumpFractionUpDown(
        _rawInput,
        _cursorPos,
        isUp: true,
      );
      if (jumped != null) {
        _cursorPos = jumped;
      } else if (_calculatorMode == 6 && _ineqDegree == 1 && _replayIndex == -1) {
        _cycleInequalitySign(backwards: true);
      } else {
        _cycleHistoryReplayUp();
      }
    });
  }

  void _handleDpadDown() {
    setState(() {
      if (_isMenuOpen) {
        final count = CasioLcdScreen.menuItemCount;
        _menuCursorIndex = (_menuCursorIndex + 2) % count;
        return;
      }
      if (_calculatorMode == 4 &&
          !_polyIsNotableMode &&
          _isChoosingRuffiniDegree &&
          _activeResolution == null) {
        _ruffiniDegree = _ruffiniDegree < 6 ? _ruffiniDegree + 1 : 2;
        return;
      }
      if (_activeResolution != null) {
        _activeStepIndex = _activeResolution!.steps.length - 1;
        return;
      }
      if (_calculatorMode == 7) {
        _statMoveDpad(dRow: 1, dCol: 0);
        return;
      }
      if (_calculatorMode == 8) {
        _matrixMoveDpad(dRow: 1, dCol: 0);
        return;
      }
      if (_calculatorMode == 9) {
        _vectorMoveDpad(dRow: 1, dCol: 0);
        return;
      }
      if (_calculatorMode == 10) {
        _complexMoveDpad(dRow: 1, dCol: 0);
        return;
      }
      if (_calculatorMode == 11) {
        _calculusMoveDpad(dRow: 1, dCol: 0);
        return;
      }
      if (_isCoefficientMode) {
        if (_calculatorMode == 3 && _systemDim == 2) {
          if (_sysActiveIndex < 3) {
            _sysActiveIndex += 3;
          }
        } else if (_calculatorMode == 3 && _systemDim == 3) {
          if (_sys3ActiveIndex < 8) {
            _sys3ActiveIndex += 4;
          }
        } else if (_calculatorMode == 6 && _ineqDegree == 2) {
          if (_currentActiveIndex == 3) {
            _cycleInequalitySign();
          } else {
            _currentActiveIndex++;
          }
        } else {
          if (_currentActiveIndex < _currentCellValues.length - 1) {
            _currentActiveIndex++;
          }
        }
        return;
      }
      if (_calculatorMode == 2) {
        final sideRaw = _eqActiveSide == 0 ? _eqLeftRaw : _eqRightRaw;
        final sideCur = _eqActiveSide == 0 ? _eqLeftCursorPos : _eqRightCursorPos;
        final jumped = ExpressionParser.jumpFractionUpDown(sideRaw, sideCur, isUp: false);
        if (jumped != null) {
          if (_eqActiveSide == 0) {
            _eqLeftCursorPos = jumped;
          } else {
            _eqRightCursorPos = jumped;
          }
        } else {
          _cycleHistoryReplayDown();
        }
        return;
      }
      // Modo escritura libre: saltar numerador -> denominador, ciclar desigualdad o Replay
      final jumped = ExpressionParser.jumpFractionUpDown(
        _rawInput,
        _cursorPos,
        isUp: false,
      );
      if (jumped != null) {
        _cursorPos = jumped;
      } else if (_calculatorMode == 6 && _ineqDegree == 1 && _replayIndex == -1) {
        _cycleInequalitySign();
      } else {
        _cycleHistoryReplayDown();
      }
    });
  }

  void _statInsertToken(String token) {
    if (_statActiveRow >= _statRows.length) return;
    final row = _statRows[_statActiveRow];
    if (_statActiveCol == 0) {
      String cur = row.xi;
      if (token == '-') {
        cur = cur.startsWith('-') ? cur.substring(1) : '-$cur';
      } else if (token == '/' || token == '.') {
        if (cur.isNotEmpty && cur != '-' && !cur.contains(token)) {
          cur += token;
        }
      } else if (RegExp(r'^[0-9]$').hasMatch(token)) {
        cur += token;
      }
      _statRows[_statActiveRow] = (xi: cur, fi: row.fi);
    } else {
      String cur = row.fi;
      if (RegExp(r'^[0-9]$').hasMatch(token)) {
        cur += token;
      }
      _statRows[_statActiveRow] = (xi: row.xi, fi: cur);
    }
  }

  void _statBackspace() {
    if (_statActiveRow >= _statRows.length) return;
    final row = _statRows[_statActiveRow];
    if (_statActiveCol == 0) {
      if (row.xi.isNotEmpty) {
        _statRows[_statActiveRow] = (
          xi: row.xi.substring(0, row.xi.length - 1),
          fi: row.fi,
        );
        return;
      }
    } else {
      if (row.fi.isNotEmpty) {
        _statRows[_statActiveRow] = (
          xi: row.xi,
          fi: row.fi.substring(0, row.fi.length - 1),
        );
        return;
      }
    }
    if (row.xi.isEmpty && row.fi.isEmpty && _statRows.length > 1) {
      _statRows.removeAt(_statActiveRow);
      if (_statActiveRow >= _statRows.length) {
        _statActiveRow = _statRows.length - 1;
      }
    }
  }

  void _statAdvanceRowOnEquals() {
    if (_statActiveRow < _statRows.length - 1) {
      _statActiveRow++;
    } else {
      _statRows.add((xi: '', fi: ''));
      _statActiveRow = _statRows.length - 1;
    }
  }

  void _statMoveDpad({required int dRow, required int dCol}) {
    if (dCol != 0) {
      _statActiveCol = (_statActiveCol + dCol).clamp(0, 1);
    }
    if (dRow < 0 && _statActiveRow > 0) {
      _statActiveRow--;
    } else if (dRow > 0) {
      if (_statActiveRow < _statRows.length - 1) {
        _statActiveRow++;
      } else if (_statRows[_statActiveRow].xi.trim().isNotEmpty) {
        _statRows.add((xi: '', fi: ''));
        _statActiveRow = _statRows.length - 1;
      }
    }
  }

  void _toggleLcdTheme() {
    setState(() {
      _isShiftActive = false;
      _isAlphaActive = false;
      _isOledDark = !_isOledDark;
    });
  }

  void _toggleSound() {
    setState(() {
      _isSoundMuted = KeyClickSound.toggleMute();
    });
  }

  Future<void> _copyLatexToClipboardShortcut() async {
    setState(() {
      _isShiftActive = false;
      _isAlphaActive = false;
    });
    if (_activeResolution == null) {
      if (_isCoefficientMode ||
          _calculatorMode == 7 ||
          _calculatorMode == 8 ||
          _calculatorMode == 9 ||
          _calculatorMode == 10 ||
          (_calculatorMode == 11 && _calculusExprRaw.trim().isNotEmpty) ||
          (_calculatorMode == 2 &&
              (_eqLeftRaw.trim().isNotEmpty || _eqRightRaw.trim().isNotEmpty)) ||
          (_rawInput.trim().isNotEmpty && _rawInput != '0')) {
        _solveCurrentMode();
      }
    }
    if (_activeResolution != null) {
      await GoodnotesExporter.copyLatexBlockToClipboard(_activeResolution!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Bloque LaTeX copiado al portapapeles!'),
            backgroundColor: Color(0xFF4F46E5),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (_calculatorMode == 2 &&
        (_eqLeftRaw.trim().isNotEmpty || _eqRightRaw.trim().isNotEmpty)) {
      final l = _eqLeftRaw.isEmpty
          ? r'\square'
          : ExpressionParser.rawToLiveLatex(_eqLeftRaw);
      final r = _eqRightRaw.isEmpty
          ? r'\square'
          : ExpressionParser.rawToLiveLatex(_eqRightRaw);
      await Clipboard.setData(ClipboardData(text: '$l = $r'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ecuación LaTeX copiada al portapapeles.'),
            backgroundColor: Color(0xFF4F46E5),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (_rawInput.trim().isNotEmpty && _rawInput != '0') {
      await Clipboard.setData(
        ClipboardData(text: ExpressionParser.rawToLiveLatex(_rawInput)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expresión LaTeX copiada al portapapeles.'),
            backgroundColor: Color(0xFF4F46E5),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _selectHistoryEntry(ClassHistoryEntry entry) {
    setState(() {
      _isMenuOpen = false;
      if (entry.calculatorMode != null &&
          entry.calculatorMode! >= 1 &&
          entry.calculatorMode! <= 11) {
        _calculatorMode = entry.calculatorMode!;
      }
      _activeResolution = entry.resolution;
      _activeStepIndex = 0;
      _showDecimalApprox = false;
      final restored = _entryToEditableRaw(entry);
      if (_calculatorMode == 2) {
        _restoreMode2EquationString(restored);
      } else if (_calculatorMode == 11) {
        _calculusExprRaw = entry.rawExpression ?? '';
        _calculusCursorPos = _calculusExprRaw.length;
      } else {
        _rawInput = restored;
        _cursorPos = _rawInput.length;
      }
      _replayIndex = -1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cargado ejercicio de clase: ${entry.modeName}'),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleFavoriteInHistory(String id) async {
    setState(() {
      _historyEntries = _historyEntries
          .map((e) => e.id == id ? e.copyWith(isFavorite: !e.isFavorite) : e)
          .toList();
    });
    try {
      await _historyService.toggleFavorite(id);
    } catch (_) {}
  }

  Future<void> _deleteEntryFromHistory(String id) async {
    setState(() {
      _historyEntries = _historyEntries.where((e) => e.id != id).toList();
    });
    try {
      await _historyService.deleteEntry(id);
    } catch (_) {}
  }

  void _openAiTutor() {
    _isShiftActive = false;
    _isAlphaActive = false;
    if (_activeResolution == null) {
      _solveCurrentMode();
    }
    if (_activeResolution != null) {
      AiTutorSheet.show(
        context,
        resolution: _activeResolution!,
        stepIndex: _activeStepIndex,
      );
    }
  }

  void _openStickerExport() {
    _isShiftActive = false;
    _isAlphaActive = false;
    if (_activeResolution == null) {
      _solveCurrentMode();
    }
    if (_activeResolution != null) {
      GoodnotesExporter.showStickerPreviewDialog(
        context,
        _activeResolution!,
        graphAnalysis: _calculatorMode == 5 ? _currentGraphAnalysis : null,
      );
    }
  }

  void _openHistorySheet() {
    ClassHistorySheet.show(
      context,
      historyService: _historyService,
      onSelectEntry: _selectHistoryEntry,
    );
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
              ? r'\textcolor{#2E86DE}{\blacksquare}'
              : r'\square')
          : ExpressionParser.rawToLiveLatex(
              _eqLeftRaw,
              cursorPos: (showLiveCursor && _eqActiveSide == 0)
                  ? _eqLeftCursorPos
                  : null,
            );
      final String rightTex = _eqRightRaw.isEmpty
          ? (showLiveCursor && _eqActiveSide == 1
              ? r'\textcolor{#2E86DE}{\blacksquare}'
              : r'\square')
          : ExpressionParser.rawToLiveLatex(
              _eqRightRaw,
              cursorPos: (showLiveCursor && _eqActiveSide == 1)
                  ? _eqRightCursorPos
                  : null,
            );
      liveLatex = '$leftTex = $rightTex';
    } else if (_calculatorMode == 1 ||
        (_calculatorMode == 4 && _polyIsNotableMode) ||
        (_calculatorMode == 6 && _ineqDegree == 1)) {
      liveLatex = ExpressionParser.rawToLiveLatex(
        _rawInput,
        cursorPos: showLiveCursor ? _cursorPos : null,
      );
    } else {
      liveLatex = _rawInput;
    }

    final modeLabels = {
      1: 'M1: CALC & √',
      2: 'M2: ECUACIONES',
      3: _systemDim == 3 ? 'M3: SIST 3×3' : 'M3: SIST 2×2',
      4: _polyIsNotableMode
          ? 'M4: NOTABLES'
          : (_isChoosingRuffiniDegree
              ? 'M4: RUFFINI'
              : 'M4: RUFFINI ($_ruffiniDegree.º)'),
      5: 'M5: PARÁBOLAS',
      6: _ineqDegree == 1 ? 'M6: INEC. 1°' : 'M6: INEC. 2°',
      7: 'M7: ESTADÍST.',
      8: 'M8: MATRICES ($_matrixDim×$_matrixDim)',
      9: 'M9: VECTORES ${_vectorDim}D',
      10: 'M10: COMPLEJOS',
      11: 'M11: CÁLCULO',
    };
    final modeLabel = modeLabels[_calculatorMode] ?? 'M1: CALC & √';

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        toolbarHeight: 46,
        titleSpacing: 12,
        backgroundColor: const Color(0xFF141619),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
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
        ),
        actions: [
          _HeaderBezelButton(
            key: const Key('appbar_export_png'),
            label: 'PNG',
            tooltip: 'EXPORTAR PNG',
            accentColor: const Color(0xFF94A3B8),
            onPressed: _openStickerExport,
          ),
          const SizedBox(width: 6),
          _HeaderBezelButton(
            key: const Key('appbar_copy_latex'),
            label: 'TEX',
            tooltip: 'COPIAR LaTeX',
            accentColor: const Color(0xFF94A3B8),
            onPressed: _copyLatexToClipboardShortcut,
          ),
          const SizedBox(width: 6),
          _HeaderBezelButton(
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
            final bool isExpanded = constraints.maxWidth >= 760;

            if (!isExpanded) {
              // Modo Compacto / Móvil (< 760 px): chasis centrado hasta 430 px ocupando el alto
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

            // Modo Expandido / Estilo Calculadora de Windows (>= 760 px)
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 430,
                        child: _buildCalculatorChassis(
                          liveLatex: liveLatex,
                          modeLabel: modeLabel,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: WindowsSidePanel(
                          activeTabIndex: _sidePanelTabIndex,
                          onTabChanged: (index) {
                            setState(() {
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
                            setState(() {
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
          painter: _CarbonTexturePainter(),
          child: Padding(
            padding: const EdgeInsets.all(8.5),
            child: LayoutBuilder(
              builder: (context, chassisConstraints) {
                final double maxChassisH = chassisConstraints.maxHeight.isFinite
                    ? chassisConstraints.maxHeight
                    : 700.0;
                final double targetLcdH =
                    (maxChassisH * 0.37).clamp(195.0, 290.0);
                final bool enforceKeyMinHeights = maxChassisH >= 745.0;
                final double? sciMinH = enforceKeyMinHeights ? 48.0 : null;
                final double? numMinH = enforceKeyMinHeights ? 56.0 : null;

                return Column(
                  children: [
                    // 1. Pantalla LCD Natural Textbook Display o Visor Gráfico (36%-40%, minHeight: 195 px)
                    SizedBox(
                      height: targetLcdH,
                      child: _calculatorMode == 5 &&
                              _showGraphView &&
                              _currentGraphAnalysis != null
                      ? CasioGraphCanvas(
                          analysisResult: _currentGraphAnalysis!,
                          selectedPoint: _selectedGraphPoint,
                          onPointSelected: (point) {
                            setState(() {
                              _selectedGraphPoint = point;
                            });
                          },
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
                          customHeaderTitle: _lcdCustomHeaderTitle,
                          customBodyView: (_calculatorMode == 4 &&
                                  !_polyIsNotableMode &&
                                  _isChoosingRuffiniDegree)
                              ? _buildRuffiniDegreeSelector()
                              : (_calculatorMode == 7
                                  ? CasioStatTableView(
                                      rows: _statRows,
                                      activeRow: _statActiveRow,
                                      activeCol: _statActiveCol,
                                      isOledDark: _isOledDark,
                                      onCellTap: (r, c) {
                                        setState(() {
                                          _activeResolution = null;
                                          _statActiveRow = r;
                                          _statActiveCol = c;
                                        });
                                      },
                                    )
                                  : (_calculatorMode == 8
                                      ? CasioMatrixEditorView(
                                          dimension: _matrixDim,
                                          activeMatrixTarget: _matrixActiveTarget,
                                          selectedOperation: _matrixOp,
                                          cellsA: _matrixCellsA,
                                          cellsB: _matrixCellsB,
                                          scalarK: _matrixScalarK,
                                          activeRow: _matrixActiveRow,
                                          activeCol: _matrixActiveCol,
                                          isOledDark: _isOledDark,
                                          onCellTap: (r, c) {
                                            setState(() {
                                              _activeResolution = null;
                                              if (_matrixActiveTarget == 2) {
                                                _matrixActiveTarget = 0;
                                              }
                                              _matrixActiveRow = r;
                                              _matrixActiveCol = c;
                                            });
                                          },
                                          onSwitchMatrixTarget: (target) {
                                            setState(() {
                                              _activeResolution = null;
                                              _matrixActiveTarget = target;
                                            });
                                          },
                                          onChangeDimension: (dim) {
                                            setState(() {
                                              _activeResolution = null;
                                              _matrixDim = dim;
                                              _matrixActiveRow =
                                                  _matrixActiveRow.clamp(0, dim - 1);
                                              _matrixActiveCol =
                                                  _matrixActiveCol.clamp(0, dim - 1);
                                            });
                                          },
                                          onSelectOperation: (op) {
                                            final hasMatA = _matrixCellsA.any(
                                                (c) => c.trim().isNotEmpty);
                                            final hasMatB = _matrixCellsB.any(
                                                (c) => c.trim().isNotEmpty);
                                            setState(() {
                                              _matrixOp = op;
                                              if (!op.needsMatrixB &&
                                                  op != MatrixOperation.scalarMultiply) {
                                                _matrixActiveTarget = 0;
                                              } else if (op ==
                                                      MatrixOperation.scalarMultiply &&
                                                  _matrixScalarK.trim().isEmpty) {
                                                _matrixActiveTarget = 2;
                                              } else if (op.needsMatrixB &&
                                                  hasMatA &&
                                                  !hasMatB) {
                                                _matrixActiveTarget = 1;
                                                _matrixActiveRow = 0;
                                                _matrixActiveCol = 0;
                                              }
                                            });
                                            if (op == MatrixOperation.scalarMultiply) {
                                              if (hasMatA &&
                                                  _matrixScalarK.trim().isNotEmpty) {
                                                _solveCurrentMode();
                                              }
                                            } else if (op.needsMatrixB) {
                                              if (hasMatA && hasMatB) {
                                                _solveCurrentMode();
                                              }
                                            } else if (hasMatA) {
                                              _solveCurrentMode();
                                            }
                                          },
                                        )
                                      : (_calculatorMode == 9
                                          ? CasioVectorEditorView(
                                              dimension: _vectorDim,
                                              selectedOperation: _vectorOp,
                                              cellsU: _vecUCells,
                                              cellsV: _vecVCells,
                                              activeRow: _vectorActiveRow,
                                              activeCol: _vectorActiveCol,
                                              isOledDark: _isOledDark,
                                              onCellTap: (r, c) {
                                                setState(() {
                                                  _activeResolution = null;
                                                  _vectorActiveRow = r;
                                                  _vectorActiveCol = c;
                                                });
                                              },
                                              onChangeDimension: _setVectorDim,
                                              onSelectOperation: (op) {
                                                final hasU = _vecUCells.any(
                                                    (c) => c.trim().isNotEmpty);
                                                final hasV = _vecVCells.any(
                                                    (c) => c.trim().isNotEmpty);
                                                setState(() {
                                                  _vectorOp = op;
                                                  if (op ==
                                                      VectorOperation.crossAndArea) {
                                                    _vectorDim = 3;
                                                  }
                                                  if (!op.needsSecondVector) {
                                                    _vectorActiveRow = 0;
                                                  } else if (hasU && !hasV) {
                                                    _vectorActiveRow = 1;
                                                    _vectorActiveCol = 0;
                                                  }
                                                });
                                                if (!op.needsSecondVector && hasU) {
                                                  _solveCurrentMode();
                                                } else if (op.needsSecondVector &&
                                                    hasU &&
                                                    hasV) {
                                                  _solveCurrentMode();
                                                }
                                              },
                                            )
                                          : (_calculatorMode == 10
                                              ? CasioComplexEditorView(
                                                  selectedOperation: _complexOp,
                                                  cells: _complexCells,
                                                  activeIndex: _complexActiveIndex,
                                                  isOledDark: _isOledDark,
                                                  onCellTap: (idx) {
                                                    setState(() {
                                                      _activeResolution = null;
                                                      _complexActiveIndex = idx;
                                                    });
                                                  },
                                                  onSelectOperation: _selectComplexOp,
                                                )
                                              : (_calculatorMode == 11
                                                  ? CasioCalculusEditorView(
                                                      selectedOperation: _calculusOp,
                                                      expressionRaw: _calculusExprRaw,
                                                      expressionCursorPos:
                                                          _calculusCursorPos,
                                                      x0Raw: _calculusX0Raw,
                                                      limitARaw: _calculusLimitARaw,
                                                      limitBRaw: _calculusLimitBRaw,
                                                      activeField:
                                                          _calculusActiveField,
                                                      isOledDark: _isOledDark,
                                                      onSelectField: (field) {
                                                        setState(() {
                                                          _activeResolution = null;
                                                          _calculusActiveField = field;
                                                        });
                                                      },
                                                      onSelectOperation: (op) {
                                                        setState(() {
                                                          _activeResolution = null;
                                                          _calculusOp = op;
                                                          if (op !=
                                                                  CalculusOperation
                                                                      .tangentLine &&
                                                              op !=
                                                                  CalculusOperation
                                                                      .definiteIntegral) {
                                                            _calculusActiveField = 0;
                                                          } else if (op ==
                                                                  CalculusOperation
                                                                      .tangentLine &&
                                                              _calculusActiveField >
                                                                  1) {
                                                            _calculusActiveField = 1;
                                                          }
                                                        });
                                                      },
                                                    )
                                                  : null))))),
                          isMenuOpen: _isMenuOpen,
                          menuCursorIndex: _menuCursorIndex,
                          onSelectMenuMode: _selectModeFromMenu,
                          onMenuCursorChanged: (idx) {
                            setState(() {
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
                          isCalcPromptActive: _isCalcPromptActive,
                          calcExpressionLatex: _isCalcPromptActive
                              ? ExpressionParser.rawToLiveLatex(_calcExpressionRaw)
                              : null,
                          calcValueRaw: _calcValueRaw,
                          inequalitySignBadge:
                              _calculatorMode == 6 && _ineqDegree == 1
                                  ? _inequalitySign.symbol
                                  : null,
                          onCycleInequalitySign: () {
                            setState(() {
                              _cycleInequalitySign();
                            });
                          },
                          coefficientView: _isCoefficientMode
                              ? CasioCoefficientView(
                                  mode: _calculatorMode,
                                  cellValues: _currentCellValues,
                                  cellLabels: _currentCellLabels,
                                  activeIndex: _currentActiveIndex,
                                  isOledDark: _isOledDark,
                                  notableTypeIndex: _identityType.index,
                                  inequalitySignSymbol: _inequalitySign.symbol,
                                  onCycleInequalitySign: () {
                                    setState(() {
                                      _cycleInequalitySign();
                                    });
                                  },
                                  onCellTap: (idx) {
                                    setState(() {
                                      _currentActiveIndex = idx;
                                    });
                                  },
                                )
                              : null,
                        ),
                ),

                // Barra interactiva contextual para Modos 2..11
                if (_calculatorMode == 2) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        key: const Key('eq_var_x'),
                        label: 'x  (incógnita)',
                        selected: false,
                        onTap: _insertVariableX,
                      ),
                      const SizedBox(width: 4),
                      _buildMethodTab(
                        key: const Key('eq_sign_equals'),
                        label: '⇄ Miembro (=)',
                        selected: _eqActiveSide == 1,
                        onTap: _insertEqualsInEquation,
                      ),
                    ],
                  ),
                ] else if (_calculatorMode == 3) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        key: const Key('sys_dim_2'),
                        label: '2×2',
                        selected: _systemDim == 2,
                        onTap: () {
                          setState(() {
                            _systemDim = 2;
                            _sysActiveIndex = 0;
                            _activeResolution = null;
                            _activeStepIndex = 0;
                          });
                        },
                      ),
                      const SizedBox(width: 3),
                      _buildMethodTab(
                        key: const Key('sys_dim_3'),
                        label: '3×3',
                        selected: _systemDim == 3,
                        onTap: () {
                          setState(() {
                            _systemDim = 3;
                            _sys3ActiveIndex = 0;
                            _activeResolution = null;
                            _activeStepIndex = 0;
                          });
                        },
                      ),
                      if (_systemDim == 2) ...[
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: 'Sustitución',
                          selected:
                              _systemMethod == SystemResolutionMethod.sustitucion,
                          onTap: () {
                            setState(() {
                              _systemMethod = SystemResolutionMethod.sustitucion;
                              if (_activeResolution != null) {
                                _solveCurrentMode();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: 'Igualación',
                          selected:
                              _systemMethod == SystemResolutionMethod.igualacion,
                          onTap: () {
                            setState(() {
                              _systemMethod = SystemResolutionMethod.igualacion;
                              if (_activeResolution != null) {
                                _solveCurrentMode();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: 'Reducción',
                          selected:
                              _systemMethod == SystemResolutionMethod.reduccion,
                          onTap: () {
                            setState(() {
                              _systemMethod = SystemResolutionMethod.reduccion;
                              if (_activeResolution != null) {
                                _solveCurrentMode();
                              }
                            });
                          },
                        ),
                      ] else ...[
                        for (final method in System3x3Method.values) ...[
                          const SizedBox(width: 3),
                          _buildMethodTab(
                            key: Key('sys3_method_${method.name}'),
                            label: method.displayName,
                            selected: _sys3Method == method,
                            onTap: () {
                              setState(() {
                                _sys3Method = method;
                              });
                              if (_activeResolution != null) {
                                _solveCurrentMode();
                              }
                            },
                          ),
                        ],
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          key: const Key('sys3_solve_btn'),
                          label: 'Resolver',
                          selected: false,
                          onTap: _solveCurrentMode,
                        ),
                      ],
                    ],
                  ),
                ] else if (_calculatorMode == 4) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        key: const Key('poly_tab_ruffini'),
                        label: 'Ruffini',
                        selected: !_polyIsNotableMode,
                        onTap: () {
                          setState(() {
                            _polyIsNotableMode = false;
                            _activeResolution = null;
                            _activeStepIndex = 0;
                          });
                        },
                      ),
                      const SizedBox(width: 3),
                      _buildMethodTab(
                        key: const Key('poly_tab_notables'),
                        label: 'Notables',
                        selected: _polyIsNotableMode,
                        onTap: () {
                          setState(() {
                            _polyIsNotableMode = true;
                            _activeResolution = null;
                            _activeStepIndex = 0;
                          });
                        },
                      ),
                      if (!_polyIsNotableMode) ...[
                        for (int deg = 2; deg <= 6; deg++) ...[
                          const SizedBox(width: 3),
                          _buildMethodTab(
                            key: Key('ruffini_tab_$deg'),
                            label: '$deg.º',
                            selected:
                                !_isChoosingRuffiniDegree && _ruffiniDegree == deg,
                            onTap: () {
                              setState(() {
                                _setRuffiniDegree(deg, enterTemplate: true);
                              });
                            },
                          ),
                        ],
                      ] else ...[
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          key: const Key('notable_var_x'),
                          label: 'x',
                          selected: false,
                          onTap: _insertVariableX,
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: '(A+B)²',
                          selected:
                              _identityType == NotableIdentityType.squareOfSum,
                          onTap: () {
                            setState(() {
                              _identityType = NotableIdentityType.squareOfSum;
                              if (_rawInput == '0' || _activeResolution != null) {
                                _rawInput = '(x + 1)^2';
                                _cursorPos = _rawInput.length;
                                _replayIndex = -1;
                                _activeResolution = null;
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: '(A-B)²',
                          selected:
                              _identityType == NotableIdentityType.squareOfDiff,
                          onTap: () {
                            setState(() {
                              _identityType = NotableIdentityType.squareOfDiff;
                              if (_rawInput == '0' || _activeResolution != null) {
                                _rawInput = '(x - 1)^2';
                                _cursorPos = _rawInput.length;
                                _replayIndex = -1;
                                _activeResolution = null;
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          label: '(A+B)(A-B)',
                          selected:
                              _identityType == NotableIdentityType.sumTimesDiff,
                          onTap: () {
                            setState(() {
                              _identityType = NotableIdentityType.sumTimesDiff;
                              if (_rawInput == '0' || _activeResolution != null) {
                                _rawInput = '(x + 1)(x - 1)';
                                _cursorPos = _rawInput.length;
                                _replayIndex = -1;
                                _activeResolution = null;
                              }
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ] else if (_calculatorMode == 5) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        label: _showGraphView ? '📈 Ver Gráfica' : '📝 Ver Pasos',
                        selected: true,
                        onTap: () {
                          setState(() {
                            _showGraphView = !_showGraphView;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      if (_selectedGraphPoint != null)
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFF3B82F6)),
                            ),
                            child: Text(
                              '${_selectedGraphPoint!.label}: (${_selectedGraphPoint!.x % 1 == 0 ? _selectedGraphPoint!.x.toInt() : _selectedGraphPoint!.x.toStringAsFixed(1)}, ${_selectedGraphPoint!.y % 1 == 0 ? _selectedGraphPoint!.y.toInt() : _selectedGraphPoint!.y.toStringAsFixed(1)})',
                              style: const TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else if (_calculatorMode == 6) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildMethodTab(
                        key: const Key('ineq_deg_1'),
                        label: '1.º',
                        selected: _ineqDegree == 1,
                        onTap: () {
                          setState(() {
                            _ineqDegree = 1;
                            _activeResolution = null;
                            _activeStepIndex = 0;
                          });
                        },
                      ),
                      const SizedBox(width: 3),
                      _buildMethodTab(
                        key: const Key('ineq_deg_2'),
                        label: '2.º',
                        selected: _ineqDegree == 2,
                        onTap: () {
                          setState(() {
                            _ineqDegree = 2;
                            _activeResolution = null;
                            _activeStepIndex = 0;
                          });
                        },
                      ),
                      if (_ineqDegree == 1) ...[
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          key: const Key('ineq_var_x'),
                          label: 'x',
                          selected: false,
                          onTap: _insertVariableX,
                        ),
                      ],
                      for (final s in InequalitySign.values) ...[
                        const SizedBox(width: 3),
                        _buildMethodTab(
                          key: Key('ineq_sign_${s.name}'),
                          label: s.symbol,
                          selected: _inequalitySign == s,
                          onTap: () {
                            setState(() {
                              _setInequalitySign(s, insertIfMissing: true);
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ] else if (_calculatorMode == 7) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (_activeResolution != null)
                        _buildMethodTab(
                          key: const Key('stat_edit_btn'),
                          label: 'Tabla',
                          selected: false,
                          onTap: () {
                            setState(() {
                              _activeResolution = null;
                              _activeStepIndex = 0;
                            });
                          },
                        )
                      else
                        _buildMethodTab(
                          key: const Key('stat_add_row_btn'),
                          label: '+ Fila',
                          selected: false,
                          onTap: () {
                            setState(() {
                              _statRows.add((xi: '', fi: ''));
                              _statActiveRow = _statRows.length - 1;
                              _statActiveCol = 0;
                            });
                          },
                        ),
                      const SizedBox(width: 4),
                      _buildMethodTab(
                        key: const Key('stat_optn_btn'),
                        label: 'OPTN',
                        selected: false,
                        onTap: _openStatOptionsModal,
                      ),
                      const SizedBox(width: 4),
                      _buildMethodTab(
                        key: const Key('stat_calc_btn'),
                        label: 'CALC STAT',
                        selected: true,
                        onTap: _solveCurrentMode,
                      ),
                    ],
                  ),
                ] else if (_calculatorMode == 8) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (_activeResolution != null)
                        _buildMethodTab(
                          key: const Key('matrix_edit_btn'),
                          label: 'Editar',
                          selected: false,
                          onTap: () {
                            setState(() {
                              _activeResolution = null;
                              _activeStepIndex = 0;
                            });
                          },
                        )
                      else ...[
                        _buildMethodTab(
                          key: const Key('matrix_bar_2x2'),
                          label: '2×2',
                          selected: _matrixDim == 2,
                          onTap: () {
                            setState(() {
                              _matrixDim = 2;
                              _matrixActiveRow = _matrixActiveRow.clamp(0, 1);
                              _matrixActiveCol = _matrixActiveCol.clamp(0, 1);
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        _buildMethodTab(
                          key: const Key('matrix_bar_3x3'),
                          label: '3×3',
                          selected: _matrixDim == 3,
                          onTap: () {
                            setState(() {
                              _matrixDim = 3;
                            });
                          },
                        ),
                      ],
                      const SizedBox(width: 4),
                      _buildMethodTab(
                        key: const Key('matrix_solve_btn'),
                        label: 'Calcular (${_matrixOp.shortLabel})',
                        selected: true,
                        onTap: _solveCurrentMode,
                      ),
                    ],
                  ),
                ] else if (_calculatorMode == 9) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (_activeResolution != null) ...[
                        _buildMethodTab(
                          key: const Key('vector_edit_btn'),
                          label: 'Editar',
                          selected: false,
                          onTap: () {
                            setState(() {
                              _activeResolution = null;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                      ] else ...[
                        _buildMethodTab(
                          key: const Key('vector_bar_2d'),
                          label: '2D',
                          selected: _vectorDim == 2,
                          onTap: () => _setVectorDim(2),
                        ),
                        const SizedBox(width: 4),
                        _buildMethodTab(
                          key: const Key('vector_bar_3d'),
                          label: '3D',
                          selected: _vectorDim == 3,
                          onTap: () => _setVectorDim(3),
                        ),
                        const SizedBox(width: 4),
                      ],
                      _buildMethodTab(
                        key: const Key('vector_solve_btn'),
                        label: 'Calcular (${_vectorOp.shortLabel})',
                        selected: false,
                        onTap: _solveCurrentMode,
                      ),
                    ],
                  ),
                ] else if (_calculatorMode == 10) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (_activeResolution != null) ...[
                        _buildMethodTab(
                          key: const Key('complex_edit_btn'),
                          label: 'Editar',
                          selected: false,
                          onTap: () {
                            setState(() {
                              _activeResolution = null;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                      _buildMethodTab(
                        key: const Key('complex_polar_btn'),
                        label: 'a+bi→r_α',
                        selected: _complexOp == ComplexOperation.toPolar,
                        onTap: () => _selectComplexOp(ComplexOperation.toPolar),
                      ),
                      const SizedBox(width: 4),
                      _buildMethodTab(
                        key: const Key('complex_solve_btn'),
                        label: 'Calcular',
                        selected: false,
                        onTap: _solveCurrentMode,
                      ),
                    ],
                  ),
                ] else if (_calculatorMode == 11) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (_activeResolution != null) ...[
                        _buildMethodTab(
                          key: const Key('calculus_edit_btn'),
                          label: 'Editar',
                          selected: false,
                          onTap: () {
                            setState(() {
                              _activeResolution = null;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                      ] else ...[
                        _buildMethodTab(
                          key: const Key('calculus_x_btn'),
                          label: 'x',
                          selected: false,
                          onTap: () {
                            setState(() {
                              if (_calculusActiveField != 0) {
                                _calculusActiveField = 0;
                              }
                              _activeResolution = null;
                              _applyRawInsertion('x');
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                      _buildMethodTab(
                        key: const Key('calculus_solve_btn'),
                        label: 'Calcular (${_calculusOp.shortLabel})',
                        selected: false,
                        onTap: _solveCurrentMode,
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 6),

                // =========================================================
                // 2. ZONA DE CONTROL SUPERIOR ERGONÓMICA (3 bloques, D-Pad 108x84)
                // =========================================================
                SizedBox(
                  height: 84,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bloque Izquierdo: Teclas grandes SHIFT y ALPHA
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CompactControlKey(
                                label: 'SHIFT',
                                backgroundColor: const Color(0xFFE5A93C),
                                textColor: Colors.black,
                                isActive: _isShiftActive,
                                onTap: () => _handleKeyPress('SHIFT'),
                              ),
                              const SizedBox(width: 6),
                              _CompactControlKey(
                                label: 'ALPHA',
                                backgroundColor: const Color(0xFFE05252),
                                textColor: Colors.white,
                                isActive: _isAlphaActive,
                                onTap: () => _handleKeyPress('ALPHA'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Bloque Central: D-Pad Cepillado (108x84 px)
                      Center(
                        child: CasioReplayPad(
                          onLeft: _handleDpadLeft,
                          onRight: _handleDpadRight,
                          onUp: _handleDpadUp,
                          onDown: _handleDpadDown,
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Bloque Derecho: Teclas grandes MODE (SETUP) y CALC (OPTN)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CompactControlKey(
                                label: 'MODE',
                                caption: 'SETUP',
                                backgroundColor: const Color(0xFF2E5A50),
                                textColor: Colors.white,
                                isActive: _isMenuOpen || _isSetupOpen,
                                onTap: () => _handleKeyPress('MODE'),
                              ),
                              const SizedBox(width: 6),
                              _CompactControlKey(
                                label: 'CALC',
                                caption: 'OPTN',
                                backgroundColor: const Color(0xFF253042),
                                textColor: Colors.white,
                                onTap: () {
                                  if (_isShiftActive) {
                                    setState(() {
                                      _isShiftActive = false;
                                      _isAlphaActive = false;
                                    });
                                    if (_calculatorMode == 7) {
                                      _openStatOptionsModal();
                                    } else {
                                      _openQuickOptnModal();
                                    }
                                  } else {
                                    _handleKeyPress('CALC');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                // =========================================================
                // 3. RESTO DEL TECLADO 5 COLUMNAS ALINEADAS (Sci 2x5 + Num 4x5)
                // =========================================================
                Expanded(
                  child: Column(
                    children: [
                      // Sci Row 1 (5 cols): a/b, √■, x², log■□, S⬄D
                      Expanded(
                        flex: 48,
                        child: Row(
                          children: [
                            CasioPhysicalKey(
                              label: 'a/b',
                              shiftLabel: 'c a/b',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => _handleKeyPress('/'),
                            ),
                            CasioPhysicalKey(
                              label: '√■',
                              shiftLabel: 'ⁿ√■',
                              alphaLabel: '³√■',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => _handleKeyPress('√'),
                            ),
                            CasioPhysicalKey(
                              label: 'x²',
                              shiftLabel: 'x■',
                              alphaLabel: 'x³',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => _handleKeyPress('^2'),
                            ),
                            CasioPhysicalKey(
                              label: 'log■□',
                              customLabelWidget: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'log',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(0.5, 4.0),
                                    child: Text(
                                      '■',
                                      key: const Key('log_key_subscript_base'),
                                      style: const TextStyle(
                                        color: Color(0xFFCBD5E1),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 1.5),
                                  const Text(
                                    '□',
                                    key: Key('log_key_argument'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              shiftLabel: '10ˣ',
                              alphaLabel: 'ln',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => _handleKeyPress('LOG'),
                            ),
                            CasioPhysicalKey(
                              label: 'S⬄D',
                              backgroundColor: const Color(0xFF343842),
                              minHeight: sciMinH,
                              onTap: () => _handleKeyPress('SD'),
                            ),
                          ],
                        ),
                      ),

                      // Sci Row 2 (5 cols): (, ), sin, cos, tan
                      Expanded(
                        flex: 48,
                        child: Row(
                          children: [
                            CasioPhysicalKey(
                              label: '(',
                              alphaLabel: 'Y',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => _handleKeyPress('('),
                            ),
                            CasioPhysicalKey(
                              label: ')',
                              alphaLabel: 'X',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => _handleKeyPress(')'),
                            ),
                            CasioPhysicalKey(
                              label: 'sin',
                              shiftLabel: 'sin⁻¹',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => _handleKeyPress('sin'),
                            ),
                            CasioPhysicalKey(
                              label: 'cos',
                              shiftLabel: 'cos⁻¹',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => _handleKeyPress('cos'),
                            ),
                            CasioPhysicalKey(
                              label: 'tan',
                              shiftLabel: 'tan⁻¹',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => _handleKeyPress('tan'),
                            ),
                          ],
                        ),
                      ),

                      // Num Row 1: 7, 8, 9, DEL (Azul), AC (Azul)
                      Expanded(
                        flex: 56,
                        child: Row(
                          children: [
                            CasioPhysicalKey(
                              label: '7',
                              alphaLabel: 'A',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('7'),
                            ),
                            CasioPhysicalKey(
                              label: '8',
                              alphaLabel: 'B',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('8'),
                            ),
                            CasioPhysicalKey(
                              label: '9',
                              alphaLabel: 'C',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('9'),
                            ),
                            CasioPhysicalKey(
                              label: 'DEL',
                              backgroundColor: const Color(0xFF2E86DE),
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('DEL'),
                            ),
                            CasioPhysicalKey(
                              label: 'AC',
                              backgroundColor: const Color(0xFF2E86DE),
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('AC'),
                            ),
                          ],
                        ),
                      ),

                      // Num Row 2: 4, 5, 6, × (m.c.m. / M.C.D.), ÷ (FACT)
                      Expanded(
                        flex: 56,
                        child: Row(
                          children: [
                            CasioPhysicalKey(
                              label: '4',
                              alphaLabel: 'D',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('4'),
                            ),
                            CasioPhysicalKey(
                              label: '5',
                              alphaLabel: 'E',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('5'),
                            ),
                            CasioPhysicalKey(
                              label: '6',
                              alphaLabel: 'F',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('6'),
                            ),
                            CasioPhysicalKey(
                              label: '×',
                              shiftLabel: 'm.c.m.',
                              alphaLabel: 'M.C.D.',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('*'),
                            ),
                            CasioPhysicalKey(
                              label: '÷',
                              shiftLabel: 'FACT',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress(':'),
                            ),
                          ],
                        ),
                      ),

                      // Num Row 3: 1, 2, 3, +, -
                      Expanded(
                        flex: 56,
                        child: Row(
                          children: [
                            CasioPhysicalKey(
                              label: '1',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('1'),
                            ),
                            CasioPhysicalKey(
                              label: '2',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('2'),
                            ),
                            CasioPhysicalKey(
                              label: '3',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('3'),
                            ),
                            CasioPhysicalKey(
                              label: '+',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('+'),
                            ),
                            CasioPhysicalKey(
                              label: '-',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('-'),
                            ),
                          ],
                        ),
                      ),

                      // Num Row 4: 0, . (° ' "), ×10ˣ (%), ANS (M+ / M), = (Azul)
                      Expanded(
                        flex: 56,
                        child: Row(
                          children: [
                            CasioPhysicalKey(
                              label: '0',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('0'),
                            ),
                            CasioPhysicalKey(
                              label: '.',
                              shiftLabel: '° \' "',
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress(
                                _isShiftActive ? 'DMS' : '.',
                              ),
                            ),
                            CasioPhysicalKey(
                              label: '×10ˣ',
                              shiftLabel: '%',
                              backgroundColor: const Color(0xFF2B2E36),
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('SCI10'),
                            ),
                            CasioPhysicalKey(
                              label: 'ANS',
                              shiftLabel: 'M+',
                              alphaLabel: 'M',
                              backgroundColor: const Color(0xFF343842),
                              minHeight: numMinH,
                              onTap: () {
                                if (_isShiftActive) {
                                  _isShiftActive = false;
                                  _handleKeyPress('M+');
                                } else if (_isAlphaActive) {
                                  _handleKeyPress('M+');
                                } else {
                                  _handleKeyPress('ANS');
                                }
                              },
                            ),
                            CasioPhysicalKey(
                              label: '=',
                              backgroundColor: const Color(0xFF2E86DE),
                              minHeight: numMinH,
                              onTap: () => _handleKeyPress('='),
                            ),
                          ],
                        ),
                      ),
                    ],
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

  String? get _lcdIdleHint {
    if (_calculatorMode == 2) {
      return 'Escribe a cada lado del = fijo (usa ◀ ▶ o ⇄ Miembro (=)) y pulsa =';
    }
    if (_calculatorMode == 3 && _systemDim == 3) {
      return 'Introduce x, y, z, d con = o D-Pad (vacío=0) y elige Gauss / Cramer';
    }
    if (_calculatorMode == 4 && !_polyIsNotableMode) {
      return _isChoosingRuffiniDegree
          ? 'Elige grado (2.º–6.º): toca una tarjeta, pulsa 2..6 o ◀ ▶ + ='
          : 'Rellena ${_ruffiniDegree + 1} coef. (0 si falta grado) y pulsa =';
    }
    if (_calculatorMode == 6) {
      return _ineqDegree == 1
          ? 'Teclea inecuación (elige < ≤ > ≥ con ▲ ▼ o botón en LCD) y pulsa ='
          : 'Rellena a, b, c; cambia < ≤ > ≥ en la casilla (▲ ▼) o barra y pulsa =';
    }
    if (_calculatorMode == 7) {
      return 'Introduce xi/fi, pulsa = para bajar fila, ◀ ▶ ▲ ▼ moverte y CALC STAT';
    }
    if (_calculatorMode == 8) {
      return 'Rellena celdas (0 si vacío), muévete con D-Pad o = y elige operación en LCD';
    }
    if (_calculatorMode == 9) {
      return 'Elige 2D/3D y operación (|u|, u·v, u×v), edita u y v y pulsa =';
    }
    if (_calculatorMode == 10) {
      return 'Introduce z1 = a + bi y z2 = c + di (o módulo/ángulo en Polar) y pulsa =';
    }
    if (_calculatorMode == 11) {
      return 'Escribe P(x), elige f\'(x), recta tangente o ∫ (Barrow) y pulsa =';
    }
    return null;
  }

  String? get _lcdCustomHeaderTitle {
    if (_calculatorMode == 3 && _systemDim == 3) {
      return 'SISTEMA 3×3 (${_sys3Method.displayName.toUpperCase()})';
    }
    if (_calculatorMode == 4) {
      if (_polyIsNotableMode) {
        return 'IDENTIDADES NOTABLES';
      }
      return _isChoosingRuffiniDegree
          ? 'ELIGE GRADO DE P(x)'
          : 'RUFFINI GRADO $_ruffiniDegree';
    }
    if (_calculatorMode == 6) {
      return _ineqDegree == 1
          ? 'INECUACIÓN 1.º GRADO'
          : 'INECUACIÓN 2.º GRADO';
    }
    if (_calculatorMode == 7) {
      return 'ESTADÍSTICA 1-VAR';
    }
    if (_calculatorMode == 8) {
      return 'MATRICES $_matrixDim×$_matrixDim';
    }
    if (_calculatorMode == 9) {
      return 'VECTORES ${_vectorDim}D (${_vectorOp.shortLabel})';
    }
    if (_calculatorMode == 10) {
      return 'COMPLEJOS (${_complexOp.shortLabel})';
    }
    if (_calculatorMode == 11) {
      return 'CÁLCULO (${_calculusOp.shortLabel})';
    }
    return null;
  }

  void _showOptnBottomSheet({
    required String title,
    required List<Widget> Function(BuildContext sheetContext) itemsBuilder,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...itemsBuilder(ctx),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openQuickOptnModal() {
    _showOptnBottomSheet(
      title: 'OPTN · Opciones Rápidas (STEP-BY-STEP LD)',
      itemsBuilder: (ctx) => [
        if (_calculatorMode == 1)
          ListTile(
            leading: const Icon(Icons.functions_rounded, color: Color(0xFFFBBF24)),
            title: const Text(
              'CALC · Evaluar expresión para x = ?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(ctx);
              setState(_enterCalcPromptSync);
            },
          ),
        ListTile(
          leading: const Icon(Icons.rotate_right_rounded, color: Color(0xFF38BDF8)),
          title: Text(
            'Unidad angular: cambiar a ${_angleUnit == AngleUnit.deg ? 'RAD' : 'DEG'}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _toggleAngleUnit();
          },
        ),
        ListTile(
          leading: const Icon(Icons.image_outlined, color: Color(0xFF2DD4BF)),
          title: const Text(
            'Exportar desarrollo a PNG transparente',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _openStickerExport();
          },
        ),
        ListTile(
          leading: const Icon(Icons.code_rounded, color: Color(0xFF818CF8)),
          title: const Text(
            'Copiar bloque LaTeX al portapapeles',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _copyLatexToClipboardShortcut();
          },
        ),
      ],
    );
  }

  void _openStatOptionsModal() {
    _showOptnBottomSheet(
      title: 'OPTN · Estadística 1-Var (STEP-BY-STEP LD)',
      itemsBuilder: (ctx) => [
        ListTile(
          leading: const Icon(Icons.calculate_rounded, color: Color(0xFF38BDF8)),
          title: const Text(
            '1: Cálculo de 1 variable (CALC STAT)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Tabla de frecuencias, x̄, σ², σ, Mo, Me, Q₁, Q₃',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _solveCurrentMode();
          },
        ),
        ListTile(
          leading: const Icon(Icons.sticky_note_2_rounded, color: Color(0xFF2DD4BF)),
          title: const Text(
            '2: Exportar Tabla y Pasos a PNG',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _openStickerExport();
          },
        ),
        ListTile(
          leading: const Icon(Icons.code_rounded, color: Color(0xFF818CF8)),
          title: const Text(
            '3: Copiar Bloque LaTeX al Portapapeles',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _copyLatexToClipboardShortcut();
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFF87171)),
          title: const Text(
            '4: Vaciar tabla (AC)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          onTap: () {
            Navigator.pop(ctx);
            setState(() {
              _statRows = [(xi: '', fi: '')];
              _statActiveRow = 0;
              _statActiveCol = 0;
              _activeResolution = null;
              _activeStepIndex = 0;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRuffiniDegreeSelector() {
    const supDegrees = {2: 'x²', 3: 'x³', 4: 'x⁴', 5: 'x⁵', 6: 'x⁶'};
    final textColor =
        _isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF101815);
    final unselectedBg =
        _isOledDark ? const Color(0xFF1E293B) : const Color(0xFFC8D6CD);
    final unselectedBorder =
        _isOledDark ? const Color(0xFF334155) : const Color(0xFF7A8C80);
    final selectedBg =
        _isOledDark ? const Color(0xFF2563EB) : const Color(0xFF1E3A5F);

    return LayoutBuilder(
      builder: (context, constraints) {
        final safeWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 320.0;
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: safeWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selecciona el grado del polinomio P(x):',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (int deg = 2; deg <= 6; deg++) ...[
                        if (deg > 2) const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            key: Key('ruffini_degree_$deg'),
                            onTap: () {
                              setState(() {
                                _setRuffiniDegree(deg, enterTemplate: true);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _ruffiniDegree == deg
                                    ? selectedBg
                                    : unselectedBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _ruffiniDegree == deg
                                      ? const Color(0xFF60A5FA)
                                      : unselectedBorder,
                                  width: _ruffiniDegree == deg ? 1.8 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$deg.º',
                                    style: TextStyle(
                                      color: _ruffiniDegree == deg
                                          ? Colors.white
                                          : textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    supDegrees[deg]!,
                                    style: TextStyle(
                                      color: _ruffiniDegree == deg
                                          ? const Color(0xFFDBEAFE)
                                          : textColor.withValues(alpha: 0.78),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMethodTab({
    Key? key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFF2A2E37),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? const Color(0xFF60A5FA)
                  : const Color(0xFF3B4252),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactControlKey extends StatefulWidget {
  final String label;
  final String? caption;
  final Color backgroundColor;
  final Color textColor;
  final bool isActive;
  final VoidCallback onTap;

  const _CompactControlKey({
    required this.label,
    this.caption,
    required this.backgroundColor,
    required this.textColor,
    this.isActive = false,
    required this.onTap,
  });

  @override
  State<_CompactControlKey> createState() => _CompactControlKeyState();
}

class _CompactControlKeyState extends State<_CompactControlKey> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder =
        widget.isActive ? Colors.white : const Color(0xFF494E5B);

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          HapticFeedback.lightImpact();
          KeyClickSound.playControl();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          transform: Matrix4.translationValues(0.0, _isPressed ? 1.5 : 0.0, 0.0),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: effectiveBorder,
              width: widget.isActive ? 1.6 : 1.0,
            ),
            boxShadow: _isPressed
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x99000000),
                      offset: Offset(0, 2.5),
                      blurRadius: 1.5,
                    ),
                  ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.caption != null)
                  Text(
                    widget.caption!,
                    style: const TextStyle(
                      color: Color(0xFFE5A93C),
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBezelButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final Color accentColor;
  final VoidCallback onPressed;

  const _HeaderBezelButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.accentColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF1F232B),
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: const Color(0xFF353C49),
                width: 1.0,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: accentColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarbonTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1.0;

    const step = 10.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = (y ~/ step).isEven ? 0.0 : step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
