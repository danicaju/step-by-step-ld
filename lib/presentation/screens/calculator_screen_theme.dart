part of 'calculator_screen.dart';

/// Tema de hardware: reconstruye la pantalla al cambiarlo y abre el selector.
extension _CalculatorScreenTheme on _CalculatorScreenState {
  void _onThemeChanged() {
    if (mounted) updateState(() {});
  }

  void _openThemePicker() => ThemePickerCard.show(context);
}
