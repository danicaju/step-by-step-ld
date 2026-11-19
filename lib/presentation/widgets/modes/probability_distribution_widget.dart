import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../lcd/lcd_palette.dart';
import '../lcd/lcd_input_box.dart';
import 'form_cell_box.dart';
import 'mode_form.dart';

/// Ficha de Normal `N(μ, σ)` y Binomial `B(n, p)` dentro de la LCD.
///
/// Fila superior con la insignia y el selector de probabilidad; tarjeta de parametros
/// (`μ = [ ]`, `σ = [ ]` / `n = [ ]`, `p = [ ]`) y tarjeta con la expresion que se calcula
/// (`P( [a] ≤ X ≤ [b] )`, `P( X = [k] )`...). Las celdas aceptan fracciones (`1/6`) con a/b.
/// Foco del [ModeFormState]: 0 = selector, luego los campos en orden (μ, σ, a, b / n, p, k).
class ProbabilityDistributionWidget extends StatelessWidget {
  final ModeFormState form;
  final LcdTheme theme;
  final bool binomial;
  final ValueChanged<int> onFocus;
  final String keyPrefix;

  const ProbabilityDistributionWidget({
    super.key,
    required this.form,
    required this.theme,
    required this.binomial,
    required this.onFocus,
    this.keyPrefix = 'xform',
  });

  static const Color _ink = Color(0xFF1A2530);
  static const Color _amber = Color(0xFFE5A93C);
  static const Color _lcd = Color(0xFFC8D6CD);
  static const Color _idle = Color(0xFFBDCEBE);
  static const Color _border = Color(0xFF7A8A7E);

  /// Expresion de la probabilidad como trozos: texto fijo o indice de campo (`int`).
  static List<Object> expressionParts(bool binomial, int selector) {
    if (binomial) {
      final rel = ['=', '≤', '≥'][selector.clamp(0, 2)];
      return ['P(X $rel', 2, ')'];
    }
    return switch (selector) {
      1 => ['P(X ≥', 2, ')'],
      2 => ['P(', 2, '≤ X ≤', 3, ')'],
      _ => ['P(X ≤', 2, ')'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final night = theme == LcdTheme.night;
    final fg = night ? const Color(0xFFE8F3EE) : _ink;
    final selActive = form.focus == 0;
    final params = binomial ? const ['n', 'p'] : const ['μ', 'σ'];

    Widget cell(int i, {double width = 78}) {
      final f = form.fields[i];
      final active = form.focus == i + form.base;
      return SizedBox(
        width: width,
        child: LcdInputBox(
          key: Key('${keyPrefix}_cell_$i'),
          active: active,
          palette: pal,
          latex: FormCellBox.latexOf(f, active: active, fracNumerator: form.fracNum),
          text: f.text,
          fontSize: 15,
          minWidth: width,
          minHeight: 30,
          onTap: () => onFocus(i + form.base),
        ),
      );
    }

    Widget card(Key key, String title, Widget child) => Container(
          key: key,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          decoration: BoxDecoration(
            color: night ? pal.inset.withValues(alpha: 0.5) : _lcd.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _border, width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            child,
          ]),
        );

    final badge = Container(
      key: Key('${keyPrefix}_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(5)),
      child: Math.tex(
        binomial ? r'B(n,\ p)' : r'N(\mu,\ \sigma)',
        textStyle: const TextStyle(color: _lcd, fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );

    final selector = GestureDetector(
      onTap: () => onFocus(0),
      child: Container(
        key: Key('${keyPrefix}_selector'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selActive ? _ink : (night ? pal.inset : _idle),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: selActive ? _amber : _border, width: selActive ? 2.2 : 1.5),
        ),
        child: Text(
          '◀ ${form.selectorLabels[form.selector]} ▶',
          style: TextStyle(color: selActive ? _lcd : fg, fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );

    final paramCard = card(
      Key('${keyPrefix}_params'),
      'PARÁMETROS',
      Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 2; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 5),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 32,
                child: Text('${params[i]} =', style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              cell(i),
            ]),
          ),
      ]),
    );

    final textStyle = TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w800);
    final calcCard = card(
      Key('${keyPrefix}_calc'),
      'CALCULAR',
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (final part in expressionParts(binomial, form.selector)) ...[
          if (part is int) cell(part, width: 70) else Text('$part', style: textStyle),
          const SizedBox(width: 4),
        ],
      ]),
    );

    return Container(
      key: Key('${keyPrefix}_widget'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [badge, const SizedBox(width: 8), selector]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            paramCard,
            const SizedBox(width: 8),
            calcCard,
          ]),
        ]),
      ),
    );
  }
}
