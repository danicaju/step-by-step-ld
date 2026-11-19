import 'package:flutter/material.dart';

import '../../core/audio/hardware_sound_synthesizer.dart';

/// Forma de las teclas del teclado.
enum KeyCapShape { defaultOriginal, roundedPill, retroWedge, flatChiclet }

/// Morfologia del D-Pad.
enum DPadMorphology { defaultOriginal, circularPetal, retroCross, minimalRing }

/// Acabado de la carcasa (micro-textura).
enum ChassisFinish { carbonDots, softTouch, grain, plain }

/// Estilo resuelto de una tecla fisica.
class KeyStyle {
  final Color background;
  final Color text;
  final Color border;
  final double radius;
  final double relief;
  final bool stadium;
  final bool mono;
  const KeyStyle(this.background, this.text, this.border, this.radius, this.relief,
      {this.stadium = false, this.mono = false});
}

/// Modelo completo de un tema de hardware: colores globales + morfologia + sonido.
///
/// `Predeterminado` ([isDefault]) devuelve siempre los valores originales de la app.
class CalculatorHardwareTheme {
  final String id;
  final String name;
  final bool isDefault;
  final KeyCapShape keyShape;
  final DPadMorphology dpad;
  final ChassisFinish finish;
  final KeySoundProfile sound;
  final bool monoLegends;

  // Superficies exteriores y barra superior.
  final Color outerBg;
  final Color appBarBg;
  final Color appBarTitle;
  final Color appBarAccent;
  final Color barButtonBg;
  final Color barButtonBorder;
  final Color barButtonText;

  // Carcasa.
  final Color chassisTop;
  final Color chassisMid;
  final Color chassisBottom;
  final Color chassisBorder;
  final Color textureColor;

  // Teclas.
  final Color numKey;
  final Color numKeyText;
  final Color funcKey;
  final Color funcKeyText;
  final Color delAcKey;
  final Color shiftKey;
  final Color alphaKey;
  final Color shiftLegend;
  final Color alphaLegend;
  final Color keyBorder;

  // D-Pad.
  final Color dpadBody;
  final Color dpadBorder;
  final Color dpadIcon;

  // LCD.
  final Color lcdBackground;
  final Color lcdInset;

  // Panel derecho / modales.
  final Color panelBg;
  final Color panelTabBar;
  final Color panelCard;
  final Color panelText;
  final Color panelMuted;
  final Color panelBorder;
  final Color panelAccent;

  const CalculatorHardwareTheme({
    required this.id,
    required this.name,
    this.isDefault = false,
    required this.keyShape,
    required this.dpad,
    required this.finish,
    required this.sound,
    this.monoLegends = false,
    required this.outerBg,
    required this.appBarBg,
    required this.appBarTitle,
    required this.appBarAccent,
    required this.barButtonBg,
    required this.barButtonBorder,
    required this.barButtonText,
    required this.chassisTop,
    required this.chassisMid,
    required this.chassisBottom,
    required this.chassisBorder,
    required this.textureColor,
    required this.numKey,
    required this.numKeyText,
    required this.funcKey,
    required this.funcKeyText,
    required this.delAcKey,
    required this.shiftKey,
    required this.alphaKey,
    required this.shiftLegend,
    required this.alphaLegend,
    required this.keyBorder,
    required this.dpadBody,
    required this.dpadBorder,
    required this.dpadIcon,
    required this.lcdBackground,
    required this.lcdInset,
    required this.panelBg,
    required this.panelTabBar,
    required this.panelCard,
    required this.panelText,
    required this.panelMuted,
    required this.panelBorder,
    required this.panelAccent,
  });

  static const Color _origNum = Color(0xFF3B4049);
  static const Color _origSci = Color(0xFF1F2227);
  static const Color _origOp = Color(0xFF4A4F5C);
  static const Color _origShift = Color(0xFFE5A93C);

