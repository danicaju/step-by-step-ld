import 'package:flutter/material.dart';

import '../../domain/math_engine/models/step_resolution.dart';
import 'common/lcd_scroll_body.dart';
import 'lcd/lcd_math_sanitizer.dart';
import 'lcd/lcd_mode_menu.dart';
import 'lcd/lcd_setup_and_submenus.dart';
import 'lcd/lcd_palette.dart';
import 'lcd/lcd_steps_body.dart';
import 'lcd/lcd_edge_arrows.dart';

export 'lcd/lcd_math_sanitizer.dart';
export 'lcd/lcd_status_bar.dart';
export 'lcd/lcd_mode_menu.dart';
export 'lcd/lcd_setup_and_submenus.dart';
export 'lcd/lcd_pedagogical_box.dart';
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
  /// Construye la cabecera de selectores; `wrap` indica si debe ir en varias filas.
  final Widget? Function(bool wrap)? headerSelectorsBuilder;

  /// La cabecera puede pasar a 2 filas (Wrap) en LCD estrecha y suficientemente alta.
  final bool headerCanWrap;

  /// Ancho maximo de la LCD para usar la cabecera en 2 filas (el scroll absorbe el alto).
  static const double wrapMaxWidth = 480;

  /// Alto minimo (sin barra de estado) que necesita el cuerpo; por debajo scrollea.
  final double? bodyMinHeight;

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
    this.headerSelectorsBuilder,
    this.headerCanWrap = false,
    this.supplementaryVisualView,
    this.supplementaryVisualFlex = 6,
    this.bodyMinHeight,
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

  /// Menu MODE / SETUP / CALC dentro del scroll vertical de la LCD.
  Widget _scrolled(String id, double minH, LcdPalette palette, Widget child) =>
      LcdScrollBody(
        ink: palette.formula,
        background: palette.background,
        minContentHeight: minH,
        resetKey: id,
        builder: (context, h) => child,
      );

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
            ? _scrolled(
                'menu',
                0,
                palette,
                LcdModeMenu(
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
              ))
            : isSetupOpen
            ? setupView ?? _scrolled(
                'setup',
                120,
                palette,
                LcdSetupMenu(
                isOledDark: isOledDark,
                isRadMode: isRadMode,
                onSelectSetupOption: onSelectSetupOption,
                formulaColor: formulaColor,
                stepTitleColor: stepTitleColor,
              ))
            : isCalcPromptActive
            ? _scrolled(
                'calc',
                100,
                palette,
                LcdCalcPrompt(
                varLabel: calcVarLabel,
                calcValueRaw: calcValueRaw,
                calcExpressionLatex: calcExpressionLatex,
                formulaColor: formulaColor,
                stepTitleColor: stepTitleColor,
              ))
            : LcdStepsBody(
                screen: this,
                palette: palette,
                hasSteps: hasSteps,
                displayLatex: displayLatex,
                stepTitle: stepTitle,
                pedagogicalNote: pedagogicalNote,
                warningTrick: warningTrick,
                isMultiLineLatex: isMultiLineLatex,
                latexFontSize: latexFontSize,
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