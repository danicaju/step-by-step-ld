import 'package:flutter/material.dart';
import 'casio_dpad.dart';
import 'calculator_bezel_widgets.dart';
import 'keypad_key_definitions.dart';

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
  final VoidCallback? onDpadCenter;
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
    this.onDpadCenter,
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
                          onCenter: onDpadCenter,
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
                                alphaCaption: '=',
                                isAlphaActive: isAlphaActive,
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
                      Expanded(
                        flex: 96,
                        child: KeypadScientificRows(
                          isShiftActive: isShiftActive,
                          isAlphaActive: isAlphaActive,
                          sciMinH: sciMinH,
                          onKeyPress: onKeyPress,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        flex: 224,
                        child: KeypadNumericRows(
                          isShiftActive: isShiftActive,
                          isAlphaActive: isAlphaActive,
                          numMinH: numMinH,
                          onKeyPress: onKeyPress,
                        ),
                      ),
                    ],
                  ),
                ),
      ],
    );
  }
}