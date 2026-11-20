import 'package:flutter/material.dart';
import 'pages/scan_page.dart';
import 'theme/app_theme.dart';

void main() => runApp(const TuniZitApp());

class TuniZitApp extends StatelessWidget {
  const TuniZitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuniZit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppShell(),
    );
  }
}

/// Navigation basse comme dans le prototype.
/// Seul l'onglet « Accueil » (scanner) est actif pour l'instant.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = <Widget>[
    ScanPage(),
    _ComingSoon(title: 'Oliveraies', icon: Icons.landscape_outlined),
    _ComingSoon(title: 'Planification', icon: Icons.event_note_outlined),
    _ComingSoon(title: 'Zakat & IA', icon: Icons.calculate_outlined),
    _ComingSoon(title: 'Outils', icon: Icons.handyman_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.landscape_outlined), selectedIcon: Icon(Icons.landscape), label: 'Oliveraies'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Planification'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'Zakat & IA'),
          NavigationDestination(icon: Icon(Icons.handyman_outlined), selectedIcon: Icon(Icons.handyman), label: 'Outils'),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String title;
  final IconData icon;
  const _ComingSoon({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: const Color(0xFF2E7D4F)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Bientôt disponible', style: TextStyle(color: Color(0xFF5E7466))),
        ]),
      ),
    );
  }
}