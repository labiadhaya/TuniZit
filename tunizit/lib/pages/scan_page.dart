import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/scan_service.dart';
import '../theme/app_theme.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  late final AnimationController _scanCtrl;

  int _tab = 0; // 0 = Scanner / Photo, 1 = Guide maladies
  String _lang = 'fr'; // langue de réponse de l'IA : fr | ar
  File? _image;
  ScanResult? _result;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

   Future<void> _pick(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) _toast('Impossible d’ouvrir la caméra ou la galerie.');
      return;
    }
    if (picked == null) return;

    final file = File(picked.path);

    setState(() {
      _image = file;
      _result = null;
      _error = null;
      _loading = true;
    });

    try {
      final res = await ScanService.scan(file, lang: _lang);
      if (!mounted) return;
      setState(() => _result = res);
    } on ScanException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Une erreur inattendue est survenue. Réessayez.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _Header(
              lang: _lang,
              onLang: (l) => setState(() => _lang = l),
            ),
            const SizedBox(height: 14),
            const _TagChip(),
            const SizedBox(height: 10),
            const Text(
              'Diagnostic & Santé de l’Olivier',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Détection des maladies, ravageurs et carences à partir d’une photo de feuille, '
              'de fruit, de rameau ou de tronc, analysée par IA.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            _Segmented(index: _tab, onChanged: (i) => setState(() => _tab = i)),
            const SizedBox(height: 16),
            if (_tab == 0) ..._scanTab() else const _GuideTab(),
          ],
        ),
      ),
    );
  }

  List<Widget> _scanTab() {
    return [
      _CaptureCard(
        image: _image,
        loading: _loading,
        scanAnim: _scanCtrl,
        partLabel: _result == null ? null : _partLabel(_result!.part),
        busy: _loading,
        onCamera: () => _pick(ImageSource.camera),
        onGallery: () => _pick(ImageSource.gallery),
      ),
      const SizedBox(height: 16),
      if (_image == null && _result == null && _error == null) const _PhotoTips(),
      if (_error != null) _ErrorTile(message: _error!),
      if (_result != null) ..._resultWidgets(_result!),
    ];
  }

  List<Widget> _resultWidgets(ScanResult r) {
    if (!r.isOlivePlant) {
      return [
        _Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.eco_outlined, color: AppColors.warn),
              SizedBox(width: 8),
              Text('Aucun olivier détecté',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Text(
              r.advice.isNotEmpty
                  ? r.advice
                  : 'Cette photo ne semble pas montrer un olivier. Cadrez une feuille, un fruit ou un rameau.',
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ]),
        ),
      ];
    }

    return [
      if (!r.imageUsable) _QualityTile(result: r),
      _ResultCard(result: r),
    ];
  }

  static String _partLabel(String p) {
    switch (p) {
      case 'leaf':
        return 'FEUILLE';
      case 'fruit':
        return 'FRUIT';
      case 'branch':
        return 'RAMEAU';
      case 'trunk':
        return 'TRONC';
      case 'flower':
        return 'FLEUR';
      default:
        return 'ORGANE';
    }
  }
}

// ───────────────────────── En-tête ─────────────────────────

class _Header extends StatelessWidget {
  final String lang;
  final ValueChanged<String> onLang;
  const _Header({required this.lang, required this.onLang});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.forest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.spa_rounded, color: AppColors.lime, size: 22),
      ),
      const SizedBox(width: 10),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TuniZit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1)),
        SizedBox(height: 2),
        Text('منصة الزيتون', style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ]),
      const Spacer(),
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          _LangBtn(label: 'FR', active: lang == 'fr', onTap: () => onLang('fr')),
          _LangBtn(label: 'العربية', active: lang == 'ar', onTap: () => onLang('ar')),
        ]),
      ),
      const SizedBox(width: 10),
      Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(color: AppColors.forest, shape: BoxShape.circle),
        child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
      ),
    ]);
  }
}

