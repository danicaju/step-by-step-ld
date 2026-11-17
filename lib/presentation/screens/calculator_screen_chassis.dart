part of 'calculator_screen.dart';

extension _CalculatorScreenChassis on _CalculatorScreenState {
  Widget _buildCalculatorChassis({
    required String liveLatex,
    required String modeLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1E22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF22252C),
            Color(0xFF1C1E22),
            Color(0xFF16181C),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF252830),
          width: 3.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xCC000000),
            offset: Offset(0, 14),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Color(0x1EFFFFFF),
            offset: Offset(0, -1),
            blurRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: CustomPaint(
          painter: CarbonTexturePainter(),
          child: Padding(
            padding: const EdgeInsets.all(8.5),
            child: LayoutBuilder(
              builder: (context, chassisConstraints) {
                final double maxChassisH = chassisConstraints.maxHeight.isFinite
                    ? chassisConstraints.maxHeight
                    : 700.0;
                final bool isUltraCompact = maxChassisH < 400.0;
                final bool isCompactH = maxChassisH < 540.0;
                final double targetLcdH = isUltraCompact
                    ? (maxChassisH * 0.20).clamp(56.0, 90.0)
                    : isCompactH
                        ? (maxChassisH * 0.25).clamp(70.0, 140.0)
                        : (maxChassisH * 0.36).clamp(180.0, 290.0);
                final bool enforceKeyMinHeights = maxChassisH >= 745.0;
                final double? sciMinH = enforceKeyMinHeights ? 48.0 : null;
                final double? numMinH = enforceKeyMinHeights ? 56.0 : null;
                final double controlZoneH = isUltraCompact
                    ? 38.0
                    : isCompactH
                        ? 48.0
                        : 84.0;
                final double dpadW = isUltraCompact
                    ? 72.0
                    : isCompactH
                        ? 84.0
                        : 108.0;
                final double dpadH = isUltraCompact
                    ? 38.0
                    : isCompactH
                        ? 48.0
                        : 84.0;
                final double controlKeyVPad = isUltraCompact
                    ? 1.0
                    : isCompactH
                        ? 2.0
                        : 12.0;

                return Column(
                  children: [
                    // 1. Pantalla LCD Natural Textbook Display o Visor Gráfico (36%-40%, minHeight: 195 px)
                    SizedBox(
                      height: targetLcdH,
                      child: _buildLcdPanel(liveLatex: liveLatex, modeLabel: modeLabel),
                    ),

                    // Barra interactiva contextual para Modos 2..12 (oculta si el MENU está abierto)
                    if (!_isMenuOpen) ...[
                      ..._buildBasicModesToolbar(),
                      ..._buildAdvancedModesToolbar(),
                    ],

                    const SizedBox(height: 6),

                    // Keypad ergonómico ClassWiz
                    Expanded(
                      child: CalculatorKeypadView(
                        controlZoneH: controlZoneH,
                        controlKeyVPad: controlKeyVPad,
                        dpadW: dpadW,
                        dpadH: dpadH,
                        sciMinH: sciMinH,
                        numMinH: numMinH,
                        isShiftActive: _isShiftActive,
                        isAlphaActive: _isAlphaActive,
                        isMenuOpen: _isMenuOpen,
                        isSetupOpen: _isSetupOpen,
                        onKeyPress: _handleKeyPress,
                        onDpadLeft: _handleDpadLeft,
                        onDpadRight: _handleDpadRight,
                        onDpadUp: _handleDpadUp,
                        onDpadDown: _handleDpadDown,
                        onDpadCenter: () => _handleKeyPress('='),
                        onOptnPressed: () {
                          if (_isShiftActive) {
                            updateState(() {
                              _isShiftActive = false;
                              _isAlphaActive = false;
                            });
                            if (_calculatorMode == 8) {
                              _openStatOptionsModal();
                            } else {
                              _openQuickOptnModal();
                            }
                          } else if (_isAlphaActive && _calculatorMode == 2) {
                            _insertEqualsInEquation();
                          } else {
                            _handleKeyPress('CALC');
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
