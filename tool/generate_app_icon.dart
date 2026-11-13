import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _sansFamily = 'LdIndustrialSans';
const String _mathItalicFamily = 'LdKatexMathItalic';
const String _mathBoldFamily = 'LdKatexMainBold';

void main() {
  test('Generar Iconos Oficiales STEP-BY-STEP LD (1024x1024 px Formato 1)', () async {
    await _loadRenderFonts();

    final iconDir = Directory('assets/icon');
    if (!iconDir.existsSync()) {
      iconDir.createSync(recursive: true);
    }

    // 1. Icono maestro completo (1024x1024 px, 100 % opaco para iOS / Web / Windows)
    final fullResult = await _renderIcon(isForegroundOnly: false);
    final fullFile = File('assets/icon/app_icon.png');
    fullFile.writeAsBytesSync(fullResult.pngBytes);
    expect(fullFile.existsSync(), isTrue);
    expect(fullResult.pngBytes.length, greaterThan(20000));

    // Verificación estricta de opacidad total en app_icon.png (requisito iOS App Store)
    for (final offset in [0, (1024 * 512 + 512) * 4, (1024 * 1024 - 1) * 4]) {
      expect(fullResult.rgbaBytes[offset + 3], equals(255));
    }

    // 2. Capa frontal transparente Android Adaptive (margen de seguridad >= 20 %)
    final fgResult = await _renderIcon(isForegroundOnly: true);
    final fgFile = File('assets/icon/app_icon_foreground.png');
    fgFile.writeAsBytesSync(fgResult.pngBytes);
    expect(fgFile.existsSync(), isTrue);
    expect(fgResult.pngBytes.length, greaterThan(10000));

    // Verificación de transparencia total en el 20 % perimetral de app_icon_foreground.png
    const int marginPx = 205; // >= 20.0 % de margen seguro en los cuatro lados
    for (int y = 0; y < 1024; y += 16) {
      for (int x = 0; x < 1024; x += 16) {
        if (x < marginPx || x >= 1024 - marginPx || y < marginPx || y >= 1024 - marginPx) {
          final alpha = fgResult.rgbaBytes[(y * 1024 + x) * 4 + 3];
          expect(alpha, equals(0), reason: 'Pixel ($x, $y) invade el margen de seguridad del 20 %.');
        }
      }
    }

    debugPrint('Iconos STEP-BY-STEP LD generados en assets/icon/:');
    debugPrint('- app_icon.png (${(fullResult.pngBytes.length / 1024).toStringAsFixed(1)} KB)');
    debugPrint('- app_icon_foreground.png (${(fgResult.pngBytes.length / 1024).toStringAsFixed(1)} KB)');
  });
}

class _RenderedIcon {
  final Uint8List pngBytes;
  final Uint8List rgbaBytes;
  const _RenderedIcon({required this.pngBytes, required this.rgbaBytes});
}

Future<void> _loadRenderFonts() async {
  String? katexFontDir;
  final pkgFile = File('.dart_tool/package_config.json');
  if (pkgFile.existsSync()) {
    try {
      final decoded = jsonDecode(pkgFile.readAsStringSync()) as Map<String, dynamic>;
      final packages = (decoded['packages'] as List<dynamic>?) ?? const [];
      for (final item in packages) {
        if (item is Map<String, dynamic> && item['name'] == 'flutter_math_fork') {
          final rootUri = item['rootUri'] as String?;
          if (rootUri != null) {
            final dir = Directory.fromUri(Uri.parse(rootUri));
            katexFontDir = '${dir.path}${Platform.pathSeparator}lib${Platform.pathSeparator}katex_fonts${Platform.pathSeparator}fonts';
          }
          break;
        }
      }
    } catch (_) {}
  }

  String? flutterMaterialFontsDir;
  try {
    // Platform.resolvedExecutable en `flutter test` apunta a dart/flutter_tester dentro del SDK
    Directory cursor = File(Platform.resolvedExecutable).parent;
    for (int i = 0; i < 6; i++) {
      final candidate = Directory(
        '${cursor.path}${Platform.pathSeparator}bin${Platform.pathSeparator}cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}material_fonts',
      );
      if (candidate.existsSync()) {
        flutterMaterialFontsDir = candidate.path;
        break;
      }
      if (cursor.parent.path == cursor.path) break;
      cursor = cursor.parent;
    }
  } catch (_) {}

  await _registerFont(_sansFamily, [
    if (flutterMaterialFontsDir != null) '$flutterMaterialFontsDir${Platform.pathSeparator}roboto-black.ttf',
    if (flutterMaterialFontsDir != null) '$flutterMaterialFontsDir${Platform.pathSeparator}roboto-bold.ttf',
    r'C:\Windows\Fonts\bahnschrift.ttf',
    r'C:\Windows\Fonts\segoeuib.ttf',
    r'C:\Windows\Fonts\arialbd.ttf',
    if (katexFontDir != null) '$katexFontDir${Platform.pathSeparator}KaTeX_SansSerif-Bold.ttf',
  ]);

  await _registerFont(_mathItalicFamily, [
    if (katexFontDir != null) '$katexFontDir${Platform.pathSeparator}KaTeX_Math-Italic.ttf',
    if (katexFontDir != null) '$katexFontDir${Platform.pathSeparator}KaTeX_Math-BoldItalic.ttf',
    r'C:\Windows\Fonts\georgiai.ttf',
  ]);

  await _registerFont(_mathBoldFamily, [
    if (katexFontDir != null) '$katexFontDir${Platform.pathSeparator}KaTeX_Main-Bold.ttf',
    if (flutterMaterialFontsDir != null) '$flutterMaterialFontsDir${Platform.pathSeparator}roboto-bold.ttf',
    r'C:\Windows\Fonts\georgiab.ttf',
  ]);
}

