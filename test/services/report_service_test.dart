import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:bnssa/services/report_service.dart';

void main() {
  group('ReportService.sendReport', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ReportService svc;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      svc = ReportService(firestore: fakeFirestore);
    });

    test('crée un document dans la collection reports', () async {
      await svc.sendReport(
        questionId: 'q1',
        questionText: 'Quelle est la fréquence des compressions ?',
        userId: 'uid_test',
        reason: 'La réponse correcte semble incorrecte.',
      );
      final snap = await fakeFirestore.collection('reports').get();
      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['questionId'], 'q1');
      expect(data['userId'], 'uid_test');
      expect(data['status'], 'pending');
    });

    test('accepte userId null (anonymous)', () async {
      await svc.sendReport(
        questionId: 'q2',
        questionText: 'Question test',
        userId: null,
        reason: 'Raison',
      );
      final snap = await fakeFirestore.collection('reports').get();
      expect(snap.docs.first.data()['userId'], 'anonymous');
    });
  });
}
