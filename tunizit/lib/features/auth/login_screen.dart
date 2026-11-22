import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/lang.dart';
import '../../core/theme.dart';

// صفحة الدخول وإنشاء حساب جديد عبر خدمة المصادقة متاع Supabase.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // قيم الحقول وحالة الطلب والرسائل اللي تظهر للمستخدم.
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  bool _signUp = false;
  bool _loading = false;
  bool _hide = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _pwd.dispose();
    super.dispose();
  }

  String _friendly(String m) {
    // نحوّلو أخطاء Supabase المعروفة لعبارات مفهومة في الواجهة.
    if (m.contains('Invalid login credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (m.contains('Email not confirmed')) {
      return 'Email non confirmé. Vérifiez votre boîte mail.';
    }
    if (m.contains('already registered')) {
      return 'Cet email possède déjà un compte. Connectez-vous.';
    }
    return m;
  }

  Future<void> _submit() async {
    // نثبتو من المدخلات، وبعد نعملو دخول أو إنشاء حساب حسب الاختيار.
    final email = _email.text.trim();
    final pwd = _pwd.text;
    if (!email.contains('@')) {
      setState(() => _error = 'Entrez une adresse email valide.');
      return;
    }
    if (pwd.length < 6) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_signUp) {
        final r = await auth.signUp(email: email, password: pwd);
        if (r.session == null && mounted) {
          setState(() {
            _signUp = false;
            _info = 'Compte créé. Confirmez votre email, puis connectez-vous.';
          });
        }
      } else {
        await auth.signInWithPassword(email: email, password: pwd);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _friendly(e.message));
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur : $e');
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Widget _message(String text, Color color, IconData icon) {
    // نفس شكل التنبيه للأخطاء ورسائل النجاح.
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LangBuilder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: LangSwitch(),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 92,
                              height: 92,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: AppShadows.soft,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.forest,
                                    AppColors.oliveLight,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.eco,
                                  color: Colors.white, size: 48),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tunizit',
                            textAlign: TextAlign.center,
                            style: t.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.forest,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLang.tr("Votre assistant pour l'oliveraie",
                                'مساعدك الذكي لحقل الزيتون'),
                            textAlign: TextAlign.center,
                            style: t.bodyLarge
                                ?.copyWith(color: AppColors.muted),
                          ),
                          const SizedBox(height: 28),
                          AppCard(
                            padding: const EdgeInsets.all(18),
                            margin: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: AppLang.tr('Email', 'البريد الإلكتروني'),
                                    prefixIcon:
                                        const Icon(Icons.mail_outline),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _pwd,
                                  obscureText: _hide,
                                  decoration: InputDecoration(
                                    labelText: AppLang.tr('Mot de passe', 'كلمة المرور'),
                                    prefixIcon:
                                        const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_hide
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () =>
                                          setState(() => _hide = !_hide),
                                    ),
                                  ),
                                  onSubmitted: (_) =>
                                      _loading ? null : _submit(),
                                ),
                                if (_error != null)
                                  _message(
                                    _error!,
                                    Theme.of(context).colorScheme.error,
                                    Icons.error_outline,
                                  ),
                                if (_info != null)
                                  _message(_info!, AppColors.good,
                                      Icons.check_circle_outline),
                                const SizedBox(height: 18),
                                FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  child: _loading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(_signUp
                                          ? AppLang.tr('Créer mon compte',
                                              'إنشاء حسابي')
                                          : AppLang.tr('Se connecter',
                                              'تسجيل الدخول')),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() {
                                      _signUp = !_signUp;
                                      _error = null;
                                      _info = null;
                                    }),
                            child: Text(_signUp
                                ? AppLang.tr("J'ai déjà un compte",
                                    'لدي حساب بالفعل')
                                : AppLang.tr('Pas de compte ? Créer un compte',
                                    'ليس لديك حساب؟ أنشئ حسابا')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}