Future<void> _registerFont(String family, List<String> candidates) async {
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      final loader = FontLoader(family)
        ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
      await loader.load();
      return;
    }
  }
}

Future<_RenderedIcon> _renderIcon({required bool isForegroundOnly}) async {
  const double size = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

  if (!isForegroundOnly) {
    _drawCarbonChassisAndBezel(canvas, size);
  }

  canvas.save();
  if (isForegroundOnly) {
    // Zona segura Android Adaptive: contenido escalado (~22 % de margen por lado >= 20 %)
    canvas.translate(size / 2, size / 2);
    canvas.scale(0.72);
    canvas.translate(-size / 2, -(size / 2) + 18.0);
  }

  // 1. Cabecera: Siglas LD + micro-etiqueta STEP en ámbar #E5A93C
  _drawBrandHeader(canvas);

  // 2. Mitad superior: Mini Pantalla LCD hundida (#DDE6DF) con inset shadow 12 px
  _drawMiniLcdScreen(canvas);

  // 3. Mitad inferior: Cuadrícula 2x2 de teclas físicas abombadas Casio ClassWiz
  _drawPhysicalKeypadGrid(canvas);

  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
  final rgbaData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _RenderedIcon(
    pngBytes: pngData!.buffer.asUint8List(),
    rgbaBytes: rgbaData!.buffer.asUint8List(),
  );
}

void _drawCarbonChassisAndBezel(Canvas canvas, double size) {
  // Base 100 % opaca carbón oscuro (#181A1E)
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size, size),
    Paint()..color = const Color(0xFF181A1E),
  );

  // Viñeteado direccional mate muy sutil para profundidad industrial sin neones
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size, size),
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size),
        const [Color(0xFF1E2127), Color(0xFF181A1E), Color(0xFF121417)],
        const [0.0, 0.45, 1.0],
      ),
  );

  // Patrón geométrico diagonal tejido de fibra de carbono Casio ClassWiz (2x2 twill)
  const double step = 28.0;
  final darkStrand = Paint()..color = const Color(0xFF111317).withValues(alpha: 0.48);
  final litStrand = Paint()..color = const Color(0xFF23272F).withValues(alpha: 0.36);
  final microHairline = Paint()
    ..color = const Color(0xFF343A46).withValues(alpha: 0.20)
    ..strokeWidth = 1.1
    ..style = PaintingStyle.stroke;

  for (double y = -step; y < size + step; y += step) {
    final int row = (y / step).floor();
    for (double x = -step; x < size + step; x += step) {
      final int col = (x / step).floor();
      final bool isEvenDiag = ((row + col) & 1) == 0;
      final Path diamond = Path()
        ..moveTo(x + step * 0.5, y)
        ..lineTo(x + step, y + step * 0.5)
        ..lineTo(x + step * 0.5, y + step)
        ..lineTo(x, y + step * 0.5)
        ..close();
      canvas.drawPath(diamond, isEvenDiag ? litStrand : darkStrand);

      // Sutil veta direccional alterna ±45° propia del tejido de carbono
      if (isEvenDiag) {
        canvas.drawLine(
          Offset(x + 4, y + step * 0.5),
          Offset(x + step * 0.5, y + 4),
          microHairline,
        );
      } else {
        canvas.drawLine(
          Offset(x + step * 0.5, y + 4),
          Offset(x + step - 4, y + step * 0.5),
          microHairline,
        );
      }
    }
  }

  // Bisel interior metálico oscuro (#2A2E37) con ranura mecanizada
  const double bezelInset = 46.0;
  final bezelRRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(bezelInset, bezelInset, size - bezelInset * 2, size - bezelInset * 2),
    const Radius.circular(174),
  );

  // Ranura exterior oscura para dar relieve al bisel metálico
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(bezelInset - 4, bezelInset - 4, size - (bezelInset - 4) * 2, size - (bezelInset - 4) * 2),
      const Radius.circular(178),
    ),
    Paint()
      ..color = const Color(0xFF0C0D10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0,
  );

  // Aro principal en #2A2E37 con luz cenital metálica sutil
  canvas.drawRRect(
    bezelRRect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..shader = ui.Gradient.linear(
        const Offset(0, bezelInset),
        Offset(0, size - bezelInset),
        const [Color(0xFF3E4552), Color(0xFF2A2E37), Color(0xFF1D2027)],
        const [0.0, 0.45, 1.0],
      ),
  );

  // Ranura interior limpia
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(bezelInset + 7, bezelInset + 7, size - (bezelInset + 7) * 2, size - (bezelInset + 7) * 2),
      const Radius.circular(167),
    ),
    Paint()
      ..color = const Color(0xFF0F1114)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0,
  );
}

