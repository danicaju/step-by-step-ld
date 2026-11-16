import 'package:flutter/material.dart';

class MatrixEditorChips {
  static Widget lcdPill({
    required Key key,
    required String label,
    required bool selected,
    required bool isOledDark,
    Color? accentColor,
    required VoidCallback onTap,
  }) {
    final Color baseSelected = accentColor ?? const Color(0xFF2563EB);
    final Color bg = selected
        ? baseSelected
        : (isOledDark ? const Color(0xFF1E293B) : const Color(0xFFBAC7BE));
    final Color fg = selected
        ? Colors.white
        : (isOledDark ? const Color(0xFF94A3B8) : const Color(0xFF334155));

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: selected ? 1.0 : 0.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static Widget lcdDimPill({
    required Key key,
    required String label,
    required bool selected,
    required bool isOledDark,
    required VoidCallback onTap,
  }) {
    final Color bg = selected
        ? const Color(0xFF2563EB)
        : (isOledDark ? const Color(0xFF1E293B) : const Color(0xFFC7D3C9));
    final Color fg = selected
        ? Colors.white
        : (isOledDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected ? Colors.cyanAccent : Colors.transparent,
            width: selected ? 1.0 : 0.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static Widget lcdActionChip({
    required Key key,
    required String label,
    required bool selected,
    required bool isOledDark,
    required VoidCallback onTap,
  }) {
    final Color bg = selected
        ? (isOledDark ? const Color(0xFF2563EB) : const Color(0xFF1E3A5F))
        : (isOledDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1));
    final Color fg = selected
        ? Colors.white
        : (isOledDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? const Color(0xFF60A5FA)
                : (isOledDark
                    ? const Color(0xFF334155)
                    : const Color(0xFF94A3B8)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
