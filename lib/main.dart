import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/calculator_screen.dart';
import 'presentation/theme/calculator_themes.dart';
import 'presentation/theme/theme_contrast.dart';
import 'presentation/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización resiliente: si aún no está configurado google-services.json
  // o falla la red, la aplicación arranca con el motor pedagógico local sin romperse.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase no configurado o sin credenciales nativas ($e). Operando en modo local.');
  }

  await ThemeController.instance.load();

  runApp(const ProviderScope(child: CasioCalculatorApp()));
}

/// Tema global Casio ClassWiz: chasis `#181E29`, tinta `#1A2530`, LCD `#C8D6CD` y acento ámbar.
/// Sustituye los tonos violeta/índigo por defecto de Material 3 (SnackBar, chips, diálogos...).
/// Con [hw] distinto de `Predeterminado`, SnackBar y tooltips toman los colores del tema.
ThemeData casioTheme({CalculatorHardwareTheme? hw}) {
  const ink = Color(0xFF1A2530);
  const lcd = Color(0xFFC8D6CD);
  const amber = Color(0xFFE5A93C);
  const alphaRed = Color(0xFFE05D5D);
  final themed = hw != null && !hw.isDefault;
  final scheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: amber,
    onPrimary: ink,
    primaryContainer: Color(0xFF3A2F14),
    onPrimaryContainer: amber,
    secondary: Color(0xFF8FA39A),
    onSecondary: ink,
    secondaryContainer: Color(0xFF2A332F),
    onSecondaryContainer: lcd,
    tertiary: alphaRed,
    onTertiary: ink,
    tertiaryContainer: Color(0xFF4A2323),
    onTertiaryContainer: Color(0xFFF2B8B8),
    error: alphaRed,
    onError: ink,
    surface: Color(0xFF181E29),
    onSurface: Color(0xFFE8EDE9),
    onSurfaceVariant: Color(0xFFA9B6B0),
    outline: Color(0xFF6B7A74),
    outlineVariant: Color(0xFF3A4540),
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: Color(0xFF12161F),
    surfaceContainerLow: Color(0xFF161B25),
    surfaceContainer: Color(0xFF1B2230),
    surfaceContainerHigh: Color(0xFF202838),
    surfaceContainerHighest: Color(0xFF262F40),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: themed ? hw.panelText : ink,
      contentTextStyle: TextStyle(
        color: themed ? hw.panelBg : lcd,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: themed
          ? ThemeContrast.ensure(hw.shiftKey, hw.panelText, ThemeContrast.text)
          : amber,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 700),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: themed ? hw.panelText : ink,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: themed ? hw.panelBorder : const Color(0xFF474E5D)),
      ),
      textStyle: TextStyle(
        color: themed ? hw.panelBg : lcd,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class CasioCalculatorApp extends StatelessWidget {
  const CasioCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'STEP-BY-STEP LD',
        debugShowCheckedModeBanner: false,
        theme: casioTheme(hw: ThemeController.current),
        home: const CalculatorScreen(),
      ),
    );
  }
}