void _drawBrandHeader(Canvas canvas) {
  const double left = 128.0;
  const double right = 896.0;
  const double baselineY = 104.0;

  // Siglas LD en tipografía geométrica industrial bold blanca/plata
  final ldParagraph = _buildParagraph(
    text: 'LD',
    fontSize: 60.0,
    fontWeight: FontWeight.w900,
    fontFamily: _sansFamily,
    color: const Color(0xFFF1F5F9),
    letterSpacing: 3.0,
    maxWidth: 180.0,
    height: 1.0,
  );
  canvas.drawParagraph(ldParagraph, const Offset(left, baselineY));

  // Micro-etiqueta STEP en ámbar #E5A93C justo al lado de LD
  const double pillLeft = left + 104.0;
  const double pillTop = baselineY + 9.0;
  const double pillW = 114.0;
  const double pillH = 40.0;
  final pillRect = const Rect.fromLTWH(pillLeft, pillTop, pillW, pillH);
  final pillRRect = RRect.fromRectAndRadius(pillRect, const Radius.circular(8.0));

  canvas.drawRRect(
    pillRRect,
    Paint()
      ..shader = ui.Gradient.linear(
        pillRect.topCenter,
        pillRect.bottomCenter,
        const [Color(0xFFF2BC52), Color(0xFFE5A93C), Color(0xFFC88B22)],
        const [0.0, 0.55, 1.0],
      ),
  );
  canvas.drawRRect(
    pillRRect,
    Paint()
      ..color = const Color(0xFFFFE39E).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );

  final stepParagraph = _buildParagraph(
    text: 'STEP',
    fontSize: 24.0,
    fontWeight: FontWeight.w900,
    fontFamily: _sansFamily,
    color: const Color(0xFF141619),
    letterSpacing: 2.2,
    textAlign: TextAlign.center,
    maxWidth: pillW,
    height: 1.0,
  );
  canvas.drawParagraph(
    stepParagraph,
    Offset(pillLeft, pillTop + (pillH - stepParagraph.height) / 2.0),
  );

  // Acabado metálico Casio a la derecha de la insignia hasta alinear con el borde derecho
  const double railStart = pillLeft + pillW + 22.0;
  const double railY = pillTop + pillH / 2.0;
  canvas.drawLine(
    const Offset(railStart, railY),
    const Offset(right, railY),
    Paint()
      ..strokeWidth = 2.5
      ..shader = ui.Gradient.linear(
        const Offset(railStart, railY),
        const Offset(right, railY),
        const [Color(0xFF47505E), Color(0xFF2A2E37)],
      ),
  );
  // Pequeño remate ámbar técnico en el extremo derecho del rail
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(right - 14.0, railY - 3.0, 14.0, 6.0),
      const Radius.circular(3.0),
    ),
    Paint()..color = const Color(0xFFE5A93C),
  );
}

