import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../domain/math_engine/models/step_resolution.dart';
import '../../domain/services/ai_tutor_service.dart';
import 'casio_lcd_screen.dart';

class AiTutorSheet extends StatefulWidget {
  final StepByStepResolution resolution;
  final int stepIndex;

  const AiTutorSheet({
    super.key,
    required this.resolution,
    required this.stepIndex,
  });

  /// Método estático conveniente para abrir el modal del tutor desde cualquier punto
  static Future<void> show(
    BuildContext context, {
    required StepByStepResolution resolution,
    required int stepIndex,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF7C5CFF), width: 1.5),
      ),
      builder: (ctx) => AiTutorSheet(
        resolution: resolution,
        stepIndex: stepIndex,
      ),
    );
  }

  @override
  State<AiTutorSheet> createState() => _AiTutorSheetState();
}

class _AiTutorSheetState extends State<AiTutorSheet> {
  final AiTutorService _tutorService = AiTutorService();
  TutorDiagnosis? _diagnosis;
  bool _isLoading = true;
  String? _activeDoubt;

  @override
  void initState() {
    super.initState();
    _fetchDiagnosis();
  }

  Future<void> _fetchDiagnosis([String? doubt]) async {
    setState(() {
      _isLoading = true;
      _activeDoubt = doubt;
    });

    try {
      final res = await _tutorService.analyzeCurrentStep(
        resolution: widget.resolution,
        stepIndex: widget.stepIndex,
        studentDoubt: doubt,
      );
      if (mounted) {
        setState(() {
          _diagnosis = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final validIndex =
        widget.stepIndex.clamp(0, widget.resolution.steps.length - 1);
    final MathStep step = widget.resolution.steps[validIndex];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Pestaña de arrastre superior
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF7C5CFF).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Cabecera del Tutor IA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CFF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF7C5CFF)),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF7C5CFF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'TUTOR IA SOCRÁTICO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_diagnosis != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _diagnosis!.isCloudAi
                                      ? const Color(0xFF4C1D95)
                                      : const Color(0xFF134E4A),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _diagnosis!.isCloudAi
                                      ? 'Gemini 2.5 Flash'
                                      : 'Motor Local ESO',
                                  style: TextStyle(
                                    color: _diagnosis!.isCloudAi
                                        ? const Color(0xFFD8B4FE)
                                        : const Color(0xFF5EEAD4),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          'Paso ${step.index} de ${widget.resolution.steps.length}: ${step.shortTitle}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF334155), height: 16),

            // Contenido con scroll
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Expresión matemática del paso renderizada en LaTeX
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OPERACIÓN ANALIZADA',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Math.tex(
                                CasioLcdScreen.sanitizeForMathTex(step.latexExpression),
                                textStyle: const TextStyle(
                                  fontSize: 22,
                                  color: Color(0xFFF8FAFC),
                                  fontWeight: FontWeight.w600,
                                ),
                                onErrorFallback: (err) => Text(
                                  step.latexExpression,
                                  style: const TextStyle(fontSize: 16, color: Color(0xFFF8FAFC)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Estado de carga o tarjetas de diagnóstico
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF7C5CFF),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'El Tutor IA está analizando tu paso con método socrático...',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_diagnosis != null) ...[
                      // 1. Tarjeta Pregunta Socrática
                      _DiagnosisCard(
                        icon: Icons.psychology_outlined,
                        iconColor: const Color(0xFFA78BFA),
                        bgColor: const Color(0xFF231F33),
                        borderColor: const Color(0xFF7C5CFF),
                        title: 'Pregunta para reflexionar',
                        content: _diagnosis!.socraticQuestion,
                        contentColor: const Color(0xFFF3E8FF),
                      ),
                      const SizedBox(height: 12),

                      // 2. Tarjeta Pista Conceptual
                      _DiagnosisCard(
                        icon: Icons.lightbulb_outline,
                        iconColor: const Color(0xFF38BDF8),
                        bgColor: const Color(0xFF132338),
                        borderColor: const Color(0xFF0284C7),
                        title: 'Pista Conceptual (ESO / Bachillerato)',
                        content: _diagnosis!.conceptualHint,
                        contentColor: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(height: 12),

                      // 3. Tarjeta Trampa de Examen (si aplica)
                      if (_diagnosis!.examTrapAlert != null) ...[
                        _DiagnosisCard(
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFFEF4444),
                          bgColor: const Color(0xFF2E1515),
                          borderColor: const Color(0xFFDC2626),
                          title: '¡Cazador de Errores de Examen!',
                          content: _diagnosis!.examTrapAlert!,
                          contentColor: const Color(0xFFFEE2E2),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],

                    const SizedBox(height: 10),

                    // Fila de Preguntas Frecuentes del Alumno
                    const Text(
                      'PREGUNTAS RÁPIDAS AL TUTOR',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickDoubtChip(
                          label: '¿Por qué sale ese signo?',
                          icon: Icons.exposure,
                          isSelected:
                              _activeDoubt == '¿Por qué sale ese signo?',
                          onTap: () => _fetchDiagnosis('¿Por qué sale ese signo?'),
                        ),
                        _QuickDoubtChip(
                          label: '¿De dónde sale el denominador?',
                          icon: Icons.splitscreen,
                          isSelected:
                              _activeDoubt == '¿De dónde sale el denominador?',
                          onTap: () => _fetchDiagnosis(
                              '¿De dónde sale el denominador?'),
                        ),
                        _QuickDoubtChip(
                          label: 'Dame un ejemplo parecido más fácil',
                          icon: Icons.extension_outlined,
                          isSelected: _activeDoubt ==
                              'Dame un ejemplo parecido más fácil',
                          onTap: () => _fetchDiagnosis(
                              'Dame un ejemplo parecido más fácil'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiagnosisCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final String title;
  final String content;
  final Color contentColor;

  const _DiagnosisCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    required this.content,
    required this.contentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              color: contentColor,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickDoubtChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickDoubtChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      backgroundColor: isSelected
          ? const Color(0xFF7C5CFF)
          : const Color(0xFF1E293B),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFFA78BFA)
            : const Color(0xFF475569),
      ),
      onPressed: onTap,
    );
  }
}
