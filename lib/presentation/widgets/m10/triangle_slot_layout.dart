import 'dart:ui';

/// Geometria fija del editor de triangulos: vertices A, B, C y la casilla de cada lado y angulo.
///
/// Todo en un lienzo de [canvas] (se escala con `FittedBox`). Funcion pura y comprobable:
/// ninguna casilla se solapa con otra ni cruza un lado del triangulo.
class TriangleSlotLayout {
  static const Size canvas = Size(384, 226);
  static const double slotW = 78; // rotulo + casilla
  static const double slotH = 30;

  /// Vertices A, B, C.
  final List<Offset> v;

  /// Esquina superior izquierda de la casilla del lado a, b, c (opuestos a A, B, C).
  final List<Offset> sides;

  /// Idem para el angulo en A, B, C (`null` = no editable, p. ej. el angulo recto).
  final List<Offset?> angles;

  const TriangleSlotLayout._(this.v, this.sides, this.angles);

  /// Rectangulo (C = 90°, B arriba a la izquierda) o triangulo cualquiera.
  factory TriangleSlotLayout.of({required bool right}) => right
      ? const TriangleSlotLayout._(
          [Offset(300, 176), Offset(118, 58), Offset(118, 176)],
          [Offset(30, 100), Offset(170, 182), Offset(204, 52)],
          [Offset(298, 140), Offset(132, 20), null],
        )
      : const TriangleSlotLayout._(
          [Offset(46, 186), Offset(338, 186), Offset(226, 46)],
          [Offset(278, 62), Offset(52, 62), Offset(153, 192)],
          [Offset(102, 152), Offset(226, 152), Offset(244, 22)],
        );

  Rect sideRect(int i) => sides[i] & const Size(slotW, slotH);
  Rect? angleRect(int i) => angles[i] == null ? null : angles[i]! & const Size(slotW, slotH);

  List<Rect> get allRects => [
        for (var i = 0; i < 3; i++) sideRect(i),
        for (var i = 0; i < 3; i++)
          if (angleRect(i) != null) angleRect(i)!,
      ];
}