void _drawMiniLcdScreen(Canvas canvas) {
  const double left = 128.0;
  const double top = 182.0;
  const double width = 768.0;
  const double height = 274.0;
  const double radius = 26.0;

  final lcdRect = const Rect.fromLTWH(left, top, width, height);
  final lcdRRect = RRect.fromRectAndRadius(lcdRect, const Radius.circular(radius));

  // Cavidad exterior biselada donde encaja la LCD
  canvas.drawRRect(
    RRect.fromRectAndRadius(lcdRect.inflate(6.0), const Radius.circular(radius + 5)),
    Paint()..color = const Color(0xFF0C0E11),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(lcdRect.inflate(4.0), const Radius.circular(radius + 3)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = ui.Gradient.linear(
        lcdRect.topCenter,
        lcdRect.bottomCenter,
        const [Color(0xFF20242B), Color(0xFF393F4B)],
      ),
  );

  // Cristal líquido verde clásico (#DDE6DF)
  canvas.drawRRect(
    lcdRRect,
    Paint()
      ..shader = ui.Gradient.linear(
        lcdRect.topCenter,
        lcdRect.bottomCenter,
        const [Color(0xFFD5DFD7), Color(0xFFDDE6DF), Color(0xFFE2EBE4)],
        const [0.0, 0.55, 1.0],
      ),
  );

  // Inset shadow oscura real de 12 px recortada dentro de la LCD
  canvas.save();
  canvas.clipRRect(lcdRRect);

  // Halo de sombra interior de 12 px (stroke 24 px centrado en el perímetro, la mitad entra 12 px)
  canvas.drawRRect(
    lcdRRect.shift(const Offset(0, 3)),
    Paint()
      ..color = const Color(0xFF0B120E).withValues(alpha: 0.56)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0),
  );

  // Gradiente lineal superior de 12 px simulando profundidad bajo el marco
  canvas.drawRect(
    const Rect.fromLTWH(left, top, width, 16.0),
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(left, top),
        const Offset(left, top + 16.0),
        [const Color(0xFF243028).withValues(alpha: 0.48), const Color(0x00243028)],
      ),
  );

  // Marco fino interior del cristal
  canvas.drawRRect(
    lcdRRect,
    Paint()
      ..color = const Color(0xFF56685C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5,
  );

  // Fórmula exacta limpia: \frac{\sqrt{x}}{2} en tinta oscura #0F172A
  _drawLcdSqrtFraction(canvas, centerX: left + 252.0, centerY: top + height / 2.0);

  // Flechas de paso ◀ ▶ en azul Casio (#2563EB) a la derecha de la LCD
  _drawLcdStepArrows(canvas, centerX: left + 618.0, centerY: top + height / 2.0);

  canvas.restore();
}

void _drawLcdSqrtFraction(
  Canvas canvas, {
  required double centerX,
  required double centerY,
}) {
  const Color inkColor = Color(0xFF0F172A);
  final strokePaint = Paint()
    ..color = inkColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // Coordenada vertical de la barra de fracción principal
  final double barY = centerY + 14.0;
  const double barHalfW = 112.0;

  // 1. Barra de fracción horizontal limpia
  canvas.drawLine(
    Offset(centerX - barHalfW, barY),
    Offset(centerX + barHalfW, barY),
    strokePaint,
  );

  // 2. Numerador: √x centrado sobre la barra
  const double radLeft = -78.0;
  final double radTop = barY - 102.0;
  final double radBottom = barY - 22.0;
  const double radRight = 70.0;

  final sqrtPath = Path()
    ..moveTo(centerX + radLeft - 14, radTop + 46)
    ..lineTo(centerX + radLeft, radTop + 38)
    ..lineTo(centerX + radLeft + 18, radBottom)
    ..lineTo(centerX + radLeft + 46, radTop)
    ..lineTo(centerX + radRight, radTop)
    ..lineTo(centerX + radRight, radTop + 15);
  canvas.drawPath(sqrtPath, strokePaint);

  // Variable itálica KaTeX 'x' centrada bajo el techo del radical [-32..+70 -> centro +19]
  final xPara = _buildParagraph(
    text: 'x',
    fontSize: 84.0,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    fontFamily: _mathItalicFamily,
    color: inkColor,
    textAlign: TextAlign.center,
    maxWidth: 90.0,
    height: 1.0,
  );
  canvas.drawParagraph(xPara, Offset(centerX + 19.0 - 45.0, radTop + 8.0));

  // 3. Denominador '2' debajo de la barra de fracción
  final twoPara = _buildParagraph(
    text: '2',
    fontSize: 82.0,
    fontWeight: FontWeight.bold,
    fontFamily: _mathBoldFamily,
    color: inkColor,
    textAlign: TextAlign.center,
    maxWidth: 100.0,
    height: 1.0,
  );
  canvas.drawParagraph(twoPara, Offset(centerX - 50.0, barY + 14.0));
}

