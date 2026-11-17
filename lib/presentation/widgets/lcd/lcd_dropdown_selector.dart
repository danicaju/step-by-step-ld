import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'lcd_dropdown_menu_panel.dart';
import 'lcd_dropdown_nav.dart';

export 'lcd_dropdown_nav.dart';

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

/// Puente entre las teclas fisicas (D-Pad, 1-9, =, AC) y el menu abierto.
/// Solo un menu puede estar abierto a la vez: [active].
class LcdDropdownController {
  static LcdDropdownController? active;

  _LcdDropdownSelectorState? _state;

  bool get isOpen => _state?._entry != null;

  void open() => _state?._open();
  void close() => _state?._close();

  /// Teclas fisicas con el menu abierto. `true` si la pulsacion fue consumida.
  /// 1-9 eligen la opcion; `=` confirma; `AC` cierra; cualquier otra tecla cierra sin consumir.
  bool handleKey(String key) {
    final s = _state;
    if (s == null || s._entry == null) return false;
    final idx = LcdDropdownNav.digitIndex(key, s.widget.items.length);
    if (idx != null) {
      s._choose(idx);
      return true;
    }
    if (key == '=') {
      s._choose(s._nav!.index);
      return true;
    }
    s._close();
    return key == 'AC';
  }

  /// D-Pad con el menu abierto (siempre lo consume).
  bool handleDpad(String dir) {
    final s = _state;
    if (s == null || s._entry == null) return false;
    s._moveHighlight(dir);
    return true;
  }
}

/// Selector desplegable compacto con estetica industrial Casio ClassWiz.
/// El menu es un overlay no modal (las teclas fisicas siguen activas), con
/// prefijos `1:`-`9:`, scroll automatico con D-Pad y 1 o 2 columnas.
class LcdDropdownSelector<T> extends StatefulWidget {
  final Key? widgetKey;
  final String? prefix;
  final T value;
  final List<LcdDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool isOledDark;
  final double height;
  final double fontSize;
  final bool isHighlighted;

  /// 1 o 2 columnas; `null` = automatico (2 si todas las etiquetas son cortas).
  final int? columns;
  final LcdDropdownController? controller;

  /// Pantalla LCD que acota el menu (nunca tapa la barra inferior de pistas).
  final GlobalKey? boundsKey;

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
    this.columns,
    this.controller,
    this.boundsKey,
  });

  @override
  State<LcdDropdownSelector<T>> createState() => _LcdDropdownSelectorState<T>();
}

class _LcdDropdownSelectorState<T> extends State<LcdDropdownSelector<T>> {
  static const double _bottomReserve = 24; // barra inferior de pistas de la LCD
  final LayerLink _link = LayerLink();
  late final LcdDropdownController _ctrl = widget.controller ?? LcdDropdownController();
  OverlayEntry? _entry;
  LcdDropdownNav? _nav;

  int get _columns => (widget.columns ?? LcdDropdownNav.autoColumns(
          [for (final it in widget.items) it.label])).clamp(1, 2);

  @override
  void initState() {
    super.initState();
    _ctrl._state = this;
  }

  @override
  void didUpdateWidget(covariant LcdDropdownSelector<T> old) {
    super.didUpdateWidget(old);
    _ctrl._state = this;
    if (_entry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _entry?.markNeedsBuild());
    }
  }

  @override
  void dispose() {
    _removeEntry();
    if (_ctrl._state == this) _ctrl._state = null;
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    if (LcdDropdownController.active == _ctrl) LcdDropdownController.active = null;
  }

  void _open() {
    if (_entry != null || widget.items.isEmpty) return;
    LcdDropdownController.active?.close();
    final cur = widget.items.indexWhere((it) => it.value == widget.value);
    _nav = LcdDropdownNav(
      count: widget.items.length,
      columns: _columns,
      index: math.max(cur, 0),
    );
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
    LcdDropdownController.active = _ctrl;
    setState(() {});
  }

  void _close() {
    if (_entry == null) return;
    _removeEntry();
    if (mounted) setState(() {});
  }

  void _choose(int index) {
    final item = widget.items[index];
    _close();
    widget.onChanged(item.value);
  }

  void _moveHighlight(String dir) {
    if (_nav?.move(dir) ?? false) _entry?.markNeedsBuild();
  }

  Rect? _rectOf(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final selBox = context.findRenderObject();
    if (selBox is! RenderBox || !selBox.attached || _nav == null) {
      return const SizedBox.shrink();
    }
    final sel = selBox.localToGlobal(Offset.zero) & selBox.size;
    final screen = MediaQuery.sizeOf(overlayContext);
    final lcd = _rectOf(widget.boundsKey) ?? Rect.fromLTWH(0, 0, screen.width, screen.height);

    // Ancho: etiqueta mas larga + prefijo, acotado por la LCD.
    final painter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
    var longest = 0.0;
    for (final it in widget.items) {
      painter.text = TextSpan(
        text: it.label,
        style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.w900),
      );
      painter.layout();
      longest = math.max(longest, painter.width);
    }
    final cols = _columns;
    final colWidth = longest + 17 + 10 + 12;
    final width = (colWidth * cols + 6)
        .clamp(sel.width, math.max(sel.width, lcd.width - 8))
        .toDouble();
    final dx = math.min(0.0, lcd.right - 4 - (sel.left + width));
    final maxH = math.max(
      kLcdDropdownRowHeight * 2 + 3,
      lcd.bottom - sel.bottom - _bottomReserve - 4,
    );

    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: Offset(dx, sel.height + 2),
        child: Material(
          type: MaterialType.transparency,
          child: LcdDropdownMenuPanel(
            labels: [for (final it in widget.items) it.label],
            itemKeys: [for (final it in widget.items) it.key],
            highlighted: _nav!.index,
            selected: widget.items.indexWhere((it) => it.value == widget.value),
            columns: cols,
            width: width,
            maxHeight: maxH,
            isOledDark: widget.isOledDark,
            fontSize: widget.fontSize,
            onTapItem: _choose,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.items.firstWhere(
      (it) => it.value == widget.value,
      orElse: () => widget.items.first,
    );
    final dark = widget.isOledDark;
    final hl = widget.isHighlighted;
    final open = _entry != null;

    final Color bgColor = (hl || open)
        ? (dark ? const Color(0xFF2B3445) : const Color(0xFF181E29))
        : (dark ? const Color(0xFF1E2A26) : const Color(0xFFC8D6CD));
    final Color borderColor = (hl || open)
        ? (dark ? const Color(0xFF2F3E38) : const Color(0xFF2B3445))
        : (dark ? const Color(0xFF3B4A42) : const Color(0xFF7A8C80));
    final Color textColor = (hl || open)
        ? Colors.white
        : (dark ? const Color(0xFFDDE6DF) : const Color(0xFF101815));
    final Color arrowColor = (hl || open)
        ? Colors.white70
        : (dark ? const Color(0xFF9DB0A4) : const Color(0xFF2F3E38));

    return CompositedTransformTarget(
      link: _link,
      child: Tooltip(
        message: widget.prefix != null
            ? '${widget.prefix}: ${currentItem.label}'
            : currentItem.label,
        child: GestureDetector(
          key: widget.widgetKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => open ? _close() : _open(),
          child: Container(
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(3.0),
              border: Border.all(color: borderColor, width: (hl || open) ? 1.5 : 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.prefix != null)
                  Text(
                    '${widget.prefix} ',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.75),
                      fontSize: widget.fontSize - 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  currentItem.label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  open ? '▴' : '▾',
                  style: TextStyle(
                    color: arrowColor,
                    fontSize: widget.fontSize + 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
