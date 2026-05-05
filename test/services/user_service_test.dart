// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:bnssa/services/user_service.dart';

void main() {
  group('UserService.isProfileComplete', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserService svc;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      svc = UserService(firestore: fakeFirestore);
    });

    test('retourne false si le document nexiste pas', () async {
      final result = await svc.isProfileComplete('uid_inexistant');
      expect(result, false);
    });

    test('retourne false si pseudo absent', () async {
      await fakeFirestore.collection('users').doc('uid1').set({'lastName': 'DUPONT'});
      final result = await svc.isProfileComplete('uid1');
      expect(result, false);
    });

    test('retourne false si lastName absent', () async {
      await fakeFirestore.collection('users').doc('uid2').set({'pseudo': 'jo42'});
      final result = await svc.isProfileComplete('uid2');
      expect(result, false);
    });

    test('retourne true si pseudo et lastName présents', () async {
      await fakeFirestore.collection('users').doc('uid3').set({
        'pseudo': 'jo42',
        'lastName': 'DUPONT',
      });
      final result = await svc.isProfileComplete('uid3');
      expect(result, true);
    });
  });

  group('UserService.saveUserProfile', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserService svc;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      svc = UserService(firestore: fakeFirestore);
    });

    test('écrit les champs lastName, firstName, pseudo et profile_completed', () async {
      await svc.saveUserProfile('uid1', lastName: 'DUPONT', firstName: 'Jean', pseudo: 'jd42');
      final doc = await fakeFirestore.collection('users').doc('uid1').get();
      final data = doc.data()!;
      expect(data['lastName'], 'DUPONT');
      expect(data['firstName'], 'Jean');
      expect(data['pseudo'], 'jd42');
      expect(data['profile_completed'], true);
    });

    test('merge — ne supprime pas les champs existants', () async {
      await fakeFirestore.collection('users').doc('uid2').set({'credits': 3});
      await svc.saveUserProfile('uid2', lastName: 'MARTIN', firstName: 'Paul', pseudo: 'pm99');
      final doc = await fakeFirestore.collection('users').doc('uid2').get();
      expect(doc.data()!['credits'], 3);
    });
  });

  group('UserService.updateActivity', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserService svc;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      svc = UserService(firestore: fakeFirestore);
    });

    test('crée le document avec last_connection si inexistant', () async {
      await svc.updateActivity('uid1');
      final doc = await fakeFirestore.collection('users').doc('uid1').get();
      expect(doc.exists, true);
      expect(doc.data()!.containsKey('last_connection'), true);
    });
  });

  group('UserService.checkDailyReward', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserService svc;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      svc = UserService(firestore: fakeFirestore);
    });

    test('retourne false si le document nexiste pas', () async {
      final result = await svc.checkDailyReward('uid_absent');
      expect(result, false);
    });

    test('retourne true et incrémente credits si last_daily_gift est null', () async {
      await fakeFirestore.collection('users').doc('uid1').set({'credits': 0});
      final result = await svc.checkDailyReward('uid1');
      expect(result, true);
    });

    test('retourne false si last_daily_gift est aujourd hui', () async {
      await fakeFirestore.collection('users').doc('uid2').set({
        'credits': 5,
        'last_daily_gift': DateTime.now(),
      });
      final result = await svc.checkDailyReward('uid2');
      expect(result, false);
    });
  });

  group('UserService.userStream', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserService svc;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      svc = UserService(firestore: fakeFirestore);
    });

    test('émet le document utilisateur', () async {
      await fakeFirestore.collection('users').doc('uid1').set({'pseudo': 'jo42', 'credits': 2});
      final snap = await svc.userStream('uid1').first;
      final data = snap.data() as Map<String, dynamic>;
      expect(data['pseudo'], 'jo42');
      expect(data['credits'], 2);
    });
  });

  group('UserService.hasMistakes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserService svc;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      svc = UserService(firestore: fakeFirestore);
    });

    test('retourne false si pas de mistakes', () async {
      final result = await svc.hasMistakes('uid1');
      expect(result, false);
    });

    test('retourne true si au moins une mistake existe', () async {
      await fakeFirestore
          .collection('users').doc('uid1')
          .collection('mistakes').doc('m1')
          .set({'questionId': 'q1'});
      final result = await svc.hasMistakes('uid1');
      expect(result, true);
    });
  });
}