void _drawLcdStepArrows(
  Canvas canvas, {
  required double centerX,
  required double centerY,
}) {
  // Separador vertical sutil estilo LCD Casio entre fórmula y flechas de paso
  canvas.drawLine(
    Offset(centerX - 134.0, centerY - 64.0),
    Offset(centerX - 134.0, centerY + 64.0),
    Paint()
      ..color = const Color(0xFF9FB0A4)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round,
  );

  final arrowPaint = Paint()
    ..color = const Color(0xFF2563EB)
    ..style = PaintingStyle.fill;

  const double triW = 48.0;
  const double triHalfH = 34.0;
  const double gap = 28.0;

  // Flecha izquierda ◀
  final double leftCenterX = centerX - gap / 2.0 - triW / 2.0;
  final leftArrow = Path()
    ..moveTo(leftCenterX - triW / 2.0, centerY)
    ..lineTo(leftCenterX + triW / 2.0, centerY - triHalfH)
    ..lineTo(leftCenterX + triW / 2.0, centerY + triHalfH)
    ..close();
  canvas.drawPath(leftArrow, arrowPaint);

  // Flecha derecha ▶
  final double rightCenterX = centerX + gap / 2.0 + triW / 2.0;
  final rightArrow = Path()
    ..moveTo(rightCenterX + triW / 2.0, centerY)
    ..lineTo(rightCenterX - triW / 2.0, centerY - triHalfH)
    ..lineTo(rightCenterX - triW / 2.0, centerY + triHalfH)
    ..close();
  canvas.drawPath(rightArrow, arrowPaint);
}

void _drawPhysicalKeypadGrid(Canvas canvas) {
  const double gridLeft = 128.0;
  const double gridTop = 492.0;
  const double colGap = 28.0;
  const double rowGap = 26.0;
  const double keyW = (768.0 - colGap) / 2.0; // 370 px
  const double keyH = (400.0 - rowGap) / 2.0; // 187 px

  final topLeft = const Rect.fromLTWH(gridLeft, gridTop, keyW, keyH);
  final topRight = Rect.fromLTWH(gridLeft + keyW + colGap, gridTop, keyW, keyH);
  final bottomLeft = Rect.fromLTWH(gridLeft, gridTop + keyH + rowGap, keyW, keyH);
  final bottomRight = Rect.fromLTWH(gridLeft + keyW + colGap, gridTop + keyH + rowGap, keyW, keyH);

  // 1. Arriba-Izquierda: SHIFT dorada Casio (#E5A93C)
  _drawDomedCasioKey(
    canvas,
    rect: topLeft,
    baseColor: const Color(0xFFE5A93C),
    contentBuilder: (r) {
      final p = _buildParagraph(
        text: 'SHIFT',
        fontSize: 54.0,
        fontWeight: FontWeight.w900,
        fontFamily: _sansFamily,
        color: const Color(0xFF141619),
        letterSpacing: 2.0,
        textAlign: TextAlign.center,
        maxWidth: r.width,
        height: 1.0,
      );
      canvas.drawParagraph(p, Offset(r.left, r.top + (r.height - p.height) / 2.0));
    },
  );

  // 2. Arriba-Derecha: ALPHA roja coral (#E05252)
  _drawDomedCasioKey(
    canvas,
    rect: topRight,
    baseColor: const Color(0xFFE05252),
    contentBuilder: (r) {
      final p = _buildParagraph(
        text: 'ALPHA',
        fontSize: 54.0,
        fontWeight: FontWeight.w900,
        fontFamily: _sansFamily,
        color: Colors.white,
        letterSpacing: 2.0,
        textAlign: TextAlign.center,
        maxWidth: r.width,
        height: 1.0,
      );
      canvas.drawParagraph(p, Offset(r.left, r.top + (r.height - p.height) / 2.0));
    },
  );

  // 3. Abajo-Izquierda: Tecla carbón (#22252B) con símbolo de fracción a/b vertical
  _drawDomedCasioKey(
    canvas,
    rect: bottomLeft,
    baseColor: const Color(0xFF22252B),
    contentBuilder: (r) {
      final cx = r.center.dx;
      final cy = r.center.dy;
      const white = Color(0xFFF8FAFC);

      final aPara = _buildParagraph(
        text: 'a',
        fontSize: 48.0,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        fontFamily: _mathItalicFamily,
        color: white,
        textAlign: TextAlign.center,
        maxWidth: 80.0,
        height: 1.0,
      );
      canvas.drawParagraph(aPara, Offset(cx - 40.0, cy - 54.0));

      canvas.drawLine(
        Offset(cx - 34.0, cy + 1.0),
        Offset(cx + 34.0, cy + 1.0),
        Paint()
          ..color = white
          ..strokeWidth = 6.5
          ..strokeCap = StrokeCap.round,
      );

      final bPara = _buildParagraph(
        text: 'b',
        fontSize: 48.0,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        fontFamily: _mathItalicFamily,
        color: white,
        textAlign: TextAlign.center,
        maxWidth: 80.0,
        height: 1.0,
      );
      canvas.drawParagraph(bPara, Offset(cx - 40.0, cy + 6.0));
    },
  );

  // 4. Abajo-Derecha: Tecla azul Casio (#3B78E7) con signo '=' vectorial blanco
  _drawDomedCasioKey(
    canvas,
    rect: bottomRight,
    baseColor: const Color(0xFF3B78E7),
    contentBuilder: (r) {
      final cx = r.center.dx;
      final cy = r.center.dy;
      final eqPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy - 19.0), width: 92.0, height: 15.0),
          const Radius.circular(5.0),
        ),
        eqPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy + 19.0), width: 92.0, height: 15.0),
          const Radius.circular(5.0),
        ),
        eqPaint,
      );
    },
  );
}

