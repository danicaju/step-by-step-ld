import 'calculator_settings.dart';

/// Formateo de números según [CalculatorSettings] (Norm / Fix / Sci, separador y fracción mixta).
class NumberFormatter {
  const NumberFormatter._();

  /// Formatea un decimal para LaTeX respetando Norm / Fix / Sci y el separador.
  static String decimal(double value, {int maxDecimals = 6}) {
    final String raw;
    switch (CalculatorSettings.numberFormat) {
      case NumberFormatMode.fix:
        raw = value.toStringAsFixed(CalculatorSettings.digits);
      case NumberFormatMode.sci:
        raw = _scientific(value);
      case NumberFormatMode.norm:
        if (value == value.roundToDouble()) {
          raw = value.toInt().toString();
        } else {
          raw = value
              .toStringAsFixed(maxDecimals)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
        }
    }
    final grouped = groupThousands(raw);
    return CalculatorSettings.decimalComma ? grouped.replaceAll('.', ',') : grouped;
  }

  /// Agrupa de tres en tres la parte entera si `Digit Sep` está activo.
  static String groupThousands(String raw) {
    if (!CalculatorSettings.digitSeparator || raw.contains(r'\')) return raw;
    final m = RegExp(r'^(-?)(\d+)(.*)$').firstMatch(raw);
    if (m == null) return raw;
    final digits = m.group(2)!;
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(r'\,');
      buf.write(digits[i]);
    }
    return '${m.group(1)}$buf${m.group(3)}';
  }

  static String _scientific(double value) {
    final sig = CalculatorSettings.digits == 0 ? 10 : CalculatorSettings.digits;
    if (value == 0) return (0.0).toStringAsFixed(sig - 1);
    final parts = value.toStringAsExponential(sig - 1).split('e');
    final exp = int.parse(parts[1].replaceFirst('+', ''));
    return '${parts[0]}\\times 10^{$exp}';
  }

  /// Fracción exacta en LaTeX: impropia `\frac{n}{d}` o mixta `w\frac{r}{d}`.
  static String fraction(int numerator, int denominator) {
    if (denominator == 1) return groupThousands('$numerator');
    final abs = numerator.abs();
    final sign = numerator < 0 ? '-' : '';
    if (CalculatorSettings.mixedFractions && abs > denominator) {
      final whole = abs ~/ denominator;
      final rem = abs % denominator;
      if (rem == 0) return '$sign$whole';
      return '$sign$whole\\frac{$rem}{$denominator}';
    }
    return '$sign\\frac{$abs}{$denominator}';
  }

  /// Parsea un decimal aceptando coma o punto como separador.
  static double? parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));
}
