import 'package:material_ui/material_ui.dart';
import '../../../core/lang.dart';
import '../../../core/theme.dart';
import '../data/form_options.dart';
import '../services/recommendation_service.dart';
import '../widgets/option_tile.dart';
import 'recommendation_results_screen.dart';

List<String> _stepTitles() => [
      AppLang.tr('Localisation', 'الموقع'),
      AppLang.tr('Sol', 'التربة'),
      AppLang.tr('Eau', 'الماء'),
      AppLang.tr('Objectif', 'الهدف'),
    ];

List<String> _stepQuestions() => [
      AppLang.tr('Où se trouve votre terrain ?', 'أين توجد أرضك؟'),
      AppLang.tr('Comment est votre terre ?', 'كيف هي تربة أرضك؟'),
      AppLang.tr('De quelle eau disposez-vous ?', 'ما هو الماء المتوفر لديك؟'),
      AppLang.tr('Que voulez-vous produire ?', 'ماذا تريد أن تنتج؟'),
    ];

const _stepIcons = [
  Icons.place_outlined,
  Icons.landscape_outlined,
  Icons.water_drop_outlined,
  Icons.eco_outlined,
];

class RecommendationFormScreen extends StatefulWidget {
  const RecommendationFormScreen({super.key});

  @override
  State<RecommendationFormScreen> createState() =>
      _RecommendationFormScreenState();
}

class _RecommendationFormScreenState extends State<RecommendationFormScreen> {
  int _step = 0;
  bool _loading = false;
  String? _error;

  String? _gouvernorat;
  String? _gel;
  String? _sol;
  String? _drainage;
  String? _salinite;
  String? _eau;
  String? _irrigationSysteme;
  String? _salinEau;
  String? _objectif;
  String? _systeme;
  final _pluvio = TextEditingController();

  @override
  void dispose() {
    _pluvio.dispose();
    super.dispose();
  }

  double? _parsePluvio() =>
      double.tryParse(_pluvio.text.trim().replaceAll(',', '.'));

  String? _validateStep() {
    switch (_step) {
      case 0:
        if (_gouvernorat == null) {
          return AppLang.tr('Choisissez votre gouvernorat.',
              'اختر ولايتك.');
        }
        final p = _parsePluvio();
        if (p == null) {
          return AppLang.tr(
              'Indiquez la pluviométrie annuelle en mm (exemple : 300).',
              'أدخل كمية الأمطار السنوية بالمم (مثال: 300).');
        }
        if (p < 0 || p > 2000) {
          return AppLang.tr('La pluviométrie doit être entre 0 et 2000 mm.',
              'يجب أن تكون الأمطار بين 0 و2000 مم.');
        }
        return null;
      case 1:
        if (_sol == null) {
          return AppLang.tr('Choisissez le type de sol.', 'اختر نوع التربة.');
        }
        if (_drainage == null) {
          return AppLang.tr('Choisissez le drainage.', 'اختر نوع الصرف.');
        }
        return null;
      case 2:
        if (_eau == null) {
          return AppLang.tr('Choisissez la disponibilité de l\'eau.',
              'اختر مدى توفر الماء.');
        }
        if (_eau != 'pluvial' && _irrigationSysteme == null) {
          return AppLang.tr('Choisissez le système d\'irrigation.',
              'اختر نظام الري.');
        }
        return null;
      default:
        if (_objectif == null) {
          return AppLang.tr('Choisissez votre objectif.', 'اختر هدفك.');
        }
        return null;
    }
  }