  /// Fondo de la tecla y color del texto segun su rol; el original se conserva en `Predeterminado`.
  KeyStyle keyStyle(String label, Color? origBg, Color? origText) {
    final bg = origBg ?? _origNum;
    final isDelAc = label == 'DEL' || label == 'AC';
    if (isDefault) {
      return KeyStyle(
        bg,
        origText ?? Colors.white,
        const Color(0xFF494E5B),
        6,
        bg.computeLuminance() < 0.03 ? 1.5 : 3.5,
      );
    }
    final Color fill;
    final Color text;
    if (isDelAc) {
      fill = delAcKey;
      text = Colors.white;
    } else if (label == 'SHIFT') {
      fill = shiftKey;
      text = const Color(0xFF1A1A1A);
    } else if (label == 'ALPHA') {
      fill = alphaKey;
      text = Colors.white;
    } else if (origBg == null || origBg == _origNum) {
      fill = numKey;
      text = numKeyText;
    } else {
      fill = funcKey;
      text = funcKeyText;
    }
    final isSci = origBg == _origSci || origBg == _origOp;
    return switch (keyShape) {
      KeyCapShape.roundedPill =>
        KeyStyle(fill, text, keyBorder, 15, 2.5, stadium: isSci && origBg == _origSci),
      KeyCapShape.retroWedge => KeyStyle(fill, text, keyBorder, 2, 4.5, mono: true),
      KeyCapShape.flatChiclet => KeyStyle(fill, text, keyBorder, 9, 1.0),
      KeyCapShape.defaultOriginal => KeyStyle(fill, text, keyBorder, 6, 3.0),
    };
  }

  /// Leyenda impresa SHIFT/ALPHA sobre la carcasa (se ajusta el contraste en carcasas claras).
  Color get legendShift => isDefault ? _origShift : shiftLegend;
  Color get legendAlpha => isDefault ? const Color(0xFFE05D5D) : alphaLegend;

  /// Traduce un color literal del panel oscuro original a su equivalente en este tema.
  Color panel(Color c) {
    if (isDefault) return c;
    final a = c.a;
    if (c.toARGB32() & 0xFFFFFF == 0) return c;
    if (c.toARGB32() & 0xFFFFFF == 0xE5A93C) return panelAccent.withValues(alpha: a);
    final hsl = HSLColor.fromColor(c);
    if (hsl.saturation > 0.35 && hsl.lightness > 0.25 && hsl.lightness < 0.85) return c;
    final l = hsl.lightness;
    final Color out;
    if (l < 0.12) {
      out = panelBg;
    } else if (l < 0.155) {
      out = panelTabBar;
    } else if (l < 0.168) {
      out = panelBorder;
    } else if (l < 0.19) {
      out = panelCard;
    } else if (l < 0.32) {
      out = panelBorder;
    } else if (l > 0.60) {
      out = panelText;
    } else {
      out = panelMuted;
    }
    return a >= 1 ? out : out.withValues(alpha: a);
  }

  /// Color del `<meta name="theme-color">` y del `body` en web.
  String get webColorHex => _hex(isDefault ? const Color(0xFF121418) : outerBg);

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Barra de estado del sistema: iconos claros sobre fondos oscuros y viceversa.
  Brightness get outerBrightness => outerBg.computeLuminance() < 0.4 ? Brightness.dark : Brightness.light;
}

const Color _white = Color(0xFFFFFFFF);

/// Identificadores persistidos en `SharedPreferences` (`selected_hardware_theme`).
abstract final class HardwareThemes {
  static const CalculatorHardwareTheme defaultTheme = CalculatorHardwareTheme(
    id: 'default',
    name: 'Predeterminado',
    isDefault: true,
    keyShape: KeyCapShape.defaultOriginal,
    dpad: DPadMorphology.defaultOriginal,
    finish: ChassisFinish.carbonDots,
    sound: KeySoundProfile.defaultOriginal,
    outerBg: Color(0xFF121418),
    appBarBg: Color(0xFF141619),
    appBarTitle: Color(0xFFF1F5F9),
    appBarAccent: Color(0xFFE5A93C),
    barButtonBg: Color(0xFF1F232B),
    barButtonBorder: Color(0xFF353C49),
    barButtonText: Color(0xFF94A3B8),
    chassisTop: Color(0xFF22252C),
    chassisMid: Color(0xFF1C1E22),
    chassisBottom: Color(0xFF16181C),
    chassisBorder: Color(0xFF252830),
    textureColor: Color(0x0AFFFFFF),
    numKey: Color(0xFF3B4049),
    numKeyText: _white,
    funcKey: Color(0xFF1F2227),
    funcKeyText: _white,
    delAcKey: Color(0xFF4A4F5C),
    shiftKey: Color(0xFFE5A93C),
    alphaKey: Color(0xFFE05252),
    shiftLegend: Color(0xFFE5A93C),
    alphaLegend: Color(0xFFE05D5D),
    keyBorder: Color(0xFF494E5B),
    dpadBody: Color(0xFF2A2E37),
    dpadBorder: Color(0xFF474E5D),
    dpadIcon: Color(0xFFE2E8F0),
    lcdBackground: Color(0xFFC8D6CD),
    lcdInset: Color(0xFFBDCEBE),
    panelBg: Color(0xFF16191E),
    panelTabBar: Color(0xFF1E222A),
    panelCard: Color(0xFF232830),
    panelText: Color(0xFFE2E8F0),
    panelMuted: Color(0xFF94A3B8),
    panelBorder: Color(0xFF2C323E),
    panelAccent: Color(0xFFE5A93C),
  );

