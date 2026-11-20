import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';
import '../theme/calculator_themes.dart';

import '../../domain/math_engine/models/inequality_models.dart';
import '../../domain/math_engine/models/step_resolution.dart';
import '../../domain/math_engine/solvers/function_graph_solver.dart';
import '../../domain/services/class_history_service.dart';
import 'side_panel/side_panel_history_tab.dart';
import 'side_panel/side_panel_chalkboard_view.dart';
/// Panel lateral acoplado estilo Windows Calculator para pantallas anchas (`>= 760 px`).
/// Incluye pestañas para el Historial de Clase en vivo y el Desglose Paso a Paso / Pizarra.
class WindowsSidePanel extends StatelessWidget {
  final int activeTabIndex;
  final ValueChanged<int> onTabChanged;
  final List<ClassHistoryEntry> historyEntries;
  final ClassHistoryService historyService;
  final ValueChanged<ClassHistoryEntry> onSelectHistoryEntry;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onDeleteHistoryEntry;
  final StepByStepResolution? activeResolution;
  final int activeStepIndex;
  final ValueChanged<int> onSelectStep;
  final FunctionAnalysisResult? graphAnalysis;

  /// Datos de la recta real (M6 / M7): se pintan integros en el paso que los muestra.
  final Inequality1DVisualData? ineqVisual;
  final bool isOledDark;
  final VoidCallback onExportSticker;
  final VoidCallback onCopyLatex;
  final VoidCallback onOpenAiTutor;

  const WindowsSidePanel({
    super.key,
    required this.activeTabIndex,
    required this.onTabChanged,
    required this.historyEntries,
    required this.historyService,
    required this.onSelectHistoryEntry,
    required this.onToggleFavorite,
    required this.onDeleteHistoryEntry,
    required this.activeResolution,
    required this.activeStepIndex,
    required this.onSelectStep,
    this.graphAnalysis,
    this.ineqVisual,
    this.isOledDark = false,
    required this.onExportSticker,
    required this.onCopyLatex,
    required this.onOpenAiTutor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _pnl.panel(const Color(0xFF16191E)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _pnl.panel(const Color(0xFF252830)),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _pnl.panel(Color(0x88000000)),
            offset: Offset(0, 12),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra superior de pestañas
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _pnl.panel(Color(0xFF1E222A)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(color: _pnl.panel(Color(0xFF2C323E)), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DockTabButton(
                    label: 'DESGLOSE PASO A PASO',
                    badgeText: activeResolution != null
                        ? '${activeResolution!.steps.length}'
                        : null,
                    selected: activeTabIndex == 1,
                    accentColor: _pnl.panel(const Color(0xFFE5A93C)),
                    onTap: () => onTabChanged(1),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _DockTabButton(
                    label: 'HISTORIAL',
                    badgeText: '${historyEntries.length}',
                    selected: activeTabIndex == 0,
                    accentColor: _pnl.panel(const Color(0xFFE5A93C)),
                    onTap: () => onTabChanged(0),
                  ),
                ),
              ],
            ),
          ),

          // Contenido según pestaña seleccionada
          Expanded(
            child: activeTabIndex == 0
                ? SidePanelHistoryTab(
                    entries: historyEntries,
                    historyService: historyService,
                    onSelectEntry: onSelectHistoryEntry,
                    onToggleFavorite: onToggleFavorite,
                    onDeleteEntry: onDeleteHistoryEntry,
                  )
                : SidePanelChalkboardView(
                    resolution: activeResolution,
                    activeStepIndex: activeStepIndex,
                    onSelectStep: onSelectStep,
                    graphAnalysis: graphAnalysis,
                    ineqVisual: ineqVisual,
                    isOledDark: isOledDark,
                    onExportSticker: onExportSticker,
                    onCopyLatex: onCopyLatex,
                    onOpenAiTutor: onOpenAiTutor,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DockTabButton extends StatelessWidget {
  final String label;
  final String? badgeText;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _DockTabButton({
    required this.label,
    this.badgeText,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _pnl.panel(const Color(0xFF252A34)) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accentColor : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? _pnl.panel(Colors.white) : _pnl.panel(const Color(0xFF94A3B8)),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? accentColor
                      : _pnl.panel(const Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    color: selected && accentColor == _pnl.panel(const Color(0xFFE5A93C))
                        ? Colors.black
                        : _pnl.panel(Colors.white),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

CalculatorHardwareTheme get _pnl => ThemeController.current;