class _LangBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LangBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.forest : AppColors.muted,
            )),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.lime.withAlpha(160),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.biotech_outlined, size: 16, color: AppColors.forest),
          SizedBox(width: 6),
          Text('IA Phytosanitaire • التشخيص الذكي',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.forest)),
        ]),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _Segmented({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget item(int i, IconData icon, String label) {
      final active = index == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(i),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: active ? AppColors.forest : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: active ? Colors.white : AppColors.ink),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.ink,
                  )),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(170),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(children: [
        item(0, Icons.center_focus_strong_outlined, 'Scanner / Photo'),
        item(1, Icons.menu_book_outlined, 'Guide maladies'),
      ]),
    );
  }
}

// ───────────────────────── Carte de capture ─────────────────────────

class _CaptureCard extends StatelessWidget {
  final File? image;
  final bool loading;
  final bool busy;
  final Animation<double> scanAnim;
  final String? partLabel;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _CaptureCard({
    required this.image,
    required this.loading,
    required this.busy,
    required this.scanAnim,
    required this.partLabel,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SizedBox(
            height: 280,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              if (image != null)
                Image.file(image!, fit: BoxFit.cover)
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1C5B3A), Color(0xFF0B3320)],
                    ),
                  ),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.eco_rounded, size: 56, color: AppColors.lime),
                      SizedBox(height: 12),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Cadrez une feuille, un fruit ou un rameau',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ),
              // Voile + ligne de balayage pendant l'analyse
              if (loading) ...[
                Container(color: Colors.black.withAlpha(90)),
                AnimatedBuilder(
                  animation: scanAnim,
                  builder: (_, __) => Align(
                    alignment: Alignment(0, -1 + 2 * scanAnim.value),
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [BoxShadow(color: AppColors.lime.withAlpha(200), blurRadius: 14)],
                      ),
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: Text('Analyse des symptômes en cours…',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              Positioned(
                top: 14,
                left: 14,
                child: _Pill(
                  dot: true,
                  label: loading ? 'Analyse IA en cours' : 'Diagnostic IA actif',
                ),
              ),
              if (partLabel != null && !loading)
                Positioned(
                  bottom: 14,
                  left: 14,
                  child: _Pill(label: 'Organe : $partLabel', dark: true),
                ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _PrimaryButton(
              icon: Icons.photo_camera_outlined,
              label: 'Prendre une photo',
              onPressed: busy ? null : onCamera,
            ),
            const SizedBox(height: 10),
            _SoftButton(
              icon: Icons.photo_library_outlined,
              label: 'Importer du verger',
              onPressed: busy ? null : onGallery,
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool dot;
  final bool dark;
  const _Pill({required this.label, this.dot = false, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? AppColors.forest.withAlpha(220) : Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppColors.leaf, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
        ],
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : AppColors.forest,
            )),
      ]),
    );
  }
}

// ───────────────────────── Boutons ─────────────────────────

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _SoftButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.forest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
      ),
    );
  }
}

// ───────────────────────── Conteneurs ─────────────────────────

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withAlpha(18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? accent;
  final Widget child;
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.child,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.forest;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tileBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
        ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

class _Bullets extends StatelessWidget {
  final List<String> items;
  const _Bullets(this.items);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7, right: 8),
                    child: Icon(Icons.circle, size: 5, color: AppColors.leaf),
                  ),
                  Expanded(
                    child: Text(t, style: const TextStyle(height: 1.4, color: AppColors.ink)),
                  ),
                ]),
              ))
          .toList(),
    );
  }
}

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
      );
}

// ───────────────────────── Alertes ─────────────────────────

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: AppColors.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Analyse impossible',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
            const SizedBox(height: 4),
            Text(message, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 4),
            const Text('Reprenez la photo ou réessayez dans un instant.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class _QualityTile extends StatelessWidget {
  final ScanResult result;
  const _QualityTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withAlpha(150),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.camera_enhance_outlined, color: AppColors.amberText),
          SizedBox(width: 8),
          Text('Photo difficile à analyser',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.amberText)),
        ]),
        if (result.imageIssues.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Bullets(result.imageIssues),
        ],
        if (result.retakeTips.isNotEmpty) ...[
          const _SubLabel('Pour une meilleure photo'),
          _Bullets(result.retakeTips),
        ],
      ]),
    );
  }
}

