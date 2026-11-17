import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../domain/math_engine/models/step_resolution.dart';
import 'lcd/lcd_math_sanitizer.dart';
import 'lcd/lcd_status_bar.dart';
import 'lcd/lcd_mode_menu.dart';
import 'lcd/lcd_setup_and_submenus.dart';
import 'lcd/lcd_pedagogical_box.dart';

export 'lcd/lcd_math_sanitizer.dart';
export 'lcd/lcd_status_bar.dart';
export 'lcd/lcd_mode_menu.dart';
export 'lcd/lcd_setup_and_submenus.dart';
export 'lcd/lcd_pedagogical_box.dart';


class CasioLcdScreen extends StatelessWidget {
  final String currentInputLatex;
  final StepByStepResolution? currentResolution;
  final int activeStepIndex;
  final bool isShiftActive;
  final bool isAlphaActive;
  final bool isMemoryActive;
  final bool isOledDark;
  final bool isSoundMuted;
  final bool showDecimalApprox;
  final String? modeLabel;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onToggleSound;
  final Widget? coefficientView;
  final Widget? customBodyView;
  final String? idleHint;
  final String? customHeaderTitle;
  final bool isMenuOpen;
  final int menuCursorIndex;
  final ValueChanged<int>? onSelectMenuMode;
  final ValueChanged<int>? onMenuCursorChanged;
  final bool isRadMode;
  final VoidCallback? onToggleAngleUnit;
  final bool isSetupOpen;
  final ValueChanged<int>? onSelectSetupOption;
  final bool isCalcPromptActive;
  final String? calcExpressionLatex;
  final String calcValueRaw;
  final Widget? headerSelectors;

  final Widget? supplementaryVisualView;

  const CasioLcdScreen({
    super.key,
    required this.currentInputLatex,
    required this.currentResolution,
    required this.activeStepIndex,
    required this.isShiftActive,
    required this.isAlphaActive,
    this.isMemoryActive = false,
    this.isOledDark = false,
    this.isSoundMuted = false,
    required this.showDecimalApprox,
    this.modeLabel,
    this.onToggleTheme,
    this.onToggleSound,
    this.coefficientView,
    this.customBodyView,
    this.idleHint,
    this.customHeaderTitle,
    this.isMenuOpen = false,
    this.menuCursorIndex = 0,
    this.onSelectMenuMode,
    this.onMenuCursorChanged,
    this.isRadMode = false,
    this.onToggleAngleUnit,
    this.isSetupOpen = false,
    this.onSelectSetupOption,
    this.isCalcPromptActive = false,
    this.calcExpressionLatex,
    this.calcValueRaw = '',
    this.headerSelectors,
    this.supplementaryVisualView,
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
  Widget build(BuildContext context) {
    final bool hasSteps =
        currentResolution != null && currentResolution!.steps.isNotEmpty;

    // Si el usuario pulsó S<=>D en el último paso, mostramos el decimal aproximado
    String displayLatex;
    if (hasSteps) {
      final isLastStep = activeStepIndex == currentResolution!.steps.length - 1;
      displayLatex = (isLastStep && showDecimalApprox)
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

    final Color backgroundColor =
        isOledDark ? const Color(0xFF111615) : const Color(0xFFDDE6DF);
    final Color insetTopColor =
        isOledDark ? const Color(0xFF0A0D0C) : const Color(0xFFC2CFC6);
    final Color borderColor =
        isOledDark ? const Color(0xFF27322E) : const Color(0xFF5D6B62);
    final Color formulaColor =
        isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A);
    final Color originalFormulaColor =
        isOledDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final Color stepTitleColor =
        isOledDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);

    return Container(
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
            ? LcdSetupMenu(
                isOledDark: isOledDark,
                isRadMode: isRadMode,
                onSelectSetupOption: onSelectSetupOption,
                formulaColor: formulaColor,
                stepTitleColor: stepTitleColor,
              )
            : isCalcPromptActive
            ? LcdCalcPrompt(
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
                  final bool showBottomNote = lcdConstraints.maxHeight >=
                          (supplementaryVisualView != null ? 190.0 : 118.0) &&
                      (coefficientView == null || lcdConstraints.maxHeight >= 140.0);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LcdStatusBar(
                        isShiftActive: isShiftActive,
                        isAlphaActive: isAlphaActive,
                        isMemoryActive: isMemoryActive,
                        isRadMode: isRadMode,
                        onToggleAngleUnit: onToggleAngleUnit,
                        modeLabel: modeLabel,
                        hasSteps: hasSteps,
                        activeStepIndex: activeStepIndex,
                        totalSteps: currentResolution?.steps.length ?? 0,
                        stepTitle: stepTitle,
                        stepTitleColor: stepTitleColor,
                        isOledDark: isOledDark,
                        isSoundMuted: isSoundMuted,
                        onToggleSound: onToggleSound,
                        onToggleTheme: onToggleTheme,
                      ),
                      if (headerSelectors != null) headerSelectors!,
          // 2. Expresión de entrada original pequeña arriba a la izquierda (como en Casio reales)
          if (hasSteps) ...[
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                CasioLcdScreen.sanitizeForMathTex(currentResolution!.originalInputLatex),
                textStyle: TextStyle(
                  fontSize: 14,
                  color: originalFormulaColor,
                ),
                onErrorFallback: (err) => Text(
                  currentResolution!.originalInputLatex,
                  style: TextStyle(
                    fontSize: 12,
                    color: originalFormulaColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 4),

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
                                Expanded(
                                  flex: 4,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Math.tex(
                                        cleanDisplay,
                                        textStyle: TextStyle(
                                          fontSize: latexFontSize * 0.9,
                                          color: formulaColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        onErrorFallback: (err) => Text(
                                          cleanDisplay,
                                          style: TextStyle(
                                            fontSize: latexFontSize * 0.7,
                                            color: formulaColor,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Expanded(
                                  flex: 6,
                                  child: supplementaryVisualView!,
                                ),
                              ],
                            );
                          },
                        )
                      else
                        Align(
                          alignment: isMultiLineLatex
                              ? Alignment.center
                              : Alignment.centerRight,
                          child: LayoutBuilder(
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
                                  child: Math.tex(
                                    cleanDisplay,
                                    textStyle: TextStyle(
                                      fontSize: latexFontSize,
                                      color: formulaColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    onErrorFallback: (err) => Text(
                                      cleanDisplay,
                                      style: TextStyle(
                                        fontSize: latexFontSize * 0.75,
                                        color: formulaColor,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
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
  }
}