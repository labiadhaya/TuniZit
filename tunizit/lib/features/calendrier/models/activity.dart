import '../widgets/calendrier_utils.dart';

enum ActivityStatus {
  aFaire('a_faire', 'À faire'),
  enCours('en_cours', 'En cours'),
  terminee('terminee', 'Terminée');

  const ActivityStatus(this.api, this.label);
  final String api;
  final String label;

  static ActivityStatus fromApi(String? v) =>
      values.firstWhere((e) => e.api == v, orElse: () => ActivityStatus.aFaire);
}

enum ActivityPriority {
  basse('basse', 'Basse'),
  moyenne('moyenne', 'Moyenne'),
  haute('haute', 'Élevée');

  const ActivityPriority(this.api, this.label);
  final String api;
  final String label;

  static ActivityPriority fromApi(String? v) => values.firstWhere(
    (e) => e.api == v,
    orElse: () => ActivityPriority.moyenne,
  );
}

/// Catégories (clé stockée en base -> libellé affiché).
/// Les exemples viennent du PDF : taille, irrigation, fertilisation,
/// surveillance des maladies, récolte (+ labour, traitement, équipement
/// qui apparaissent dans la capture).
const Map<String, String> kActivityCategories = {
  'labour': 'Labour',
  'traitement': 'Traitement',
  'taille': 'Taille',
  'irrigation': 'Irrigation',
  'fertilisation': 'Fertilisation',
  'surveillance': 'Surveillance des maladies',
  'recolte': 'Récolte',
  'equipement': 'Équipement',
};

String categoryLabel(String key) => kActivityCategories[key] ?? key;

/// Élément simple pour les dropdowns (exploitation / parcelle).
class Option {
  const Option({required this.id, required this.label, this.parentId});
  final String id;
  final String label;

  /// Pour une parcelle : l'id de son exploitation.
  final String? parentId;
}

/// Bloc "Cycle phénologique" en haut de l'écran.
class PhenologyInfo {
  const PhenologyInfo({
    required this.saison,
    required this.phase,
    required this.conseil,
  });
  final String saison;
  final String phase;
  final String conseil;

  factory PhenologyInfo.fromJson(Map<String, dynamic> j) => PhenologyInfo(
    saison: j['saison'] as String? ?? '',
    phase: j['phase'] as String? ?? '',
    conseil: j['conseil'] as String? ?? '',
  );
}

class Activity {
  const Activity({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    this.description,
    this.locationLabel,
    this.parcelId,
    this.exploitationId,
    this.parcelName,
    this.parcelVariety,
    this.treesCount,
    this.progress = 0,
    this.dueDate,
    this.reminderAt,
    this.completedAt,
    this.validated = false,
  });

  final String id;
  final String title;
  final String category;
  final ActivityPriority priority;
  final ActivityStatus status;
  final String? description;
  final String? locationLabel; // ex: "Hangar central" (tâche sans parcelle)
  final String? parcelId;
  final String? exploitationId;
  final String? parcelName; // ex: "Parcelle 1"
  final String? parcelVariety; // ex: "Chemlali"
  final int? treesCount; // ex: 340
  final int progress; // 0..100
  final DateTime? dueDate;
  final DateTime? reminderAt;
  final DateTime? completedAt;
  final bool validated;

  /// Ligne grise sous le titre :
  /// "Parcelle 1 • Chemlali (340 oliviers)" ou "Hangar central • Équipements…"
  String get subtitle {
    if (parcelName != null) {
      final variety = parcelVariety != null ? ' • $parcelVariety' : '';
      final trees = treesCount != null ? ' ($treesCount oliviers)' : '';
      return '$parcelName$variety$trees';
    }
    return [
      locationLabel,
      description,
    ].where((s) => s != null && s.trim().isNotEmpty).join(' • ');
  }

  Activity copyWith({
    ActivityStatus? status,
    int? progress,
    DateTime? completedAt,
    bool? validated,
  }) => Activity(
    id: id,
    title: title,
    category: category,
    priority: priority,
    status: status ?? this.status,
    description: description,
    locationLabel: locationLabel,
    parcelId: parcelId,
    exploitationId: exploitationId,
    parcelName: parcelName,
    parcelVariety: parcelVariety,
    treesCount: treesCount,
    progress: progress ?? this.progress,
    dueDate: dueDate,
    reminderAt: reminderAt,
    completedAt: completedAt ?? this.completedAt,
    validated: validated ?? this.validated,
  );

  factory Activity.fromJson(Map<String, dynamic> j) {
    final p = j['parcels'] as Map<String, dynamic>?; // jointure Supabase
    return Activity(
      id: j['id'].toString(),
      title: j['title'] as String? ?? '',
      category: j['category'] as String? ?? '',
      description: j['description'] as String?,
      locationLabel: j['location_label'] as String?,
      parcelId: j['parcel_id']?.toString(),
      exploitationId: j['exploitation_id']?.toString(),
      parcelName: p?['name'] as String?,
      parcelVariety: p?['variety'] as String?,
      treesCount: (p?['trees_count'] as num?)?.toInt(),
      priority: ActivityPriority.fromApi(j['priority'] as String?),
      status: ActivityStatus.fromApi(j['status'] as String?),
      progress: (j['progress'] as num?)?.toInt() ?? 0,
      dueDate: _date(j['due_date']),
      reminderAt: _date(j['reminder_at']),
      completedAt: _date(j['completed_at']),
      validated: j['validated'] == true,
    );
  }

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  /// Corps du POST /api/activities
  Map<String, dynamic> toCreateJson() => {
    'title': title,
    'category': category,
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
    if (parcelId != null) 'parcel_id': parcelId,
    if (exploitationId != null) 'exploitation_id': exploitationId,
    'priority': priority.api,
    'status': status.api,
    'progress': progress,
    if (dueDate != null) 'due_date': ymd(dueDate!),
    if (reminderAt != null)
      'reminder_at': reminderAt!.toUtc().toIso8601String(),
  };
}
