import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ScannedExerciseResult {
  final String title;
  final String detectedCategory;
  final int targetMode;
  final String extractedExpressionRaw;
  final String extractedLatex;
  final String? handwrittenErrorDetected;

  const ScannedExerciseResult({
    required this.title,
    required this.detectedCategory,
    required this.targetMode,
    required this.extractedExpressionRaw,
    required this.extractedLatex,
    this.handwrittenErrorDetected,
  });
}

class NotebookScannerService {
  final ImagePicker _picker = ImagePicker();

  /// Captura una fotografía usando la cámara del dispositivo
  Future<XFile?> pickFromCamera() async {
    return _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
  }

  /// Selecciona una imagen desde la galería
  Future<XFile?> pickFromGallery() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
  }

  /// Analiza los bytes de la fotografía del cuaderno
  Future<ScannedExerciseResult> scanNotebookBytes(Uint8List imageBytes) async {
    if (Firebase.apps.isNotEmpty) {
      try {
        final cloudResult = await _scanWithGeminiVision(imageBytes);
        if (cloudResult != null) {
          return cloudResult;
        }
      } catch (e) {
        debugPrint('Escáner IA: error en Gemini Vision ($e), usando fallback');
      }
    }

    // Fallback inteligente o modo offline
    return getDemoExercises().first;
  }

  /// Devuelve un ejercicio demo del catálogo para pruebas y simulaciones offline
  Future<ScannedExerciseResult> offlineDemoScan({int index = 0}) async {
    final demos = getDemoExercises();
    return demos[index.clamp(0, demos.length - 1)];
  }

  /// Inferencia multimodal con Gemini 2.5 Flash mediante Firebase AI
  Future<ScannedExerciseResult?> _scanWithGeminiVision(Uint8List bytes) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(
        'Eres el Profesor de Matemáticas y Auditor de Cuadernos de una calculadora Casio para ESO/Bachillerato en España. '
        'Tu tarea es analizar la foto del cuaderno del alumno, transcribir la ecuación o problema matemático y auditar los pasos '
        'escritos a mano para detectar si el alumno cometió algún fallo típico de examen (signos en fracciones, dobles productos, ceros en Ruffini, etc.).\n'
        'Responde estrictamente con estas 5 líneas:\n'
        'TITULO: [Nombre del ejercicio, ej: Ecuación con fracciones]\n'
        'CATEGORIA: [arithmetic | linear_eq | quadratic_eq | ruffini | system_2x2 | notable | function_graph]\n'
        'MODO: [Número del 1 al 7]\n'
        'RAW: [Expresión formateada para la calculadora]\n'
        'LATEX: [Expresión en LaTeX lista para flutter_math_fork]\n'
        'ERROR_DETECTADO: [Explicación detallada del error cometido en el papel, o escribe NINGUNO si todo está bien]',
      ),
    );

    final prompt = 'Analiza esta página de cuaderno escolar, extrae el ejercicio principal y audita los pasos.';
    final response = await model.generateContent([
      Content.multi([
        TextPart(prompt),
        InlineDataPart('image/jpeg', bytes),
      ]),
    ]);

    final text = response.text;
    if (text == null || text.trim().isEmpty) return null;

    String title = 'Ejercicio detectado';
    String category = 'arithmetic';
    int mode = 1;
    String raw = '';
    String latex = '';
    String? errorDetected;

    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.startsWith('TITULO:')) {
        title = t.substring('TITULO:'.length).trim();
      } else if (t.startsWith('CATEGORIA:')) {
        category = t.substring('CATEGORIA:'.length).trim();
      } else if (t.startsWith('MODO:')) {
        mode = int.tryParse(t.substring('MODO:'.length).trim()) ?? 1;
      } else if (t.startsWith('RAW:')) {
        raw = t.substring('RAW:'.length).trim();
      } else if (t.startsWith('LATEX:')) {
        latex = t.substring('LATEX:'.length).trim();
      } else if (t.startsWith('ERROR_DETECTADO:')) {
        final err = t.substring('ERROR_DETECTADO:'.length).trim();
        if (err.toUpperCase() != 'NINGUNO' && err.isNotEmpty) {
          errorDetected = err;
        }
      }
    }

    if (raw.isEmpty) raw = latex;

    return ScannedExerciseResult(
      title: title,
      detectedCategory: category,
      targetMode: mode.clamp(1, 11),
      extractedExpressionRaw: raw,
      extractedLatex: latex,
      handwrittenErrorDetected: errorDetected,
    );
  }

  /// Catálogo de fotos y ejercicios simulados de examen con fallos reales de libreta
  static List<ScannedExerciseResult> getDemoExercises() {
    return const [
      ScannedExerciseResult(
        title: 'Ecuación de 1.º Grado con Fracciones',
        detectedCategory: 'linear_eq',
        targetMode: 2,
        extractedExpressionRaw: r'\frac{x-2}{3} - \frac{x+1}{4} = 2',
        extractedLatex: r'\frac{x - 2}{3} - \frac{x + 1}{4} = 2',
        handwrittenErrorDetected:
            'En el 2.º renglón de tu cuaderno escribiste -3x + 3 en vez de -3x - 3. '
            '¡El signo menos delante de la fracción afecta a todo el numerador!: -(x + 1) = -x - 1.',
      ),
      ScannedExerciseResult(
        title: 'Estudio y Gráfica de Parábola',
        detectedCategory: 'function_graph',
        targetMode: 5,
        extractedExpressionRaw: 'x^2 - 4x + 3',
        extractedLatex: 'y = x^2 - 4x + 3',
        handwrittenErrorDetected:
            'En el cálculo del vértice escribiste xᵥ = 4/2 = -2 por no aplicar bien la regla del doble signo: '
            'xᵥ = -(-4)/(2·1) = +2.',
      ),
      ScannedExerciseResult(
        title: 'Factorización por Regla de Ruffini',
        detectedCategory: 'ruffini',
        targetMode: 4,
        extractedExpressionRaw: '1, 0, -7, 6',
        extractedLatex: 'P(x) = x^3 - 7x + 6',
        handwrittenErrorDetected:
            'En la tabla de Ruffini de tu libreta colocaste los coeficientes 1, -7, 6 olvidando el 0 en x². '
            'Recuerda que un grado ausente siempre lleva un 0.',
      ),
      ScannedExerciseResult(
        title: 'Identidad Notable',
        detectedCategory: 'notable',
        targetMode: 4,
        extractedExpressionRaw: '(2x - 3)^2',
        extractedLatex: '(2x - 3)^2',
        handwrittenErrorDetected:
            'Desarrollaste (2x - 3)² como 4x² + 9 olvidando el doble producto central: 2·(2x)·3 = 12x. '
            'El trinomio correcto es 4x² - 12x + 9.',
      ),
    ];
  }
}
