import '../models/activity.dart';

/// Contrat entre l'écran et les données.
/// L'écran ne connaît que ça : Mock maintenant, HttpActivityService après.
abstract class ActivityService {
  /// Si [parcelId] est donné : tâches de cette parcelle + tâches sans parcelle
  /// (ex: "Hangar central").
  Future<List<Activity>> list({String? parcelId});

  Future<Activity> create(Activity draft);

  Future<Activity> updateStatus(
    String id,
    ActivityStatus status, {
    int? progress,
  });

  /// null = pas de phase connue -> la carte n'est pas affichée.
  Future<PhenologyInfo?> phenology();

  Future<List<Option>> exploitations();

  /// Toutes les parcelles de l'utilisateur (Option.parentId = exploitation).
  Future<List<Option>> parcels();
}

class _ParcelRow {
  const _ParcelRow(
    this.id,
    this.name,
    this.variety,
    this.trees,
    this.exploitationId,
  );
  final String id;
  final String name;
  final String variety;
  final int trees;
  final String exploitationId;
}

/// Données en mémoire = les 3 cartes de la capture. Aucun backend requis.
class MockActivityService implements ActivityService {
  static const _exploitations = [Option(id: 'e1', label: 'Exploitation 1')];

  static const _parcelRows = [
    _ParcelRow('p1', 'Parcelle 1', 'Chemlali', 340, 'e1'),
    _ParcelRow('p2', 'Parcelle 2', 'Chétoui', 210, 'e1'),
  ];

  final List<Activity> _items = [
    Activity(
      id: 'a1',
      title: 'Labour superficiel pour casser la croûte',
      category: 'labour',
      priority: ActivityPriority.haute,
      status: ActivityStatus.aFaire,
      parcelId: 'p1',
      exploitationId: 'e1',
      parcelName: 'Parcelle 1',
      parcelVariety: 'Chemlali',
      treesCount: 340,
      dueDate: DateTime(2026, 10, 30),
    ),
    Activity(
      id: 'a2',
      title: 'Révision des filets et caisses ajourées',
      category: 'equipement',
      priority: ActivityPriority.moyenne,
      status: ActivityStatus.enCours,
      locationLabel: 'Hangar central',
      description: 'Équipements de battage',
      progress: 65,
    ),
    Activity(
      id: 'a3',
      title: 'Traitement préventif automnal à la bouillie bordelaise',
      category: 'traitement',
      priority: ActivityPriority.moyenne,
      status: ActivityStatus.terminee,
      locationLabel: 'Protection préventive',
      description: 'Œil de paon',
      progress: 100,
      completedAt: DateTime(2026, 10, 12),
      validated: true,
    ),
  ];

  int _seq = 100;

  Future<T> _delay<T>(T value) =>
      Future.delayed(const Duration(milliseconds: 250), () => value);

  @override
  Future<List<Activity>> list({String? parcelId}) {
    final res =
        _items
            .where(
              (a) =>
                  parcelId == null ||
                  a.parcelId == null ||
                  a.parcelId == parcelId,
            )
            .toList()
          ..sort((x, y) {
            final byStatus = x.status.index.compareTo(y.status.index);
            if (byStatus != 0) return byStatus;
            final dx = x.dueDate ?? DateTime(2100);
            final dy = y.dueDate ?? DateTime(2100);
            return dx.compareTo(dy);
          });
    return _delay(res);
  }

  @override
  Future<Activity> create(Activity d) {
    _ParcelRow? row;
    for (final r in _parcelRows) {
      if (r.id == d.parcelId) row = r;
    }
    final done = d.status == ActivityStatus.terminee;
    final created = Activity(
      id: 'a${_seq++}',
      title: d.title,
      category: d.category,
      priority: d.priority,
      status: d.status,
      description: d.description,
      locationLabel: d.locationLabel,
      parcelId: d.parcelId,
      exploitationId: d.exploitationId,
      parcelName: row?.name,
      parcelVariety: row?.variety,
      treesCount: row?.trees,
      progress: done ? 100 : d.progress,
      dueDate: d.dueDate,
      reminderAt: d.reminderAt,
      completedAt: done ? DateTime.now() : null,
      validated: done,
    );
    _items.add(created);
    return _delay(created);
  }

  @override
  Future<Activity> updateStatus(
    String id,
    ActivityStatus status, {
    int? progress,
  }) {
    final i = _items.indexWhere((a) => a.id == id);
    if (i < 0) return Future.error(Exception('Introuvable'));
    final old = _items[i];
    final done = status == ActivityStatus.terminee;
    final updated = Activity(
      id: old.id,
      title: old.title,
      category: old.category,
      priority: old.priority,
      status: status,
      description: old.description,
      locationLabel: old.locationLabel,
      parcelId: old.parcelId,
      exploitationId: old.exploitationId,
      parcelName: old.parcelName,
      parcelVariety: old.parcelVariety,
      treesCount: old.treesCount,
      progress: done
          ? 100
          : (progress ?? (status == ActivityStatus.aFaire ? 0 : old.progress)),
      dueDate: old.dueDate,
      reminderAt: old.reminderAt,
      completedAt: done ? DateTime.now() : null,
      validated: done,
    );
    _items[i] = updated;
    return _delay(updated);
  }

  @override
  Future<PhenologyInfo?> phenology() => _delay(
    const PhenologyInfo(
      saison: 'Automne',
      phase: 'Pré-récolte & Véraison',
      conseil:
          "Optimisez l'accumulation lipidique. Nettoyez les inter-rangs "
          'pour préparer le déploiement fluide des filets de récolte.',
    ),
  );

  @override
  Future<List<Option>> exploitations() => _delay(_exploitations);

  @override
  Future<List<Option>> parcels() => _delay([
    for (final r in _parcelRows)
      Option(
        id: r.id,
        label: '${r.name} - ${r.variety}',
        parentId: r.exploitationId,
      ),
  ]);
}