class _PhotoTips extends StatelessWidget {
  const _PhotoTips();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline, color: AppColors.forest),
          SizedBox(width: 8),
          Text('Pour un diagnostic fiable',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        SizedBox(height: 10),
        _Bullets([
          'Photographiez à la lumière du jour, sans flash.',
          'Approchez-vous à 15-20 cm de la zone atteinte, image nette.',
          'Choisissez un organe bien touché : feuille, fruit ou rameau.',
          'Pour un dessèchement, prenez aussi la branche entière.',
        ]),
      ]),
    );
  }
}

// ───────────────────────── Carte résultat ─────────────────────────

class _ResultCard extends StatelessWidget {
  final ScanResult result;
  const _ResultCard({required this.result});

  String get _title {
    if (result.isHealthy) return 'Olivier en bonne santé';
    final fr = result.diseaseFr;
    if (fr != null && fr.trim().isNotEmpty) return fr;
    return 'Diagnostic incertain';
  }

  String get _badge {
    if (result.isHealthy) return 'RÉSULTAT IA : PLANTE SAINE';
    if (result.isUncertain) return 'DIAGNOSTIC INCERTAIN';
    return result.confidence >= 0.85
        ? 'RÉSULTAT IA HAUTEMENT PROBABLE'
        : 'RÉSULTAT IA PROBABLE';
  }

  Color get _badgeBg {
    if (result.isHealthy) return AppColors.lime;
    if (result.isUncertain) return const Color(0xFFE6E9E6);
    return AppColors.amber;
  }

  Color get _badgeFg {
    if (result.isHealthy) return AppColors.forest;
    if (result.isUncertain) return AppColors.muted;
    return AppColors.amberText;
  }