  static const CalculatorHardwareTheme rosa = CalculatorHardwareTheme(
    id: 'rosa',
    name: 'Rosa Soft-Touch',
    keyShape: KeyCapShape.roundedPill,
    dpad: DPadMorphology.circularPetal,
    finish: ChassisFinish.softTouch,
    sound: KeySoundProfile.softSilicone,
    outerBg: Color(0xFFD986A4),
    appBarBg: Color(0xFFC97493),
    appBarTitle: Color(0xFF3B232D),
    appBarAccent: Color(0xFF8F2D4E),
    barButtonBg: Color(0xFFF5DCE5),
    barButtonBorder: Color(0xFFA83256),
    barButtonText: Color(0xFF3B232D),
    chassisTop: Color(0xFFEFA9C1),
    chassisMid: Color(0xFFE89EB8),
    chassisBottom: Color(0xFFDE90AC),
    chassisBorder: Color(0xFFC97493),
    textureColor: Color(0x12FFFFFF),
    numKey: Color(0xFFFDF6F9),
    numKeyText: Color(0xFF3B232D),
    funcKey: Color(0xFFC95D82),
    funcKeyText: _white,
    delAcKey: Color(0xFF8F2D4E),
    shiftKey: Color(0xFFE09F3E),
    alphaKey: Color(0xFFA83256),
    shiftLegend: Color(0xFF7A4A00),
    alphaLegend: Color(0xFF7A1F3D),
    keyBorder: Color(0xFFB0587A),
    dpadBody: Color(0xFFF5DCE5),
    dpadBorder: Color(0xFFC95D82),
    dpadIcon: Color(0xFF3B232D),
    lcdBackground: Color(0xFFDCE3DC),
    lcdInset: Color(0xFFD0D9D0),
    panelBg: Color(0xFFF5DCE5),
    panelTabBar: Color(0xFFEBC4D2),
    panelCard: Color(0xFFFFF7FA),
    panelText: Color(0xFF3B232D),
    panelMuted: Color(0xFF7A5566),
    panelBorder: Color(0xFFD9A5B9),
    panelAccent: Color(0xFFA83256),
  );

  static const CalculatorHardwareTheme arena = CalculatorHardwareTheme(
    id: 'arena',
    name: 'Arena Retro 80s',
    keyShape: KeyCapShape.retroWedge,
    dpad: DPadMorphology.retroCross,
    finish: ChassisFinish.grain,
    sound: KeySoundProfile.retroMechanical,
    monoLegends: true,
    outerBg: Color(0xFFC4B8A3),
    appBarBg: Color(0xFFB3A68F),
    appBarTitle: Color(0xFF2C261E),
    appBarAccent: Color(0xFF8A3A2E),
    barButtonBg: Color(0xFFEAE2D3),
    barButtonBorder: Color(0xFF6E604D),
    barButtonText: Color(0xFF2C261E),
    chassisTop: Color(0xFFDDD4C3),
    chassisMid: Color(0xFFD8CEBC),
    chassisBottom: Color(0xFFCFC4B0),
    chassisBorder: Color(0xFFB3A68F),
    textureColor: Color(0x14000000),
    numKey: Color(0xFFF7F3EB),
    numKeyText: Color(0xFF2C261E),
    funcKey: Color(0xFF6E604D),
    funcKeyText: Color(0xFFF7F3EB),
    delAcKey: Color(0xFFB85446),
    shiftKey: Color(0xFFD9A441),
    alphaKey: Color(0xFFA8452F),
    shiftLegend: Color(0xFF7A5200),
    alphaLegend: Color(0xFF8A2F1F),
    keyBorder: Color(0xFF4F4435),
    dpadBody: Color(0xFF6E604D),
    dpadBorder: Color(0xFF4F4435),
    dpadIcon: Color(0xFFF7F3EB),
    lcdBackground: Color(0xFFC9D3C3),
    lcdInset: Color(0xFFBCC7B6),
    panelBg: Color(0xFFEAE2D3),
    panelTabBar: Color(0xFFDDD4C3),
    panelCard: Color(0xFFF7F3EB),
    panelText: Color(0xFF2C261E),
    panelMuted: Color(0xFF6E604D),
    panelBorder: Color(0xFFB3A68F),
    panelAccent: Color(0xFF8A3A2E),
  );

