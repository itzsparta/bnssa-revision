import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bnssa/widgets/trainer_pack_card.dart';

void main() {
  group('TrainerPackCard', () {
    Widget buildCard() => const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: TrainerPackCard())),
        );

    testWidgets('affiche le prix mensuel par défaut', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('10 €'), findsOneWidget);
      expect(find.text('/ mois'), findsOneWidget);
      expect(find.text('100 €'), findsNothing);
    });

    testWidgets('toggle annuel affiche le prix annuel', (tester) async {
      await tester.pumpWidget(buildCard());
      await tester.tap(find.text('Annuel'));
      await tester.pump();
      expect(find.text('100 €'), findsOneWidget);
      expect(find.text('/ an'), findsOneWidget);
      expect(find.text('10 €'), findsNothing);
    });

    testWidgets('retour sur mensuel rétablit le prix mensuel', (tester) async {
      await tester.pumpWidget(buildCard());
      await tester.tap(find.text('Annuel'));
      await tester.pump();
      await tester.tap(find.text('Mensuel'));
      await tester.pump();
      expect(find.text('10 €'), findsOneWidget);
      expect(find.text('100 €'), findsNothing);
    });
  });
}
