import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:bnssa/services/theme_service.dart';

void main() {
  group('ThemeService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ThemeService svc;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      svc = ThemeService(firestore: fakeFirestore);
    });

    test('getAllThemes retourne les documents de la collection themes', () async {
      await fakeFirestore.collection('themes').doc('t1').set({'title': 'Ranimer la victime'});
      await fakeFirestore.collection('themes').doc('t2').set({'title': 'Noyade'});
      final snap = await svc.getAllThemes();
      expect(snap.docs.length, 2);
    });

    test('themesStream émet les thèmes en temps réel', () async {
      await fakeFirestore.collection('themes').doc('t1').set({'title': 'Ranimer'});
      final snap = await svc.themesStream().first;
      expect(snap.docs.length, 1);
    });

    test('getThemeQuestions retourne les questions de la sous-collection', () async {
      await fakeFirestore
          .collection('themes').doc('t1')
          .collection('questions').doc('q1')
          .set({
            'questionText': 'Que faire en cas d arrêt cardiaque ?',
            'correctAnswerIndex': 0,
            'options': ['Appeler le 15', 'Partir', 'Attendre'],
            'explanation': 'Appeler les secours',
          });
      final questions = await svc.getThemeQuestions('t1', 'Ranimer');
      expect(questions.length, 1);
      expect(questions.first.id, 'q1');
      expect(questions.first.themeName, 'Ranimer');
    });

    test('getThemeQuestions respecte le paramètre limit', () async {
      for (int i = 0; i < 10; i++) {
        await fakeFirestore
            .collection('themes').doc('t1')
            .collection('questions').doc('q$i')
            .set({
              'questionText': 'Q$i',
              'correctAnswerIndex': 0,
              'options': ['A', 'B'],
              'explanation': '',
            });
      }
      final questions = await svc.getThemeQuestions('t1', 'Ranimer', limit: 5);
      expect(questions.length, 5);
    });
  });
}
