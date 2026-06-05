import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProgressionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- LISTE DES QUÊTES (MISE À JOUR) ---
  static final List<Map<String, dynamic>> quests = [
    // --- QUÊTES UNIQUES ---
    {
      'id': 'first_quiz',
      'title': 'Première Plongée',
      'desc': 'Termine ton premier Quiz.',
      'xp': 50,
      'icon': Icons.pool
    },
    {
      'id': 'profile_pic',
      'title': 'Carte d\'Identité',
      'desc': 'Définis ta date d\'examen.',
      'xp': 20,
      'icon': Icons.calendar_today
    },

    // --- QUÊTES QUOTIDIENNES (AJOUTÉES) ---
    {
      'id': 'daily_qcm',
      'title': 'Entraînement Quotidien',
      'desc': 'Faire 1 série de QCM.',
      'xp': 30,
      'icon': Icons.quiz
    },
    {
      'id': 'daily_anki',
      'title': 'Gymnastique Cérébrale',
      'desc': 'Réviser 10 cartes Anki.',
      'xp': 50,
      'icon': Icons.psychology
    },
    {
      'id': 'daily_stats',
      'title': 'Analyse',
      'desc': 'Consulter ses statistiques.',
      'xp': 20,
      'icon': Icons.bar_chart
    },

    // --- QUÊTES HEBDOMADAIRES (AJOUTÉES) ---
    {
      'id': 'weekly_exam',
      'title': 'Test Grandeur Nature',
      'desc': 'Réussir 1 Examen Blanc.',
      'xp': 200,
      'icon': Icons.timer
    },
    {
      'id': 'weekly_streak',
      'title': 'Régularité',
      'desc': 'Série de 3 jours consécutifs.',
      'xp': 100,
      'icon': Icons.local_fire_department
    },
  ];

  // --- CALCUL DU NIVEAU ---
  static int getLevel(int xp) {
    return (xp / 200).floor() + 1;
  }

  static double getLevelProgress(int xp) {
    int currentLevelXp = (getLevel(xp) - 1) * 200;
    int nextLevelXp = getLevel(xp) * 200;
    return (xp - currentLevelXp) / (nextLevelXp - currentLevelXp);
  }

  static String getTitle(int level) {
    if (level >= 30) return "Instructeur BNSSA 👑";
    if (level >= 20) return "Chef de Poste 🔱";
    if (level >= 10) return "Sauveteur Qualifié 🛟";
    if (level >= 5) return "Nageur Confirmé 🏊";
    return "Apprenti Sauveteur 🥥";
  }

  // --- VALIDER UNE QUÊTE ---
  static Future<void> completeQuest(BuildContext context, String questId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentReference userRef = _db.collection('users').doc(user.uid);

    // 1. On cherche la quête dans notre liste locale pour avoir ses infos (XP, Titre)
    var quest = quests.firstWhere((q) => q['id'] == questId, orElse: () => {});
    if (quest.isEmpty) {
      return;
    }

    // 2. On vérifie si elle est déjà faite dans Firebase
    DocumentSnapshot doc = await userRef.get();
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    List<dynamic> completed = data['completed_quests'] ?? [];

    if (completed.contains(questId)) return; // Déjà fait, on arrête.

    // 3. On valide et on donne l'XP
    int xpGain = quest['xp'];

    await userRef.update({
      'completed_quests': FieldValue.arrayUnion([questId]),
      'xp': FieldValue.increment(xpGain),
      'score_total': FieldValue.increment(xpGain),
    });

    // 4. Notification visuelle
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(child: Text("Objectif validé : ${quest['title']} (+$xpGain XP) !")),
          ],
        ),
        backgroundColor: Colors.indigo,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
    }
  }
}