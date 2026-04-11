import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdService {
  RewardedAd? _rewardedAd;

  static Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  void loadAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test ID Android
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Ad failed to load: $error');
        },
      ),
    );
  }

  void showRewardedAd(BuildContext context, Function onRewardGranted) {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) async {
          // CORRECTION ULTIME : On capture le Messenger AVANT l'attente (Async Gap)
          // Comme ça, on n'utilise plus 'context' dans la zone dangereuse.
          final messenger = ScaffoldMessenger.of(context);

          await _addCredits(5); // Le temps d'attente est ici

          // On utilise la variable 'messenger' sauvegardée plus haut
          messenger.showSnackBar(
              const SnackBar(content: Text("+5 Crédits ajoutés !")));
          onRewardGranted();
          loadAd();
        },
      );
      _rewardedAd = null;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Publicité non disponible, réessayez plus tard.")));
      loadAd();
    }
  }

  Future<void> _addCredits(int amount) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'credits': FieldValue.increment(amount)});
    }
  }

  static Future<bool> spendCredits(int amount, BuildContext context) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    DocumentReference userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    return await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return false;

      int current = (snapshot.data() as Map<String, dynamic>)['credits'] ?? 0;
      if (current >= amount) {
        transaction.update(userRef, {'credits': FieldValue.increment(-amount)});
        return true;
      } else {
        return false;
      }
    });
  }
}
