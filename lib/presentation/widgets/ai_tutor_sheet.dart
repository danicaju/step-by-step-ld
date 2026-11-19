import 'package:flutter/material.dart';
import '../../domain/math_engine/models/step_resolution.dart';
import '../../domain/services/ai_tutor_service.dart';
import '../theme/theme_contrast.dart';
import '../theme/theme_controller.dart';
import 'casio_lcd_screen.dart';
import 'safe_math.dart';

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
    final hw = ThemeController.current;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: hw.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: hw.panelAccentText, width: 1.5),
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
    final hw = ThemeController.current;
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
                color: hw.panelAccentText.withValues(alpha: 0.4),
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
                      color: hw.panelAccentText.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: hw.panelAccentText),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: hw.panelAccentText,
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
                            Text(
                              'TUTOR IA SOCRÁTICO',
                              style: TextStyle(
                                color: hw.panelText,
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
                                      ? hw.panelCard
                                      : hw.panelCard,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _diagnosis!.isCloudAi
                                      ? 'Gemini 2.5 Flash'
                                      : 'Motor Local ESO',
                                  style: TextStyle(
                                    color: _diagnosis!.isCloudAi
                                        ? hw.panelAccentText
                                        : hw.panelAccentText,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          'Paso ${step.index} de ${widget.resolution.steps.length}: ${step.shortTitle}',
                          style: TextStyle(
                            color: hw.panelMuted,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: hw.panelText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(color: hw.panelBorder, height: 16),

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
                        color: hw.panelCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: hw.panelBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OPERACIÓN ANALIZADA',
                            style: TextStyle(
                              color: hw.panelMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SafeMath.tex(
                                CasioLcdScreen.sanitizeForMathTex(step.latexExpression),
                                textStyle: TextStyle(
                                  fontSize: 22,
                                  color: hw.panelText,
                                  fontWeight: FontWeight.w600,
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
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: hw.panelAccentText,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'El Tutor IA está analizando tu paso con método socrático...',
                              style: TextStyle(
                                color: hw.panelMuted,
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
                        iconColor: hw.panelAccentText,
                        bgColor: hw.panelCard,
                        borderColor: hw.panelAccentText,
                        title: 'Pregunta para reflexionar',
                        content: _diagnosis!.socraticQuestion,
                        contentColor: hw.panelText,
                      ),
                      const SizedBox(height: 12),

                      // 2. Tarjeta Pista Conceptual
                      _DiagnosisCard(
                        icon: Icons.lightbulb_outline,
                        iconColor: hw.panelAccentText,
                        bgColor: hw.panelCard,
                        borderColor: hw.panelBorder,
                        title: 'Pista Conceptual (ESO / Bachillerato)',
                        content: _diagnosis!.conceptualHint,
                        contentColor: hw.panelText,
                      ),
                      const SizedBox(height: 12),

                      // 3. Tarjeta Trampa de Examen (si aplica)
                      if (_diagnosis!.examTrapAlert != null) ...[
                        _DiagnosisCard(
                          icon: Icons.warning_amber_rounded,
                          iconColor: hw.isDefault ? const Color(0xFFEF4444) : const Color(0xFFB91C1C),
                          bgColor: hw.isDefault ? const Color(0xFF2E1515) : hw.isDefault ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D),
                          borderColor: const Color(0xFFDC2626),
                          title: '¡Cazador de Errores de Examen!',
                          content: _diagnosis!.examTrapAlert!,
                          contentColor: hw.isDefault ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],

                    const SizedBox(height: 10),

                    // Fila de Preguntas Frecuentes del Alumno
                    Text(
                      'PREGUNTAS RÁPIDAS AL TUTOR',
                      style: TextStyle(
                        color: hw.panelMuted,
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
    final hw = ThemeController.current;
    return ActionChip(
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected ? hw.actionFg : hw.panelText,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? hw.actionFg : hw.panelText,
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      backgroundColor: isSelected
          ? hw.actionBg
          : hw.panelCard,
      side: BorderSide(
        color: isSelected
            ? hw.panelAccentText
            : hw.panelBorder,
      ),
      onPressed: onTap,
    );
  }
}
