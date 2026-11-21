import 'package:flutter/material.dart';

import 'calendrier_theme.dart';
import 'calendrier_utils.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';
import 'task_card.dart';

/// Bottom sheet "Détails" : infos de la tâche + actions selon le statut.
/// Pop avec `true` si quelque chose a changé (l'écran recharge la liste).
class ActivityDetailsSheet extends StatefulWidget {
  const ActivityDetailsSheet({
    super.key,
    required this.activity,
    required this.service,
  });
  final Activity activity;
  final ActivityService service;

  @override
  State<ActivityDetailsSheet> createState() => _ActivityDetailsSheetState();
}

class _ActivityDetailsSheetState extends State<ActivityDetailsSheet> {
  late double _progress = widget.activity.progress.toDouble();
  bool _busy = false;

  Future<void> _apply(ActivityStatus s, {int? progress}) async {
    setState(() => _busy = true);
    try {
      await widget.service.updateStatus(
        widget.activity.id,
        s,
        progress: progress,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de la mise à jour, réessaie.')),
      );
    }
  }

  Widget _info(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: CalColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: CalColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final status = a.status;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
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
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (status != ActivityStatus.terminee)
                    priorityBadge(a.priority),
                  statusBadge(a),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                a.title,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: CalColors.text,
                ),
              ),
              const SizedBox(height: 16),
              _info('Catégorie', categoryLabel(a.category)),
              _info('Parcelle', a.parcelName == null ? null : a.subtitle),
              _info('Lieu', a.parcelName == null ? a.locationLabel : null),
              _info('Échéance', a.dueDate == null ? null : frDate(a.dueDate!)),
              _info(
                'Rappel',
                a.reminderAt == null ? null : frDateTime(a.reminderAt!),
              ),
              _info(
                'Exécutée le',
                a.completedAt == null ? null : frDate(a.completedAt!),
              ),
              _info('Description', a.description),
              const SizedBox(height: 8),
              if (status == ActivityStatus.enCours) ...[
                Text(
                  'Avancement : ${_progress.round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: CalColors.text,
                  ),
                ),
                Slider(
                  value: _progress,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_progress.round()}%',
                  activeColor: CalColors.progress,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _progress = v),
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _apply(
                          ActivityStatus.enCours,
                          progress: _progress.round(),
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: CalColors.primary,
                  ),
                  child: const Text('Enregistrer l\'avancement'),
                ),
                const SizedBox(height: 8),
              ],
              if (status == ActivityStatus.aFaire)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _apply(ActivityStatus.enCours, progress: 0),
                  style: FilledButton.styleFrom(
                    backgroundColor: CalColors.primary,
                  ),
                  child: const Text('Démarrer la tâche'),
                ),
              if (status != ActivityStatus.terminee) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _apply(ActivityStatus.terminee),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CalColors.primary,
                    side: const BorderSide(color: CalColors.primary),
                  ),
                  child: const Text('Marquer comme terminée ✓'),
                ),
              ] else
                OutlinedButton(
                  onPressed: _busy ? null : () => _apply(ActivityStatus.aFaire),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CalColors.primary,
                    side: const BorderSide(color: CalColors.primary),
                  ),
                  child: const Text('Rouvrir la tâche'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
