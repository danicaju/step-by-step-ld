import 'package:flutter/material.dart';

import '../../domain/math_engine/models/step_resolution.dart';
import 'lcd/lcd_math_sanitizer.dart';
import 'lcd/lcd_status_bar.dart';
import 'lcd/lcd_mode_menu.dart';
import 'lcd/lcd_setup_and_submenus.dart';
import 'lcd/lcd_pedagogical_box.dart';
import '../utils/latex_plain_text.dart';
import 'lcd/lcd_copyable_result.dart';
import 'lcd/lcd_blinking_latex.dart';
import 'lcd/lcd_step_formula.dart';
import 'lcd/lcd_palette.dart';

export 'lcd/lcd_math_sanitizer.dart';
export 'lcd/lcd_status_bar.dart';
export 'lcd/lcd_mode_menu.dart';
export 'lcd/lcd_setup_and_submenus.dart';
export 'lcd/lcd_pedagogical_box.dart';
import 'lcd/lcd_edge_arrows.dart';
import 'safe_math.dart';
export 'lcd/lcd_edge_arrows.dart';


class CasioLcdScreen extends StatelessWidget {
  final String currentInputLatex;
  final StepByStepResolution? currentResolution;
  final int activeStepIndex;
  final bool isShiftActive;
  final bool isAlphaActive;
  final bool isMemoryActive;
  final bool showDisp;
  final bool showSto;
  final bool showIns;
  final LcdEdgeFlags? edgeFlags;
  final String? resultOverrideLatex;
  final String calcVarLabel;
  final bool isOledDark;
  final LcdTheme? lcdTheme;
  final bool isSoundMuted;
  final bool showDecimalApprox;
  final String? modeLabel;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onToggleSound;
  final VoidCallback? onUndo;
  final Widget? coefficientView;
  final Widget? customBodyView;
  final String? idleHint;
  final String? customHeaderTitle;
  final bool isMenuOpen;
  final int menuCursorIndex;
  final ValueChanged<int>? onSelectMenuMode;
  final ValueChanged<int>? onMenuCursorChanged;
  final bool isRadMode;
  final String? angleLabel;
  final Widget? setupView;
  final VoidCallback? onToggleAngleUnit;
  final bool isSetupOpen;
  final ValueChanged<int>? onSelectSetupOption;
  final bool isCalcPromptActive;
  final String? calcExpressionLatex;
  final String calcValueRaw;
  final Widget? headerSelectors;

  final Widget? supplementaryVisualView;

  /// Reparto (sobre 10) del alto para [supplementaryVisualView]; el resto es la formula.
  final int supplementaryVisualFlex;

  const CasioLcdScreen({
    super.key,
    required this.currentInputLatex,
    required this.currentResolution,
    required this.activeStepIndex,
    required this.isShiftActive,
    required this.isAlphaActive,
    this.isMemoryActive = false,
    this.showDisp = false,
    this.showSto = false,
    this.showIns = false,
    this.edgeFlags,
    this.resultOverrideLatex,
    this.calcVarLabel = 'x',
    this.isOledDark = false,
    this.lcdTheme,
    this.isSoundMuted = false,
    required this.showDecimalApprox,
    this.modeLabel,
    this.onToggleTheme,
    this.onToggleSound,
    this.onUndo,
    this.coefficientView,
    this.customBodyView,
    this.idleHint,
    this.customHeaderTitle,
    this.isMenuOpen = false,
    this.menuCursorIndex = 0,
    this.onSelectMenuMode,
    this.onMenuCursorChanged,
    this.isRadMode = false,
    this.angleLabel,
    this.setupView,
    this.onToggleAngleUnit,
    this.isSetupOpen = false,
    this.onSelectSetupOption,
    this.isCalcPromptActive = false,
    this.calcExpressionLatex,
    this.calcValueRaw = '',
    this.headerSelectors,
    this.supplementaryVisualView,
    this.supplementaryVisualFlex = 6,
  });

  /// Número de módulos visibles por página en el MENU paginado (2×2).
  /// Número de módulos visibles por página en el MENU paginado (2×2).
  static const int menuItemsPerPage = 4;

  /// Cantidad de entradas en el menú ClassWiz MENU (`1..12`).
  static int get menuItemCount => classWizMenuItems.length;

  /// Cantidad total de páginas del menú ClassWiz (`3`).
  static int get menuPageCount =>
      (classWizMenuItems.length + menuItemsPerPage - 1) ~/ menuItemsPerPage;

  /// Devuelve el identificador de modo (`1..12`) de la casilla [index].
  static int menuModeIdAt(int index) {
    final safeIdx = index.clamp(0, classWizMenuItems.length - 1);
    return classWizMenuItems[safeIdx].modeId;
  }

  /// Devuelve el índice en el menú paginado correspondiente al modo [modeId].
  static int menuIndexForMode(int modeId) {
    final idx = classWizMenuItems.indexWhere((m) => m.modeId == modeId);
    return idx >= 0 ? idx : 0;
  }

