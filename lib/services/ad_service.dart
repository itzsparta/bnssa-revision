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
          final messenger = ScaffoldMessenger.of(context);
          final user = FirebaseAuth.instance.currentUser;
          
          if (user != null) {
            // Utilisation d'un service externe (passé en param ou via ref)
            // Ici on va tricher un peu en utilisant Firebase directement si on n'a pas accès à ref,
            // mais on devrait idéalement passer le CreditService.
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'credits': FieldValue.increment(5)});
          }

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

  // Les méthodes _addCredits et spendCredits ont été migrées vers CreditService.
}
