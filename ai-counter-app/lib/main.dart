import 'package:flutter/material.dart';

import 'home_screen.dart';

void main() => runApp(const AiCounterApp());

class AiCounterApp extends StatelessWidget {
  const AiCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ytilities',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
