import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/calculator_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización resiliente: si aún no está configurado google-services.json
  // o falla la red, la aplicación arranca con el motor pedagógico local sin romperse.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase no configurado o sin credenciales nativas ($e). Operando en modo local.');
  }

  runApp(const ProviderScope(child: CasioCalculatorApp()));
}

class CasioCalculatorApp extends StatelessWidget {
  const CasioCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STEP-BY-STEP LD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const CalculatorScreen(),
    );
  }
}