  Color get _sevColor {
    switch (result.severity) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.warn;
      default:
        return AppColors.leaf;
    }
  }

  static String _sev(String? s) {
    switch (s) {
      case 'high':
        return 'Élevée';
      case 'medium':
        return 'Modérée';
      case 'low':
        return 'Faible';
      default:
        return '—';
    }
  }

  static String _urgency(String u) {
    switch (u) {
      case 'treat_now':
        return 'Intervenir immédiatement';
      case 'treat_soon':
        return 'Traiter sous 1 à 2 semaines';
      case 'monitor':
        return 'À surveiller (7 à 15 jours)';
      default:
        return 'Aucune action urgente';
    }
  }

  static String _spread(String s) {
    switch (s) {
      case 'high':
        return 'Élevé';
      case 'medium':
        return 'Moyen';
      default:
        return 'Faible';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final pct = (r.confidence * 100);
    final ar = (r.diseaseAr ?? '').trim();
    final sub = [
      if (ar.isNotEmpty) ar,
      if ((r.pathogen ?? '').trim().isNotEmpty) r.pathogen!.trim(),
    ].join(' • ');

    // Hypothèses secondaires : on retire celle qui correspond au diagnostic principal.
    final main = (r.diseaseFr ?? '').toLowerCase().trim();
    final others = r.differential
        .where((d) => d.nameFr.toLowerCase().trim() != main)
        .take(3)
        .toList();

    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Badge + ID
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _badgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_outlined, size: 16, color: _badgeFg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(_badge,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800, color: _badgeFg)),
                ),
              ]),
            ),
          ),
          if (r.scanId != null) ...[
            const SizedBox(width: 8),
            Text('ID #${r.scanId}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ]),
        const SizedBox(height: 14),

        // Titre + confiance
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.15)),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(sub, style: const TextStyle(color: AppColors.muted, height: 1.3)),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text.rich(TextSpan(children: [
              TextSpan(
                text: pct.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.forest),
              ),
              const TextSpan(
                text: '%',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.forest),
              ),
            ])),
            const Text('Indice de\nconfiance',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.2)),
          ]),
        ]),
        const SizedBox(height: 16),

        // Hypothèses secondaires
        if (others.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.tile,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.tileBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('HYPOTHÈSES SECONDAIRES ÉVALUÉES',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted)),
              const SizedBox(height: 10),
              ...others.map((d) => _ProbRow(d: d)),
            ]),
          ),
        ],

        // Symptômes
        if (r.symptoms.isNotEmpty)
          _InfoTile(
            icon: Icons.visibility_outlined,
            title: 'Symptômes observés',
            child: _Bullets(r.symptoms),
          ),

        // Gravité & urgence
        if (!r.isHealthy)
          _InfoTile(
            icon: Icons.speed_outlined,
            title: 'Gravité & urgence',
            accent: _sevColor,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Gravité : ${_sev(r.severity)}',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: _sevColor)),
              const SizedBox(height: 4),
              Text(_urgency(r.urgency), style: const TextStyle(height: 1.4)),
            ]),
          ),

        // Traitement
        if (!r.isHealthy && !r.treatment.isEmpty)
          _InfoTile(
            icon: Icons.healing_outlined,
            title: 'Plan de traitement',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.treatment.immediateActions.isNotEmpty) ...[
                const _SubLabel('À faire maintenant'),
                _Bullets(r.treatment.immediateActions),
              ],
              if (r.treatment.organic.isNotEmpty) ...[
                const _SubLabel('Solutions biologiques / douces'),
                _Bullets(r.treatment.organic),
              ],
              if (r.treatment.chemical.isNotEmpty) ...[
                const _SubLabel('Traitements chimiques possibles'),
                _Bullets(r.treatment.chemical),
                const Text(
                  'Respectez l’étiquette, la dose homologuée, le délai avant récolte et portez des protections.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35),
                ),
              ],
              if ((r.treatment.timing ?? '').isNotEmpty) ...[
                const _SubLabel('Meilleure période'),
                Text(r.treatment.timing!, style: const TextStyle(height: 1.4)),
              ],
            ]),
          ),

        // Prévention
        if (r.prevention.isNotEmpty)
          _InfoTile(
            icon: Icons.shield_outlined,
            title: 'Prévention',
            child: _Bullets(r.prevention),
          ),

        // Vigilance
        if (!r.isHealthy && (r.riskFactors.isNotEmpty || r.followUp.isNotEmpty))
          _InfoTile(
            icon: Icons.warning_amber_rounded,
            title: 'Vigilance sanitaire',
            accent: AppColors.warn,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Risque de propagation : ${_spread(r.spreadRisk)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (r.riskFactors.isNotEmpty) ...[
                const _SubLabel('Facteurs favorisants'),
                _Bullets(r.riskFactors),
              ],
              if (r.followUp.isNotEmpty) ...[
                const _SubLabel('Suivi'),
                _Bullets(r.followUp),
              ],
            ]),
          ),

        // Conseil
        if (r.advice.isNotEmpty)
          _InfoTile(
            icon: Icons.record_voice_over_outlined,
            title: 'Conseil de l’agronome',
            child: Text(r.advice, style: const TextStyle(height: 1.45)),
          ),

        // Expert
        if (r.needsExpert)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.support_agent, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Avis d’un expert recommandé',
                      style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
                  const SizedBox(height: 4),
                  Text(
                    (r.expertReason ?? '').isNotEmpty
                        ? r.expertReason!
                        : 'Le diagnostic n’est pas assez certain. Contactez un ingénieur agricole ou le CRDA de votre région.',
                    style: const TextStyle(height: 1.4),
                  ),
                ]),
              ),
            ]),
          ),

        const SizedBox(height: 4),
        _PrimaryButton(
          icon: Icons.link,
          label: 'Associer à la parcelle',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Association aux parcelles : bientôt disponible.')),
          ),
        ),
        const SizedBox(height: 10),
        _SoftButton(
          icon: Icons.menu_book_outlined,
          label: 'Consulter un expert agronome',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mise en relation avec un expert : bientôt disponible.')),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Ce diagnostic est une aide à la décision basée sur une photo. Il ne remplace pas '
          'l’avis d’un professionnel ni une analyse de laboratoire.',
          style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.35),
        ),
      ]),
    );
  }
}

