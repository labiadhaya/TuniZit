import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/lang.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  // نجهّزو Flutter ونتّصلو بـ Supabase قبل ما تظهر أول صفحة.
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
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
      // كي تتبدّل اللغة للعربية، نقلبو اتجاه الواجهة من اليمين لليسار.
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

// يختار الصفحة حسب حالة الدخول: ما فماش session؟ نمشيو لتسجيل الدخول،
// وإلا نظهرو الصفحة الرئيسية.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        return session == null ? const LoginScreen() : const HomeScreen();
      },
    );
  }
}