import 'package:flutter/material.dart';

import '../../theme/theme_controller.dart';

class CalculatorMethodTab extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const CalculatorMethodTab({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Predeterminado conserva los colores originales; el resto usa los del tema activo.
    final hw = ThemeController.current;
    final fg = hw.isDefault
        ? (selected ? Colors.white : const Color(0xFF94A3B8))
        : (selected ? hw.funcKeyText : hw.numKeyText);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hw.isDefault
                ? (selected ? const Color(0xFF181E29) : const Color(0xFF2A2E37))
                : (selected ? hw.funcKey : hw.numKey),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: hw.isDefault
                  ? (selected ? const Color(0xFF2B3445) : const Color(0xFF3B4252))
                  : hw.keyBorder,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 13,
                    color: fg,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
