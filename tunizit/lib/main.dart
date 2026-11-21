import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/lang.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'pages/scan_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  runApp(const TunizitApp());
}

class TunizitApp extends StatelessWidget {
  const TunizitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tunizit',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Bascule RTL automatiquement quand la langue arabe est choisie.
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: AppLang.isAr,
        builder: (context, ar, _) => Directionality(
          textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// Affiche la connexion ou l'accueil selon la session Supabase.
// (Provisoire : l'authentification definitive sera celle du module Auth.)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        return session == null ? const LoginScreen() : const AppShell();
      },
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