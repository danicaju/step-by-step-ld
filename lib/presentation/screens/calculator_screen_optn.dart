part of 'calculator_screen.dart';

extension _CalculatorScreenOptn on _CalculatorScreenState {
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
              updateState(_enterCalcPromptSync);
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
            updateState(() {
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
}
