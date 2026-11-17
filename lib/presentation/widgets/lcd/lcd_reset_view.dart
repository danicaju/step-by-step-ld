import 'package:flutter/material.dart';

import 'lcd_palette.dart';

/// Pantalla clasica RESET (SHIFT + 9): menu de 3 opciones y confirmacion.
class LcdResetView extends StatelessWidget {
  final LcdTheme theme;
  final int stage; // 0 = menu, 1 = confirmacion
  final int choice; // 0..2
  final ValueChanged<int>? onTapOption;

  const LcdResetView({
    super.key,
    required this.theme,
    required this.stage,
    required this.choice,
    this.onTapOption,
  });

  static const List<String> options = ['Setup', 'Memoria', 'Inicializar todo'];
  static const Color _active = Color(0xFF1A2530);
  static const Color _border = Color(0xFF7A8A7E);

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final bool dark = theme == LcdTheme.night;
    final Color idleBg = dark ? const Color(0xFF1A2421) : const Color(0xFFBDCEBE);
    return Column(
      key: const Key('lcd_reset_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'RESET',
          key: const Key('reset_title'),
          style: TextStyle(color: pal.formula, fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        if (stage == 0)
          for (int i = 0; i < options.length; i++)
            GestureDetector(
              key: Key('reset_opt_$i'),
              onTap: () => onTapOption?.call(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: choice == i ? _active : idleBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: choice == i ? _active : _border),
                ),
                child: Text(
                  '${i + 1}: ${options[i]}',
                  style: TextStyle(
                    color: choice == i ? Colors.white : pal.formula,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
        else ...[
          Text(
            '${choice + 1}: ${options[choice]}',
            key: const Key('reset_confirm_target'),
            style: TextStyle(color: pal.formula, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '[ = ] : Sí   |   [ AC ] : Cancelar',
            key: const Key('reset_confirm'),
            style: TextStyle(color: pal.formula, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
        const Spacer(),
        Text(
          stage == 0 ? '1-3 o ▲▼ y = · AC salir' : 'Esta acción borra datos',
          style: TextStyle(color: pal.title, fontSize: 9.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
