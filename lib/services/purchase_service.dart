import 'dart:io';
import 'package:flutter/foundation.dart'; // Pour debugPrint
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PurchaseService {
  // --- CONFIGURATION ---
  // Vous obtiendrez ces clés sur le site de RevenueCat plus tard
  static const _apiKeyAndroid = 'goog_votre_cle_publique_ici';
  static const _apiKeyIOS = 'appl_votre_cle_publique_ici';

  static Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_apiKeyAndroid);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(_apiKeyIOS);
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

  // --- ACHETER UN PRODUIT ---
  static Future<bool> purchaseProduct(String productIdentifier) async {
    try {
      // 1. On lance l'achat (L'écran Google/Apple s'ouvre)
      // Note : Pour l'instant, comme on n'a pas configuré les produits, on simule.
      // Une fois configuré, on utilisera : await Purchases.purchaseProduct(productIdentifier);

      // --- SIMULATION (Correction Code Mort) ---
      await Future.delayed(const Duration(seconds: 2)); // Faux délai

      // On considère que ça marche toujours pour le test actuel
      await _giveReward(productIdentifier);
      return true;
      // -----------------------------------------

    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("Erreur achat: $e");
      }
      return false;
    }
  }

  // --- DISTRIBUTION DES RÉCOMPENSES ---
  static Future<void> _giveReward(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    if (productId.contains('20_credits')) {
      await userRef.update({'credits': FieldValue.increment(20)});
    } else if (productId.contains('50_credits')) {
      await userRef.update({'credits': FieldValue.increment(50)});
    } else if (productId.contains('100_credits')) {
      await userRef.update({'credits': FieldValue.increment(100)});
    } else if (productId.contains('premium')) {
      await userRef.update({'isPremium': true, 'credits': 9999});
    } else if (productId.contains('trainer')) {
      await userRef.update({'role': 'trainer', 'isPremium': true});
    }
  }
}