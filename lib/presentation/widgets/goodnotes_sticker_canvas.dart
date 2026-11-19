import 'package:flutter/material.dart';
import '../../domain/math_engine/models/step_resolution.dart';
import '../../domain/math_engine/solvers/function_graph_solver.dart';
import '../theme/theme_contrast.dart';
import '../theme/theme_controller.dart';
import '../utils/latex_plain_text.dart';
import 'casio_graph_canvas.dart';
import 'casio_lcd_screen.dart';
import 'safe_math.dart';
/// Canvas dedicado para renderizado de stickers con estética de cuaderno / pizarra
class GoodnotesStickerCanvas extends StatelessWidget {
  final StepByStepResolution resolution;
  final FunctionAnalysisResult? graphAnalysis;

  const GoodnotesStickerCanvas({
    super.key,
    required this.resolution,
    this.graphAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del Sticker
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A93C),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'STEP-BY-STEP LD',
                  style: TextStyle(
                    color: Color(0xFF1A2530),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Resolución Paso a Paso',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Expresión inicial
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enunciado: ',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SafeMath.tex(
                      CasioLcdScreen.sanitizeForMathTex(resolution.originalInputLatex),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Gráfica cartesiana si estamos en modo funciones
          if (graphAnalysis != null) ...[
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: CasioGraphCanvas(
                analysisResult: graphAnalysis!,
                isStickerMode: true,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: graphAnalysis!.notablePoints.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.type == PointType.vertex
                        ? const Color(0xFFF3EFE6)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: p.type == PointType.vertex
                          ? ThemeController.current.inkOnPaper
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  child: Text(
                    '${p.label}: (${p.x % 1 == 0 ? p.x.toInt() : p.x.toStringAsFixed(1)}, ${p.y % 1 == 0 ? p.y.toInt() : p.y.toStringAsFixed(1)})',
                    style: TextStyle(
                      color: p.type == PointType.vertex
                          ? ThemeController.current.inkOnPaper
                          : const Color(0xFFB91C1C),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // Lista de pasos
          ...resolution.steps.map((step) => _buildStepCard(step)),

          const SizedBox(height: 10),

          // Resultado final destacado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Resultado: ',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SafeMath.tex(
                          CasioLcdScreen.sanitizeForMathTex(resolution.exactResultLatex),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            color: Color(0xFF064E3B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (resolution.decimalApproxLatex.trim().isNotEmpty) ...[
                          const SizedBox(width: 10),
                          SafeMath.tex(
                            CasioLcdScreen.sanitizeForMathTex(
                              '(\\approx ${resolution.decimalApproxLatex})',
                            ),
                            textStyle: const TextStyle(
                              color: Color(0xFF047857),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(MathStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del paso con flecha de implicación
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paso ${step.index}',
                style: TextStyle(
                  color: ThemeController.current.inkOnPaper,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '⇒',
                style: TextStyle(
                  color: ThemeController.current.inkOnPaper,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  step.shortTitle,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Expresión LaTeX del paso
          Padding(
            padding: const EdgeInsets.only(left: 14.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SafeMath.tex(
                CasioLcdScreen.sanitizeForMathTex(step.latexExpression),
                textStyle: const TextStyle(
                  fontSize: 17,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),

          // Explicación pedagógica
          Padding(
            padding: const EdgeInsets.only(left: 14.0),
            child: Text(
              LatexPlainText.toPlain(step.pedagogicalNote),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          // Alerta de examen opcional
          if (step.warningTrick != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 14.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFDC2626)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        LatexPlainText.toPlain(step.warningTrick!),
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}