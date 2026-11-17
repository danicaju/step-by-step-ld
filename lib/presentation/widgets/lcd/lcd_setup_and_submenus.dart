import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'lcd_math_sanitizer.dart';

class LcdSubmenuHeaderRow extends StatelessWidget {
  final String badgeText;
  final Color badgeColor;
  final String hintText;
  final Color hintColor;

  const LcdSubmenuHeaderRow({
    super.key,
    required this.badgeText,
    required this.badgeColor,
    required this.hintText,
    required this.hintColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badgeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                hintText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: hintColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LcdSetupMenu extends StatelessWidget {
  final bool isOledDark;
  final bool isRadMode;
  final ValueChanged<int>? onSelectSetupOption;
  final Color formulaColor;
  final Color stepTitleColor;

  const LcdSetupMenu({
    super.key,
    required this.isOledDark,
    required this.isRadMode,
    this.onSelectSetupOption,
    required this.formulaColor,
    required this.stepTitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isOledDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A);
    final idleBg = isOledDark
        ? const Color(0xFF1A2220)
        : const Color(0xFFCBD5CE).withValues(alpha: 0.65);

    Widget buildRow(int opt, String title, bool isCurrent) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: InkWell(
            onTap: () => onSelectSetupOption?.call(opt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isCurrent ? activeBg : idleBg,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFFD99B26)
                      : formulaColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: isCurrent ? Colors.white : formulaColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Color(0xFFD99B26),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcdSubmenuHeaderRow(
          badgeText: 'CONFIG / SETUP',
          badgeColor: const Color(0xFFD99B26),
          hintText: '[1-3] o [AC]',
          hintColor: stepTitleColor,
        ),
        const SizedBox(height: 6),
        buildRow(1, '1: Unidad Angular DEG (Grados)', !isRadMode),
        buildRow(2, '2: Unidad Angular RAD (Radianes)', isRadMode),
        buildRow(3, '3: Tema LCD (${isOledDark ? "OLED" : "Clasica"})', false),
      ],
    );
  }
}

class LcdCalcPrompt extends StatelessWidget {
  final String calcValueRaw;
  final String varLabel;
  final String? calcExpressionLatex;
  final Color formulaColor;
  final Color stepTitleColor;

  const LcdCalcPrompt({
    super.key,
    required this.calcValueRaw,
    this.varLabel = 'x',
    this.calcExpressionLatex,
    required this.formulaColor,
    required this.stepTitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final valueDisplay = calcValueRaw.isEmpty ? r'\textcolor{#1A2530}{\blacksquare}' : calcValueRaw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcdSubmenuHeaderRow(
          badgeText: 'CALC',
          badgeColor: const Color(0xFF1A2530),
          hintText: 'Introduce valor y [=]',
          hintColor: stepTitleColor,
        ),
        const SizedBox(height: 6),
        if (calcExpressionLatex != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              LcdMathSanitizer.sanitizeForMathTex(calcExpressionLatex!),
              textStyle: TextStyle(
                fontSize: 14,
                color: formulaColor.withValues(alpha: 0.85),
              ),
            ),
          ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$varLabel? ',
              style: const TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Math.tex(
              LcdMathSanitizer.sanitizeForMathTex(valueDisplay),
              textStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Pulsa = para calcular en este valor, o AC para cancelar.',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: formulaColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
