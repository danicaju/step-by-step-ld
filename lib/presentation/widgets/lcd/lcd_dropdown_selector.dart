import 'package:flutter/material.dart';

/// Ítem para [LcdDropdownSelector].
class LcdDropdownItem<T> {
  final T value;
  final String label;
  final Key? key;

  const LcdDropdownItem({
    required this.value,
    required this.label,
    this.key,
  });
}

/// Selector desplegable compacto integrado con la estética industrial Casio ClassWiz.
/// Diseñado para caber dentro de la cabecera de la LCD y ser accesible por toque o D-Pad.
class LcdDropdownSelector<T> extends StatelessWidget {
  final Key? widgetKey;
  final String? prefix;
  final T value;
  final List<LcdDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool isOledDark;
  final double height;
  final double fontSize;
  final bool isHighlighted;

  const LcdDropdownSelector({
    super.key,
    this.widgetKey,
    this.prefix,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isOledDark = false,
    this.height = 24.0,
    this.fontSize = 11.0,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentItem = items.firstWhere(
      (it) => it.value == value,
      orElse: () => items.first,
    );

    // Paleta de hardware ClassWiz (anti-slop, sin bordes azules/cian)
    final Color bgColor = isHighlighted
        ? (isOledDark ? const Color(0xFF2B3445) : const Color(0xFF181E29))
        : (isOledDark ? const Color(0xFF1E2A26) : const Color(0xFFC8D6CD));

    final Color borderColor = isHighlighted
        ? (isOledDark ? const Color(0xFF2F3E38) : const Color(0xFF2B3445))
        : (isOledDark ? const Color(0xFF3B4A42) : const Color(0xFF7A8C80));

    final Color textColor = isHighlighted
        ? Colors.white
        : (isOledDark ? const Color(0xFFDDE6DF) : const Color(0xFF101815));

    final Color arrowColor = isHighlighted
        ? Colors.white70
        : (isOledDark ? const Color(0xFF9DB0A4) : const Color(0xFF2F3E38));

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isOledDark ? const Color(0xFF1E2A26) : const Color(0xFFDDE6DF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isOledDark ? const Color(0xFF3B4A42) : const Color(0xFF9DB0A4),
              width: 1.2,
            ),
          ),
          textStyle: TextStyle(
            color: isOledDark ? const Color(0xFFEFF3F0) : const Color(0xFF1A2530),
            fontSize: fontSize + 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: PopupMenuButton<T>(
        key: widgetKey,
        initialValue: value,
        tooltip: prefix != null ? '$prefix: ${currentItem.label}' : currentItem.label,
        padding: EdgeInsets.zero,
        onSelected: onChanged,
        itemBuilder: (context) => [
          for (final item in items)
            PopupMenuItem<T>(
              key: item.key,
              value: item.value,
              height: 34,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: item.value == value
                      ? (isOledDark ? const Color(0xFF2B3445) : const Color(0xFF181E29))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    if (item.value == value) ...[
                      Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: item.value == value ? Colors.white : textColor,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: item.value == value
                              ? Colors.white
                              : (isOledDark ? const Color(0xFFEFF3F0) : const Color(0xFF181E29)),
                          fontSize: fontSize + 1,
                          fontWeight: item.value == value ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(5.0),
            border: Border.all(
              color: borderColor,
              width: isHighlighted ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prefix != null) ...[
                Text(
                  '$prefix ',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.75),
                    fontSize: fontSize - 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              Text(
                currentItem.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '▾',
                style: TextStyle(color: arrowColor, fontSize: fontSize + 1, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