  static const CalculatorHardwareTheme menta = CalculatorHardwareTheme(
    id: 'menta',
    name: 'Menta Salvia',
    keyShape: KeyCapShape.flatChiclet,
    dpad: DPadMorphology.minimalRing,
    finish: ChassisFinish.plain,
    sound: KeySoundProfile.minimalChiclet,
    outerBg: Color(0xFF739984),
    appBarBg: Color(0xFF65896F),
    appBarTitle: Color(0xFF1D2E25),
    appBarAccent: Color(0xFF2F5A43),
    barButtonBg: Color(0xFFDCE8E0),
    barButtonBorder: Color(0xFF49755D),
    barButtonText: Color(0xFF1D2E25),
    chassisTop: Color(0xFF8DB29D),
    chassisMid: Color(0xFF88AD98),
    chassisBottom: Color(0xFF7FA38E),
    chassisBorder: Color(0xFF65896F),
    textureColor: Color(0x00000000),
    numKey: Color(0xFFF4F8F5),
    numKeyText: Color(0xFF1D2E25),
    funcKey: Color(0xFF49755D),
    funcKeyText: _white,
    delAcKey: Color(0xFFB85A4A),
    shiftKey: Color(0xFFE5A93C),
    alphaKey: Color(0xFFC0503F),
    shiftLegend: Color(0xFF6B4700),
    alphaLegend: Color(0xFF7A2418),
    keyBorder: Color(0xFF5C8470),
    dpadBody: Color(0xFFF4F8F5),
    dpadBorder: Color(0xFF49755D),
    dpadIcon: Color(0xFF1D2E25),
    lcdBackground: Color(0xFFD3E0D6),
    lcdInset: Color(0xFFC6D5C9),
    panelBg: Color(0xFFDCE8E0),
    panelTabBar: Color(0xFFC9DACF),
    panelCard: Color(0xFFF4F8F5),
    panelText: Color(0xFF1D2E25),
    panelMuted: Color(0xFF49755D),
    panelBorder: Color(0xFFA9C2B3),
    panelAccent: Color(0xFF2F5A43),
  );

  static const CalculatorHardwareTheme perla = CalculatorHardwareTheme(
    id: 'perla',
    name: 'Blanco Perla',
    keyShape: KeyCapShape.flatChiclet,
    dpad: DPadMorphology.defaultOriginal,
    finish: ChassisFinish.plain,
    sound: KeySoundProfile.studioCrisp,
    outerBg: Color(0xFFCFD4DE),
    appBarBg: Color(0xFFC1C7D3),
    appBarTitle: Color(0xFF1E2430),
    appBarAccent: Color(0xFF8A5A00),
    barButtonBg: Color(0xFFFFFFFF),
    barButtonBorder: Color(0xFF8E97A8),
    barButtonText: Color(0xFF1E2430),
    chassisTop: Color(0xFFEAEDF2),
    chassisMid: Color(0xFFE3E6EC),
    chassisBottom: Color(0xFFDADEE6),
    chassisBorder: Color(0xFFBBC1CE),
    textureColor: Color(0x00000000),
    numKey: Color(0xFFFFFFFF),
    numKeyText: Color(0xFF1E2430),
    funcKey: Color(0xFF4A5568),
    funcKeyText: _white,
    delAcKey: Color(0xFFC85A53),
    shiftKey: Color(0xFFE5A93C),
    alphaKey: Color(0xFFC0463F),
    shiftLegend: Color(0xFF7A5200),
    alphaLegend: Color(0xFF8E2A24),
    keyBorder: Color(0xFFA4ACBB),
    dpadBody: Color(0xFF2A2E37),
    dpadBorder: Color(0xFF474E5D),
    dpadIcon: Color(0xFFE2E8F0),
    lcdBackground: Color(0xFFC8D6CD),
    lcdInset: Color(0xFFBDCEBE),
    panelBg: Color(0xFFECEFF4),
    panelTabBar: Color(0xFFDDE2EA),
    panelCard: Color(0xFFFFFFFF),
    panelText: Color(0xFF1E2430),
    panelMuted: Color(0xFF4A5568),
    panelBorder: Color(0xFFC3C9D5),
    panelAccent: Color(0xFF8A5A00),
  );

  /// Orden del selector (teclas 1-5 en SETUP).
  static const List<CalculatorHardwareTheme> all = [defaultTheme, rosa, arena, menta, perla];

  static CalculatorHardwareTheme byId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => defaultTheme);
}
