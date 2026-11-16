class NotableFirstQuadEntry {
  final String sinLatex;
  final String? sinRawUnrationalized;
  final String cosLatex;
  final String? cosRawUnrationalized;
  final String? tanLatex; // null = indefinido (90°)
  final String? tanRawUnrationalized;
  final double sinVal;
  final double cosVal;
  final double? tanVal;

  const NotableFirstQuadEntry({
    required this.sinLatex,
    this.sinRawUnrationalized,
    required this.cosLatex,
    this.cosRawUnrationalized,
    required this.tanLatex,
    this.tanRawUnrationalized,
    required this.sinVal,
    required this.cosVal,
    required this.tanVal,
  });
}

class NotableTrigTable {
  static const Map<int, NotableFirstQuadEntry> table = {
    0: NotableFirstQuadEntry(
      sinLatex: '0',
      cosLatex: '1',
      tanLatex: '0',
      tanRawUnrationalized: null,
      sinVal: 0,
      cosVal: 1,
      tanVal: 0,
    ),
    30: NotableFirstQuadEntry(
      sinLatex: r'\frac{1}{2}',
      cosLatex: r'\frac{\sqrt{3}}{2}',
      tanLatex: r'\frac{\sqrt{3}}{3}',
      tanRawUnrationalized: r'\frac{1}{\sqrt{3}}',
      sinVal: 0.5,
      cosVal: 0.8660254037844386,
      tanVal: 0.5773502691896257,
    ),
    45: NotableFirstQuadEntry(
      sinLatex: r'\frac{\sqrt{2}}{2}',
      sinRawUnrationalized: r'\frac{1}{\sqrt{2}}',
      cosLatex: r'\frac{\sqrt{2}}{2}',
      cosRawUnrationalized: r'\frac{1}{\sqrt{2}}',
      tanLatex: '1',
      sinVal: 0.7071067811865476,
      cosVal: 0.7071067811865476,
      tanVal: 1,
    ),
    60: NotableFirstQuadEntry(
      sinLatex: r'\frac{\sqrt{3}}{2}',
      cosLatex: r'\frac{1}{2}',
      tanLatex: r'\sqrt{3}',
      sinVal: 0.8660254037844386,
      cosVal: 0.5,
      tanVal: 1.7320508075688772,
    ),
    90: NotableFirstQuadEntry(
      sinLatex: '1',
      cosLatex: '0',
      tanLatex: null,
      tanRawUnrationalized: null,
      sinVal: 1,
      cosVal: 0,
      tanVal: null,
    ),
  };
}