  void _next() {
    final err = _validateStep();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  void _back() {
    setState(() {
      _error = null;
      _step--;
    });
  }

  void _setEau(String? v) {
    setState(() {
      _eau = v;
      if (v == 'pluvial') {
        _irrigationSysteme = null;
        _salinEau = null;
        if (_systeme == 'intensif' || _systeme == 'super_intensif') {
          _systeme = null;
        }
      }
    });
  }

  Future<void> _pickGouvernorat() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GouvernoratSheet(selected: _gouvernorat),
    );
    if (picked != null) setState(() => _gouvernorat = picked);
  }

  Future<void> _submit() async {
    final err = _validateStep();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final form = <String, dynamic>{
      'gouvernorat': _gouvernorat,
      'pluvio': _parsePluvio(),
      'sol': _sol,
      'drainage': _drainage,
      'eau': _eau,
      'objectif': _objectif,
    };
    if (_gel != null) form['gel'] = _gel;
    if (_salinite != null) form['salinite'] = _salinite;
    if (_salinEau != null) form['salinite_eau'] = _salinEau;
    if (_systeme != null) form['systeme'] = _systeme;
    if (_irrigationSysteme != null) {
      form['irrigation_systeme'] = _irrigationSysteme;
    }

    try {
      final r = await RecommendationService().getRecommendations(form);
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecommendationResultsScreen(response: r),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w800,
        color: AppColors.olive,
      ),
    );
  }

  List<Widget> _buildStep(BuildContext context) {
    final titleStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.forest);
    switch (_step) {
      case 0:
        return [
          _label(AppLang.tr('GOUVERNORAT *', 'الولاية *')),
          const SizedBox(height: 8),
          _PickerField(
            value: _gouvernorat,
            hint: AppLang.tr('Choisir votre gouvernorat', 'اختر ولايتك'),
            onTap: _pickGouvernorat,
          ),
          const SizedBox(height: 24),
          _label(AppLang.tr('PLUVIOMÉTRIE ANNUELLE *', 'الأمطار السنوية *')),
          const SizedBox(height: 4),
          Text(
            AppLang.tr(
              'Quantité de pluie par an dans votre région. '
                  'Demandez au CRDA si vous ne la connaissez pas.',
              'كمية الأمطار سنويا في منطقتك. '
                  'اسأل المندوبية الجهوية للفلاحة إن لم تكن تعرفها.',
            ),
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pluvio,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: AppLang.tr('exemple : 300', 'مثال: 300'),
              suffixText: 'mm',
              prefixIcon: const Icon(Icons.cloud_outlined),
            ),
          ),
          const SizedBox(height: 24),
          OptionGroup(
            title: AppLang.tr('Gel en hiver (facultatif)',
                'الصقيع في الشتاء (اختياري)'),
            options: gelOpts,
            value: _gel,
            optional: true,
            onChanged: (v) => setState(() => _gel = v),
          ),
        ];
      case 1:
        return [
          OptionGroup(
            title: AppLang.tr('Type de sol *', 'نوع التربة *'),
            options: solOpts,
            value: _sol,
            onChanged: (v) => setState(() => _sol = v),
          ),
          const SizedBox(height: 16),
          OptionGroup(
            title: AppLang.tr('Drainage *', 'الصرف *'),
            options: drainageOpts,
            value: _drainage,
            onChanged: (v) => setState(() => _drainage = v),
          ),
          const SizedBox(height: 16),
          OptionGroup(
            title: AppLang.tr('Salinité du sol (facultatif)',
                'ملوحة التربة (اختياري)'),
            options: salinityOpts,
            value: _salinite,
            optional: true,
            onChanged: (v) => setState(() => _salinite = v),
          ),
        ];
      case 2:
        return [
          OptionGroup(
            title: AppLang.tr('Disponibilité de l\'eau *', 'توفر الماء *'),
            options: eauOpts,
            value: _eau,
            onChanged: _setEau,
          ),
          if (_eau != null && _eau != 'pluvial') ...[
            const SizedBox(height: 16),
            OptionGroup(
              title: AppLang.tr('Système d\'irrigation *', 'نظام الري *'),
              options: irrigationOpts,
              value: _irrigationSysteme,
              onChanged: (v) => setState(() => _irrigationSysteme = v),
            ),
            const SizedBox(height: 16),
            OptionGroup(
              title: AppLang.tr('Salinité de l\'eau (facultatif)',
                  'ملوحة الماء (اختياري)'),
              options: salinityOpts,
              value: _salinEau,
              optional: true,
              onChanged: (v) => setState(() => _salinEau = v),
            ),
          ],
        ];
      default:
        return [
          OptionGroup(
            title: AppLang.tr('Objectif de production *', 'هدف الإنتاج *'),
            options: objectifOpts,
            value: _objectif,
            onChanged: (v) => setState(() => _objectif = v),
          ),
          const SizedBox(height: 16),
          OptionGroup(
            title: AppLang.tr('Système de culture visé (facultatif)',
                'نظام الزراعة المستهدف (اختياري)'),
            options: _eau == 'pluvial' ? [systemeOpts.first] : systemeOpts,
            value: _systeme,
            optional: true,
            onChanged: (v) => setState(() => _systeme = v),
          ),
          if (_eau == 'pluvial')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                AppLang.tr(
                  'Les systèmes intensifs demandent de l\'irrigation : '
                      'ils ne sont pas proposés avec « pluie seulement ».',
                  'الأنظمة المكثفة تتطلب الري: '
                      'لذلك لا تُقترح مع «الأمطار فقط».',
                ),
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          Text(AppLang.tr('Résumé de vos réponses', 'ملخص إجاباتك'),
              style: titleStyle),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _SummaryRow(AppLang.tr('Gouvernorat', 'الولاية'),
                    _gouvernorat ?? '-'),
                _SummaryRow(AppLang.tr('Pluviométrie', 'الأمطار'),
                    '${_pluvio.text.trim()} mm'),
                _SummaryRow(AppLang.tr('Gel', 'الصقيع'),
                    labelFor(gelOpts, _gel)),
                _SummaryRow(
                    AppLang.tr('Sol', 'التربة'), labelFor(solOpts, _sol)),
                _SummaryRow(AppLang.tr('Drainage', 'الصرف'),
                    labelFor(drainageOpts, _drainage)),
                _SummaryRow(
                    AppLang.tr('Eau', 'الماء'), labelFor(eauOpts, _eau)),
                if (_irrigationSysteme != null)
                  _SummaryRow(AppLang.tr('Irrigation', 'الري'),
                      labelFor(irrigationOpts, _irrigationSysteme)),
              ],
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return LangBuilder(builder: (context) {
      final isLast = _step == _stepTitles().length - 1;
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            AppLang.tr('Quelle variété planter ?', 'أي صنف تغرس؟'),
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
        body: SafeArea(
          child: Column(
            children: [
              _StepHeader(step: _step),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._buildStep(context),
                          if (_error != null)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: scheme.onErrorContainer),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                          color: scheme.onErrorContainer),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A233012),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _back,
                          child: Text(AppLang.tr('Précédent', 'السابق')),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed:
                            _loading ? null : (isLast ? _submit : _next),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(isLast
                                ? AppLang.tr('Voir les recommandations',
                                    'عرض التوصيات')
                                : AppLang.tr('Suivant', 'التالي')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final titles = _stepTitles();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < titles.length; i++)
                Expanded(
                  child: Container(
                    margin: EdgeInsetsDirectional.only(
                        end: i == titles.length - 1 ? 0 : 6),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? AppColors.forest
                          : AppColors.olive.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.oliveSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_stepIcons[step],
                    size: 20, color: AppColors.forest),
              ),
              const SizedBox(width: 10),
              Text(
                '${AppLang.tr('Étape', 'الخطوة')} ${step + 1} '
                '${AppLang.tr('sur', 'من')} ${titles.length} · ${titles[step]}',
                style: t.labelLarge?.copyWith(
                  color: AppColors.olive,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _stepQuestions()[step],
            style: t.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.place_outlined, color: AppColors.olive),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value ?? hint,
                    style: TextStyle(
                      fontSize: 16,
                      color: value == null ? AppColors.muted : AppColors.ink,
                      fontWeight:
                          value == null ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _norm(String s) {
  const from = 'àâäéèêëîïôöùûüç';
  const to = 'aaaeeeeiioouuuc';
  var r = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    r = r.replaceAll(from[i], to[i]);
  }
  return r;
}

class _GouvernoratSheet extends StatefulWidget {
  const _GouvernoratSheet({this.selected});

  final String? selected;

  @override
  State<_GouvernoratSheet> createState() => _GouvernoratSheetState();
}

class _GouvernoratSheetState extends State<_GouvernoratSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = gouvernorats
        .where((g) => _norm(g).contains(_norm(_q.trim())))
        .toList();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              AppLang.tr('Choisissez votre gouvernorat', 'اختر ولايتك'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: AppLang.tr('Rechercher...', 'بحث...'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final g in list)
                    ListTile(
                      title: Text(g),
                      trailing: g == widget.selected
                          ? const Icon(Icons.check, color: AppColors.good)
                          : null,
                      onTap: () => Navigator.of(context).pop(g),
                    ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(AppLang.tr('Aucun résultat.', 'لا توجد نتائج.')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}