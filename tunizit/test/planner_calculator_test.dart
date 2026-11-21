import 'package:flutter_test/flutter_test.dart';

import 'package:tunizit/planner/planner_calculator.dart';

void main() {
  test('PlannerInput serializes the backend request fields', () {
    const input = PlannerInput(
      governorate: 'Bizerte',
      irrigated: true,
      varieties: ['Arbequina'],
      wantSuperIntensive: true,
      lengthM: 200,
      widthM: 100,
    );

    expect(input.toJson(), {
      'governorate': 'Bizerte',
      'irrigated': true,
      'varieties': ['Arbequina'],
      'wantSuperIntensive': true,
      'lengthM': 200,
      'widthM': 100,
      'marginM': 2,
    });
  });

  test('PlannerInput omits dimensions when using surface area', () {
    const input = PlannerInput(
      governorate: 'Bizerte',
      irrigated: false,
      surfaceHa: 2,
    );

    final json = input.toJson();

    expect(json['surfaceHa'], 2);
    expect(json.containsKey('lengthM'), isFalse);
    expect(json.containsKey('widthM'), isFalse);
  });

  test('PlannerResult parses the backend response fields', () {
    final result = PlannerResult.fromJson({
      'system': 'irrigueClassique',
      'zone': 'nord',
      'length_m': 200,
      'width_m': 100,
      'dimensions_estimated': false,
      'surface_m2': 20000,
      'usable_area_m2': 190 * 96,
      'row_spacing_m': 6,
      'tree_spacing_m': 7,
      'rows': 16,
      'trees_per_row': 28,
      'total_trees': 448,
      'density_per_ha': 224,
      'variety_rows': {'Arbequina': 16},
      'row_varieties': List<String>.filled(16, 'Arbequina'),
      'warnings': ['Spacing values are provisional.'],
    });

    expect(result.system, PlantingSystem.irrigueClassique);
    expect(result.zone, Zone.nord);
    expect(result.rows, 16);
    expect(result.treesPerRow, 28);
    expect(result.totalTrees, 448);
    expect(result.varietyRows, {'Arbequina': 16});
    expect(result.rowVarieties, List<String>.filled(16, 'Arbequina'));
    expect(result.warnings, ['Spacing values are provisional.']);
  });
}
