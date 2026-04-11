import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/page_transition.dart';
import '../pages/shop_page.dart';

class HeaderStats extends StatelessWidget {
  const HeaderStats({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          var data = snapshot.data!.data() as Map<String, dynamic>;

          // RECUPERATION DES DONNÉES
          int credits = data['credits'] ?? 0;
          int scoreTotal = data['score_total'] ?? 0;
          bool isPremium = data['isPremium'] ?? false;

          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. POINTS GAGNÉS (Score)
              _buildBadge(
                  emoji: "🏆", // <--- CHANGEMENT ICI : Trophée au lieu de l'étoile
                  color: Colors.amber,
                  text: "$scoreTotal pts",
                  onTap: () {
                    // Optionnel : Afficher un classement ou détails
                  }),

              const SizedBox(width: 12.0),

              // 2. CRÉDITS (Lien vers Boutique)
              _buildBadge(
                // Si VIP : Couronne, sinon Éclair
                  emoji: isPremium ? "👑" : "⚡",
                  color: isPremium ? Colors.purpleAccent : Colors.blueAccent,
                  text: isPremium ? "VIP" : "$credits",
                  onTap: () {
                    Navigator.push(
                        context, SlideRightRoute(page: const ShopPage()));
                  }),
            ],
          );
        });
  }

  Widget _buildBadge(
      {required String emoji,
        required Color color,
        required String text,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16.0)),

            const SizedBox(width: 6.0),

            Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: Text(text,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 13.0,
                      height: 1.0)),
            ),
          ],
        ),
      ),
    );
  }
}