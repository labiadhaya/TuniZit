import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunizit/features/calendrier/models/activity.dart';
import 'package:tunizit/features/calendrier/screens/calendrier_screen.dart';
import 'package:tunizit/features/calendrier/services/activity_service.dart';

void main() {
  test('mock service creates activities and updates their status', () async {
    final service = MockActivityService();
    final created = await service.create(
      Activity(
        id: '',
        title: 'Tailler les oliviers',
        category: 'taille',
        priority: ActivityPriority.moyenne,
        status: ActivityStatus.aFaire,
      ),
    );
    expect(created.title, 'Tailler les oliviers');
    expect(created.status, ActivityStatus.aFaire);

    final updated = await service.updateStatus(
      created.id,
      ActivityStatus.enCours,
      progress: 35,
    );
    expect(updated.status, ActivityStatus.enCours);
    expect(updated.progress, 35);
  });

  testWidgets('calendar filters activities by status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CalendrierScreen(service: MockActivityService())),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Labour superficiel pour casser la croûte'),
      findsOneWidget,
    );
    await tester.tap(find.text('Terminées (1)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Traitement préventif automnal à la bouillie bordelaise'),
      findsOneWidget,
    );
    expect(find.text('Labour superficiel pour casser la croûte'), findsNothing);
  });

  testWidgets('new task sheet displays the activity form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CalendrierScreen(service: MockActivityService())),
    );
    await tester.pumpAndSettle();

    final addButton = find.text('+ Nouvelle tâche / Rappel');
    await tester.scrollUntilVisible(
      addButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Catégorie *'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
  });
}
