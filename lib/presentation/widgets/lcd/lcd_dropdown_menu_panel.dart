import 'package:flutter/material.dart';

/// Altura fija de fila del menu (28-30 px: doble de densidad que PopupMenu).
const double kLcdDropdownRowHeight = 28.0;

/// Panel del menu desplegable estilo Casio ClassWiz: fondo LCD, borde 1.5 px,
/// sombra solida (2,2), filas con prefijo `1:`-`9:`, scrollbar fino e indicadores ▲ ▼.
class LcdDropdownMenuPanel extends StatefulWidget {
  const LcdDropdownMenuPanel({
    super.key,
    required this.labels,
    required this.itemKeys,
    required this.highlighted,
    required this.selected,
    required this.columns,
    required this.width,
    required this.maxHeight,
    required this.onTapItem,
    this.isOledDark = false,
    this.fontSize = 11.0,
  });

  final List<String> labels;
  final List<Key?> itemKeys;
  final int highlighted;
  final int selected;
  final int columns;
  final double width;
  final double maxHeight;
  final ValueChanged<int> onTapItem;
  final bool isOledDark;
  final double fontSize;

  @override
  State<LcdDropdownMenuPanel> createState() => _LcdDropdownMenuPanelState();
}

class _LcdDropdownMenuPanelState extends State<LcdDropdownMenuPanel> {
  final ScrollController _scroll = ScrollController();

  int get _rows => (widget.labels.length + widget.columns - 1) ~/ widget.columns;
  double get _contentHeight => _rows * kLcdDropdownRowHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisible();
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant LcdDropdownMenuPanel old) {
    super.didUpdateWidget(old);
    if (old.highlighted != widget.highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Mantiene la fila resaltada dentro de la ventana visible.
  void _ensureVisible() {
    if (!mounted || !_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    final top = (widget.highlighted ~/ widget.columns) * kLcdDropdownRowHeight;
    final bottom = top + kLcdDropdownRowHeight;
    final pos = _scroll.position;
    double? target;
    if (top < pos.pixels) {
      target = top;
    } else if (bottom > pos.pixels + pos.viewportDimension) {
      target = bottom - pos.viewportDimension;
    }
    if (target != null) {
      _scroll.jumpTo(target.clamp(0.0, pos.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isOledDark;
    final bg = dark ? const Color(0xFF1E2A26) : const Color(0xFFC8D6CD);
    final border = dark ? const Color(0xFF3B4A42) : const Color(0xFF1A2530);
    final height = (_contentHeight + 3).clamp(0.0, widget.maxHeight);

    return Container(
      key: const Key('lcd_dropdown_panel'),
      width: widget.width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(color: border, offset: const Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                key: const Key('lcd_dropdown_scroll'),
                controller: _scroll,
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Column(
                    children: [
                      for (int r = 0; r < _rows; r++)
                        Row(
                          children: [
                            for (int c = 0; c < widget.columns; c++)
                              Expanded(child: _cell(r * widget.columns + c)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _scroll,
                  builder: (_, __) => _decorations(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int i) {
    if (i >= widget.labels.length) return const SizedBox(height: kLcdDropdownRowHeight);
    final active = i == widget.highlighted;
    final dark = widget.isOledDark;
    final fg = active
        ? Colors.white
        : (dark ? const Color(0xFFE8F3EE) : const Color(0xFF1A2530));
    final activeBg = dark ? const Color(0xFF2B3445) : const Color(0xFF1A2530);
    return GestureDetector(
      key: widget.itemKeys[i],
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onTapItem(i),
      child: Container(
        height: kLcdDropdownRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        color: active ? activeBg : Colors.transparent,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            SizedBox(
              width: 17,
              child: Text(
                i < 9 ? '${i + 1}:' : '',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.8),
                  fontSize: widget.fontSize - 1.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                widget.labels[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: widget.fontSize,
                  fontWeight: i == widget.selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
            if (i == widget.selected)
              Text('•', style: TextStyle(color: fg, fontSize: widget.fontSize)),
          ],
        ),
      ),
    );
  }

  /// Scrollbar fino a la derecha e indicadores ▲ / ▼ de contenido oculto.
  Widget _decorations() {
    if (!_scroll.hasClients ||
        !_scroll.position.hasContentDimensions ||
        _scroll.position.maxScrollExtent <= 0.5) {
      return const SizedBox.shrink();
    }
    final pos = _scroll.position;
    final view = pos.viewportDimension;
    final ink = widget.isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF1A2530);
    final barH = (view * view / (view + pos.maxScrollExtent)).clamp(10.0, view);
    final barTop = pos.pixels / pos.maxScrollExtent * (view - barH);
    final hiddenAbove = pos.pixels > 0.5;
    final hiddenBelow = pos.pixels < pos.maxScrollExtent - 0.5;
    return Stack(
      children: [
        Positioned(
          right: 1,
          top: barTop,
          width: 3,
          height: barH,
          child: ColoredBox(key: const Key('lcd_dropdown_scrollbar'), color: ink),
        ),
        if (hiddenAbove)
          Positioned(
            right: 6,
            top: 0,
            child: Text('▲',
                key: const Key('lcd_dropdown_more_up'),
                style: TextStyle(color: ink, fontSize: 8, height: 1.1)),
          ),
        if (hiddenBelow)
          Positioned(
            right: 6,
            bottom: 0,
            child: Text('▼',
                key: const Key('lcd_dropdown_more_down'),
                style: TextStyle(color: ink, fontSize: 8, height: 1.1)),
          ),
      ],
    );
  }
}
