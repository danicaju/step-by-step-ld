import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/latex_plain_text.dart';
import '../casio_lcd_screen.dart';
import '../common/lcd_scroll_body.dart';
import '../safe_math.dart';
import 'lcd_blinking_latex.dart';
import 'lcd_copyable_result.dart';
import 'lcd_palette.dart';
import 'lcd_step_formula.dart';

/// Rama principal de la LCD: barra de estado FIJA + cuerpo con scroll vertical
/// ([LcdScrollBody]) con cabecera de selectores, entrada, formula/editor y nota.
class LcdStepsBody extends StatelessWidget {
  final CasioLcdScreen screen;
  final LcdPalette palette;
  final bool hasSteps;
  final String displayLatex;
  final String stepTitle;
  final String pedagogicalNote;
  final String? warningTrick;
  final bool isMultiLineLatex;
  final double latexFontSize;

  const LcdStepsBody({
    super.key,
    required this.screen,
    required this.palette,
    required this.hasSteps,
    required this.displayLatex,
    required this.stepTitle,
    required this.pedagogicalNote,
    required this.warningTrick,
    required this.isMultiLineLatex,
    required this.latexFontSize,
  });

  /// Aproximacion del alto de la barra de estado: los umbrales historicos se median
  /// sobre la LCD completa, el cuerpo scrolleable ya no la incluye.
  static const double _statusAllowance = 24;

  @override
  Widget build(BuildContext context) {
    final s = screen;
    return LayoutBuilder(
      builder: (context, outer) {
        final bool visualFirst = hasSteps &&
            s.supplementaryVisualView != null &&
            s.supplementaryVisualFlex >= 8;
        final bool wrapHeader =
            s.headerCanWrap && outer.maxWidth < CasioLcdScreen.wrapMaxWidth;
        final Widget? header =
            visualFirst ? null : s.headerSelectorsBuilder?.call(wrapHeader);
        final double headerExtra = header == null ? 0.0 : (wrapHeader ? 56.0 : 30.0);
        // Alto minimo legible del contenido: por debajo se hace scroll en vez de desbordar.
        final double autoMin = (s.supplementaryVisualView != null
                ? 190.0
                : (s.coefficientView != null ? 140.0 : 118.0)) +
            headerExtra;
        final double autoContent = autoMin - _statusAllowance + 10;
        final double minContent = math.max(s.bodyMinHeight ?? 0, autoContent);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LcdStatusBar(
              isShiftActive: s.isShiftActive,
              isAlphaActive: s.isAlphaActive,
              isMemoryActive: s.isMemoryActive,
              showDisp: s.showDisp,
              showSto: s.showSto,
              showIns: s.showIns,
              isRadMode: s.isRadMode,
              angleLabel: s.angleLabel,
              onToggleAngleUnit: s.onToggleAngleUnit,
              modeLabel: s.modeLabel,
              hasSteps: hasSteps,
              activeStepIndex: s.activeStepIndex,
              totalSteps: s.currentResolution?.steps.length ?? 0,
              stepTitle: stepTitle,
              stepTitleColor: palette.title,
              isOledDark: s.isOledDark,
              stepTitleBelow: outer.maxHeight >= 150,
              isSoundMuted: s.isSoundMuted,
              onToggleSound: s.onToggleSound,
              onToggleTheme: s.onToggleTheme,
              onUndo: s.onUndo,
            ),
            Expanded(
              child: LcdScrollBody(
                ink: palette.formula,
                background: palette.background,
                minContentHeight: minContent,
                lockScroll: visualFirst,
                resetKey: (s.modeLabel, s.activeStepIndex, hasSteps),
                builder: (context, bodyH) =>
                    _content(bodyH + _statusAllowance, header, wrapHeader, headerExtra, visualFirst),
              ),
            ),
          ],
        );
      },
    );
  }

  /// [h]: alto equivalente de la LCD completa (cuerpo + barra de estado).
  Widget _content(double h, Widget? header, bool wrapHeader, double headerExtra, bool visualFirst) {
    final s = screen;
    final double maxNoteHeight = (h * 0.34).clamp(28.0, 68.0);
    final double noteCap = wrapHeader ? maxNoteHeight.clamp(28.0, 40.0) : maxNoteHeight;
    final bool showBottomNote = h >= (s.supplementaryVisualView != null ? 190.0 : 118.0) + headerExtra &&
        (s.coefficientView == null || h >= 140.0 + headerExtra);
    final res = s.currentResolution;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header,
        // Expresion de entrada original pequena arriba a la izquierda (como en Casio reales).
        if (hasSteps && h >= 100 && !visualFirst) ...[
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SafeMath.tex(
              CasioLcdScreen.sanitizeForMathTex(res!.originalInputLatex),
              textStyle: TextStyle(fontSize: 14, color: palette.original),
            ),
          ),
        ],
        SizedBox(height: h >= 100 ? 4 : 1),
        Expanded(
          child: s.customBodyView != null && !hasSteps
              ? s.customBodyView!
              : s.coefficientView != null && !hasSteps
                  ? Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) => ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                            maxHeight: constraints.maxHeight,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: s.coefficientView!,
                          ),
                        ),
                      ),
                    )
                  : Stack(children: [_formulaArea(h, visualFirst)]),
        ),
        if (showBottomNote) ...[
          const SizedBox(height: 4),
          LcdPedagogicalBox(
            warningTrick: warningTrick,
            pedagogicalNote: pedagogicalNote,
            maxNoteHeight: noteCap,
            isOledDark: s.isOledDark,
          ),
        ],
      ],
    );
  }

  Widget _formulaArea(double h, bool visualFirst) {
    final s = screen;
    final Color formulaColor = palette.formula;
    final Color backgroundColor = palette.background;
    final res = s.currentResolution;
    if (s.supplementaryVisualView != null && hasSteps) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cleanDisplay = CasioLcdScreen.sanitizeForMathTex(displayLatex);
          return Column(
            children: [
              // Con flex 10 el visual ocupa toda la LCD (recta real en su propio paso).
              if (s.supplementaryVisualFlex < 10)
                Expanded(
                  flex: 10 - s.supplementaryVisualFlex,
                  child: Align(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: LcdBlinkingLatex(
                        isOledDark: s.isOledDark,
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
              if (s.supplementaryVisualFlex < 10) const SizedBox(height: 3),
              Expanded(flex: s.supplementaryVisualFlex, child: s.supplementaryVisualView!),
            ],
          );
        },
      );
    }
    return LcdCopyableResult(
      enabled: hasSteps && s.activeStepIndex == res!.steps.length - 1,
      copyText: LatexPlainText.toPlain(s.showDecimalApprox && res != null
          ? res.decimalApproxLatex
          : (res?.exactResultLatex ?? '')),
      ink: formulaColor,
      background: backgroundColor,
      child: Align(
        alignment: isMultiLineLatex ? Alignment.center : Alignment.centerRight,
        child: hasSteps
            ? LcdStepFormula(
                latex: displayLatex,
                originalLatex: h >= 100 && !visualFirst ? res!.originalInputLatex : null,
                fontSize: latexFontSize,
                color: formulaColor,
                background: backgroundColor,
                centered: isMultiLineLatex,
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final cleanDisplay = CasioLcdScreen.sanitizeForMathTex(displayLatex);
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                      maxHeight: constraints.maxHeight,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment:
                          isMultiLineLatex ? Alignment.center : Alignment.centerRight,
                      child: LcdBlinkingLatex(
                        isOledDark: s.isOledDark,
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
      ),
    );
  }
}
