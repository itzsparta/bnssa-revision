import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:bnssa/services/license_service.dart';

void main() {
  group('LicenseService.trainerLicensesStream', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LicenseService svc;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      svc = LicenseService(firestore: fakeFirestore);
    });

    test('émet uniquement les licences du formateur demandé', () async {
      await fakeFirestore.collection('license_codes').add({'createdBy': 'uid1', 'code': 'BNSSA-AAA001'});
      await fakeFirestore.collection('license_codes').add({'createdBy': 'uid2', 'code': 'BNSSA-BBB002'});
      final snap = await svc.trainerLicensesStream('uid1').first;
      expect(snap.docs.length, 1);
      expect((snap.docs.first.data() as Map<String, dynamic>)['code'], 'BNSSA-AAA001');
    });
  });

  group('LicenseService.redeemCode', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LicenseService svc;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      svc = LicenseService(firestore: fakeFirestore);
    });

    test('lève une exception si le code nexiste pas', () async {
      await expectLater(
        svc.redeemCode('BNSSA-XXXXXX', 'uid_user'),
        throwsA(isA<Exception>()),
      );
    });

    test('lève une exception si le code est déjà utilisé', () async {
      await fakeFirestore.collection('license_codes').doc('code1').set({
        'code': 'BNSSA-USED01',
        'used': true,
      });
      await expectLater(
        svc.redeemCode('BNSSA-USED01', 'uid_user'),
        throwsA(isA<Exception>()),
      );
    });

    test('active le code et met à jour le profil utilisateur', () async {
      await fakeFirestore.collection('license_codes').doc('code1').set({
        'code': 'BNSSA-VALID1',
        'used': false,
        'trainerUid': 'uid_trainer',
      });
      await fakeFirestore.collection('users').doc('uid_user').set({'isPremium': false});
      await svc.redeemCode('BNSSA-VALID1', 'uid_user');
      final licDoc = await fakeFirestore.collection('license_codes').doc('code1').get();
      expect(licDoc.data()!['used'], true);
      final userDoc = await fakeFirestore.collection('users').doc('uid_user').get();
      expect(userDoc.data()!['isPremium'], true);
    });
  });
}