  static String sanitizeForMathTex(String latex) =>
      LcdMathSanitizer.sanitizeForMathTex(latex);

  @override
  Widget build(BuildContext context) => _buildLcd(context);

  Widget _buildLcd(BuildContext context) {
    final bool hasSteps =
        currentResolution != null && currentResolution!.steps.isNotEmpty;

    // Si el usuario pulsó S<=>D en el último paso, mostramos el decimal aproximado
    String displayLatex;
    if (hasSteps) {
      final isLastStep = activeStepIndex == currentResolution!.steps.length - 1;
      displayLatex = (isLastStep && resultOverrideLatex != null)
          ? resultOverrideLatex!
          : (isLastStep && showDecimalApprox)
          ? '${currentResolution!.exactResultLatex} \\approx ${currentResolution!.decimalApproxLatex}'
          : currentResolution!.steps[activeStepIndex].latexExpression;
    } else {
      displayLatex = currentInputLatex.isEmpty ? '0' : currentInputLatex;
    }

    final String stepTitle = hasSteps
        ? currentResolution!.steps[activeStepIndex].shortTitle
        : (customHeaderTitle ?? 'NATURAL-V.P.A.M.');

    final String pedagogicalNote = hasSteps
        ? currentResolution!.steps[activeStepIndex].pedagogicalNote
        : (idleHint ?? 'Usa ◀ ▶ tras pulsar = para recorrer cada paso');

    final String? warningTrick = hasSteps
        ? currentResolution!.steps[activeStepIndex].warningTrick
        : null;

    final bool isMultiLineLatex = displayLatex.contains(r'\begin{array}') ||
        displayLatex.contains(r'\begin{cases}') ||
        displayLatex.contains(r'\begin{aligned}') ||
        displayLatex.contains(r'\begin{matrix}');
    final double latexFontSize = isMultiLineLatex ? 18.0 : 25.0;

    final LcdPalette palette = LcdPalette.of(
      lcdTheme ?? (isOledDark ? LcdTheme.night : LcdTheme.classic),
    );
    final Color backgroundColor = palette.background;
    final Color insetTopColor = palette.inset;
    final Color borderColor = palette.border;
    final Color formulaColor = palette.formula;
    final Color originalFormulaColor = palette.original;
    final Color stepTitleColor = palette.title;

    final Widget lcdBody = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(2.5, 3.0, 2.0, 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D10),
        borderRadius: BorderRadius.circular(11.0),
        border: Border.all(color: const Color(0xFF2C313A), width: 1.5),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 8.5),
        decoration: BoxDecoration(
          color: backgroundColor,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: const Alignment(0.0, -0.82),
            colors: [insetTopColor, backgroundColor],
          ),
          borderRadius: BorderRadius.circular(8.5),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: isMenuOpen
            ? LcdModeMenu(
                menuCursorIndex: menuCursorIndex,
                onMenuCursorChanged: onMenuCursorChanged,
                onSelectMenuMode: onSelectMenuMode,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                isMemoryActive: isMemoryActive,
                isOledDark: isOledDark,
                backgroundColor: backgroundColor,
                formulaColor: formulaColor,
                stepTitleColor: stepTitleColor,
              )
            : isSetupOpen
            ? setupView ?? LcdSetupMenu(
                isOledDark: isOledDark,
                isRadMode: isRadMode,
                onSelectSetupOption: onSelectSetupOption,
                formulaColor: formulaColor,
                stepTitleColor: stepTitleColor,
              )
            : isCalcPromptActive
            ? LcdCalcPrompt(
                varLabel: calcVarLabel,
                calcValueRaw: calcValueRaw,
                calcExpressionLatex: calcExpressionLatex,
                formulaColor: formulaColor,
                stepTitleColor: stepTitleColor,
              )
            : LayoutBuilder(
                builder: (context, lcdConstraints) {
                  final double maxNoteHeight = lcdConstraints.maxHeight.isFinite
                      ? (lcdConstraints.maxHeight * 0.34).clamp(28.0, 68.0)
                      : 68.0;
                  // Visual dominante (caja espanola): el dibujo manda, sin selector ni enunciado repetido.
                  final bool visualFirst = hasSteps &&
                      supplementaryVisualView != null &&
                      supplementaryVisualFlex >= 8;
                  final double headerExtra =
                      headerSelectors != null && !visualFirst ? 30.0 : 0.0;
                  final bool showBottomNote = lcdConstraints.maxHeight >=
                          (supplementaryVisualView != null ? 190.0 : 118.0) + headerExtra &&
                      (coefficientView == null ||
                          lcdConstraints.maxHeight >= 140.0 + headerExtra);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LcdStatusBar(
                        isShiftActive: isShiftActive,
                        isAlphaActive: isAlphaActive,
                        isMemoryActive: isMemoryActive,
                        showDisp: showDisp,
                        showSto: showSto,
                        showIns: showIns,
                        isRadMode: isRadMode,
                        angleLabel: angleLabel,
                        onToggleAngleUnit: onToggleAngleUnit,
                        modeLabel: modeLabel,
                        hasSteps: hasSteps,
                        activeStepIndex: activeStepIndex,
                        totalSteps: currentResolution?.steps.length ?? 0,
                        stepTitle: stepTitle,
                        stepTitleColor: stepTitleColor,
                        isOledDark: isOledDark,
                        stepTitleBelow: lcdConstraints.maxHeight >= 150,
                        isSoundMuted: isSoundMuted,
                        onToggleSound: onToggleSound,
                        onToggleTheme: onToggleTheme,
                        onUndo: onUndo,
                      ),
                      if (headerSelectors != null && !visualFirst) headerSelectors!,
          // 2. Expresión de entrada original pequeña arriba a la izquierda (como en Casio reales)
          if (hasSteps && lcdConstraints.maxHeight >= 100 && !visualFirst) ...[
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SafeMath.tex(
                CasioLcdScreen.sanitizeForMathTex(currentResolution!.originalInputLatex),
                textStyle: TextStyle(
                  fontSize: 14,
                  color: originalFormulaColor,
                ),
              ),
            ),
          ],

          SizedBox(height: lcdConstraints.maxHeight >= 100 ? 4 : 1),

          // 3. Expresión principal renderizada en LaTeX, vista personalizada o Plantilla de Coeficientes
          Expanded(
            child: customBodyView != null && !hasSteps
                ? customBodyView!
                : coefficientView != null && !hasSteps
                ? Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                            maxHeight: constraints.maxHeight,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: coefficientView!,
                          ),
                        );
                      },
                    ),
                  )
                : Stack(
                    children: [
                      if (supplementaryVisualView != null && hasSteps)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cleanDisplay =
                                CasioLcdScreen.sanitizeForMathTex(displayLatex);
                            return Column(
                              children: [
                                // Con flex 10 el visual ocupa toda la LCD (recta real en su propio paso).
                                if (supplementaryVisualFlex < 10)
                                Expanded(
                                  flex: 10 - supplementaryVisualFlex,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: LcdBlinkingLatex(
                                        isOledDark: isOledDark,
                                        latex: cleanDisplay,
                                        textStyle: TextStyle(
                                          fontSize: latexFontSize * 0.9,
                                          color: formulaColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (supplementaryVisualFlex < 10) const SizedBox(height: 3),
                                Expanded(
                                  flex: supplementaryVisualFlex,
                                  child: supplementaryVisualView!,
                                ),
                              ],
                            );
                          },
                        )
                      else
                        LcdCopyableResult(
                          enabled: hasSteps && activeStepIndex == currentResolution!.steps.length - 1,
                          copyText: LatexPlainText.toPlain(
                              showDecimalApprox && currentResolution != null
                                  ? currentResolution!.decimalApproxLatex
                                  : (currentResolution?.exactResultLatex ?? '')),
                          ink: formulaColor,
                          background: backgroundColor,
                          child: Align(
                          alignment: isMultiLineLatex
                              ? Alignment.center
                              : Alignment.centerRight,
                          child: hasSteps
                              ? LcdStepFormula(
                                  latex: displayLatex,
                                  originalLatex:
                                      lcdConstraints.maxHeight >= 100 && !visualFirst
                                          ? currentResolution!.originalInputLatex
                                          : null,
                                  fontSize: latexFontSize,
                                  color: formulaColor,
                                  background: backgroundColor,
                                  centered: isMultiLineLatex,
                                )
                              : LayoutBuilder(
                            builder: (context, constraints) {
                              final cleanDisplay =
                                  CasioLcdScreen.sanitizeForMathTex(displayLatex);
                              return ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth,
                                  maxHeight: constraints.maxHeight,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: isMultiLineLatex
                                      ? Alignment.center
                                      : Alignment.centerRight,
                                  child: LcdBlinkingLatex(
                                    isOledDark: isOledDark,
                                    latex: cleanDisplay,
                                    textStyle: TextStyle(
                                      fontSize: latexFontSize,
                                      color: formulaColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )),
                    ],
                  ),
          ),

                      if (showBottomNote) ...[
                        const SizedBox(height: 4),
                        LcdPedagogicalBox(
                          warningTrick: warningTrick,
                          pedagogicalNote: pedagogicalNote,
                          maxNoteHeight: maxNoteHeight,
                          isOledDark: isOledDark,
                        ),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
    final flags = edgeFlags;
    if (flags == null || !flags.any) return lcdBody;
    return Stack(
      children: [
        lcdBody,
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: LcdEdgeArrows(flags: flags, color: formulaColor),
          ),
        ),
      ],
    );
  }
}