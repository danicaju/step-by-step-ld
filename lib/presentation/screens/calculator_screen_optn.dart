part of 'calculator_screen.dart';

extension _CalculatorScreenOptn on _CalculatorScreenState {
  void _showOptnBottomSheet({
    required String title,
    required List<Widget> Function(BuildContext sheetContext) itemsBuilder,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2530),
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
        if (_calculatorMode == 1 || _calculatorMode == 12)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (label, token) in const [
                ('|x|', 'Abs('),
                ('n!', '!'),
                ('nCr', 'nCr'),
                ('nPr', 'nPr'),
                ('ℯ', 'ℯ'),
                ('Ran#', 'Ran#'),
                ('RanInt#', 'RanInt#('),
              ])
                OutlinedButton(
                  key: Key('optn_insert_$token'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE5A93C),
                    side: const BorderSide(color: Color(0xFFE5A93C)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    updateState(() {
                      if (_activeResolution != null) _clearActiveResolutionCursor();
                      _applyRawInsertion(token);
                    });
                  },
                  child: Text(label),
                ),
            ],
          ),
        if (_calculatorMode == 1)
          ListTile(
            leading: const Icon(Icons.functions_rounded, color: Color(0xFFFBBF24)),
            title: const Text(
              'CALC · Evaluar expresión para x = ?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(ctx);
              updateState(_enterCalcPromptSync);
            },
          ),
        ListTile(
          leading: const Icon(Icons.rotate_right_rounded, color: Color(0xFFE5A93C)),
          title: Text(
            'Unidad angular: $_angleLabel (cambiar)',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _toggleAngleUnit();
          },
        ),
        ListTile(
          leading: const Icon(Icons.image_outlined, color: Color(0xFFE5A93C)),
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
          leading: const Icon(Icons.code_rounded, color: Color(0xFFE5A93C)),
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
}

const List<LcdListItem> _ibrItems = [
  LcdListItem('Per(', 'Periódico ► Fracción', detail: 'Per(2.1,6)'),
  LcdListItem('÷R', 'División con resto', detail: '17 ÷R 5'),
  LcdListItem('nCr', 'Combinaciones nCr'),
  LcdListItem('nPr', 'Variaciones nPr'),
  LcdListItem('!', 'Factorial x!'),
  LcdListItem('prop:0', 'Regla de 3 Directa'),
  LcdListItem('prop:1', 'Regla de 3 Inversa'),
  LcdListItem('prop:2', 'Factores de Conversión'),
];

/// Formulario de Regla de 3 / Factores de conversion (OPTN > Arsenal Iberia de M1).
extension _CalculatorScreenIberia on _CalculatorScreenState {
  void _openProportion(int mode) {
    _cw.list = null;
    _activeResolution = null;
    _activeStepIndex = 0;
    _lcdErrorKind = null;
    _cw.prop = ProportionFormState()..mode = mode;
  }

  Widget _buildPropWidget() {
    final f = _cw.prop!;
    return ProportionConversionWidget(
      form: f,
      theme: _lcdTheme,
      boundsKey: _lcdBoundsKey,
      onModeChanged: (m) => updateState(() => f.setMode(m)),
      onFocus: (i) => updateState(() => f.focus = i),
    );
  }

  void _propDpad(String dir) => _cw.prop!.dpad(dir);

  /// Teclado fisico con el formulario abierto. Siempre consume la pulsacion.
  bool _handlePropKey(String key) {
    final f = _cw.prop!;
    _isShiftActive = false;
    _isAlphaActive = false;
    if (_lcdErrorKind != null) {
      if (key == 'AC') _lcdErrorKind = null;
      return true;
    }
    if (key == 'AC') {
      _cw.prop = null;
      return true;
    }
    if (key == '=') {
      if (f.focus < 0) {
        f.ctrl.open();
      } else if (f.focus < 2) {
        f.focus++;
      } else {
        _solveProportion();
      }
      return true;
    }
    final isUnit = f.isConversion && f.focus > 0;
    if (f.focus < 0 || isUnit) return true;
    final cur = f.cells[f.focus];
    if (key == 'DEL') {
      if (cur.isNotEmpty) f.cells[f.focus] = cur.substring(0, cur.length - 1);
    } else if (RegExp(r'^[0-9]$').hasMatch(key) || key == '.' || key == '-' || key == '/') {
      f.cells[f.focus] = _appendTokenToNumericCell(cur, key);
    }
    return true;
  }

  void _solveProportion() {
    final f = _cw.prop!;
    try {
      final StepByStepResolution res;
      if (f.isConversion) {
        res = ConversionFactorSolver.solve(
          ProportionSolver.parseQuantity(f.cells[0]),
          ConversionCatalog.units[f.fromIdx],
          ConversionCatalog.units[f.toIdx],
        );
      } else {
        final a = ProportionSolver.parseQuantity(f.cells[0]);
        final b = ProportionSolver.parseQuantity(f.cells[1]);
        final c = ProportionSolver.parseQuantity(f.cells[2]);
        res = f.mode == 0 ? ProportionSolver.direct(a, b, c) : ProportionSolver.inverse(a, b, c);
      }
      final label = ['REGLA3 DIRECTA', 'REGLA3 INVERSA', 'CONVERSION'][f.mode];
      _cw.prop = null;
      _activeResolution = res;
      _activeStepIndex = 0;
      _showDecimalApprox = false;
      _recordCurrentResolutionToHistory(res, 'M1: $label');
    } on ArsenalException catch (e) {
      _showLcdError(e.message);
    }
  }
}
