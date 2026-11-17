/// Formato numérico de resultados (SETUP 2).
enum NumberFormatMode { norm, fix, sci }

/// Salida por defecto: MathI/MathO (exacta) o MathI/DecimalO (decimal directo).
enum MathOutputMode { mathO, decimalO }

/// Configuración global de formato (SETUP 2, 3 y 4) consumida por [Rational].
///
/// Es un singleton de dominio sin dependencias de widgets: la pantalla lo
/// actualiza desde el menú SETUP y todo el motor lo lee al formatear.
class CalculatorSettings {
  CalculatorSettings._();

  /// Norm / Fix / Sci.
  static NumberFormatMode numberFormat = NumberFormatMode.norm;

  /// Dígitos de Fix (decimales 0-9) o Sci (cifras significativas, 0 = 10).
  static int digits = 2;

  /// `true` = fracción mixta `ab/c`; `false` = impropia `d/c`.
  static bool mixedFractions = false;

  /// `true` = coma decimal (por defecto, España); `false` = punto.
  static bool decimalComma = true;

  /// Salida por defecto al pulsar `=` (SETUP).
  static MathOutputMode mathOutput = MathOutputMode.mathO;

  /// `true` = separador de miles (`1 234 567,89`).
  static bool digitSeparator = false;

  /// Restaura los valores de fábrica.
  static void reset() {
    numberFormat = NumberFormatMode.norm;
    digits = 2;
    mixedFractions = false;
    decimalComma = true;
    mathOutput = MathOutputMode.mathO;
    digitSeparator = false;
  }

  static String get numberFormatLabel => switch (numberFormat) {
        NumberFormatMode.norm => 'Norm',
        NumberFormatMode.fix => 'Fix $digits',
        NumberFormatMode.sci => 'Sci ${digits == 0 ? 10 : digits}',
      };
}
