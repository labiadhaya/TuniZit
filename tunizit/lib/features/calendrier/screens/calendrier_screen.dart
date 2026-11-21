import 'package:flutter/material.dart';

import '../widgets/calendrier_theme.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';
import '../widgets/activity_details_sheet.dart';
import '../widgets/new_task_sheet.dart';
import '../widgets/phenology_card.dart';
import '../widgets/task_card.dart';

const _kAll = '__all__';

/// Écran "Travaux & Calendrier" (onglet Outils).
///
/// - [service] : par défaut MockActivityService (données de la capture).
/// - [embedded] : true quand tu l'intègres dans l'onglet "Outils" (sans Scaffold,
///   car le header et la barre du bas viennent de l'écran parent).
class CalendrierScreen extends StatefulWidget {
  const CalendrierScreen({super.key, this.service, this.embedded = false});
  final ActivityService? service;
  final bool embedded;

  @override
  State<CalendrierScreen> createState() => _CalendrierScreenState();
}

class _CalendrierScreenState extends State<CalendrierScreen> {
  late final ActivityService _service = widget.service ?? MockActivityService();

  List<Activity> _activities = [];
  List<Option> _parcels = [];
  PhenologyInfo? _phenology;
  String _parcelKey = _kAll;
  ActivityStatus? _filter; // null = Toutes
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final parcels = await _service.parcels();
      final pheno = await _service.phenology();
      if (!mounted) return;
      setState(() {
        _parcels = parcels;
        _phenology = pheno;
        // Comme dans la capture : la 1ère parcelle est sélectionnée par défaut.
        if (parcels.isNotEmpty) _parcelKey = parcels.first.id;
      });
    } catch (_) {
      // la liste affichera l'erreur si le serveur est injoignable
    }
    await _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _service.list(
        parcelId: _parcelKey == _kAll ? null : _parcelKey,
      );
      if (!mounted) return;
      setState(() {
        _activities = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les interventions.';
        _loading = false;
      });
    }
  }

  int _count(ActivityStatus? s) => s == null
      ? _activities.length
      : _activities.where((a) => a.status == s).length;

  List<Activity> get _visible => _filter == null
      ? _activities
      : _activities.where((a) => a.status == _filter).toList();

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  );

  Future<void> _openNew() async {
    final created = await showModalBottomSheet<Activity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => NewTaskSheet(
        service: _service,
        defaultParcelId: _parcelKey == _kAll ? null : _parcelKey,
      ),
    );
    if (created != null) {
      _toast('Tâche ajoutée');
      _load();
    }
  }

  Future<void> _openDetails(Activity a) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => ActivityDetailsSheet(activity: a, service: _service),
    );
    if (changed == true) _load();
  }

  Future<void> _complete(Activity a) async {
    try {
      await _service.updateStatus(a.id, ActivityStatus.terminee);
      _toast('Tâche terminée ✓');
      _load();
    } catch (_) {
      _toast('Échec de la mise à jour, réessaie.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (_phenology != null) PhenologyCard(info: _phenology!),
          const SizedBox(height: 22),
          _header(),
          const SizedBox(height: 14),
          _chips(),
          const SizedBox(height: 16),
          ..._body(),
          const SizedBox(height: 10),
          _newButton(),
        ],
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: CalColors.bg,
      appBar: AppBar(
        backgroundColor: CalColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Travaux & Calendrier',
          style: TextStyle(fontWeight: FontWeight.w800, color: CalColors.text),
        ),
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'Interventions du verger',
            style: TextStyle(
              fontSize: 21,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: CalColors.text,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 196,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0x99FFFFFF),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: CalColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: CalColors.text,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _parcelKey,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CalColors.text,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: _kAll,
                        child: Text(
                          'Toutes les parcelles',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final p in _parcels)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(p.label, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null || v == _parcelKey) return;
                      setState(() => _parcelKey = v);
                      _load();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chips() {
    final items = <(String, ActivityStatus?)>[
      ('Toutes', null),
      ('À faire', ActivityStatus.aFaire),
      ('En cours', ActivityStatus.enCours),
      ('Terminées', ActivityStatus.terminee),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (label, status) in items)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _chip('$label (${_count(status)})', _filter == status, () {
                setState(() => _filter = status);
              }),
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? CalColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? CalColors.primary : CalColors.border,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : CalColors.text,
          ),
        ),
      ),
    );
  }

  List<Widget> _body() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: CircularProgressIndicator(color: CalColors.primary),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Text(_error!, style: const TextStyle(color: CalColors.muted)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      ];
    }
    final list = _visible;
    if (list.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'Aucune intervention pour ce filtre.',
              style: TextStyle(color: CalColors.muted, fontSize: 15),
            ),
          ),
        ),
      ];
    }
    return [
      for (final a in list)
        TaskCard(
          key: ValueKey(a.id),
          activity: a,
          onDetails: () => _openDetails(a),
          onComplete: () => _complete(a),
        ),
    ];
  }

  Widget _newButton() {
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        onPressed: _openNew,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text(
          '+ Nouvelle tâche / Rappel',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: CalColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}
