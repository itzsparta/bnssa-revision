import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'secrets.dart';
import 'notification_service.dart';

class PurchaseService {

  static Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(Secrets.revenueCatAndroid);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(Secrets.revenueCatIOS);
    } else {
      return;
    }

    await Purchases.configure(configuration);
  }

  // Lier l'achat à l'utilisateur Firebase actuel
  static Future<void> login() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await Purchases.logIn(user.uid);
    }
  }

  // --- LES PRODUITS DISPONIBLES ---
  static Future<List<Package>> fetchOffers() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      }
    } catch (e) {
      debugPrint("Erreur récupération produits: $e");
    }
    return [];
  }

  static String generateRandomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    final code = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
    return 'BNSSA-$code';
  }

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // ignore: unused_element
  static Future<void> _generateTrainerLicense(String trainerUid) async {
    final codeRef = FirebaseFirestore.instance.collection('license_codes').doc();
    await codeRef.set({
      'code': generateRandomCode(),
      'createdBy': trainerUid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': null,
      'isUsed': false,
      'type': 'pack_reussite',
    });
  }

  // ignore: unused_element
  static Future<void> _activateTrainerSubscription(
    String uid, {
    required String type,
    required int licenseCount,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.update(firestore.collection('users').doc(uid), {
      'role': 'trainer',
      'isPremium': true,
      'trainerSubscriptionType': type,
      'trainerLastLicensePeriod': _currentMonthKey(),
    });
    for (int i = 0; i < licenseCount; i++) {
      final codeRef = firestore.collection('license_codes').doc();
      batch.set(codeRef, {
        'code': generateRandomCode(),
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': null,
        'isUsed': false,
        'type': 'pack_reussite',
      });
    }
    await batch.commit();
  }

  // ignore: unused_element
  static Future<void> _revokeTrainer(
    String uid, {
    required bool revokeStudents,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.update(firestore.collection('users').doc(uid), {
      'role': FieldValue.delete(),
      'isPremium': false,
      'trainerSubscriptionType': FieldValue.delete(),
      'trainerLastLicensePeriod': FieldValue.delete(),
    });
    if (revokeStudents) {
      final students = await firestore
          .collection('users')
          .where('premiumGrantedBy', isEqualTo: uid)
          .get();
      for (final student in students.docs) {
        batch.update(student.reference, {'isPremium': false});
      }
    }
    await batch.commit();
  }

  static Future<void> checkTrainerSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userSnap.data();
    if (data == null || data['role'] != 'trainer') return;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final active = customerInfo.entitlements.active['trainer'];

      if (active != null) {
        if (data['trainerSubscriptionType'] == 'monthly') {
          final currentPeriod = _currentMonthKey();
          final lastPeriod = data['trainerLastLicensePeriod'] as String?;
          if (currentPeriod != lastPeriod) {
            await _generateTrainerLicense(user.uid);
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'trainerLastLicensePeriod': currentPeriod});
            await NotificationService.showLocalNotification(
              'Nouvelle licence disponible',
              'Votre licence élève du mois a été ajoutée à votre espace Formateur.',
            );
          }
        }
      } else {
        final allEntitlements = customerInfo.entitlements.all['trainer'];
        final wasCancelled = allEntitlements?.unsubscribeDetectedAt != null;
        await _revokeTrainer(user.uid, revokeStudents: wasCancelled);
      }
    } catch (e) {
      debugPrint('checkTrainerSubscription error: $e');
    }
  }

  // --- ACHETER UN PRODUIT ---
  static Future<bool> purchaseProduct(String productIdentifier) async {
    try {
      final offerings = await Purchases.getOfferings();

      Package? target;
      for (final offering in offerings.all.values) {
        for (final package in offering.availablePackages) {
          if (package.storeProduct.identifier == productIdentifier) {
            target = package;
            break;
          }
        }
        if (target != null) break;
      }

      if (target == null) {
        debugPrint("Produit introuvable dans les offres RevenueCat : $productIdentifier");
        return false;
      }

      await Purchases.purchase(PurchaseParams.package(target));
      return true;

    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("Erreur achat: $e");
      }
      return false;
    }
  }
}