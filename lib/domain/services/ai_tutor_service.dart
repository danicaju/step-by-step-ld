import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../math_engine/models/step_resolution.dart';

/// Diagnóstico pedagógico generado para orientar al alumno en un paso concreto.
class TutorDiagnosis {
  /// Pregunta socrática que guía el razonamiento sin regalar el resultado
  final String socraticQuestion;

  /// Regla conceptual del currículo de ESO/Bachillerato aplicable
  final String conceptualHint;

  /// Advertencia de trampa de examen si aplica a este paso
  final String? examTrapAlert;

  /// Indica si proviene de Gemini en Cloud o del motor pedagógico local
  final bool isCloudAi;

  const TutorDiagnosis({
    required this.socraticQuestion,
    required this.conceptualHint,
    this.examTrapAlert,
    required this.isCloudAi,
  });
}

/// Servicio del Tutor IA con arquitectura de Fallback resiliente
class AiTutorService {
  /// Analiza el paso activo devolviendo un diagnóstico socrático
  Future<TutorDiagnosis> analyzeCurrentStep({
    required StepByStepResolution resolution,
    required int stepIndex,
    String? studentDoubt,
  }) async {
    final validIndex = stepIndex.clamp(0, resolution.steps.length - 1);
    final MathStep step = resolution.steps[validIndex];

    // 1. Intento Cloud si Firebase está inicializado
    if (Firebase.apps.isNotEmpty) {
      try {
        final diagnosis = await _callCloudTutor(
          resolution: resolution,
          step: step,
          stepIndex: validIndex,
          studentDoubt: studentDoubt,
        );
        if (diagnosis != null) {
          return diagnosis;
        }
      } catch (e) {
        debugPrint('Tutor IA: usando motor local por excepción en nube: $e');
      }
    }

    // 2. Fallback Pedagógico Local (Offline / Sin Firebase aún)
    return _generateLocalDiagnosis(
      resolution: resolution,
      step: step,
      stepIndex: validIndex,
      studentDoubt: studentDoubt,
    );
  }

