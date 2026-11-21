// lib/planner/planner_page.dart
// Page complète du Smart Orchard Planner avec sélection multi-variétés.
// Le calcul est fait par le backend (PlannerApi) : cette page ne fait que le formulaire + l'affichage.

import 'package:flutter/material.dart';

import 'planner_api.dart';
import 'planner_calculator.dart';
import 'planner_painter.dart';
import '../theme/app_theme.dart';
import 'planner_pdf.dart';

const _green = AppColors.leaf;
const _dark = AppColors.ink;
const _muted = AppColors.muted;
const _cream = AppColors.tile;
const _border = AppColors.tileBorder;
const _white = Colors.white;

const _varieties = [
  'Chemlali',
  'Chétoui',
  'Oueslati',
  'Zarrazi',
  'Gerboui',
  'Arbequina',
  'Arbosana',
  'Koroneiki',
];

String _fmt(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  int _step = 0;

  String? _gov;
  bool _knowsDims = true;

  final _length = TextEditingController();
  final _width = TextEditingController();
  final _surface = TextEditingController();
  final _margin = TextEditingController(text: '2');

  bool _irrigated = false;
  final Set<String> _selectedVarieties = {};
  bool _wantShd = false;

  bool _loading = false;
  bool _exporting = false;
  String? _error;
  PlannerResult? _result;
  double _usedMargin = 2;

  final List<String> _govs = governorateZone.keys.toList()..sort();

  @override
  void dispose() {
    _length.dispose();
    _width.dispose();
    _surface.dispose();
    _margin.dispose();
    super.dispose();
  }

  double? _num(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  bool get _canShd =>
      _irrigated &&
      _selectedVarieties.isNotEmpty &&
      _selectedVarieties.every(shdVarieties.contains);

  String get _varietiesLabel => _selectedVarieties.isEmpty
      ? 'Non déterminée'
      : _selectedVarieties.join(', ');

  PlannerInput _input() => PlannerInput(
    governorate: _gov!,
    irrigated: _irrigated,
    varieties: _selectedVarieties.toList(),
    wantSuperIntensive: _wantShd && _canShd,
    lengthM: _knowsDims ? _num(_length) : null,
    widthM: _knowsDims ? _num(_width) : null,
    surfaceHa: _knowsDims ? null : _num(_surface),
    marginM: _num(_margin) ?? 2,
  );

  String? _validateTerrain() {
    if (_gov == null) return 'Veuillez choisir votre gouvernorat.';

    if (_knowsDims) {
      final length = _num(_length);
      final width = _num(_width);
      if (length == null || width == null || length <= 0 || width <= 0) {
        return 'Veuillez saisir une longueur et une largeur valides.';
      }
    } else {
      final surface = _num(_surface);
      if (surface == null || surface <= 0) {
        return 'Veuillez saisir une surface valide.';
      }
    }

    final margin = _num(_margin);
    if (margin == null || margin < 0) {
      return 'La marge doit être supérieure ou égale à 0.';
    }
    return null;
  }

  void _go(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
  }

  void _next() {
    if (_step == 1) {
      final error = _validateTerrain();
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    _go(_step + 1);
  }

  Future<void> _generate() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await PlannerApi.generate(_input());
      if (!mounted) return;
      setState(() {
        _result = result;
        _usedMargin = _num(_margin) ?? 2;
        _step = 4;
      });
    } on PlannerException catch (exception) {
      if (!mounted) return;
      setState(() => _error = exception.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Une erreur inattendue est survenue.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf() async {
    final result = _result;
    if (result == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      await sharePlannerPdf(
        result,
        _usedMargin,
        governorate: _gov,
        irrigated: _irrigated,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de générer le PDF.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _reset() {
    setState(() {
      _step = 0;
      _error = null;
      _result = null;
      _gov = null;
      _knowsDims = true;
      _length.clear();
      _width.clear();
      _surface.clear();
      _margin.text = '2';
      _irrigated = false;
      _selectedVarieties.clear();
      _wantShd = false;
      _usedMargin = 2;
      _loading = false;
    });
  }

  String get _stepTitle => switch (_step) {
    1 => 'Caractéristiques du terrain',
    2 => 'Eau et variétés',
    3 => 'Résumé des paramètres',
    4 => 'Votre plan de plantation',
    _ => 'Planifier mon oliveraie',
  };

  String get _stepSubtitle => switch (_step) {
    1 => 'Commençons par les informations de votre parcelle.',
    2 => 'Précisez les conditions de plantation et les variétés.',
    3 => 'Vérifiez vos informations avant de générer le plan.',
    4 => 'Découvrez la proposition de plantation de votre parcelle.',
    _ => 'Concevez votre projet de plantation en quelques étapes.',
  };

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_step) {
      0 => _intro(),
      1 => _terrain(),
      2 => _water(),
      3 => _summary(),
      _ => _resultView(),
    };

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          _header(),
          const SizedBox(height: 30),
          Text(
            _stepTitle,
            style: const TextStyle(
              fontSize: 25,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _stepSubtitle,
            style: const TextStyle(fontSize: 14, height: 1.5, color: _muted),
          ),
          if (_step >= 1 && _step <= 3) ...[
            const SizedBox(height: 25),
            _progress(),
          ],
          const SizedBox(height: 23),
          body,
          if (_error != null) _errorBox(),
          if (_step >= 1 && _step <= 3) _navButtons(),
        ],
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Container(
        width: 47,
        height: 47,
        decoration: BoxDecoration(
          color: const Color(0xFFE9EDE4),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.eco_outlined, color: _green, size: 27),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TUNIZIT',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'SMART ORCHARD PLANNER',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: _dark,
              ),
            ),
          ],
        ),
      ),
      if (_step > 0)
        IconButton(
          onPressed: _reset,
          tooltip: 'Recommencer',
          icon: const Icon(Icons.refresh, color: _muted),
        ),
    ],
  );

  Widget _progress() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ÉTAPE $_step SUR 3',
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              color: _green,
            ),
          ),
          Text(
            '${(_step / 3 * 100).round()}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: _step / 3,
          minHeight: 7,
          backgroundColor: const Color(0xFFECEDE7),
          color: _green,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          _stepIndicator(1, 'Terrain'),
          _stepLine(1),
          _stepIndicator(2, 'Eau & variétés'),
          _stepLine(2),
          _stepIndicator(3, 'Résumé'),
        ],
      ),
    ],
  );

  Widget _stepIndicator(int number, String label) {
    final active = _step >= number;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: active ? _green : _cream,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: active
                ? const Icon(Icons.check, color: _white, size: 15)
                : Text(
                    '$number',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: active ? _dark : _muted,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(int index) => Expanded(
    child: Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 19),
      color: _step > index ? _green : _border,
    ),
  );

  Widget _errorBox() => Container(
    margin: const EdgeInsets.only(top: 15),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0ED),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFB85C50)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(color: Color(0xFF9E5148), fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _navButtons() => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loading ? null : () => _go(_step - 1),
            icon: const Icon(Icons.arrow_back, size: 17),
            label: const Text('Retour'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
              foregroundColor: _green,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _loading ? null : (_step == 3 ? _generate : _next),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _white,
                    ),
                  )
                : Icon(
                    _step == 3 ? Icons.auto_awesome : Icons.arrow_forward,
                    size: 18,
                  ),
            label: Text(
              _step == 3
                  ? (_loading ? 'Génération...' : 'Générer mon plan')
                  : 'Suivant',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: _green,
              foregroundColor: _white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _intro() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _cream,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.park_outlined, size: 37, color: _green),
        ),
        const SizedBox(height: 23),
        const Text(
          'Votre oliveraie,\nplanifiée intelligemment.',
          style: TextStyle(
            fontSize: 25,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Renseignez les caractéristiques de votre parcelle pour obtenir une proposition de plantation.',
          style: TextStyle(fontSize: 14, height: 1.7, color: _muted),
        ),
        const SizedBox(height: 25),
        _feature(Icons.grid_on_outlined, 'Organisation des rangées'),
        _feature(Icons.park_outlined, 'Estimation du nombre d’arbres'),
        _feature(Icons.map_outlined, 'Schéma de plantation 2D'),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _go(1),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Commencer la planification'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 54),
              backgroundColor: _green,
              foregroundColor: _white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _feature(IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Row(
      children: [
        Icon(icon, size: 19, color: _green),
        const SizedBox(width: 11),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF50594D)),
        ),
      ],
    ),
  );

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: _dark.withValues(alpha: 0.035),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF1EA),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: _green, size: 22),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 21),
        child,
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? suffix,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        filled: true,
        fillColor: const Color(0xFFFAFAF7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
      ),
    ),
  );

  Widget _terrain() => _sectionCard(
    title: 'Informations du terrain',
    subtitle: 'Localisation et dimensions de votre parcelle',
    icon: Icons.landscape_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Localisation',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
        const SizedBox(height: 9),
        DropdownMenu<String>(
          label: const Text('Gouvernorat'),
          initialSelection: _gov,
          expandedInsets: EdgeInsets.zero,
          menuHeight: 300,
          dropdownMenuEntries: [
            for (final governorate in _govs)
              DropdownMenuEntry(value: governorate, label: governorate),
          ],
          onSelected: (value) => setState(() => _gov = value),
        ),
        const SizedBox(height: 22),
        const Text(
          'Dimensions de la parcelle',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _dimensionTab(
                  'Dimensions',
                  _knowsDims,
                  () => setState(() => _knowsDims = true),
                ),
              ),
              Expanded(
                child: _dimensionTab(
                  'Surface',
                  !_knowsDims,
                  () => setState(() => _knowsDims = false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_knowsDims) ...[
          Row(
            children: [
              Expanded(
                child: _field(
                  _length,
                  'Longueur',
                  suffix: 'm',
                  hint: 'Ex : 100',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(_width, 'Largeur', suffix: 'm', hint: 'Ex : 50'),
              ),
            ],
          ),
          _info('Saisissez les dimensions réelles de votre parcelle.'),
        ] else ...[
          _field(
            _surface,
            'Surface de la parcelle',
            suffix: 'ha',
            hint: 'Ex : 2.5',
          ),
          _info(
            'Les dimensions seront estimées selon une forme rectangulaire de rapport 2:1.',
          ),
        ],
        const SizedBox(height: 14),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            leading: const Icon(Icons.tune, color: _green),
            title: const Text(
              'Options avancées',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
            subtitle: const Text(
              'Paramètres supplémentaires',
              style: TextStyle(fontSize: 11, color: _muted),
            ),
            children: [
              _field(_margin, 'Marge de bordure', suffix: 'm', hint: '2'),
              _info('Valeur par défaut : 2 mètres.'),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _dimensionTab(
    String label,
    bool selected,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? _white : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        boxShadow: selected
            ? [BoxShadow(color: _dark.withValues(alpha: 0.06), blurRadius: 5)]
            : [],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? _green : _muted,
        ),
      ),
    ),
  );

  Widget _info(String text) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 16, color: _green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, height: 1.5, color: _muted),
          ),
        ),
      ],
    ),
  );

  Widget _water() => _sectionCard(
    title: 'Conditions de plantation',
    subtitle: 'Gestion de l’eau et choix des variétés',
    icon: Icons.water_drop_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Parcelle irriguée',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
            subtitle: Text(
              _irrigated ? 'Culture avec irrigation' : 'Culture pluviale',
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
            activeTrackColor: _green,
            value: _irrigated,
            onChanged: (value) => setState(() {
              _irrigated = value;
              if (!_canShd) _wantShd = false;
            }),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Variétés d’olivier',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Sélectionnez une ou plusieurs variétés. Chaque variété sera placée dans un bloc de rangées séparé.',
          style: TextStyle(fontSize: 12, height: 1.5, color: _muted),
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final variety in _varieties)
              FilterChip(
                label: Text(variety),
                selected: _selectedVarieties.contains(variety),
                selectedColor: const Color(0xFFE3E9DF),
                checkmarkColor: _green,
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _selectedVarieties.add(variety);
                  } else {
                    _selectedVarieties.remove(variety);
                  }
                  if (!_canShd) _wantShd = false;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _info(
          _selectedVarieties.isEmpty
              ? 'Aucune variété sélectionnée : le choix reste à déterminer.'
              : 'Sélection : $_varietiesLabel. La répartition initiale des rangées sera équilibrée et pourra être ajustée ultérieurement.',
        ),
        if (_canShd) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Super-intensif (mécanisé)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
              subtitle: const Text(
                'Option proposée uniquement si toutes les variétés sélectionnées sont dans la liste compatible.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
              activeTrackColor: _green,
              value: _wantShd,
              onChanged: (value) => setState(() => _wantShd = value),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _dark,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _summary() {
    final dimensions = _knowsDims
        ? '${_length.text} × ${_width.text} m'
        : '${_surface.text} ha (estimée 2:1)';
    final margin = _margin.text.trim().isEmpty ? '2' : _margin.text.trim();

    return Column(
      children: [
        _sectionCard(
          title: 'Caractéristiques du terrain',
          subtitle: 'Informations de votre parcelle',
          icon: Icons.landscape_outlined,
          child: Column(
            children: [
              _line('Gouvernorat', _gov ?? '-'),
              const Divider(color: _border),
              _line('Dimensions', dimensions),
              const Divider(color: _border),
              _line('Marge de bordure', '$margin m'),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _go(1),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                  style: TextButton.styleFrom(foregroundColor: _green),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _sectionCard(
          title: 'Eau et variétés',
          subtitle: 'Conditions de plantation sélectionnées',
          icon: Icons.water_drop_outlined,
          child: Column(
            children: [
              _line('Irrigation', _irrigated ? 'Oui' : 'Non (pluvial)'),
              const Divider(color: _border),
              _line('Variétés', _varietiesLabel),
              if (_wantShd && _canShd) ...[
                const Divider(color: _border),
                _line('Système demandé', 'Super-intensif'),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _go(2),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                  style: TextButton.styleFrom(foregroundColor: _green),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: _green, size: 19),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La répartition équilibrée est une proposition d’organisation, pas une prescription agronomique.',
                  style: TextStyle(fontSize: 12, height: 1.6, color: _muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _systemLabel(PlantingSystem system) => switch (system) {
    PlantingSystem.pluvial => 'Plantation pluviale',
    PlantingSystem.irrigueClassique => 'Plantation irriguée classique',
    PlantingSystem.superIntensif => 'Plantation super-intensive',
  };

  Widget _varietyLegend(PlannerResult result) {
    if (result.varietyRows.isEmpty) {
      return const Text(
        'Aucune variété précise sélectionnée.',
        style: TextStyle(fontSize: 12, color: _muted),
      );
    }

    final varieties = result.varietyRows.keys.toList();
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: [
        for (final entry in result.varietyRows.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: plannerColorForVariety(entry.key, varieties),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${entry.key} : ${entry.value} rangée(s)',
                style: const TextStyle(fontSize: 12, color: _dark),
              ),
            ],
          ),
      ],
    );
  }

  Widget _resultView() {
    final result = _result!;
    final theme = Theme.of(context).textTheme;
    final estimated = result.dimensionsEstimated
        ? ' (estimées, rectangle 2:1)'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: _green),
                  SizedBox(width: 8),
                  Text(
                    'Plan généré',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                '${result.totalTrees} arbres',
                style: theme.displaySmall?.copyWith(
                  color: _dark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _systemLabel(result.system),
                style: const TextStyle(fontSize: 14, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _sectionCard(
          title: 'Détails de la plantation',
          subtitle: 'Indicateurs calculés automatiquement',
          icon: Icons.analytics_outlined,
          child: Column(
            children: [
              _line('Rangées', '${result.rows} × ${result.treesPerRow} arbres'),
              const Divider(color: _border),
              _line(
                'Espacement',
                '${_fmt(result.rowSpacingM)} m entre rangées · ${_fmt(result.treeSpacingM)} m sur la rangée',
              ),
              const Divider(color: _border),
              _line(
                'Densité',
                '${result.densityPerHa.toStringAsFixed(0)} arbres/ha',
              ),
              const Divider(color: _border),
              _line(
                'Surface',
                '${(result.surfaceM2 / 10000).toStringAsFixed(2)} ha',
              ),
              const Divider(color: _border),
              _line(
                'Surface utile',
                '${(result.usableAreaM2 / 10000).toStringAsFixed(2)} ha',
              ),
              const Divider(color: _border),
              _line(
                'Dimensions',
                '${_fmt(result.lengthM)} × ${_fmt(result.widthM)} m$estimated',
              ),
              if (result.varietyRows.isNotEmpty) ...[
                const Divider(color: _border),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Répartition des variétés',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _dark,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _varietyLegend(result),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 15),
        _sectionCard(
          title: 'Schéma de plantation',
          subtitle: 'Vue de dessus de votre parcelle',
          icon: Icons.grid_on_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 280,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _border),
                ),
                child: InteractiveViewer(
                  maxScale: 6,
                  child: CustomPaint(
                    painter: PlanPainter(result, _usedMargin),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              if (result.varietyRows.isNotEmpty) ...[
                const SizedBox(height: 14),
                _varietyLegend(result),
              ],
            ],
          ),
        ),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 15),
          _sectionCard(
            title: 'Remarques',
            subtitle: 'Informations complémentaires',
            icon: Icons.info_outline,
            child: Column(
              children: [
                for (final warning in result.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 17, color: _green),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            warning,
                            style: theme.bodySmall?.copyWith(
                              color: _muted,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _exporting ? null : _exportPdf,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 19),
            label: Text(
              _exporting
                  ? 'Génération du PDF...'
                  : 'Télécharger le rapport PDF',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: _dark,
              foregroundColor: _white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _go(3),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Modifier'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  foregroundColor: _green,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvelle planification'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  backgroundColor: _green,
                  foregroundColor: _white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
