import 'package:flutter/material.dart';

import 'calendrier_theme.dart';
import 'calendrier_utils.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';

/// Formulaire "Nouvelle tâche / Rappel" (champs du PDF) :
/// Titre, Catégorie, Date, Exploitation, Parcelle, Description,
/// Priorité, Rappel (date/heure), Statut.
/// Pop avec l'Activity créée.
class NewTaskSheet extends StatefulWidget {
  const NewTaskSheet({super.key, required this.service, this.defaultParcelId});
  final ActivityService service;
  final String? defaultParcelId;

  @override
  State<NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends State<NewTaskSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();

  String? _category;
  DateTime? _due;
  DateTime? _reminder;
  String? _exploitationId;
  String? _parcelId;
  ActivityPriority _priority = ActivityPriority.moyenne;
  ActivityStatus _status = ActivityStatus.aFaire;

  List<Option> _exploitations = [];
  List<Option> _parcels = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final ex = await widget.service.exploitations();
      final pa = await widget.service.parcels();
      if (!mounted) return;
      setState(() {
        _exploitations = ex;
        _parcels = pa;
        for (final p in pa) {
          if (p.id == widget.defaultParcelId) {
            _parcelId = p.id;
            _exploitationId = p.parentId;
          }
        }
      });
    } catch (_) {
      // Formulaire utilisable quand même (sans exploitation/parcelle).
    }
  }

  List<Option> get _visibleParcels => _exploitationId == null
      ? _parcels
      : _parcels.where((p) => p.parentId == _exploitationId).toList();

  InputDecoration _dec(String label, {Widget? suffix, String? errorText}) =>
      InputDecoration(
        labelText: label,
        errorText: errorText,
        suffixIcon: suffix,
        filled: true,
        fillColor: CalColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _reminder ?? _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (t == null) return;
    setState(
      () => _reminder = DateTime(d.year, d.month, d.day, t.hour, t.minute),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final done = _status == ActivityStatus.terminee;
    final desc = _desc.text.trim();
    final draft = Activity(
      id: '',
      title: _title.text.trim(),
      category: _category!,
      description: desc.isEmpty ? null : desc,
      parcelId: _parcelId,
      exploitationId: _exploitationId,
      priority: _priority,
      status: _status,
      progress: done ? 100 : 0,
      dueDate: _due,
      reminderAt: _reminder,
      completedAt: done ? DateTime.now() : null,
      validated: done,
    );
    try {
      final created = await widget.service.create(draft);
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'enregistrement, réessaie.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: CalColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nouvelle tâche / Rappel',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: CalColors.text,
                ),
              ),
              const SizedBox(height: 16),

              // Titre
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec('Titre *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Titre obligatoire'
                    : null,
              ),
              const SizedBox(height: 12),

              // Catégorie
              DropdownButtonFormField<String>(
                value: _category,
                decoration: _dec('Catégorie *'),
                items: [
                  for (final e in kActivityCategories.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Catégorie obligatoire' : null,
              ),
              const SizedBox(height: 12),

              // Date
              FormField<DateTime>(
                validator: (_) => _due == null ? 'Date obligatoire' : null,
                builder: (state) => InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await _pickDue();
                    state.didChange(_due);
                  },
                  child: InputDecorator(
                    decoration: _dec(
                      'Date *',
                      suffix: const Icon(Icons.calendar_today_outlined),
                      errorText: state.errorText,
                    ),
                    child: Text(
                      _due == null ? 'Choisir une date' : frDate(_due!),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Exploitation
              DropdownButtonFormField<String>(
                value: _exploitationId ?? '',
                decoration: _dec('Exploitation'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Aucune')),
                  for (final o in _exploitations)
                    DropdownMenuItem(value: o.id, child: Text(o.label)),
                ],
                onChanged: (v) => setState(() {
                  _exploitationId = (v == null || v.isEmpty) ? null : v;
                  // la parcelle choisie doit appartenir à l'exploitation
                  if (_parcelId != null &&
                      !_visibleParcels.any((p) => p.id == _parcelId)) {
                    _parcelId = null;
                  }
                }),
              ),
              const SizedBox(height: 12),

              // Parcelle
              DropdownButtonFormField<String>(
                value: _parcelId ?? '',
                decoration: _dec('Parcelle'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Aucune (tâche générale)'),
                  ),
                  for (final o in _visibleParcels)
                    DropdownMenuItem(value: o.id, child: Text(o.label)),
                ],
                onChanged: (v) => setState(() {
                  if (v == null || v.isEmpty) {
                    _parcelId = null;
                  } else {
                    _parcelId = v;
                    for (final p in _parcels) {
                      if (p.id == v)
                        _exploitationId = p.parentId ?? _exploitationId;
                    }
                  }
                }),
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _desc,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec('Description'),
              ),
              const SizedBox(height: 16),

              // Priorité
              const Text(
                'Priorité',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: CalColors.text,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ActivityPriority>(
                  segments: [
                    for (final p in ActivityPriority.values)
                      ButtonSegment(value: p, label: Text(p.label)),
                  ],
                  selected: {_priority},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _priority = s.first),
                ),
              ),
              const SizedBox(height: 16),

              // Rappel
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickReminder,
                child: InputDecorator(
                  decoration: _dec(
                    'Rappel (date et heure)',
                    suffix: _reminder == null
                        ? const Icon(Icons.notifications_none)
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _reminder = null),
                          ),
                  ),
                  child: Text(
                    _reminder == null ? 'Aucun rappel' : frDateTime(_reminder!),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Statut
              DropdownButtonFormField<ActivityStatus>(
                value: _status,
                decoration: _dec('Statut'),
                items: [
                  for (final s in ActivityStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) =>
                    setState(() => _status = v ?? ActivityStatus.aFaire),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: CalColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Enregistrer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
