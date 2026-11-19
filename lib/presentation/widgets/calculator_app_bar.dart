import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';
import 'calculator_bezel_widgets.dart';
import 'solar_panel.dart';

/// Barra superior de la app: logo, titulo y botones `TEMA`, `PNG`, `TEX`, `HIST`.
/// Los colores salen del tema de hardware activo (`Predeterminado` = aspecto original).
PreferredSizeWidget buildCalculatorAppBar({
  required VoidCallback onTheme,
  required VoidCallback onPng,
  required VoidCallback onTex,
  required VoidCallback onHistory,
}) {
  final hw = ThemeController.current;
  return AppBar(
    toolbarHeight: 46,
    titleSpacing: 12,
    backgroundColor: hw.appBarBg,
    surfaceTintColor: Colors.transparent,
    title: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SolarPanel(),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'STEP-BY-STEP LD',
                style: TextStyle(
                  color: hw.appBarTitle,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'NATURAL-V.P.A.M. // STEP ENGINE',
                style: TextStyle(
                  color: hw.appBarAccent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  fontSize: 8.5,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      HeaderBezelButton(
        key: const Key('appbar_theme'),
        label: 'TEMA',
        tooltip: 'TEMA DE HARDWARE',
        accentColor: const Color(0xFFE5A93C),
        onPressed: onTheme,
      ),
      const SizedBox(width: 6),
      HeaderBezelButton(
        key: const Key('appbar_export_png'),
        label: 'PNG',
        tooltip: 'EXPORTAR PNG',
        accentColor: const Color(0xFF94A3B8),
        onPressed: onPng,
      ),
      const SizedBox(width: 6),
      HeaderBezelButton(
        key: const Key('appbar_copy_latex'),
        label: 'TEX',
        tooltip: 'COPIAR LaTeX',
        accentColor: const Color(0xFF94A3B8),
        onPressed: onTex,
      ),
      const SizedBox(width: 6),
      HeaderBezelButton(
        key: const Key('appbar_history'),
        label: 'HIST',
        tooltip: 'HISTORIAL',
        accentColor: const Color(0xFFE5A93C),
        onPressed: onHistory,
      ),
      const SizedBox(width: 10),
    ],
    elevation: 0,
  );
}
