import 'package:flutter/material.dart';

import '../../../domain/math_engine/core/calculator_settings.dart';

/// Barra de estado superior de la LCD Casio ClassWiz (S, A, M, DEG/RAD, modo activo, audio, contraste).
class LcdStatusBar extends StatelessWidget {
  final bool isShiftActive;
  final bool isAlphaActive;
  final bool isMemoryActive;
  final bool showDisp;
  final bool showSto;
  final bool isRadMode;
  final String? angleLabel;
  final VoidCallback? onToggleAngleUnit;
  final String? modeLabel;
  final bool hasSteps;
  final int activeStepIndex;
  final int totalSteps;
  final String stepTitle;
  final Color stepTitleColor;
  final bool isOledDark;
  final bool isSoundMuted;
  final VoidCallback? onToggleSound;
  final VoidCallback? onToggleTheme;

  const LcdStatusBar({
    super.key,
    required this.isShiftActive,
    required this.isAlphaActive,
    required this.isMemoryActive,
    this.showDisp = false,
    this.showSto = false,
    required this.isRadMode,
    this.angleLabel,
    this.onToggleAngleUnit,
    this.modeLabel,
    required this.hasSteps,
    required this.activeStepIndex,
    required this.totalSteps,
    required this.stepTitle,
    required this.stepTitleColor,
    this.isOledDark = false,
    this.isSoundMuted = false,
    this.onToggleSound,
    this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatusBadge(
          label: 'S',
          active: isShiftActive,
          activeColor: const Color(0xFFD99B26),
          isOledDark: isOledDark,
        ),
        const SizedBox(width: 4),
        StatusBadge(
          label: 'A',
          active: isAlphaActive,
          activeColor: const Color(0xFFD64545),
          isOledDark: isOledDark,
        ),
        const SizedBox(width: 4),
        StatusBadge(
          label: 'M',
          active: isMemoryActive,
          activeColor: const Color(0xFF1A2530),
          inverted: true,
          isOledDark: isOledDark,
        ),
        if (CalculatorSettings.numberFormat != NumberFormatMode.norm) ...[
          const SizedBox(width: 4),
          StatusBadge(
            label: CalculatorSettings.numberFormat == NumberFormatMode.fix ? 'FIX' : 'SCI',
            active: true,
            activeColor: const Color(0xFF1A2530),
            inverted: true,
            isOledDark: isOledDark,
          ),
        ],
        if (showSto) ...[
          const SizedBox(width: 4),
          StatusBadge(
            label: 'STO',
            active: true,
            activeColor: const Color(0xFF1A2530),
            inverted: true,
            isOledDark: isOledDark,
          ),
        ],
        if (showDisp) ...[
          const SizedBox(width: 4),
          StatusBadge(
            label: 'Disp',
            active: true,
            activeColor: const Color(0xFF1A2530),
            inverted: true,
            isOledDark: isOledDark,
          ),
        ],
        const SizedBox(width: 4),
        InkWell(
          key: const Key('lcd_angle_badge'),
          onTap: onToggleAngleUnit,
          borderRadius: BorderRadius.circular(3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: (angleLabel != null ? angleLabel != 'DEG' : isRadMode)
                  ? const Color(0xFFE5A93C)
                  : (isOledDark ? const Color(0xFF1E2925) : const Color(0xFF1A2530)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              angleLabel ?? (isRadMode ? 'RAD' : 'DEG'),
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
                color: const Color(0xFF1A2530),
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
                  'PASO ${activeStepIndex + 1}/$totalSteps',
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
                        ? const Color(0xFFC8D6CD)
                        : const Color(0xFF1A2530)),
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
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final bool isOledDark;
  final bool inverted;

  const StatusBadge({
    super.key,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.isOledDark,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color inactiveBg = isOledDark
        ? const Color(0xFF141918)
        : const Color(0xFFC7D3CA).withValues(alpha: 0.65);
    final Color inactiveFg = isOledDark
        ? const Color(0xFF2E3D38)
        : const Color(0xFF8F9F94);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: active
            ? (inverted && isOledDark ? const Color(0xFFC8D6CD) : activeColor)
            : inactiveBg,
        borderRadius: BorderRadius.circular(2.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active
              ? (inverted && isOledDark ? const Color(0xFF141918) : (inverted ? const Color(0xFFC8D6CD) : Colors.white))
              : inactiveFg,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
