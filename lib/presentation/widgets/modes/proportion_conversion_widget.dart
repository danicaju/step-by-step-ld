import 'package:flutter/material.dart';

import '../../../domain/math_engine/proportion/proportion_conversion_solver.dart';
import '../lcd/lcd_dropdown_selector.dart';
import '../lcd/lcd_palette.dart';

/// Estado del formulario de Proporcion / Factores de conversion (sin TextField:
/// todo se teclea con el teclado fisico y se navega con el D-Pad).
class ProportionFormState {
  /// 0 = Regla de 3 directa, 1 = inversa, 2 = factores de conversion.
  int mode = 0;

  /// -1 = cabecera (desplegable); 0..2 = casillas.
  int focus = 0;
  final List<String> cells = ['', '', ''];
  int fromIdx = ConversionCatalog.units.indexWhere((u) => u.label == 'km/h');
  int toIdx = ConversionCatalog.units.indexWhere((u) => u.label == 'm/s');
  final LcdDropdownController ctrl = LcdDropdownController();

  bool get isConversion => mode == 2;

  void setMode(int m) {
    mode = m;
    focus = 0;
    for (var i = 0; i < cells.length; i++) {
      cells[i] = '';
    }
  }

  /// D-Pad. `true` si el evento fue consumido por el formulario.
  void dpad(String dir) {
    final isUnit = isConversion && (focus == 1 || focus == 2);
    switch (dir) {
      case 'left':
        if (focus > 0) focus--;
      case 'right':
        if (focus >= 0 && focus < 2) focus++;
      case 'up':
        if (isUnit) {
          _cycleUnit(-1);
        } else if (focus >= 0) {
          focus = -1;
        }
      case 'down':
        if (focus == -1) {
          focus = 0;
        } else if (isUnit) {
          _cycleUnit(1);
        }
    }
  }

  void _cycleUnit(int d) {
    final n = ConversionCatalog.units.length;
    if (focus == 1) fromIdx = (fromIdx + d + n) % n;
    if (focus == 2) toIdx = (toIdx + d + n) % n;
  }
}

/// Vista LCD del formulario. Solo pinta: la logica de teclas vive en la pantalla.
class ProportionConversionWidget extends StatelessWidget {
  static const List<String> modeLabels = [
    'Regla de 3 Directa',
    'Regla de 3 Inversa',
    'Factores de Conversión',
  ];

  final ProportionFormState form;
  final LcdTheme theme;
  final ValueChanged<int> onModeChanged;
  final ValueChanged<int> onFocus;
  final GlobalKey? boundsKey;

  const ProportionConversionWidget({
    super.key,
    required this.form,
    required this.theme,
    required this.onModeChanged,
    required this.onFocus,
    this.boundsKey,
  });

  static const Color _ink = Color(0xFF1A2530);
  static const Color _amber = Color(0xFFE5A93C);

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final dark = theme == LcdTheme.night;
    final fg = dark ? const Color(0xFFE8F3EE) : _ink;
    return Container(
      key: const Key('proportion_widget'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pal.background,
        borderRadius: BorderRadius.circular(8.5),
        border: Border.all(color: const Color(0xFF7A8A7E), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => onFocus(-1),
            child: LcdDropdownSelector<int>(
              widgetKey: const Key('proportion_mode_selector'),
              prefix: 'OPTN',
              value: form.mode,
              items: [
                for (var i = 0; i < modeLabels.length; i++)
                  LcdDropdownItem<int>(value: i, label: modeLabels[i], key: Key('proportion_mode_$i')),
              ],
              onChanged: onModeChanged,
              isOledDark: dark,
              isHighlighted: form.focus == -1,
              columns: 1,
              controller: form.ctrl,
              boundsKey: boundsKey,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: form.isConversion ? _conversionBody(fg, pal) : _proportionBody(fg, pal),
              ),
            ),
          ),
          Divider(height: 1, color: fg.withValues(alpha: 0.4)),
          const SizedBox(height: 2),
          Text(
            form.isConversion
                ? '◀▶ casilla · ▲▼ unidad · = siguiente/calcular · AC salir'
                : '◀▶ casilla · ▲ cabecera · = siguiente/calcular · AC salir',
            key: const Key('proportion_hint'),
            style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _proportionBody(Color fg, LcdPalette pal) {
    Widget arrow() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('→', style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w700)),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          _cell(0, 'A', form.cells[0], fg, pal),
          arrow(),
          _cell(1, 'B', form.cells[1], fg, pal),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _cell(2, 'C', form.cells[2], fg, pal),
          arrow(),
          _fixed('x', fg, pal),
        ]),
      ],
    );
  }

  Widget _conversionBody(Color fg, LcdPalette pal) {
    final from = ConversionCatalog.units[form.fromIdx].label;
    final to = ConversionCatalog.units[form.toIdx].label;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _cell(0, 'valor', form.cells[0], fg, pal),
      const SizedBox(width: 4),
      _cell(1, 'de', from, fg, pal, isUnit: true),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('→', style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      _cell(2, 'a', to, fg, pal, isUnit: true),
    ]);
  }

  Widget _fixed(String text, Color fg, LcdPalette pal) => Container(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 30),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pal.inset,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFF7A8A7E)),
        ),
        child: Text(text, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w800)),
      );

  Widget _cell(int index, String label, String value, Color fg, LcdPalette pal, {bool isUnit = false}) {
    final active = form.focus == index;
    final shown = value.isEmpty ? '' : value;
    return GestureDetector(
      onTap: () => onFocus(index),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 10)),
        AnimatedContainer(
          key: Key('proportion_cell_$index'),
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minWidth: 56, minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _ink : pal.inset,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: active ? _amber : const Color(0xFF7A8A7E), width: active ? 2.2 : 1),
          ),
          child: Text(
            isUnit && active ? '▲ $shown ▼' : shown,
            style: TextStyle(
              color: active ? const Color(0xFFC8D6CD) : fg,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ]),
    );
  }
}
