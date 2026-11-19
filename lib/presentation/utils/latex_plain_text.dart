import '../../core/formatting/step_note_formatter.dart';

/// Convierte fragmentos LaTeX incrustados en notas pedagógicas (que se pintan
/// con `Text` nativo) a texto plano legible: `\frac{1}{2}` -> `1/2`,
/// `\sqrt{14}` -> `√(14)`, `x^{2}` -> `x²`, `\cdot` -> `·`.
///
/// Delegado en [StepNoteFormatter] (formateador centralizado, sin `$1` literales).
class LatexPlainText {
  LatexPlainText._();

  static String toPlain(String input) => StepNoteFormatter.toPlain(input);
}