  /// Llamada a Gemini 2.5 Flash mediante Firebase AI Logic
  Future<TutorDiagnosis?> _callCloudTutor({
    required StepByStepResolution resolution,
    required MathStep step,
    required int stepIndex,
    String? studentDoubt,
  }) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(
        'Eres el Tutor Matemático IA de una calculadora Casio ClassWiz para alumnos de Secundaria (ESO) y Bachillerato en España. '
        'Tu misión es enseñar usando el método socrático: NUNCA des la solución final directa ni hagas el cálculo por el alumno. '
        'Haz preguntas que le hagan reflexionar sobre la jerarquía de operaciones, los signos, el m.c.m. o las propiedades algebraicas. '
        'Escribe siempre en texto claro y legible (usa Unicode como x², xᵥ, ·, √ en lugar de código LaTeX crudo como \\frac, \\cdot o guiones bajos). '
        'Responde exactamente en este formato de 3 líneas:\n'
        'PREGUNTA: [Pregunta socrática breve]\n'
        'PISTA: [Regla conceptual de ESO explicada de forma clara y amena]\n'
        'ALERTA: [Alerta de error típico de examen si existe, o escribe NINGUNA]',
      ),
    );

    final userPrompt = StringBuffer();
    userPrompt.writeln('Expresión original: ${resolution.originalInputLatex}');
    userPrompt.writeln(
        'Paso actual (${stepIndex + 1}/${resolution.steps.length}): ${step.shortTitle}');
    userPrompt.writeln('Operación del paso: ${step.latexExpression}');
    userPrompt.writeln('Nota del paso: ${step.pedagogicalNote}');
    if (step.warningTrick != null) {
      userPrompt.writeln('Alerta registrada: ${step.warningTrick}');
    }
    if (studentDoubt != null) {
      userPrompt.writeln('Duda específica del alumno: "$studentDoubt"');
    }

    final response = await model.generateContent([
      Content.text(userPrompt.toString()),
    ]);

    final text = response.text;
    if (text == null || text.trim().isEmpty) return null;

    String socratic = '';
    String hint = '';
    String? trap;

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('PREGUNTA:')) {
        socratic = trimmed.substring('PREGUNTA:'.length).trim();
      } else if (trimmed.startsWith('PISTA:')) {
        hint = trimmed.substring('PISTA:'.length).trim();
      } else if (trimmed.startsWith('ALERTA:')) {
        final alertText = trimmed.substring('ALERTA:'.length).trim();
        if (alertText.toUpperCase() != 'NINGUNA' && alertText.isNotEmpty) {
          trap = alertText;
        }
      }
    }

    if (socratic.isEmpty && hint.isEmpty) return null;

    return TutorDiagnosis(
      socraticQuestion: socratic.isNotEmpty
          ? socratic
          : '¿Qué operación tiene prioridad en este paso según la jerarquía matemática?',
      conceptualHint: hint.isNotEmpty ? hint : step.pedagogicalNote,
      examTrapAlert: trap ?? step.warningTrick,
      isCloudAi: true,
    );
  }

  /// Motor socrático local basado en pattern matching del AST y las notas pedagógicas
  TutorDiagnosis _generateLocalDiagnosis({
    required StepByStepResolution resolution,
    required MathStep step,
    required int stepIndex,
    String? studentDoubt,
  }) {
    final titleLower = step.shortTitle.toLowerCase();
    final latex = step.latexExpression;

    // A. Si el alumno ha seleccionado una duda predeterminada
    if (studentDoubt != null) {
      return _respondToSpecificDoubt(
        studentDoubt: studentDoubt,
        step: step,
        titleLower: titleLower,
        latex: latex,
      );
    }

    // B. Diagnóstico socrático contextual según el tipo de paso
    // Caso 1: Potencias con trampa de signo negativo (-3^2 vs (-3)^2)
    if (step.warningTrick != null || titleLower.contains('potencia')) {
      final isWithoutParentheses =
          step.warningTrick != null || titleLower.contains('sin paréntesis');
      if (isWithoutParentheses) {
        return TutorDiagnosis(
          socraticQuestion:
              '¿A qué afecta realmente el exponente: a todo el bloque o únicamente al número positivo?',
          conceptualHint:
              'En matemáticas, la potencia tiene mayor prioridad que el signo menos unario. '
              '-3² significa -(3 · 3) = -9. Para elevar el signo menos es obligatorio usar paréntesis: (-3)²',
          examTrapAlert: step.warningTrick ??
              '¡Error clásico en exámenes! Confundir -aⁿ con (-a)ⁿ.',
          isCloudAi: false,
        );
      } else {
        return TutorDiagnosis(
          socraticQuestion:
              '¿Por qué al estar el signo menos dentro del paréntesis el exponente par da resultado positivo?',
          conceptualHint:
              'Recuerda: (-a)ⁿ significa multiplicar (-a) por sí mismo n veces. '
              'Menos por menos es más, por lo que potencias pares de números negativos siempre resultan positivas.',
          examTrapAlert: null,
          isCloudAi: false,
        );
      }
    }

    // Caso 2: Denominador común (m.c.m.)
    if (titleLower.contains('m.c.m.') || titleLower.contains('denominador común')) {
      return TutorDiagnosis(
        socraticQuestion:
            '¿Por qué no podemos sumar directamente los numeradores cuando las fracciones tienen denominadores diferentes?',
        conceptualHint:
            'Para sumar fracciones necesitamos que las porciones sean del mismo tamaño. '
            'El m.c.m. calcula el denominador común más pequeño tomando factores comunes y no comunes al mayor exponente.',
        examTrapAlert:
            '¡Nunca sumes los denominadores abajo! El denominador común se mantiene intacto.',
        isCloudAi: false,
      );
    }

    // Caso 3: Amplificación de fracciones
    if (titleLower.contains('amplificar')) {
      return TutorDiagnosis(
        socraticQuestion:
            'Si multiplicas el denominador por un número para llegar al m.c.m., ¿qué debes hacerle al numerador para que la fracción no cambie de valor?',
        conceptualHint:
            'Multiplicar el numerador y el denominador por el mismo factor crea una fracción equivalente de idéntico valor numérico.',
        examTrapAlert:
            'Recuerda multiplicar también el numerador. Si solo cambias el denominador, cambias el valor de la fracción.',
        isCloudAi: false,
      );
    }

    // Caso 4: Simplificación de fracción inicial o final
    if (titleLower.contains('simplificar')) {
      return TutorDiagnosis(
        socraticQuestion:
            '¿Qué número divide de forma exacta tanto al numerador como al denominador?',
        conceptualHint:
            'Dividir ambos términos entre su Máximo Común Divisor (M.C.D.) produce la fracción irreducible más sencilla posible.',
        examTrapAlert: null,
        isCloudAi: false,
      );
    }

    // Caso 5: Operar numeradores
    if (titleLower.contains('operar numeradores')) {
      return TutorDiagnosis(
        socraticQuestion:
            'Una vez unificados los denominadores, ¿qué regla de signos aplicas a los numeradores?',
        conceptualHint:
            'Mantenemos el denominador común y sumamos o restamos algebraicamente los numeradores respetando la regla de signos.',
        examTrapAlert:
            'Cuidado con los signos negativos delante de una fracción: afectan a todo el numerador.',
        isCloudAi: false,
      );
    }

    // Caso 6: Multiplicación o División
    if (titleLower.contains('multiplicación') || titleLower.contains('división')) {
      final isDiv = titleLower.contains('división');
      return TutorDiagnosis(
        socraticQuestion: isDiv
            ? '¿Cómo se resuelve una división de fracciones: en línea o multiplicando en cruz?'
            : 'En la multiplicación de fracciones, ¿qué términos se multiplican entre sí?',
        conceptualHint: isDiv
            ? 'Para dividir fracciones multiplicamos en cruz: numerador por denominador opuesto.'
            : 'Para multiplicar fracciones operamos en línea recta: numerador por numerador y denominador por denominador.',
        examTrapAlert: isDiv
            ? 'No dividas los números directamente; la división de fracciones se convierte en una multiplicación cruzada.'
            : null,
        isCloudAi: false,
      );
    }

    // Caso 7: Vectores 2D/3D (Ortogonalidad y Producto Vectorial)
    if (titleLower.contains('producto escalar') || titleLower.contains('producto vectorial') || titleLower.contains('adjuntos (cuidado signo')) {
      final isCross = titleLower.contains('adjuntos') || titleLower.contains('determinante simbólico');
      return TutorDiagnosis(
        socraticQuestion: isCross
            ? '¿Por qué la componente j del determinante 3×3 lleva un signo negativo delante?'
            : 'Si el producto escalar u · v da exactamente 0, ¿qué ángulo forman ambos vectores entre sí?',
        conceptualHint: isCross
            ? 'Al desarrollar un determinante por adjuntos de la 1.ª fila, la posición (1,2) tiene signo (-1)¹⁺² = -1. Ese signo menos afecta a todo el menor de j.'
            : 'Por definición u · v = |u|·|v|·cos(α). Cuando u · v = 0 entre vectores no nulos, cos(α) = 0 y por tanto α = 90° (son ortogonales).',
        examTrapAlert: step.warningTrick,
        isCloudAi: false,
      );
    }

    // Caso 8: Números Complejos (i² = -1, Conjugado, Cuadrantes Polares)
    if (titleLower.contains('conjugado') || titleLower.contains('i² = -1') || titleLower.contains('argumento α')) {
      return TutorDiagnosis(
        socraticQuestion: titleLower.contains('argumento')
            ? 'Antes de usar arctan(b/a), ¿en qué cuadrante cae el punto (a, b) para saber si hay que sumar 180° o 360°?'
            : 'Al sustituir i² por -1 en una multiplicación o división de complejos, ¿qué ocurre con el signo del denominador o de bd·i²?',
        conceptualHint: step.pedagogicalNote,
        examTrapAlert: step.warningTrick,
        isCloudAi: false,
      );
    }

    // Caso 9: Cálculo (Derivadas, Tangente e Integrales por Barrow)
    if (titleLower.contains('deriv') || titleLower.contains('integr') || titleLower.contains('barrow') || titleLower.contains('primitiva') || titleLower.contains('pendiente')) {
      return TutorDiagnosis(
        socraticQuestion: titleLower.contains('barrow')
            ? 'Al aplicar F(b) - F(a), ¿por qué es obligatorio poner todo F(a) dentro de un paréntesis tras el signo menos?'
            : (titleLower.contains('deriv')
                ? 'Cuando derivas un término de la forma a·xⁿ, ¿qué le haces primero al exponente n y qué pasa después con su grado?'
                : 'Al integrar término a término ∫ a·xⁿ dx, ¿en cuánto aumenta el exponente y entre qué número divides?'),
        conceptualHint: step.pedagogicalNote,
        examTrapAlert: step.warningTrick,
        isCloudAi: false,
      );
    }

    // Respuesta genérica inteligente
    return TutorDiagnosis(
      socraticQuestion:
          '¿Cuál es la propiedad matemática fundamental que se aplica en este paso?',
      conceptualHint: step.pedagogicalNote,
      examTrapAlert: step.warningTrick,
      isCloudAi: false,
    );
  }

  /// Respuestas contextualizadas a las dudas frecuentes del alumno
  TutorDiagnosis _respondToSpecificDoubt({
    required String studentDoubt,
    required MathStep step,
    required String titleLower,
    required String latex,
  }) {
    if (studentDoubt.contains('signo')) {
      return TutorDiagnosis(
        socraticQuestion:
            'Fíjate bien en el signo delante del número: ¿está dentro o fuera de algún paréntesis o potencia?',
        conceptualHint:
            'Regla de signos clave: + con + da +, - con - da +, y signos distintos dan -. '
            'En potencias: -x² es negativo, pero (-x)² con exponente par siempre es positivo.',
        examTrapAlert: step.warningTrick,
        isCloudAi: false,
      );
    }

    if (studentDoubt.contains('denominador')) {
      return TutorDiagnosis(
        socraticQuestion:
            '¿Puedes descomponer los denominadores en números primos para ver qué factores comparten?',
        conceptualHint:
            'El denominador común se obtiene con el m.c.m. de los denominadores. '
            'Factorizamos cada uno y elegimos todos los factores primos con su exponente más alto.',
        examTrapAlert:
            'No inventes un denominador sumándolos: siempre debe ser múltiplo exacto de ambos.',
        isCloudAi: false,
      );
    }

    // Ejemplo parecido más fácil
    return TutorDiagnosis(
      socraticQuestion:
          'Si entendemos el caso sencillo, ¿puedes aplicar exactamente los mismos pasos a tu ejercicio?',
      conceptualHint: titleLower.contains('potencia')
          ? 'Ejemplo fácil: -2² = -(2 · 2) = -4, mientras que (-2)² = (-2) · (-2) = +4.'
          : 'Ejemplo fácil: 1/2 + 1/4 = 2/4 + 1/4 = 3/4 (el m.c.m. de 2 y 4 es 4).',
      examTrapAlert: step.warningTrick,
      isCloudAi: false,
    );
  }
}
