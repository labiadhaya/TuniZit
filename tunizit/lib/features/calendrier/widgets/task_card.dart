import 'package:flutter/material.dart';

import 'calendrier_theme.dart';
import 'calendrier_utils.dart';
import '../models/activity.dart';

IconData categoryIcon(String category) {
  switch (category) {
    case 'labour':
      return Icons.agriculture;
    case 'traitement':
      return Icons.science_outlined;
    case 'taille':
      return Icons.content_cut;
    case 'irrigation':
      return Icons.water_drop_outlined;
    case 'fertilisation':
      return Icons.grass;
    case 'surveillance':
      return Icons.bug_report_outlined;
    case 'recolte':
      return Icons.shopping_basket_outlined;
    case 'equipement':
      return Icons.inventory_2_outlined;
    default:
      return Icons.task_alt_outlined;
  }
}

/// Badge arrondi (priorité / statut).
class CalBadge extends StatelessWidget {
  const CalBadge(this.text, this.bg, this.fg, {super.key});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }
}

CalBadge priorityBadge(ActivityPriority p) {
  switch (p) {
    case ActivityPriority.haute:
      return CalBadge(
        'PRIORITÉ ${p.label.toUpperCase()}',
        CalColors.prioHauteBg,
        CalColors.prioHauteFg,
      );
    case ActivityPriority.moyenne:
      return CalBadge(
        'PRIORITÉ ${p.label.toUpperCase()}',
        CalColors.prioMoyenneBg,
        CalColors.prioMoyenneFg,
      );
    case ActivityPriority.basse:
      return CalBadge(
        'PRIORITÉ ${p.label.toUpperCase()}',
        CalColors.prioBasseBg,
        CalColors.prioBasseFg,
      );
  }
}

CalBadge statusBadge(Activity a) {
  if (a.status == ActivityStatus.terminee) {
    return const CalBadge(
      'Terminé ✓',
      CalColors.doneBadgeBg,
      CalColors.doneBadgeFg,
    );
  }
  if (a.status == ActivityStatus.enCours) {
    return CalBadge(
      'En cours (${a.progress}%)',
      CalColors.doingBadgeBg,
      CalColors.doingBadgeFg,
    );
  }
  return const CalBadge(
    'À faire',
    CalColors.todoBadgeBg,
    CalColors.todoBadgeFg,
  );
}

/// Carte d'une intervention. 3 variantes selon le statut :
/// à faire (échéance + Détails) / en cours (barre + Compléter) / terminée (barrée).
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.activity,
    required this.onDetails,
    required this.onComplete,
  });

  final Activity activity;
  final VoidCallback onDetails;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final done = a.status == ActivityStatus.terminee;
    final doing = a.status == ActivityStatus.enCours;
    final iconBg = done
        ? CalColors.doneIconBg
        : doing
        ? CalColors.doingIconBg
        : CalColors.todoIconBg;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDetails,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CalColors.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    done
                        ? Icons.check_circle_outline
                        : categoryIcon(a.category),
                    color: CalColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (!done) priorityBadge(a.priority),
                          statusBadge(a),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.title,
                        style: TextStyle(
                          fontSize: 19,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: CalColors.text,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: CalColors.text,
                        ),
                      ),
                      if (a.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          a.subtitle,
                          style: const TextStyle(
                            fontSize: 15,
                            color: CalColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (doing) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: a.progress / 100,
                  minHeight: 10,
                  backgroundColor: CalColors.progressTrack,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    CalColors.progress,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _strip(),
          ],
        ),
      ),
    );
  }

  Widget _strip() {
    final a = activity;
    final IconData icon;
    final InlineSpan span;
    String? actionLabel;
    IconData? actionIcon;
    VoidCallback? action;

    if (a.status == ActivityStatus.terminee) {
      icon = Icons.verified_outlined;
      final when = a.completedAt != null ? frDay(a.completedAt!) : '—';
      span = TextSpan(
        text: 'Exécuté le $when${a.validated ? ' • Validé' : ''}',
      );
    } else if (a.status == ActivityStatus.enCours) {
      icon = Icons.hourglass_bottom;
      span = TextSpan(text: 'Avancement : ${a.progress}%');
      actionLabel = 'Compléter';
      actionIcon = Icons.check;
      action = onComplete;
    } else {
      icon = Icons.event_outlined;
      span = TextSpan(
        children: [
          const TextSpan(text: 'Échéance : '),
          TextSpan(
            text: a.dueDate != null
                ? 'Avant le ${frDay(a.dueDate!)}'
                : 'Non définie',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: CalColors.text,
            ),
          ),
        ],
      );
      actionLabel = 'Détails';
      actionIcon = Icons.arrow_forward;
      action = onDetails;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CalColors.stripBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: CalColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              span,
              style: const TextStyle(fontSize: 14.5, color: CalColors.muted),
            ),
          ),
          if (actionLabel != null && action != null)
            InkWell(
              onTap: action,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: CalColors.text,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(actionIcon, size: 18, color: CalColors.text),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