class _ProbRow extends StatelessWidget {
  final Differential d;
  const _ProbRow({required this.d});

  @override
  Widget build(BuildContext context) {
    final ar = (d.nameAr ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        Row(children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppColors.leaf, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(ar.isEmpty ? d.nameFr : '${d.nameFr} ($ar)',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text('${(d.probability * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: d.probability.clamp(0.0, 1.0) as double,
            minHeight: 5,
            backgroundColor: Colors.white,
            color: AppColors.leaf,
          ),
        ),
      ]),
    );
  }
}

// ───────────────────────── Guide maladies ─────────────────────────

class _GuideItem {
  final String name;
  final String latin;
  final String signs;
  final String when;
  final IconData icon;
  const _GuideItem(this.name, this.latin, this.signs, this.when, this.icon);
}

const _guide = <_GuideItem>[
  _GuideItem(
    'Œil de paon',
    'Spilocaea oleagina',
    'Taches rondes brun-noir sur la face supérieure des feuilles, avec un halo jaune. Chute des feuilles.',
    'Hiver et printemps humides',
    Icons.circle_outlined,
  ),
  _GuideItem(
    'Verticilliose',
    'Verticillium dahliae',
    'Dessèchement brutal de branches, feuilles sèches qui restent accrochées, vaisseaux bruns sous l’écorce.',
    'Printemps et début d’été',
    Icons.park_outlined,
  ),
  _GuideItem(
    'Tuberculose (broussin)',
    'Pseudomonas savastanoi',
    'Excroissances rugueuses (galles) sur rameaux et branches.',
    'Après grêle, taille ou gaulage',
    Icons.grain,
  ),
  _GuideItem(
    'Anthracnose',
    'Colletotrichum spp.',
    'Fruits à taches brunes creusées, pustules orangées, momification et chute.',
    'Automne humide',
    Icons.local_florist_outlined,
  ),
  _GuideItem(
    'Cochenille noire & fumagine',
    'Saissetia oleae',
    'Carapaces noires en « H » sur rameaux, miellat collant puis dépôt noir (suie) sur les feuilles.',
    'Été – automne',
    Icons.bug_report_outlined,
  ),
  _GuideItem(
    'Psylle de l’olivier',
    'Euphyllura olivina',
    'Amas cotonneux blancs sur fleurs et jeunes pousses, coulure des fleurs.',
    'Printemps',
    Icons.air,
  ),
  _GuideItem(
    'Mouche de l’olive',
    'Bactrocera oleae',
    'Piqûres sombres, galeries et trous de sortie dans les olives, chute précoce.',
    'Fin d’été – automne',
    Icons.pest_control_outlined,
  ),
  _GuideItem(
    'Teigne de l’olivier',
    'Prays oleae',
    'Mines dans les feuilles, fleurs agglutinées, chute d’olives près du pédoncule.',
    'Printemps – automne',
    Icons.pest_control_rodent_outlined,
  ),
  _GuideItem(
    'Carences nutritives',
    'Fer, potassium, bore…',
    'Jaunissement entre les nervures, bout des feuilles brûlé, pousses déformées.',
    'Selon sol et irrigation',
    Icons.water_drop_outlined,
  ),
];

class _GuideTab extends StatelessWidget {
  const _GuideTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _guide
          .map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Panel(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.lime.withAlpha(180),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(g.icon, color: AppColors.forest),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(g.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(g.latin,
                            style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColors.muted)),
                        const SizedBox(height: 8),
                        Text(g.signs, style: const TextStyle(height: 1.4)),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.event_outlined, size: 15, color: AppColors.leaf),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(g.when,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.leaf)),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ))
          .toList(),
    );
  }
}