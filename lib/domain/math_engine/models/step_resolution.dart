class MathStep {
  final int index;
  final String shortTitle;
  final String latexExpression;
  final String pedagogicalNote;
  final String? warningTrick;

  const MathStep({
    required this.index,
    required this.shortTitle,
    required this.latexExpression,
    required this.pedagogicalNote,
    this.warningTrick,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'shortTitle': shortTitle,
        'latexExpression': latexExpression,
        'pedagogicalNote': pedagogicalNote,
        'warningTrick': warningTrick,
      };

  factory MathStep.fromJson(Map<String, dynamic> json) => MathStep(
        index: json['index'] as int? ?? 1,
        shortTitle: json['shortTitle'] as String? ?? '',
        latexExpression: json['latexExpression'] as String? ?? '',
        pedagogicalNote: json['pedagogicalNote'] as String? ?? '',
        warningTrick: json['warningTrick'] as String?,
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
