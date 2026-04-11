import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import des vues détaillées
import 'stats_details/anki_stats_view.dart';
import 'stats_details/qcm_stats_view.dart';
import 'stats_details/exam_stats_view.dart';
import 'stats_details/speed_stats_view.dart';

class DetailedStatsPage extends StatelessWidget {
  final String title;
  final String type;
  final Color color;

  const DetailedStatsPage({
    super.key,
    required this.title,
    required this.type,
    required this.color
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Erreur auth")));

    // --- CORRECTION DU FOND ---
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    // En mode sombre, on met un fond presque noir (0xFF121212)
    // En mode clair, on garde le gris très clair (0xFFF5F7FA)
    Color backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: backgroundColor, // <--- C'est ici que l'arrière-plan est appliqué
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            var userDoc = snapshot.data!;
            if (!userDoc.exists) return const Center(child: Text("Profil introuvable"));

            var data = userDoc.data() as Map<String, dynamic>;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildChildView(data),
            );
          }
      ),
    );
  }

  Widget _buildChildView(Map<String, dynamic> data) {
    switch (type) {
      case 'anki':
        return AnkiStatsView(userData: data, color: color);
      case 'qcm':
        return QcmStatsView(userData: data, color: color);
      case 'exam':
        return ExamStatsView(userData: data, color: color);
      case 'speed':
        return SpeedStatsView(userData: data, color: color);
      default:
        return const Center(child: Text("Type inconnu"));
    }
  }
}