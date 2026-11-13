import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../domain/math_engine/models/step_resolution.dart';

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
  final String? inequalitySignBadge;
  final VoidCallback? onCycleInequalitySign;

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
    this.inequalitySignBadge,
    this.onCycleInequalitySign,
  });

  /// Número de módulos visibles por página en el MENU paginado (2×2).
  static const int menuItemsPerPage = 4;

  /// Cantidad de entradas en el menú ClassWiz MENU (`1..11`).
  static int get menuItemCount => _classWizMenuItems.length;

  /// Cantidad total de páginas del menú ClassWiz (`3`).
  static int get menuPageCount =>
      (_classWizMenuItems.length + menuItemsPerPage - 1) ~/ menuItemsPerPage;

  /// Devuelve el identificador de modo (`1..11`) de la casilla [index].
  static int menuModeIdAt(int index) {
    final safeIdx = index.clamp(0, _classWizMenuItems.length - 1);
    return _classWizMenuItems[safeIdx].modeId;
  }

  /// Devuelve el índice en el menú paginado correspondiente al modo [modeId].
  static int menuIndexForMode(int modeId) {
    final idx = _classWizMenuItems.indexWhere((m) => m.modeId == modeId);
    return idx >= 0 ? idx : 0;
  }

  static String sanitizeForMathTex(String latex) {
    if (latex.isEmpty) return '0';
    String clean = latex.replaceAll('\r', '');
    // Normalizar superíndices unicode que no reconoce directamente flutter_math_fork
    clean = clean
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('⁴', '^4')
        .replaceAll('⁵', '^5')
        .replaceAll('⁶', '^6');
    // Normalizar tildes, caracteres no ASCII y guiones bajos en bloques \text{...} para blindar flutter_math_fork
    clean = clean.replaceAllMapped(RegExp(r'\\text\{([^}]+)\}'), (m) {
      final inner = m[1]!
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u')
          .replaceAll('Á', 'A')
          .replaceAll('É', 'E')
          .replaceAll('Í', 'I')
          .replaceAll('Ó', 'O')
          .replaceAll('Ú', 'U')
          .replaceAll('ñ', 'n')
          .replaceAll('Ñ', 'N')
          .replaceAll('¡', '')
          .replaceAll('¿', '')
          .replaceAll('_', ' ');
      return '\\text{$inner}';
    });

    // BLINDAJE CRÍTICO CONTRA CrNode EN flutter_math_fork:
    // Si la cadena contiene saltos de fila (\\ o \\[...pt] o \newline o \cr)
    // pero NO está envuelta en un entorno válido (aligned, array, matrix, cases),
    // flutter_math_fork genera un nodo temporal CrNode no resuelto que lanza UnsupportedError.
    final bool hasRowBreaks = clean.contains(r'\\') ||
        clean.contains(r'\newline') ||
        clean.contains(r'\cr');
    final bool hasEnvironment = clean.contains(r'\begin{array}') ||
        clean.contains(r'\begin{cases}') ||
        clean.contains(r'\begin{matrix}') ||
        clean.contains(r'\begin{aligned}') ||
        clean.contains(r'\begin{gathered}');

    if (hasRowBreaks && !hasEnvironment) {
      // Normalizar \newline o \cr a \\
      clean = clean.replaceAll(r'\newline', r'\\').replaceAll(r'\cr', r'\\');
      // Quitar posibles \\ finales sueltos que rompen el parser
      clean = clean.trim();
      while (clean.endsWith(r'\\')) {
        clean = clean.substring(0, clean.length - 2).trim();
      }
      if (clean.isNotEmpty) {
        clean = '\\begin{aligned} $clean \\end{aligned}';
      } else {
        clean = '0';
      }
    }

    return clean;
  }

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

    // Caja pedagógica
    final Color warningBg = isOledDark
        ? (warningTrick != null ? const Color(0xFF450A0A) : const Color(0xFF1A2220))
        : (warningTrick != null ? const Color(0xFFFEE2E2) : const Color(0xFFCBD5CE));
    final Color warningBorder = isOledDark
        ? (warningTrick != null ? const Color(0xFFDC2626) : const Color(0xFF33413E))
        : (warningTrick != null ? const Color(0xFFDC2626) : const Color(0xFF94A39B));
    final Color warningTextColor = isOledDark
        ? (warningTrick != null ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0))
        : (warningTrick != null ? const Color(0xFF991B1B) : const Color(0xFF1E293B));
    final Color warningIconColor = isOledDark
        ? (warningTrick != null ? const Color(0xFFEF4444) : const Color(0xFF38BDF8))
        : (warningTrick != null ? const Color(0xFFB91C1C) : const Color(0xFF1E293B));

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
          ? _buildClassWizMenu(
              context,
              backgroundColor,
              formulaColor,
              stepTitleColor,
            )
          : isSetupOpen
          ? _buildSetupMenu(formulaColor, stepTitleColor)
          : isCalcPromptActive
          ? _buildCalcPrompt(formulaColor, stepTitleColor)
          : LayoutBuilder(
              builder: (context, lcdConstraints) {
                final double maxNoteHeight = lcdConstraints.maxHeight.isFinite
                    ? (lcdConstraints.maxHeight * 0.34).clamp(28.0, 68.0)
                    : 68.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
          // 1. Barra de estado superior de la LCD
          Row(
            children: [
              _StatusBadge(
                label: 'S',
                active: isShiftActive,
                activeColor: const Color(0xFFD99B26),
                isOledDark: isOledDark,
              ),
              const SizedBox(width: 4),
              _StatusBadge(
                label: 'A',
                active: isAlphaActive,
                activeColor: const Color(0xFFD64545),
                isOledDark: isOledDark,
              ),
              const SizedBox(width: 4),
              _StatusBadge(
                label: 'M',
                active: isMemoryActive,
                activeColor: const Color(0xFF10B981),
                isOledDark: isOledDark,
              ),
              const SizedBox(width: 4),
              InkWell(
                key: const Key('lcd_angle_badge'),
                onTap: onToggleAngleUnit,
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRadMode
                        ? const Color(0xFF7C3AED)
                        : (isOledDark ? const Color(0xFF1E2925) : const Color(0xFF334155)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    isRadMode ? 'RAD' : 'DEG',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              if (modeLabel != null) ...[
                Flexible(
                  fit: FlexFit.loose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        modeLabel!,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              if (hasSteps)
                Flexible(
                  fit: FlexFit.loose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'PASO ${activeStepIndex + 1}/${currentResolution!.steps.length}',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      stepTitle,
                      maxLines: 1,
                      style: TextStyle(
                        color: stepTitleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (onToggleSound != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: isSoundMuted
                      ? 'Activar clic de teclas'
                      : 'Silenciar clic de teclas',
                  child: InkWell(
                    key: const Key('lcd_sound_toggle'),
                    onTap: onToggleSound,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      isSoundMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      size: 15,
                      color: isSoundMuted
                          ? const Color(0xFF94A3B8)
                          : (isOledDark
                              ? const Color(0xFF2DD4BF)
                              : const Color(0xFF0F766E)),
                    ),
                  ),
                ),
              ],
              if (onToggleTheme != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: isOledDark ? 'LCD Verde Clásico' : 'LCD OLED Oscuro',
                  child: InkWell(
                    key: const Key('lcd_theme_toggle'),
                    onTap: onToggleTheme,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.contrast_rounded,
                      size: 15,
                      color: isOledDark
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ],
          ),

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
                      if (inequalitySignBadge != null && !hasSteps)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: InkWell(
                            key: const Key('lcd_ineq_sign_btn'),
                            onTap: onCycleInequalitySign,
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isOledDark
                                    ? const Color(0xFF1E3A8A)
                                    : const Color(0xFF1E40AF),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: const Color(0xFF60A5FA),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                'Signo: $inequalitySignBadge ▾',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          const SizedBox(height: 4),

          // 4. Caja inferior de explicación pedagógica o alerta de examen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: warningBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: warningBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  warningTrick != null
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline_rounded,
                  size: 15,
                  color: warningIconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxNoteHeight),
                    child: SingleChildScrollView(
                      child: Text(
                        warningTrick ?? pedagogicalNote,
                        style: TextStyle(
                          color: warningTextColor,
                          fontSize: 11.5,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
    );
  }

  Widget _buildClassWizMenu(
    BuildContext context,
    Color backgroundColor,
    Color formulaColor,
    Color stepTitleColor,
  ) {
    final safeCursor = menuCursorIndex.clamp(0, _classWizMenuItems.length - 1);
    final selectedItem = _classWizMenuItems[safeCursor];
    final int currentPage = safeCursor ~/ menuItemsPerPage;
    final int totalPages = menuPageCount;
    final int pageStart = currentPage * menuItemsPerPage;

    void goToPage(int delta) {
      final nextPage = (currentPage + delta + totalPages) % totalPages;
      onMenuCursorChanged?.call(nextPage * menuItemsPerPage);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra de estado superior del menú con paginador PÁGINA X/3 ◀ ▶
        Row(
          children: [
            _StatusBadge(
              label: 'S',
              active: isShiftActive,
              activeColor: const Color(0xFFD99B26),
              isOledDark: isOledDark,
            ),
            const SizedBox(width: 4),
            _StatusBadge(
              label: 'A',
              active: isAlphaActive,
              activeColor: const Color(0xFFD64545),
              isOledDark: isOledDark,
            ),
            const SizedBox(width: 4),
            _StatusBadge(
              label: 'M',
              active: isMemoryActive,
              activeColor: const Color(0xFF10B981),
              isOledDark: isOledDark,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isOledDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'MENU',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              key: const Key('menu_page_prev'),
              onTap: () => goToPage(-1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '◀',
                  style: TextStyle(
                    color: formulaColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Text(
              'PÁGINA ${currentPage + 1}/$totalPages',
              key: const Key('menu_page_indicator'),
              style: TextStyle(
                color: formulaColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
            GestureDetector(
              key: const Key('menu_page_next'),
              onTap: () => goToPage(1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '▶',
                  style: TextStyle(
                    color: formulaColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Cuadrícula 2×2 espaciosa y legible (4 módulos por página)
        Expanded(
          child: Column(
            children: [
              for (int row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: 6),
                Expanded(
                  child: Row(
                    children: [
                      for (int col = 0; col < 2; col++) ...[
                        if (col > 0) const SizedBox(width: 6),
                        Expanded(
                          child: (pageStart + row * 2 + col) < _classWizMenuItems.length
                              ? _buildMenuTile(pageStart + row * 2 + col, formulaColor)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Barra inferior con el nombre del modo seleccionado y ayuda de navegación
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOledDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5CE),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isOledDark ? const Color(0xFF334155) : const Color(0xFF94A39B),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    selectedItem.fullTitle,
                    style: TextStyle(
                      color: formulaColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '[◀ ▶] o [1-9, =]',
                style: TextStyle(
                  color: formulaColor.withValues(alpha: 0.72),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile(int index, Color formulaColor) {
    final item = _classWizMenuItems[index];
    final bool isSelected = index == menuCursorIndex;
    final Color fg = isSelected
        ? (isOledDark ? Colors.black : Colors.white)
        : formulaColor;

    return InkWell(
      key: Key('menu_mode_${item.modeId}'),
      onTap: () => onSelectMenuMode?.call(item.modeId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isOledDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A))
              : (isOledDark
                  ? const Color(0xFF1A2220)
                  : const Color(0xFFCBD5CE).withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? (isOledDark ? Colors.white : const Color(0xFF0F172A))
                : (isOledDark ? const Color(0xFF27322E) : const Color(0xFF94A39B)),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.number,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      item.icon,
                      size: 24,
                      color: fg,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.shortTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupMenu(Color formulaColor, Color stepTitleColor) {
    final activeBg = isOledDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A);
    final idleBg = isOledDark
        ? const Color(0xFF1A2220)
        : const Color(0xFFCBD5CE).withValues(alpha: 0.65);

    Widget buildRow(int opt, String title, bool isCurrent) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: InkWell(
            onTap: () => onSelectSetupOption?.call(opt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isCurrent ? activeBg : idleBg,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFFD99B26)
                      : formulaColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: isCurrent ? Colors.white : formulaColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Color(0xFFD99B26),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSubmenuHeaderRow(
          badgeText: 'CONFIG / SETUP',
          badgeColor: const Color(0xFFD99B26),
          hintText: '[1-3] o [AC]',
          hintColor: stepTitleColor,
        ),
        const SizedBox(height: 6),
        buildRow(1, '1: Unidad Angular DEG (Grados)', !isRadMode),
        buildRow(2, '2: Unidad Angular RAD (Radianes)', isRadMode),
        buildRow(3, '3: Tema LCD (${isOledDark ? "OLED" : "Clasica"})', false),
      ],
    );
  }

  Widget _buildSubmenuHeaderRow({
    required String badgeText,
    required Color badgeColor,
    required String hintText,
    required Color hintColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badgeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                hintText,
                maxLines: 1,
                style: TextStyle(
                  color: hintColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalcPrompt(Color formulaColor, Color stepTitleColor) {
    final valueDisplay = calcValueRaw.isEmpty ? r'\textcolor{#2E86DE}{\blacksquare}' : calcValueRaw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSubmenuHeaderRow(
          badgeText: 'CALC: EVALUAR EN x',
          badgeColor: const Color(0xFF2563EB),
          hintText: 'Introduce valor y [=]',
          hintColor: stepTitleColor,
        ),
        const SizedBox(height: 6),
        if (calcExpressionLatex != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              CasioLcdScreen.sanitizeForMathTex(calcExpressionLatex!),
              textStyle: TextStyle(
                fontSize: 15,
                color: formulaColor.withValues(alpha: 0.78),
              ),
            ),
          ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Math.tex(
                CasioLcdScreen.sanitizeForMathTex('x = $valueDisplay'),
                textStyle: TextStyle(
                  fontSize: 25,
                  color: formulaColor,
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOledDark ? const Color(0xFF1A2220) : const Color(0xFFCBD5CE),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            'Pulsa los dígitos (o [-] para negativo) y [=] para sustituir paso a paso.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: formulaColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassWizMenuItem {
  final int modeId;
  final String number;
  final String shortTitle;
  final String fullTitle;
  final IconData icon;

  const _ClassWizMenuItem({
    required this.modeId,
    required this.number,
    required this.shortTitle,
    required this.fullTitle,
    required this.icon,
  });
}

const List<_ClassWizMenuItem> _classWizMenuItems = [
  // Página 1
  _ClassWizMenuItem(
    modeId: 1,
    number: '1',
    shortTitle: 'Calcular',
    fullTitle: '1:Calcular',
    icon: Icons.calculate_outlined,
  ),
  _ClassWizMenuItem(
    modeId: 2,
    number: '2',
    shortTitle: 'Ecuaciones',
    fullTitle: '2:Ecuaciones (1.º y 2.º Grado)',
    icon: Icons.functions_rounded,
  ),
  _ClassWizMenuItem(
    modeId: 3,
    number: '3',
    shortTitle: 'Sistemas',
    fullTitle: '3:Sistemas (2x2 / 3x3)',
    icon: Icons.table_rows_rounded,
  ),
  _ClassWizMenuItem(
    modeId: 4,
    number: '4',
    shortTitle: 'Polinomios / Ruffini',
    fullTitle: '4:Polinomios / Ruffini',
    icon: Icons.grid_4x4_rounded,
  ),
  // Página 2
  _ClassWizMenuItem(
    modeId: 5,
    number: '5',
    shortTitle: 'Gráficas',
    fullTitle: '5:Estudio de Funciones',
    icon: Icons.show_chart_rounded,
  ),
  _ClassWizMenuItem(
    modeId: 6,
    number: '6',
    shortTitle: 'Inecuaciones',
    fullTitle: '6:Inecuaciones (<, ≤, >, ≥)',
    icon: Icons.compare_arrows_rounded,
  ),
  _ClassWizMenuItem(
    modeId: 7,
    number: '7',
    shortTitle: 'Estadística',
    fullTitle: '7:Estadística 1 Variable',
    icon: Icons.bar_chart_rounded,
  ),
  _ClassWizMenuItem(
    modeId: 8,
    number: '8',
    shortTitle: 'Matrices',
    fullTitle: '8:Matrices (2x2 / 3x3)',
    icon: Icons.grid_on_rounded,
  ),
  // Página 3
  _ClassWizMenuItem(
    modeId: 9,
    number: '9',
    shortTitle: 'Vectores 3D',
    fullTitle: '9:Vectores 2D / 3D',
    icon: Icons.north_east_rounded,
  ),
  _ClassWizMenuItem(
    modeId: 10,
    number: '10',
    shortTitle: 'Complejos',
    fullTitle: '10:Complejos (a+bi ⬄ r_α)',
    icon: Icons.all_inclusive_rounded,
  ),
  _ClassWizMenuItem(
    modeId: 11,
    number: '11',
    shortTitle: 'Derivadas e Integrales',
    fullTitle: '11:Derivadas e Integrales',
    icon: Icons.calculate_rounded,
  ),
];

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final bool isOledDark;

  const _StatusBadge({
    required this.label,
    required this.active,
    required this.activeColor,
    this.isOledDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveBg = isOledDark ? const Color(0xFF1E2925) : const Color(0xFFBAC7BE);
    final inactiveText = isOledDark ? const Color(0xFF475569) : const Color(0xFF64748B);

    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? activeColor : inactiveBg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : inactiveText,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
