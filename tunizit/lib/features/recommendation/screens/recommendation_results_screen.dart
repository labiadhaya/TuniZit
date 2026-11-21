import 'package:material_ui/material_ui.dart';
import '../../../core/lang.dart';
import '../../../core/theme.dart';
import '../data/form_options.dart';
import '../models/variety_result.dart';
import '../services/recommendation_service.dart';
import '../widgets/score_gauge.dart';

class RecommendationResultsScreen extends StatefulWidget {
  const RecommendationResultsScreen({super.key, required this.response});

  final RecommendationResponse response;

  @override
  State<RecommendationResultsScreen> createState() =>
      _RecommendationResultsScreenState();
}

class _RecommendationResultsScreenState
    extends State<RecommendationResultsScreen> {
  final _service = RecommendationService();
  String _lang = 'fr';
  bool _loading = false;
  String? _error;
  Explanation? _explanation;
  int _requestCounter = 0;

  @override
  void initState() {
    super.initState();
    final r = widget.response;
    if (r.requestId != null && r.resultats.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _explain('fr'));
    }
  }

  Future<void> _explain(String lang) async {
    final id = widget.response.requestId;
    if (id == null) return;
    final ticket = ++_requestCounter;
    setState(() {
      _lang = lang;
      _loading = true;
      _error = null;
      _explanation = null;
    });
    try {
      final e = await _service.explain(id, lang);
      if (!mounted || ticket != _requestCounter) return;
      setState(() {
        _explanation = e;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || ticket != _requestCounter) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<_TagData> _tags(Map<String, dynamic> i) {
    final out = <_TagData>[];
    void add(IconData icon, String? text) {
      if (text != null && text.isNotEmpty) out.add(_TagData(icon, text));
    }

    add(Icons.place_outlined, i['gouvernorat'] as String?);
    final p = i['pluvio'];
    if (p is num) {
      final shown = p == p.roundToDouble() ? p.toInt().toString() : p.toString();
      add(Icons.cloud_outlined, '$shown mm');
    }
    if (i['sol'] != null) {
      add(Icons.landscape_outlined,
          '${AppLang.tr('Sol', 'تربة')} ${labelFor(solOpts, i['sol'] as String?).toLowerCase()}');
    }
    if (i['drainage'] != null) {
      add(Icons.opacity,
          '${AppLang.tr('Drainage', 'صرف')} ${labelFor(drainageOpts, i['drainage'] as String?).toLowerCase()}');
    }
    if (i['eau'] != null) {
      add(Icons.water_drop_outlined, labelFor(eauOpts, i['eau'] as String?));
    }
    if (i['objectif'] != null) {
      add(Icons.eco_outlined, labelFor(objectifOpts, i['objectif'] as String?));
    }
    return out;
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.olive),
          const SizedBox(width: 8),
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

  Widget _summaryCard(BuildContext context) {
    final input = widget.response.input;
    if (input == null) return const SizedBox.shrink();
    final tags = _tags(input);
    if (tags.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined,
                  size: 18, color: AppColors.olive),
              const SizedBox(width: 8),
              Text(
                AppLang.tr('Analyse de votre terrain', 'تحليل أرضك'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final t in tags) _Tag(data: t)],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.medium),
          const SizedBox(height: 12),
          Text(
            widget.response.message ?? kNoMatchMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppLang.tr(
              'Aucune variété de notre base ne correspond à toutes ces conditions. '
                  'Modifiez vos réponses ou demandez conseil à un technicien.',
              'لا يوجد صنف في قاعدتنا يطابق كل هذه الشروط. '
                  'عدّل إجاباتك أو استشر تقنيا.',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Tableau comparatif construit uniquement à partir des données reçues.
  Widget _comparisonTable(List<VarietyResult> list) {
    TableRow header() => TableRow(
          decoration: const BoxDecoration(color: AppColors.oliveSoft),
          children: [
            _cell(AppLang.tr('Variété', 'الصنف'), head: true),
            _cell(AppLang.tr('Score', 'النتيجة'), head: true),
            _cell(AppLang.tr('Atouts', 'المزايا'), head: true),
            _cell(AppLang.tr('Limites', 'القيود'), head: true),
          ],
        );
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.2),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
            horizontalInside: BorderSide(color: AppColors.border),
          ),
          children: [
            header(),
            for (final v in list)
              TableRow(
                children: [
                  _cell(v.nom, bold: true),
                  _cell('${v.score}%',
                      color: ScoreGauge.colorFor(v.score), bold: true),
                  _cell('${v.raisons.length}', color: AppColors.good),
                  _cell('${v.limites.length}',
                      color: v.limites.isEmpty
                          ? AppColors.muted
                          : AppColors.medium),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text,
      {bool head = false, bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: head ? 12 : 14,
          fontWeight: head || bold ? FontWeight.w800 : FontWeight.w500,
          color: head ? AppColors.forest : (color ?? AppColors.ink),
        ),
      ),
    );
  }

  Widget _explanationCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isAi = _explanation?.isAi ?? false;
    return AppCard(
      color: const Color(0xFFF1F6E8),
      borderColor: const Color(0xFFCFDDB5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.olive),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLang.tr('Explication simple', 'شرح مبسّط'),
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.forest,
                selectedForegroundColor: Colors.white,
                foregroundColor: AppColors.forest,
                backgroundColor: Colors.white,
              ),
              segments: const [
                ButtonSegment<String>(value: 'fr', label: Text('Français')),
                ButtonSegment<String>(value: 'ar', label: Text('العربية')),
                ButtonSegment<String>(value: 'ar_tn', label: Text('بالتونسي')),
              ],
              selected: {_lang},
              onSelectionChanged: (s) {
                if (!_loading) _explain(s.first);
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            Row(
              children: [
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.olive),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(AppLang.tr('Préparation de l\'explication...',
                      'جارٍ إعداد الشرح...')),
                ),
              ],
            ),
          if (_error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () => _explain(_lang),
                  child: Text(AppLang.tr('Réessayer', 'إعادة المحاولة')),
                ),
              ],
            ),
          if (_explanation != null) ...[
            Directionality(
              textDirection:
                  _lang == 'fr' ? TextDirection.ltr : TextDirection.rtl,
              child: SizedBox(
                width: double.infinity,
                child: SelectableText(
                  _explanation!.texte,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isAi ? Icons.smart_toy_outlined : Icons.description_outlined,
                  size: 16,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isAi
                        ? AppLang.tr(
                            'Générée par IA à partir du calcul ci-dessus. À vérifier avec un technicien.',
                            'مُولَّد بالذكاء الاصطناعي انطلاقا من الحساب أعلاه. يُستحسن التأكد منه مع تقني.')
                        : AppLang.tr(
                            'Texte automatique (le service IA est indisponible).',
                            'نص آلي (خدمة الذكاء الاصطناعي غير متاحة).'),
                    style: t.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.response;
    return LangBuilder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            AppLang.tr('Vos recommandations', 'توصياتك'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.forest,
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsetsDirectional.only(end: 12),
              child: LangSwitch(),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _summaryCard(context),
                if (r.valeursParDefaut.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${AppLang.tr('Valeurs par défaut utilisées', 'القيم الافتراضية المستعملة')} : ${r.valeursParDefaut.join(', ')}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                if (r.resultats.isEmpty) _emptyState(context),
                if (r.resultats.isNotEmpty)
                  _sectionTitle(
                    AppLang.tr('Variétés recommandées', 'الأصناف الموصى بها'),
                    Icons.emoji_events_outlined,
                  ),
                for (var i = 0; i < r.resultats.length; i++)
                  _VarietyCard(v: r.resultats[i], rank: i + 1),
                if (r.resultats.length > 1) ...[
                  _sectionTitle(
                    AppLang.tr('Comparatif multicritères', 'مقارنة متعددة المعايير'),
                    Icons.table_chart_outlined,
                  ),
                  _comparisonTable(r.resultats),
                ],
                if (r.resultats.isNotEmpty) _explanationCard(context),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.avertissement,
                        style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                        AppLang.tr('Modifier mes réponses', 'تعديل إجاباتي')),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.home_outlined),
                    label: Text(
                        AppLang.tr('Retour à l\'accueil', 'العودة إلى الرئيسية')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagData {
  const _TagData(this.icon, this.text);
  final IconData icon;
  final String text;
}

class _Tag extends StatelessWidget {
  const _Tag({required this.data});

  final _TagData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.oliveSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 16, color: AppColors.olive),
          const SizedBox(width: 6),
          Text(
            data.text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}

class _VarietyCard extends StatelessWidget {
  const _VarietyCard({required this.v, required this.rank});

  final VarietyResult v;
  final int rank;

  bool get isBest => rank == 1;

  String _level() {
    if (v.score >= 80) return AppLang.tr('Très adapté', 'ملائم جدا');
    if (v.score >= 60) {
      return AppLang.tr('Moyennement adapté', 'ملائم نسبيا');
    }
    return AppLang.tr('Peu adapté', 'قليل الملاءمة');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = ScoreGauge.colorFor(v.score);
    return AppCard(
      borderColor: isBest ? AppColors.olive : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isBest ? AppColors.forest : AppColors.oliveSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBest) ...[
                      const Icon(Icons.emoji_events_outlined,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isBest
                          ? AppLang.tr('Meilleure correspondance',
                              'أفضل مطابقة')
                          : '${AppLang.tr('RANG', 'الرتبة')} #$rank',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isBest ? Colors.white : AppColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _level(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ScoreGauge(score: v.score, size: isBest ? 78 : 62),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.nom,
                      style: (isBest ? t.headlineSmall : t.titleLarge)
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppLang.tr('Compatibilité', 'التوافق')} ${v.score}/100',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    _VerifiedBadge(verified: v.verified),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(AppLang.tr('Pourquoi elle est proposée', 'لماذا تم اقتراحه'),
              style: t.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.forest)),
          const SizedBox(height: 6),
          for (final x in v.raisons)
            _BulletRow(
                icon: Icons.check_circle, color: AppColors.good, text: x),
          if (v.limites.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(AppLang.tr('Contraintes à connaître', 'قيود يجب معرفتها'),
                style: t.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800, color: AppColors.forest)),
            const SizedBox(height: 6),
            for (final x in v.limites)
              _BulletRow(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.medium,
                  text: x),
          ],
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.good : AppColors.medium;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verified ? Icons.verified_outlined : Icons.science_outlined,
              size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            verified
                ? AppLang.tr('Validée par un expert', 'معتمد من خبير')
                : AppLang.tr('Données à valider', 'بيانات قيد التحقق'),
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}