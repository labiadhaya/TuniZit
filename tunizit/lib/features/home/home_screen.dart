import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/lang.dart';
import '../../core/theme.dart';
import '../recommendation/data/form_options.dart';
import '../recommendation/models/variety_result.dart';
import '../recommendation/screens/recommendation_form_screen.dart';
import '../recommendation/screens/recommendation_results_screen.dart';
import '../recommendation/services/recommendation_service.dart';
import '../recommendation/widgets/score_gauge.dart';

String _formatDate(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  final l = d.toLocal();
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = RecommendationService();
  final _scroll = ScrollController();
  late Future<List<HistoryItem>> _history;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _history = _service.getHistory();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _history = _service.getHistory();
    });
  }

  Future<void> _openForm() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecommendationFormScreen()),
    );
    if (!mounted) return;
    _reload();
  }

  Future<void> _openHistory(HistoryItem h) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecommendationResultsScreen(response: h.toResponse()),
      ),
    );
  }

  void _onNav(int i) {
    switch (i) {
      case 1:
        _openForm();
        return;
      case 2:
        setState(() => _tab = 2);
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
        return;
      case 3:
        Supabase.instance.client.auth.signOut();
        return;
      default:
        setState(() => _tab = 0);
        if (_scroll.hasClients) {
          _scroll.animateTo(0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut);
        }
    }
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [TunizitLogo(), LangSwitch()],
      ),
    );
  }

  Widget _badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.oliveSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 14, color: AppColors.olive),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              AppLang.tr('Recommandation intelligente',
                  'توصية ذكية'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, String name) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppShadows.soft,
        gradient: const LinearGradient(
          colors: [AppColors.forest, AppColors.olive, AppColors.oliveLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(Icons.eco,
                size: 110, color: Colors.white.withValues(alpha: 0.10)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty)
                Text(
                  '${AppLang.tr('Bonjour', 'مرحبا')} $name',
                  style: t.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                AppLang.tr('Variétés adaptées à votre parcelle',
                    'أصناف الزيتون الملائمة لقطعتك'),
                style: t.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLang.tr(
                  'Répondez à 4 questions sur votre terrain. '
                      'Nous vous proposons les variétés les plus adaptées, '
                      'avec une explication simple.',
                  'أجب عن 4 أسئلة حول أرضك لنقترح عليك '
                      'الأصناف الأنسب مع شرح مبسّط.',
                ),
                style: t.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openForm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.forest,
                  ),
                  icon: const Icon(Icons.search),
                  label: Text(AppLang.tr('Trouver les variétés adaptées',
                      'ابحث عن الأصناف الملائمة')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.olive),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.oliveSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.forest,
        ),
      ),
    );
  }

  Widget _historyTile(HistoryItem h) {
    final top = h.results.isEmpty ? null : h.results.first;
    final gouv = h.input['gouvernorat'] as String? ?? '';
    final sol = h.input['sol'] == null
        ? ''
        : labelFor(solOpts, h.input['sol'] as String?);
    return AppCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openHistory(h),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (top != null)
                ScoreGauge(score: top.score, size: 54)
              else
                const Icon(Icons.search_off, size: 40, color: AppColors.medium),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      top?.nom ??
                          AppLang.tr('Aucune variété compatible',
                              'لا يوجد صنف مناسب'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (gouv.isNotEmpty) _chip(gouv),
                        if (sol.isNotEmpty) _chip(sol),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(h.createdAt),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                AppLang.ar ? Icons.chevron_left : Icons.chevron_right,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historySection(BuildContext context) {
    return FutureBuilder<List<HistoryItem>>(
      future: _history,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.olive),
            ),
          );
        }
        if (snap.hasError) {
          return AppCard(
            child: Row(
              children: [
                const Icon(Icons.cloud_off, color: AppColors.medium),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    snap.error is ApiException
                        ? (snap.error as ApiException).message
                        : AppLang.tr('Historique indisponible.',
                            'السجل غير متاح.'),
                  ),
                ),
                TextButton(
                  onPressed: _reload,
                  child: Text(AppLang.tr('Réessayer', 'إعادة المحاولة')),
                ),
              ],
            ),
          );
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return AppCard(
            child: Row(
              children: [
                const Icon(Icons.eco_outlined, color: AppColors.oliveLight),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLang.tr(
                      'Aucune recommandation pour le moment. '
                          'Lancez votre première recherche ci-dessus.',
                      'لا توجد توصيات حاليا. '
                          'ابدأ أول بحث لك أعلاه.',
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(children: [for (final h in items) _historyTile(h)]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final name = email.contains('@') ? email.split('@').first : email;
    return LangBuilder(
      builder: (context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _badge(),
                        ),
                        const SizedBox(height: 12),
                        _hero(context, name),
                        const SizedBox(height: 26),
                        _sectionTitle(
                          AppLang.tr('Historique de mes parcelles',
                              'سجل قطعي'),
                          icon: Icons.history,
                        ),
                        _historySection(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x1A233012),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: _onNav,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: AppLang.tr('Accueil', 'الرئيسية'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.eco_outlined),
                selectedIcon: const Icon(Icons.eco),
                label: AppLang.tr('Variétés', 'الأصناف'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.history),
                selectedIcon: const Icon(Icons.history),
                label: AppLang.tr('Historique', 'السجل'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.logout),
                label: AppLang.tr('Quitter', 'خروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}