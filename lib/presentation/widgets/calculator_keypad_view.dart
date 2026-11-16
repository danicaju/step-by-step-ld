import 'package:flutter/material.dart';
import 'casio_physical_key.dart';
import 'casio_dpad.dart';
import 'calculator_bezel_widgets.dart';

class CalculatorKeypadView extends StatelessWidget {
  final double controlZoneH;
  final double controlKeyVPad;
  final double dpadW;
  final double dpadH;
  final double? sciMinH;
  final double? numMinH;
  final bool isShiftActive;
  final bool isAlphaActive;
  final bool isMenuOpen;
  final bool isSetupOpen;
  final ValueChanged<String> onKeyPress;
  final VoidCallback onDpadLeft;
  final VoidCallback onDpadRight;
  final VoidCallback onDpadUp;
  final VoidCallback onDpadDown;
  final VoidCallback onOptnPressed;

  const CalculatorKeypadView({
    super.key,
    required this.controlZoneH,
    required this.controlKeyVPad,
    required this.dpadW,
    required this.dpadH,
    this.sciMinH,
    this.numMinH,
    required this.isShiftActive,
    required this.isAlphaActive,
    required this.isMenuOpen,
    required this.isSetupOpen,
    required this.onKeyPress,
    required this.onDpadLeft,
    required this.onDpadRight,
    required this.onDpadUp,
    required this.onDpadDown,
    required this.onOptnPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
                // =========================================================
                // 2. ZONA DE CONTROL SUPERIOR ERGONÓMICA (3 bloques, D-Pad 108x84)
                // =========================================================
                SizedBox(
                  height: controlZoneH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bloque Izquierdo: Teclas grandes SHIFT y ALPHA
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: controlKeyVPad),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CompactControlKey(
                                label: 'SHIFT',
                                backgroundColor: const Color(0xFFE5A93C),
                                textColor: Colors.black,
                                isActive: isShiftActive,
                                onTap: () => onKeyPress('SHIFT'),
                              ),
                              const SizedBox(width: 6),
                              CompactControlKey(
                                label: 'ALPHA',
                                backgroundColor: const Color(0xFFE05252),
                                textColor: Colors.white,
                                isActive: isAlphaActive,
                                onTap: () => onKeyPress('ALPHA'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Bloque Central: D-Pad Cepillado
                      Center(
                        child: CasioReplayPad(
                          width: dpadW,
                          height: dpadH,
                          onLeft: onDpadLeft,
                          onRight: onDpadRight,
                          onUp: onDpadUp,
                          onDown: onDpadDown,
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Bloque Derecho: Teclas grandes MODE (SETUP) y CALC (OPTN)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: controlKeyVPad),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CompactControlKey(
                                label: 'MODE',
                                caption: 'SETUP',
                                backgroundColor: const Color(0xFF2E5A50),
                                textColor: Colors.white,
                                isActive: isMenuOpen || isSetupOpen,
                                onTap: () => onKeyPress('MODE'),
                              ),
                              const SizedBox(width: 6),
                              CompactControlKey(
                                label: 'CALC',
                                caption: 'OPTN',
                                backgroundColor: const Color(0xFF253042),
                                textColor: Colors.white,
                                onTap: onOptnPressed,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                // =========================================================
                // 3. RESTO DEL TECLADO 5 COLUMNAS ALINEADAS (Sci 2x5 + Num 4x5)
                // =========================================================
                Expanded(
                  child: Column(
                    children: [
                      // Sci Row 1 (5 cols): a/b, √■, x², log■□, S⬄D
                      Expanded(
                        flex: 48,
                        child: Row(
                          children: [
                            CasioPhysicalKey(
                              label: 'a/b',
                              shiftLabel: 'c a/b',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => onKeyPress('/'),
                            ),
                            CasioPhysicalKey(
                              label: '√■',
                              shiftLabel: 'ⁿ√■',
                              alphaLabel: '³√■',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => onKeyPress('√'),
                            ),
                            CasioPhysicalKey(
                              label: 'x²',
                              shiftLabel: 'x■',
                              alphaLabel: 'x³',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
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
                                    child: Text(
                                      '■',
                                      key: const Key('log_key_subscript_base'),
                                      style: const TextStyle(
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
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => onKeyPress('LOG'),
                            ),
                            CasioPhysicalKey(
                              label: 'S⬄D',
                              backgroundColor: const Color(0xFF343842),
                              minHeight: sciMinH,
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
                              alphaLabel: 'Y',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => onKeyPress('('),
                            ),
                            CasioPhysicalKey(
                              label: ')',
                              alphaLabel: 'X',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => onKeyPress(')'),
                            ),
                            CasioPhysicalKey(
                              label: 'sin',
                              shiftLabel: 'sin⁻¹',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => onKeyPress('sin'),
                            ),
                            CasioPhysicalKey(
                              label: 'cos',
                              shiftLabel: 'cos⁻¹',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => onKeyPress('cos'),
                            ),
                            CasioPhysicalKey(
                              label: 'tan',
                              shiftLabel: 'tan⁻¹',
                              backgroundColor: const Color(0xFF253042),
                              minHeight: sciMinH,
                              onTap: () => onKeyPress('tan'),
                            ),
                          ],
                        ),
                      ),

                      // Num Row 1: 7, 8, 9, DEL (Azul), AC (Azul)
                      Expanded(
                        flex: 56,
                        child: Row(
                          children: [
                            CasioPhysicalKey(
                              label: '7',
                              alphaLabel: 'A',
                              minHeight: numMinH,
                              onTap: () => onKeyPress('7'),
                            ),
                            CasioPhysicalKey(
                              label: '8',
                              alphaLabel: 'B',
                              minHeight: numMinH,
                              onTap: () => onKeyPress('8'),
                            ),
                            CasioPhysicalKey(
                              label: '9',
                              alphaLabel: 'C',
                              minHeight: numMinH,
                              onTap: () => onKeyPress('9'),
                            ),
                            CasioPhysicalKey(
                              label: 'DEL',
                              backgroundColor: const Color(0xFF2E86DE),
                              minHeight: numMinH,
                              onTap: () => onKeyPress('DEL'),
                            ),
                            CasioPhysicalKey(
                              label: 'AC',
                              backgroundColor: const Color(0xFF2E86DE),
                              minHeight: numMinH,
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
                              onTap: () => onKeyPress('4'),
                            ),
                            CasioPhysicalKey(
                              label: '5',
                              alphaLabel: 'E',
                              minHeight: numMinH,
                              onTap: () => onKeyPress('5'),
                            ),
                            CasioPhysicalKey(
                              label: '6',
                              alphaLabel: 'F',
                              minHeight: numMinH,
                              onTap: () => onKeyPress('6'),
                            ),
                            CasioPhysicalKey(
                              label: '×',
                              shiftLabel: 'm.c.m.',
                              alphaLabel: 'M.C.D.',
                              minHeight: numMinH,
                              onTap: () => onKeyPress('*'),
                            ),
                            CasioPhysicalKey(
                              label: '÷',
                              shiftLabel: 'FACT',
                              minHeight: numMinH,
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
                              minHeight: numMinH,
                              onTap: () => onKeyPress('1'),
                            ),
                            CasioPhysicalKey(
                              label: '2',
                              minHeight: numMinH,
                              onTap: () => onKeyPress('2'),
                            ),
                            CasioPhysicalKey(
                              label: '3',
                              minHeight: numMinH,
                              onTap: () => onKeyPress('3'),
                            ),
                            CasioPhysicalKey(
                              label: '+',
                              minHeight: numMinH,
                              onTap: () => onKeyPress('+'),
                            ),
                            CasioPhysicalKey(
                              label: '-',
                              minHeight: numMinH,
                              onTap: () => onKeyPress('-'),
                            ),
                          ],
                        ),
                      ),

                      // Num Row 4: 0, . (° ' "), ×10ˣ (%), ANS (M+ / M), = (Azul)
                      Expanded(
                        flex: 56,
                        child: Row(
                          children: [
                            CasioPhysicalKey(
                              label: '0',
                              minHeight: numMinH,
                              onTap: () => onKeyPress('0'),
                            ),
                            CasioPhysicalKey(
                              label: '.',
                              shiftLabel: '° \' "',
                              minHeight: numMinH,
                              onTap: () => onKeyPress(
                                isShiftActive ? 'DMS' : '.',
                              ),
                            ),
                            CasioPhysicalKey(
                              label: '×10ˣ',
                              shiftLabel: '%',
                              backgroundColor: const Color(0xFF2B2E36),
                              minHeight: numMinH,
                              onTap: () => onKeyPress('SCI10'),
                            ),
                            CasioPhysicalKey(
                              label: 'ANS',
                              shiftLabel: 'M+',
                              alphaLabel: 'M',
                              backgroundColor: const Color(0xFF343842),
                              minHeight: numMinH,
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
                              backgroundColor: const Color(0xFF2E86DE),
                              minHeight: numMinH,
                              onTap: () => onKeyPress('='),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      ],
    );
  }
}