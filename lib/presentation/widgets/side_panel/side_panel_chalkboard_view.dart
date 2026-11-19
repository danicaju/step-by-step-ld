import 'package:flutter/material.dart';

import '../../theme/theme_controller.dart';
import '../../theme/calculator_themes.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../domain/math_engine/models/step_resolution.dart';
import '../../../domain/math_engine/solvers/function_graph_solver.dart';
import '../../utils/latex_plain_text.dart';
import '../casio_graph_canvas.dart';
import '../casio_lcd_screen.dart';
class SidePanelChalkboardView extends StatelessWidget {
  final StepByStepResolution? resolution;
  final int activeStepIndex;
  final ValueChanged<int> onSelectStep;
  final FunctionAnalysisResult? graphAnalysis;
  final VoidCallback onExportSticker;
  final VoidCallback onCopyLatex;
  final VoidCallback onOpenAiTutor;

  const SidePanelChalkboardView({
    super.key,
    required this.resolution,
    required this.activeStepIndex,
    required this.onSelectStep,
    this.graphAnalysis,
    required this.onExportSticker,
    required this.onCopyLatex,
    required this.onOpenAiTutor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Botonera directa en pantalla grande
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tooltip(
                message: 'EXPORTAR PNG',
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pnl.panel(const Color(0xFF0D9488)),
                    foregroundColor: _pnl.panel(Colors.white),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.image_outlined, size: 15),
                  label: const Text(
                    'EXPORTAR PNG',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: onExportSticker,
                ),
              ),
              Tooltip(
                message: 'COPIAR LaTeX',
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pnl.panel(const Color(0xFFE5A93C)),
                    foregroundColor: _pnl.panel(const Color(0xFF1A2530)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.content_copy_rounded, size: 15),
                  label: const Text(
                    'COPIAR LaTeX',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: onCopyLatex,
                ),
              ),
            ],
          ),
        ),
        Divider(color: _pnl.panel(Color(0xFF252A34)), height: 1),
        Expanded(
          child: resolution == null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.developer_board_rounded,
                          size: 42,
                          color: _pnl.panel(Color(0xFF475569)),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Introduce una expresión o coeficientes en la calculadora y pulsa = para desplegar aquí todos los pasos simultáneamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _pnl.panel(Color(0xFF94A3B8)),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: resolution!.steps.length + 2,
                  itemBuilder: (context, i) {
                    if (i == 0) return _buildHeader();
                    if (i == resolution!.steps.length + 1) return _buildResult();
                    final idx = i - 1;
                    // `ListView.builder` ya aisla cada item con su RepaintBoundary (addRepaintBoundaries).
                    return Padding(
                      key: ValueKey('step_tile_$idx'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: StepBoardTile(
                        step: resolution!.steps[idx],
                        isActive: idx == activeStepIndex,
                        onTap: () => onSelectStep(idx),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                    // Tarjeta de Enunciado
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _pnl.panel(const Color(0xFF1D222B)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _pnl.panel(const Color(0xFF2D3442))),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'ENUNCIADO:',
                            style: TextStyle(
                              color: _pnl.panel(Color(0xFF94A3B8)),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Math.tex(
                                CasioLcdScreen.sanitizeForMathTex(
                                  resolution!.originalInputLatex,
                                ),
                                textStyle: TextStyle(
                                  color: _pnl.panel(Colors.white),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                onErrorFallback: (_) => Text(
                                  resolution!.originalInputLatex,
                                  style: TextStyle(
                                    color: _pnl.panel(Colors.white),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Gráfica opcional en Modo 7
                    if (graphAnalysis != null) ...[
                      SizedBox(
                        height: 190,
                        child: CasioGraphCanvas(
                          analysisResult: graphAnalysis!,
                          isStickerMode: false,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

      ],
    );
  }

  Widget _buildResult() {
    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _pnl.panel(const Color(0xFF064E3B)).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _pnl.panel(const Color(0xFF10B981)),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: _pnl.panel(Color(0xFF34D399)),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Resultado:',
                            style: TextStyle(
                              color: _pnl.panel(Color(0xFFA7F3D0)),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Math.tex(
                                CasioLcdScreen.sanitizeForMathTex(
                                  '${resolution!.exactResultLatex} \\;\\; (\\approx ${resolution!.decimalApproxLatex})',
                                ),
                                textStyle: TextStyle(
                                  color: _pnl.panel(Colors.white),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                onErrorFallback: (_) => Text(
                                  '${resolution!.exactResultLatex} (≈ ${resolution!.decimalApproxLatex})',
                                  style: TextStyle(
                                    color: _pnl.panel(Colors.white),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
  }
}

class StepBoardTile extends StatelessWidget {
  final MathStep step;
  final bool isActive;
  final VoidCallback onTap;

  const StepBoardTile({
    super.key,
    required this.step,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? _pnl.panel(const Color(0xFF1E293B)) : _pnl.panel(const Color(0xFF1B1F27)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? _pnl.panel(const Color(0xFFE5A93C))
                : _pnl.panel(const Color(0xFF2C323E)),
            width: isActive ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _pnl.panel(const Color(0xFFE5A93C))
                        : _pnl.panel(const Color(0xFF334155)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PASO ${step.index}',
                    style: TextStyle(
                      color: _pnl.panel(Colors.white),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.shortTitle,
                    style: TextStyle(
                      color: isActive
                          ? _pnl.panel(const Color(0xFFE5A93C))
                          : _pnl.panel(const Color(0xFFE2E8F0)),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                CasioLcdScreen.sanitizeForMathTex(step.latexExpression),
                textStyle: TextStyle(
                  color: _pnl.panel(Colors.white),
                  fontSize: 17,
                ),
                onErrorFallback: (_) => Text(
                  step.latexExpression,
                  style: TextStyle(
                    color: _pnl.panel(Colors.white),
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              LatexPlainText.toPlain(step.pedagogicalNote),
              style: TextStyle(
                color: _pnl.panel(Color(0xFF94A3B8)),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            if (step.warningTrick != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _pnl.panel(const Color(0xFF450A0A)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _pnl.panel(const Color(0xFFDC2626))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: _pnl.panel(Color(0xFFEF4444)),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        LatexPlainText.toPlain(step.warningTrick!),
                        style: TextStyle(
                          color: _pnl.panel(Color(0xFFFCA5A5)),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

CalculatorHardwareTheme get _pnl => ThemeController.current;
