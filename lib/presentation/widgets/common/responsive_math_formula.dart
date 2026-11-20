import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/formatting/smart_latex_wrapper.dart';
import '../safe_math.dart';
import 'responsive_math_scroll_line.dart';

typedef MathBuilder = Widget Function(String latex, TextStyle style);

Widget _defaultBuilder(String latex, TextStyle style) => SafeMath.tex(latex, textStyle: style);

/// Cache de anchos naturales (evita volver a medir al navegar entre pasos).
abstract final class MathWidthCache {
  static final Map<String, double> _m = {};
  static double? get(String key) => _m[key];
  static void put(String key, double w) {
    if (_m.length > 400) _m.clear();
    _m[key] = w;
  }

  static void clear() => _m.clear();
}

/// Una linea de LaTeX con suelo de legibilidad.
///
/// Mide el ancho natural (sonda fuera de pantalla) y decide:
/// cabe -> tal cual; sobra poco (escala >= suelo) -> escala; sobra mucho -> [splitBuilder]
/// (salto de linea) o, si no hay, scroll horizontal con fuente a escala del suelo.
class ResponsiveMathLine extends StatefulWidget {
  final String latex;
  final TextStyle textStyle;
  final Alignment alignment;
  final double minScale;
  final double minFontPx;
  final bool allowScroll;
  final bool showScrollHints;
  final Color? backgroundColor;
  final double? knownWidth;
  final MathBuilder builder;

  /// Devuelve las lineas partidas cuando la formula necesita mas espacio; `null` = no divisible.
  final Widget? Function(BoxConstraints c, double natural)? splitBuilder;

  const ResponsiveMathLine({
    super.key,
    required this.latex,
    required this.textStyle,
    this.alignment = Alignment.centerLeft,
    this.minScale = 0.78,
    this.minFontPx = 14,
    this.allowScroll = true,
    this.showScrollHints = true,
    this.backgroundColor,
    this.knownWidth,
    this.builder = _defaultBuilder,
    this.splitBuilder,
  });

  @override
  State<ResponsiveMathLine> createState() => _ResponsiveMathLineState();
}

class _ResponsiveMathLineState extends State<ResponsiveMathLine> {
  final GlobalKey _probe = GlobalKey();
  double? _natural;

  String _key(ResponsiveMathLine w) => '${w.textStyle.fontSize}|${w.textStyle.fontWeight}|${w.latex}';

  @override
  void initState() {
    super.initState();
    _natural = widget.knownWidth ?? MathWidthCache.get(_key(widget));
  }

  @override
  void didUpdateWidget(covariant ResponsiveMathLine old) {
    super.didUpdateWidget(old);
    if (_key(old) != _key(widget)) {
      _natural = widget.knownWidth ?? MathWidthCache.get(_key(widget));
    }
  }

  void _measure() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _probe.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final w = box.size.width;
        MathWidthCache.put(_key(widget), w);
        if (_natural != w) setState(() => _natural = w);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final tex = w.builder(w.latex, w.textStyle);
    return LayoutBuilder(builder: (context, c) {
      final natural = _natural;
      if (natural == null) {
        _measure();
        return Stack(children: [
          Offstage(
            child: UnconstrainedBox(
              alignment: Alignment.topLeft,
              child: KeyedSubtree(key: _probe, child: w.builder(w.latex, w.textStyle)),
            ),
          ),
          Align(
            alignment: w.alignment,
            child: FittedBox(fit: BoxFit.scaleDown, alignment: w.alignment, child: tex),
          ),
        ]);
      }
      final avail = c.maxWidth;
      if (!avail.isFinite || natural <= avail + 0.5) {
        // Cabe en ancho; si la altura esta acotada, protege contra formulas muy altas.
        return Align(
          alignment: w.alignment,
          child: c.maxHeight.isFinite
              ? FittedBox(fit: BoxFit.scaleDown, alignment: w.alignment, child: tex)
              : tex,
        );
      }
      final fs = w.textStyle.fontSize ?? 16;
      final floor = math.max(w.minScale, w.minFontPx / fs).clamp(0.0, 1.0);
      if (avail / natural >= floor) {
        return Align(
          alignment: w.alignment,
          child: FittedBox(fit: BoxFit.scaleDown, alignment: w.alignment, child: tex),
        );
      }
      final split = w.splitBuilder?.call(c, natural);
      if (split != null) return split;
      if (!w.allowScroll) {
        return Align(
          alignment: w.alignment,
          child: FittedBox(fit: BoxFit.scaleDown, alignment: w.alignment, child: tex),
        );
      }
      return ResponsiveMathScrollLine(
        inkColor: w.textStyle.color ?? Colors.black,
        backgroundColor: w.backgroundColor,
        showHints: w.showScrollHints,
        child: w.builder(w.latex, w.textStyle.copyWith(fontSize: fs * floor)),
      );
    });
  }
}


