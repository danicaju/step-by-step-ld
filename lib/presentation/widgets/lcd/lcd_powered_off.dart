import 'package:flutter/material.dart';

/// LCD apagada (SHIFT + AC / OFF): fondo oscuro con el sello tenue de la marca.
class LcdPoweredOff extends StatelessWidget {
  const LcdPoweredOff({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('lcd_powered_off'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D0C),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF2C313A), width: 1.5),
      ),
      alignment: Alignment.center,
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CASIO',
                style: TextStyle(
                  color: Color(0xFF2E3A35),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              Text(
                'STEP-BY-STEP LD',
                style: TextStyle(
                  color: Color(0xFF2E3A35),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
