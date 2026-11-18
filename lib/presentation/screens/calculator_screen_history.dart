part of 'calculator_screen.dart';

extension _CalculatorScreenHistory on _CalculatorScreenState {

  Future<void> _loadHistoryFromStorage() async {
    try {
      final entries = await _historyService.getEntries();
      if (mounted) {
        updateState(() {
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
          !_isChoosingRuffiniDegree &&
          _cw.x.m4View < 2) ||
      (_calculatorMode == 5 && !_m5Custom);

  /// Modos con celdas estructuradas donde solo entran tokens numéricos (`0-9`, `-`, `/`, `.`).
  bool get _isGridOrStructuredMode =>
      _calculatorMode == 8 ||
      _calculatorMode == 9 ||
      _calculatorMode == 10 ||
      _calculatorMode == 11 ||
      (_calculatorMode == 12 && _calculusActiveField != 0);

  /// Verdadero cuando el cursor activo edita una expresión simbólica (`f(x)`, Modo 1, 2, 4 Notables, 6 lineal).
  bool get _supportsExpressionInput =>
      !_isCoefficientMode && !_isGridOrStructuredMode && _calculatorMode != 7;

  /// Verdadero solo en modos de expresión general con funciones científicas (`sin`, `log`, `√`, `mcm`).
  bool get _supportsScientificFns =>
      _supportsExpressionInput && _calculatorMode != 11;

  List<String> get _currentCellValues {
    switch (_calculatorMode) {
      case 3:
        if (_systemDim == 4) return _sys4Values;
        return _systemDim == 3 ? _sys3Values : _sysValues;
      case 4:
        return _ruffiniValues;
      case 5:
        return _graphKind == 1 ? _ratValues : _graphValues;
      default:
        return [];
    }
  }

  List<String> get _currentCellLabels {
    switch (_calculatorMode) {
      case 3:
        if (_systemDim == 4) return _sys4Labels;
        return _systemDim == 3 ? _sys3Labels : _sysLabels;
      case 4:
        return _ruffiniLabels;
      case 5:
        return _graphKind == 1 ? _ratLabels : _graphLabels;
      default:
        return [];
    }
  }

  int get _currentActiveIndex {
    switch (_calculatorMode) {
      case 3:
        if (_systemDim == 4) return _sys4ActiveIndex;
        return _systemDim == 3 ? _sys3ActiveIndex : _sysActiveIndex;
      case 4:
        return _ruffiniActiveIndex;
      case 5:
        return _graphActiveIndex;
      default:
        return 0;
    }
  }

  set _currentActiveIndex(int val) {
    switch (_calculatorMode) {
      case 3:
        if (_systemDim == 4) {
          _sys4ActiveIndex = val;
        } else if (_systemDim == 3) {
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
      case 7:
        return '4.º ESO-Bach.';
      case 8:
        return '2.º-4.º ESO';
      case 9:
      case 10:
      case 11:
      case 12:
        return '1.º-2.º Bach. / EBAU';
      default:
        return 'General';
    }
  }

  void _recordCurrentResolutionToHistory(
      StepByStepResolution res, String modeName) {
    if (_historySuppressed) return;
    final String? savedRawExpr;
    if (_calculatorMode == 2) {
      savedRawExpr = '${_eqLeftRaw.trim()} = ${_eqRightRaw.trim()}';
    } else if (_calculatorMode == 7) {
      savedRawExpr = _ineqSysRowInputs.take(_ineqSysRows).join(', ');
    } else if (_isCoefficientMode ||
        _calculatorMode == 8 ||
        _calculatorMode == 9 ||
        _calculatorMode == 10 ||
        _calculatorMode == 11) {
      savedRawExpr = null;
    } else if (_calculatorMode == 12) {
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
      updateState(() {
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

  Future<void> _copyLatexToClipboardShortcut() async {
    updateState(() {
      _isShiftActive = false;
      _isAlphaActive = false;
    });
    if (_activeResolution == null) {
      if (_isCoefficientMode ||
          _calculatorMode == 8 ||
          _calculatorMode == 9 ||
          _calculatorMode == 10 ||
          _calculatorMode == 11 ||
          (_calculatorMode == 7 && _ineqSysRowInputs.any((r) => r.trim().isNotEmpty)) ||
          (_calculatorMode == 12 && _calculusExprRaw.trim().isNotEmpty) ||
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
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _selectHistoryEntry(ClassHistoryEntry entry) {
    updateState(() {
      _isMenuOpen = false;
      if (entry.calculatorMode != null &&
          entry.calculatorMode! >= 1 &&
          entry.calculatorMode! <= 12) {
        _calculatorMode = entry.calculatorMode!;
      }
      _activeResolution = entry.resolution;
      _activeStepIndex = 0;
      _showDecimalApprox = false;
      final restored = _entryToEditableRaw(entry);
      if (_calculatorMode == 2) {
        _restoreMode2EquationString(restored);
      } else if (_calculatorMode == 7) {
        final rawRows = (entry.rawExpression ?? restored)
            .split(RegExp(r'[;,]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        for (int i = 0; i < _ineqSysRowInputs.length; i++) {
          _ineqSysRowInputs[i] = i < rawRows.length ? rawRows[i] : '';
          _ineqSysRowCursors[i] = _ineqSysRowInputs[i].length;
        }
        _ineqSysRows = rawRows.length.clamp(2, 4);
        _ineqSysUnknowns = (entry.rawExpression ?? restored).contains('y') ? 2 : 1;
        _ineqSysActiveRow = 0;
      } else if (_calculatorMode == 12) {
        _calculusExprRaw = entry.rawExpression ?? '';
        _calculusCursorPos = _calculusExprRaw.length;
      } else {
        _rawInput = restored;
        _cursorPos = _rawInput.length;
        if (_calculatorMode == 6) {
          if (restored.contains('^2') || restored.contains('²')) {
            _ineqDegree = 2;
          } else if (restored.contains('|') || restored.contains('/')) {
            _ineqDegree = 3;
          } else {
            _ineqDegree = 1;
          }
        }
      }
      _replayIndex = -1;
    });

    // Re-evaluar con el motor y vistas visuales actualizadas de la app
    if (_calculatorMode == 1 || _calculatorMode == 2 || _calculatorMode == 6 || _calculatorMode == 7) {
      _solveCurrentMode();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cargado ejercicio de clase: ${entry.modeName}'),
        backgroundColor: const Color(0xFF181E29),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleFavoriteInHistory(String id) async {
    updateState(() {
      _historyEntries = _historyEntries
          .map((e) => e.id == id ? e.copyWith(isFavorite: !e.isFavorite) : e)
          .toList();
    });
    try {
      await _historyService.toggleFavorite(id);
    } catch (_) {}
  }

  Future<void> _deleteEntryFromHistory(String id) async {
    updateState(() {
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
}
