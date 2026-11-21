import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:tunizit/features/recommendation/data/form_options.dart';
import 'package:tunizit/features/recommendation/models/variety_result.dart';
import 'package:tunizit/features/recommendation/widgets/score_gauge.dart';

void main() {
  test('labelFor renvoie le libellé français', () {
    expect(labelFor(solOpts, 'sableux'), 'Sableux');
    expect(labelFor(solOpts, null), 'Non précisé');
    expect(labelFor(solOpts, 'inconnu'), 'inconnu');
  });

  test('RecommendationResponse lit la réponse de l\'API', () {
    final r = RecommendationResponse.fromJson({
      'request_id': 'abc',
      'resultats': [
        {
          'id': 'chemlali',
          'variete': 'Chemlali',
          'photo_url': null,
          'score': 98,
          'raisons': ['Adaptee au sol sableux'],
          'limites': ['Sensible au gel'],
          'verified': false,
        },
      ],
      'valeurs_par_defaut': [],
      'message': null,
      'avertissement': 'Recommandation indicative.',
    });
    expect(r.requestId, 'abc');
    expect(r.resultats.length, 1);
    expect(r.resultats.first.nom, 'Chemlali');
    expect(r.resultats.first.score, 98);
    expect(r.resultats.first.verified, false);
  });

  test('ScoreGauge choisit la couleur selon le score', () {
    expect(ScoreGauge.colorFor(95), isNot(ScoreGauge.colorFor(50)));
    expect(ScoreGauge.colorFor(80), ScoreGauge.colorFor(100));
  });

  testWidgets('ScoreGauge affiche le score', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ScoreGauge(score: 98))),
      ),
    );
    expect(find.text('98'), findsOneWidget);
  });
}