/// Formula LaTeX universal: escala con suelo de legibilidad, salto inteligente de linea
/// en operadores de nivel superior (`splitLongLatex`) y scroll horizontal como red.
///
/// Sustituye a `FittedBox(scaleDown, Math.tex(...))` en la LCD de pasos, el panel
/// derecho y el export PNG. Los resultados largos ocupan varias lineas legibles en
/// lugar de una sola microscopica.
class ResponsiveMathFormula extends StatelessWidget {
  final String latex;
  final TextStyle textStyle;
  final Alignment alignment;
  final double minScale;
  final double minFontPx;
  final bool allowScroll;
  final bool showScrollHints;
  final Color? backgroundColor;
  final MathBuilder builder;
  final double lineSpacing;

  const ResponsiveMathFormula({
    super.key,
    required this.latex,
    required this.textStyle,
    this.alignment = Alignment.centerLeft,
    this.minScale = 0.78,
    this.minFontPx = 14,
    this.allowScroll = true,
    this.showScrollHints = true,
    this.backgroundColor,
    this.builder = _defaultBuilder,
    this.lineSpacing = 3,
  });

  CrossAxisAlignment get _cross => alignment.x < -0.3
      ? CrossAxisAlignment.start
      : (alignment.x > 0.3 ? CrossAxisAlignment.end : CrossAxisAlignment.center);

  Widget _line(String l, {double? known}) => ResponsiveMathLine(
        latex: l,
        textStyle: textStyle,
        alignment: alignment,
        minScale: minScale,
        minFontPx: minFontPx,
        allowScroll: allowScroll,
        showScrollHints: showScrollHints,
        backgroundColor: backgroundColor,
        knownWidth: known,
        builder: builder,
      );

  Widget? _split(BoxConstraints c, double natural) {
    final rows = splitArrayRows(latex);
    final List<String> lines;
    if (rows != null) {
      // Bloque de filas (egin{array}): cada fila se ajusta o se parte por su cuenta.
      lines = rows;
    } else {
      final total = visualLength(latex);
      final cap = (total * (c.maxWidth / natural) * 0.97).floor().clamp(6, 100000);
      lines = splitLongLatex(latex, maxVisualCharsPerLine: cap);
    }
    if (lines.length < 2) return null;
    final column = Column(
      key: const Key('math_split_lines'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _cross,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) SizedBox(height: lineSpacing),
          SizedBox(
            width: c.maxWidth,
            child: rows != null
                ? ResponsiveMathFormula(
                    latex: lines[i],
                    textStyle: textStyle,
                    alignment: Alignment.centerLeft,
                    minScale: minScale,
                    minFontPx: minFontPx,
                    allowScroll: allowScroll,
                    showScrollHints: showScrollHints,
                    backgroundColor: backgroundColor,
                    builder: builder,
                  )
                : _line(lines[i]),
          ),
        ],
      ],
    );
    return Align(
      alignment: alignment,
      child: c.maxHeight.isFinite
          ? SingleChildScrollView(physics: const ClampingScrollPhysics(), child: column)
          : column,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveMathLine(
      latex: latex,
      textStyle: textStyle,
      alignment: alignment,
      minScale: minScale,
      minFontPx: minFontPx,
      allowScroll: allowScroll,
      showScrollHints: showScrollHints,
      backgroundColor: backgroundColor,
      builder: builder,
      splitBuilder: _split,
    );
  }
}
