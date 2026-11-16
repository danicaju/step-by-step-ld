import 'package:flutter/material.dart';

class RuffiniDegreeSelectorView extends StatelessWidget {
  final int currentDegree;
  final bool isOledDark;
  final ValueChanged<int> onSelectDegree;

  const RuffiniDegreeSelectorView({
    super.key,
    required this.currentDegree,
    required this.isOledDark,
    required this.onSelectDegree,
  });

  @override
  Widget build(BuildContext context) {
    const supDegrees = {2: 'x²', 3: 'x³', 4: 'x⁴', 5: 'x⁵', 6: 'x⁶'};
    final textColor =
        isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF101815);
    final unselectedBg =
        isOledDark ? const Color(0xFF1E293B) : const Color(0xFFC8D6CD);
    final unselectedBorder =
        isOledDark ? const Color(0xFF334155) : const Color(0xFF7A8C80);
    final selectedBg =
        isOledDark ? const Color(0xFF2563EB) : const Color(0xFF1E3A5F);

    return LayoutBuilder(
      builder: (context, constraints) {
        final safeWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 320.0;
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: safeWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selecciona el grado del polinomio P(x):',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (int deg = 2; deg <= 6; deg++) ...[
                        if (deg > 2) const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            key: Key('ruffini_degree_$deg'),
                            onTap: () => onSelectDegree(deg),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 2,
                              ),
                              decoration: BoxDecoration(
                                color: currentDegree == deg
                                    ? selectedBg
                                    : unselectedBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: currentDegree == deg
                                      ? const Color(0xFF60A5FA)
                                      : unselectedBorder,
                                  width: currentDegree == deg ? 1.8 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$deg.º',
                                    style: TextStyle(
                                      color: currentDegree == deg
                                          ? Colors.white
                                          : textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    supDegrees[deg]!,
                                    style: TextStyle(
                                      color: currentDegree == deg
                                          ? const Color(0xFFDBEAFE)
                                          : textColor.withValues(alpha: 0.78),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
