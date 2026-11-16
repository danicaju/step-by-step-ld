import 'package:flutter/material.dart';

/// Caja inferior de explicación pedagógica o alerta de examen en la LCD Casio.
class LcdPedagogicalBox extends StatelessWidget {
  final String? warningTrick;
  final String pedagogicalNote;
  final double maxNoteHeight;
  final bool isOledDark;

  const LcdPedagogicalBox({
    super.key,
    this.warningTrick,
    required this.pedagogicalNote,
    required this.maxNoteHeight,
    this.isOledDark = false,
  });

  @override
  Widget build(BuildContext context) {
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
    );
  }
}
