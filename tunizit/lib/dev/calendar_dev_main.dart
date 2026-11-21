import 'package:flutter/material.dart';

import '../features/calendrier/widgets/calendrier_theme.dart';
import '../features/calendrier/screens/calendrier_screen.dart';

/// Point d'entrée de test, séparé de main.dart :
///   flutter run -t lib/dev/calendar_dev_main.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tunizit – Calendrier (dev)',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: CalColors.primary,
        scaffoldBackgroundColor: CalColors.bg,
      ),
      home: const CalendrierScreen(), // MockActivityService par défaut
    ),
  );
}
