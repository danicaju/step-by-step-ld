import 'package:flutter/material.dart';

import '../theme/calculator_themes.dart';
import '../theme/theme_controller.dart';

/// Tarjeta de seleccion de tema de hardware con vista previa de color y forma de cada modelo.
class ThemePickerCard extends StatelessWidget {
  const ThemePickerCard({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const ThemePickerCard());

  static double _radius(CalculatorHardwareTheme t) => switch (t.keyShape) {
        KeyCapShape.roundedPill => 9,
        KeyCapShape.retroWedge => 1,
        KeyCapShape.flatChiclet => 5,
        KeyCapShape.defaultOriginal => 4,
      };

  @override
  Widget build(BuildContext context) {
    final cur = ThemeController.current;
    final hw = cur;
    return Dialog(
      key: const Key('theme_picker_card'),
      backgroundColor: hw.isDefault ? const Color(0xFF16191E) : hw.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: hw.isDefault ? const Color(0xFF2C323E) : hw.panelBorder, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'TEMA DE HARDWARE',
                style: TextStyle(
                  color: hw.isDefault ? const Color(0xFFF1F5F9) : hw.panelText,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < HardwareThemes.all.length; i++)
                _tile(context, i, HardwareThemes.all[i], HardwareThemes.all[i].id == cur.id, hw),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, int i, CalculatorHardwareTheme t, bool selected, CalculatorHardwareTheme hw) {
    final fg = hw.isDefault ? const Color(0xFFE2E8F0) : hw.panelText;
    final r = _radius(t);
    Widget chip(Color c, {double w = 16}) => Container(
          width: w,
          height: 16,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: Colors.black26, width: 0.8),
          ),
        );
    return GestureDetector(
      key: Key('theme_option_${t.id}'),
      onTap: () {
        ThemeController.instance.select(t);
        Navigator.of(context).pop();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? fg.withValues(alpha: 0.10) : Colors.transparent,
          border: Border.all(
            color: selected ? (hw.isDefault ? const Color(0xFFE5A93C) : hw.panelAccent) : fg.withValues(alpha: 0.25),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 66,
              height: 32,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: t.chassisMid, borderRadius: BorderRadius.circular(6)),
              child: Row(children: [chip(t.numKey, w: 14), chip(t.funcKey, w: 14), chip(t.delAcKey, w: 10)]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${i + 1}: ${t.name}',
                style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}