void _drawDomedCasioKey(
  Canvas canvas, {
  required Rect rect,
  required Color baseColor,
  required void Function(Rect keyFaceRect) contentBuilder,
}) {
  const double radius = 28.0;
  final keyRRect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));

  // 1. Hueco de alojamiento oscuro alrededor de la tecla
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect.inflate(4.0), const Radius.circular(radius + 3)),
    Paint()..color = const Color(0xFF0D0E12),
  );

  // 2. Sombra de apoyo contenida (anti-slop)
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect.translate(0, 9.0), const Radius.circular(radius)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.62)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0),
  );

  // 3. Faldón físico inferior 3D (espesor de tecla ClassWiz)
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect.translate(0, 6.0), const Radius.circular(radius)),
    Paint()..color = Color.lerp(baseColor, Colors.black, 0.50)!,
  );

  // 4. Cara abombada convexa cilíndrica clásica Casio (sin foco circular)
  canvas.drawRRect(
    keyRRect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [
          Color.lerp(baseColor, Colors.white, 0.14)!,
          baseColor,
          Color.lerp(baseColor, baseColor, 1.0)!,
          Color.lerp(baseColor, Colors.black, 0.17)!,
        ],
        const [0.0, 0.24, 0.72, 1.0],
      ),
  );

  // Curvatura lateral sutil de tecla moldeada y catchlight cenital limpio
  canvas.save();
  canvas.clipRRect(keyRRect);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.centerLeft,
        rect.centerRight,
        [
          Colors.black.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.05),
          Colors.black.withValues(alpha: 0.14),
        ],
        const [0.0, 0.22, 0.78, 1.0],
      ),
  );

  // Catchlight cenital limpio en el labio superior
  canvas.drawLine(
    Offset(rect.left + radius, rect.top + 2.0),
    Offset(rect.right - radius, rect.top + 2.0),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round,
  );
  canvas.restore();

  // Contorno fino nítido
  canvas.drawRRect(
    keyRRect,
    Paint()
      ..color = Color.lerp(baseColor, Colors.white, 0.20)!.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  );

  // Contenido tipográfico / vectorial centrado sobre la cara de la tecla
  contentBuilder(rect);
}

ui.Paragraph _buildParagraph({
  required String text,
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
  required double maxWidth,
  String? fontFamily,
  FontStyle fontStyle = FontStyle.normal,
  TextAlign textAlign = TextAlign.left,
  double? letterSpacing,
  double? height,
}) {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textAlign: textAlign,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontFamily: fontFamily,
    ),
  )
    ..pushStyle(
      ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        fontFamily: fontFamily,
        letterSpacing: letterSpacing,
        height: height,
      ),
    )
    ..addText(text);

  return builder.build()..layout(ui.ParagraphConstraints(width: maxWidth));
}
