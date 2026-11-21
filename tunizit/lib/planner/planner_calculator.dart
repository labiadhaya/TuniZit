// lib/planner/planner_calculator.dart
// Modèles du Smart Orchard Planner.
// Aucun calcul ici : le calcul est fait par le backend (règles dans Supabase).
// Le front envoie PlannerInput (toJson) et affiche PlannerResult (fromJson).

enum Zone { nord, centre, sud }

enum PlantingSystem { pluvial, irrigueClassique, superIntensif }

const Set<String> shdVarieties = {'Arbequina', 'Arbosana', 'Koroneiki'};

/// Utilisé uniquement pour remplir la liste déroulante du formulaire.
/// (La zone réelle est déterminée par le backend.)
const Map<String, Zone> governorateZone = {
  'Bizerte': Zone.nord,
  'Béja': Zone.nord,
  'Jendouba': Zone.nord,
  'Le Kef': Zone.nord,
  'Siliana': Zone.nord,
  'Zaghouan': Zone.nord,
  'Nabeul': Zone.nord,
  'Tunis': Zone.nord,
  'Ariana': Zone.nord,
  'Ben Arous': Zone.nord,
  'Manouba': Zone.nord,
  'Sousse': Zone.centre,
  'Monastir': Zone.centre,
  'Mahdia': Zone.centre,
  'Kairouan': Zone.centre,
  'Kasserine': Zone.centre,
  'Sidi Bouzid': Zone.centre,
  'Sfax': Zone.sud,
  'Gafsa': Zone.sud,
  'Gabès': Zone.sud,
  'Médenine': Zone.sud,
  'Tataouine': Zone.sud,
  'Tozeur': Zone.sud,
  'Kébili': Zone.sud,
};

class PlannerInput {
  final String governorate;
  final bool irrigated;

  /// Liste vide = « variété non déterminée ».
  final List<String> varieties;

  final bool wantSuperIntensive;
  final double? lengthM;
  final double? widthM;
  final double? surfaceHa;
  final double marginM;

  const PlannerInput({
    required this.governorate,
    required this.irrigated,
    this.varieties = const [],
    this.wantSuperIntensive = false,
    this.lengthM,
    this.widthM,
    this.surfaceHa,
    this.marginM = 2,
  });

  Map<String, dynamic> toJson() => {
    'governorate': governorate,
    'irrigated': irrigated,
    'varieties': varieties,
    'wantSuperIntensive': wantSuperIntensive,
    if (lengthM != null) 'lengthM': lengthM,
    if (widthM != null) 'widthM': widthM,
    if (surfaceHa != null) 'surfaceHa': surfaceHa,
    'marginM': marginM,
  };
}

class PlannerResult {
  final PlantingSystem system;
  final Zone zone;
  final double lengthM;
  final double widthM;
  final bool dimensionsEstimated;
  final double surfaceM2;
  final double usableAreaM2;
  final double rowSpacingM;
  final double treeSpacingM;
  final int rows;
  final int treesPerRow;
  final int totalTrees;
  final double densityPerHa;
  final List<String> warnings;

  /// Nombre de rangées affectées à chaque variété.
  final Map<String, int> varietyRows;

  /// Variété de chaque rangée, dans l'ordre du dessin ('' = aucune variété).
  final List<String> rowVarieties;

  const PlannerResult({
    required this.system,
    required this.zone,
    required this.lengthM,
    required this.widthM,
    required this.dimensionsEstimated,
    required this.surfaceM2,
    required this.usableAreaM2,
    required this.rowSpacingM,
    required this.treeSpacingM,
    required this.rows,
    required this.treesPerRow,
    required this.totalTrees,
    required this.densityPerHa,
    required this.warnings,
    required this.varietyRows,
    required this.rowVarieties,
  });

  factory PlannerResult.fromJson(Map<String, dynamic> j) => PlannerResult(
    system: PlantingSystem.values.byName(j['system'] as String),
    zone: Zone.values.byName(j['zone'] as String),
    lengthM: (j['length_m'] as num).toDouble(),
    widthM: (j['width_m'] as num).toDouble(),
    dimensionsEstimated: j['dimensions_estimated'] as bool,
    surfaceM2: (j['surface_m2'] as num).toDouble(),
    usableAreaM2: (j['usable_area_m2'] as num).toDouble(),
    rowSpacingM: (j['row_spacing_m'] as num).toDouble(),
    treeSpacingM: (j['tree_spacing_m'] as num).toDouble(),
    rows: (j['rows'] as num).toInt(),
    treesPerRow: (j['trees_per_row'] as num).toInt(),
    totalTrees: (j['total_trees'] as num).toInt(),
    densityPerHa: (j['density_per_ha'] as num).toDouble(),
    warnings: List<String>.from(j['warnings'] as List),
    varietyRows: (j['variety_rows'] as Map).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    ),
    rowVarieties: List<String>.from(j['row_varieties'] as List),
  );
}

class PlannerException implements Exception {
  final String message;
  const PlannerException(this.message);

  @override
  String toString() => message;
}
