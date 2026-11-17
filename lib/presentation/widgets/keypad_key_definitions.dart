import 'package:flutter/material.dart';
import 'casio_physical_key.dart';
import 'fraction_key_icon.dart';

/// Filas científicas 1 y 2 del teclado Casio ClassWiz.
class KeypadScientificRows extends StatelessWidget {
  final bool isShiftActive;
  final bool isAlphaActive;
  final double? sciMinH;
  final ValueChanged<String> onKeyPress;

  const KeypadScientificRows({
    super.key,
    required this.isShiftActive,
    required this.isAlphaActive,
    this.sciMinH,
    required this.onKeyPress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sci Row 1 (5 cols): a/b, √■, x², log■□, S⬄D
        Expanded(
          flex: 48,
          child: Row(
            children: [
              CasioPhysicalKey(
                label: 'a/b',
                customLabelWidget: const FractionKeyIcon(),
                shiftLabel: 'c a/b',
                backgroundColor: const Color(0xFF1F2227),
                minHeight: sciMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('/'),
              ),
              CasioPhysicalKey(
                label: '√■',
                shiftLabel: 'ⁿ√■',
                alphaLabel: '³√■',
                backgroundColor: const Color(0xFF1F2227),
                minHeight: sciMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('√'),
              ),
              CasioPhysicalKey(
                label: 'x²',
                shiftLabel: 'x■',
                alphaLabel: 'x³',
                backgroundColor: const Color(0xFF1F2227),
                minHeight: sciMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('^2'),
              ),
              CasioPhysicalKey(
                label: 'log■□',
                customLabelWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'log',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0.5, 4.0),
                      child: const Text(
                        '■',
                        key: Key('log_key_subscript_base'),
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 1.5),
                    const Text(
                      '□',
                      key: Key('log_key_argument'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                shiftLabel: '10ˣ',
                alphaLabel: 'ln',
                backgroundColor: const Color(0xFF1F2227),
                minHeight: sciMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('LOG'),
              ),
              CasioPhysicalKey(
                label: 'S⬄D',
                shiftLabel: 'a b/c',
                backgroundColor: const Color(0xFF1F2227),
                minHeight: sciMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('SD'),
              ),
            ],
          ),
        ),

        // Sci Row 2 (5 cols): (, ), sin, cos, tan
        Expanded(
          flex: 48,
          child: Row(
            children: [
              CasioPhysicalKey(
                label: '(',
                shiftLabel: 'STO',
                alphaLabel: 'y',
                backgroundColor: const Color(0xFF1F2227),
                minHeight: sciMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('('),
              ),
              CasioPhysicalKey(
                label: ')',
                alphaLabel: 'x',
                backgroundColor: const Color(0xFF1F2227),
                minHeight: sciMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress(')'),
              ),
              CasioPhysicalKey(
                label: 'sin',
                shiftLabel: 'sin⁻¹',
                backgroundColor: const Color(0xFF1F2227),
                minHeight: sciMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('sin'),
              ),
              CasioPhysicalKey(
                label: 'cos',
                shiftLabel: 'cos⁻¹',
                backgroundColor: const Color(0xFF1F2227),
                minHeight: sciMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('cos'),
              ),
              CasioPhysicalKey(
                label: 'tan',
                shiftLabel: 'tan⁻¹',
                backgroundColor: const Color(0xFF1F2227),
                minHeight: sciMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('tan'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Filas numéricas 1 a 4 del teclado Casio ClassWiz.
class KeypadNumericRows extends StatelessWidget {
  final bool isShiftActive;
  final bool isAlphaActive;
  final double? numMinH;
  final ValueChanged<String> onKeyPress;

  const KeypadNumericRows({
    super.key,
    required this.isShiftActive,
    required this.isAlphaActive,
    this.numMinH,
    required this.onKeyPress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Num Row 1: 7, 8, 9, DEL (Azul), AC (Azul)
        Expanded(
          flex: 56,
          child: Row(
            children: [
              CasioPhysicalKey(
                label: '7',
                shiftLabel: 'CONST',
                alphaLabel: 'A',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('7'),
              ),
              CasioPhysicalKey(
                label: '8',
                shiftLabel: 'CONV',
                alphaLabel: 'B',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('8'),
              ),
              CasioPhysicalKey(
                label: '9',
                shiftLabel: 'RESET',
                alphaLabel: 'C',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('9'),
              ),
              CasioPhysicalKey(
                label: 'DEL',
                repeatable: true,
                shiftLabel: 'INS',
                backgroundColor: const Color(0xFF4A4F5C),
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('DEL'),
              ),
              CasioPhysicalKey(
                label: 'AC',
                shiftLabel: 'OFF',
                backgroundColor: const Color(0xFF4A4F5C),
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('AC'),
              ),
            ],
          ),
        ),

        // Num Row 2: 4, 5, 6, × (m.c.m. / M.C.D.), ÷ (FACT)
        Expanded(
          flex: 56,
          child: Row(
            children: [
              CasioPhysicalKey(
                label: '4',
                alphaLabel: 'D',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('4'),
              ),
              CasioPhysicalKey(
                label: '5',
                alphaLabel: 'E',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('5'),
              ),
              CasioPhysicalKey(
                label: '6',
                alphaLabel: 'F',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('6'),
              ),
              CasioPhysicalKey(
                label: '×',
                shiftLabel: 'm.c.m.',
                alphaLabel: 'M.C.D.',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('*'),
              ),
              CasioPhysicalKey(
                label: '÷',
                shiftLabel: 'FACT',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress(':'),
              ),
            ],
          ),
        ),

        // Num Row 3: 1, 2, 3, +, -
        Expanded(
          flex: 56,
          child: Row(
            children: [
              CasioPhysicalKey(
                label: '1',
                alphaLabel: 'X',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('1'),
              ),
              CasioPhysicalKey(
                label: '2',
                alphaLabel: 'Y',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('2'),
              ),
              CasioPhysicalKey(
                label: '3',
                shiftLabel: 'ENG',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('3'),
              ),
              CasioPhysicalKey(
                label: '+',
                shiftLabel: 'Pol',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('+'),
              ),
              CasioPhysicalKey(
                label: '-',
                shiftLabel: 'Rec',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('-'),
              ),
            ],
          ),
        ),

        // Num Row 4: 0, . (° ' "), ×10ˣ (π / e), ANS (M+ / M), = (≈)
        Expanded(
          flex: 56,
          child: Row(
            children: [
              CasioPhysicalKey(
                label: '0',
                shiftLabel: 'π',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress(isShiftActive ? 'PI' : '0'),
              ),
              CasioPhysicalKey(
                label: '.',
                shiftLabel: '° \' "',
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress(
                  isShiftActive ? 'DMS' : '.',
                ),
              ),
              CasioPhysicalKey(
                label: '×10ˣ',
                shiftLabel: '%',
                alphaLabel: 'e',
                backgroundColor: const Color(0xFF3B4049),
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('SCI10'),
              ),
              CasioPhysicalKey(
                label: 'ANS',
                shiftLabel: 'M+',
                alphaLabel: 'M',
                backgroundColor: const Color(0xFF3B4049),
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () {
                  if (isShiftActive || isAlphaActive) {
                    onKeyPress('M+');
                  } else {
                    onKeyPress('ANS');
                  }
                },
              ),
              CasioPhysicalKey(
                label: '=',
                shiftLabel: '≈',
                backgroundColor: const Color(0xFF4A4F5C),
                minHeight: numMinH,
                isShiftActive: isShiftActive,
                isAlphaActive: isAlphaActive,
                onTap: () => onKeyPress('='),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
