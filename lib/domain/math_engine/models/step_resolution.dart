class MathStep {
  final int index;
  final String shortTitle;
  final String latexExpression;
  final String pedagogicalNote;
  final String? warningTrick;

  /// `true` si este paso es el estudio de signos / interseccion que se dibuja en la recta real.
  final bool showsNumberLine;

  const MathStep({
    required this.index,
    required this.shortTitle,
    required this.latexExpression,
    required this.pedagogicalNote,
    this.warningTrick,
    this.showsNumberLine = false,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'shortTitle': shortTitle,
        'latexExpression': latexExpression,
        'pedagogicalNote': pedagogicalNote,
        'warningTrick': warningTrick,
        if (showsNumberLine) 'showsNumberLine': true,
      };

  factory MathStep.fromJson(Map<String, dynamic> json) => MathStep(
        index: json['index'] as int? ?? 1,
        shortTitle: json['shortTitle'] as String? ?? '',
        latexExpression: json['latexExpression'] as String? ?? '',
        pedagogicalNote: json['pedagogicalNote'] as String? ?? '',
        warningTrick: json['warningTrick'] as String?,
        showsNumberLine: json['showsNumberLine'] as bool? ?? false,
      );

  @override
  String toString() =>
      'Paso $index [$shortTitle]: $latexExpression (${warningTrick ?? pedagogicalNote})';
}

class StepByStepResolution {
  final String originalInputLatex;
  final List<MathStep> steps;
  final String exactResultLatex;
  final String decimalApproxLatex;

  const StepByStepResolution({
    required this.originalInputLatex,
    required this.steps,
    required this.exactResultLatex,
    required this.decimalApproxLatex,
  });

  /// Datos auxiliares (p. ej. de la recta real) asociados a una resolucion; sobreviven a
  /// [withOriginalInput].
  static final Expando<Object> attachments = Expando<Object>();

  /// Misma resolucion con otro enunciado (p. ej. con las fracciones verticales tecleadas).
  StepByStepResolution withOriginalInput(String latex) {
    final copy = StepByStepResolution(
      originalInputLatex: latex,
      steps: steps,
      exactResultLatex: exactResultLatex,
      decimalApproxLatex: decimalApproxLatex,
    );
    final extra = attachments[this];
    if (extra != null) attachments[copy] = extra;
    return copy;
  }

  Map<String, dynamic> toJson() => {
        'originalInputLatex': originalInputLatex,
        'steps': steps.map((s) => s.toJson()).toList(),
        'exactResultLatex': exactResultLatex,
        'decimalApproxLatex': decimalApproxLatex,
      };

  factory StepByStepResolution.fromJson(Map<String, dynamic> json) =>
      StepByStepResolution(
        originalInputLatex: json['originalInputLatex'] as String? ?? '',
        steps: (json['steps'] as List<dynamic>?)
                ?.map((e) => MathStep.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        exactResultLatex: json['exactResultLatex'] as String? ?? '',
        decimalApproxLatex: json['decimalApproxLatex'] as String? ?? '',
      );
}
