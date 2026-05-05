import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/stats_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../exam_result_details_page.dart';
import 'exam_score_chart.dart';

class ExamStatsView extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Color color;

  const ExamStatsView({super.key, required this.userData, required this.color});

  @override
  Widget build(BuildContext context) {
    // --- GESTION DES COULEURS (CORRECTIF) ---
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color subTextColor = isDark ? Colors.white70 : Colors.grey;
    // ----------------------------------------

    final user = FirebaseAuth.instance.currentUser;
    int total = userData['stats_exam_total'] ?? 0;
    int success = userData['stats_exam_success'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryCard(total, success, cardColor, textColor, subTextColor),
        const SizedBox(height: 25),

        if (user != null)
          StreamBuilder(
            stream: StatsService.examHistoryStream(user.uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
                  child: Center(child: Text("Aucun examen passé pour le moment.", style: TextStyle(color: subTextColor))),
                );
              }

              List<int> scores = docs.map((d) => (d.data() as Map<String, dynamic>)['score'] as int).toList().reversed.toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Progression des Notes & Moyenne", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 10),

                  // Le graphique gère maintenant son propre mode sombre
                  ExamScoreChart(scores: scores, color: color),

                  const SizedBox(height: 25),
                  Text("Vos Copies (Appuyez pour voir le détail)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 10),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length > 10 ? 10 : docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      return _buildExamItem(context, data, cardColor, textColor, subTextColor, isDark);
                    },
                  )
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildExamItem(BuildContext context, Map<String, dynamic> data, Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    int score = data['score'] ?? 0;
    int totalQuestions = data['total'] ?? 40;
    bool passed = data['passed'] ?? false;
    Timestamp? ts = data['date'];
    String dateStr = ts != null ? DateFormat('dd/MM à HH:mm').format(ts.toDate()) : "--/--";
    bool hasDetails = (data['details'] != null && (data['details'] as List).isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor, // Fond dynamique
        borderRadius: BorderRadius.circular(12),
        // Bordure légère en mode sombre pour délimiter
        border: isDark ? Border.all(color: Colors.white10) : Border.all(
          color: passed ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        onTap: hasDetails
            ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExamResultDetailsPage(examData: data)))
            : null,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: passed ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(passed ? Icons.emoji_events : Icons.close, color: passed ? Colors.green : Colors.red),
        ),
        title: Text(passed ? "Admis" : "Ajourné", style: TextStyle(fontWeight: FontWeight.bold, color: passed ? Colors.green[800] ?? Colors.green : Colors.red[800] ?? Colors.red)),
        subtitle: Text(dateStr, style: TextStyle(color: subTextColor)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$score/$totalQuestions", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor)),
            const SizedBox(width: 10),
            if (hasDetails) Icon(Icons.arrow_forward_ios, size: 14, color: subTextColor)
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int total, int success, Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)), // Fond dynamique
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("Examens", "$total", null, textColor, subTextColor),
          Container(width: 1, height: 40, color: subTextColor.withValues(alpha: 0.2)),
          _statItem("Réussis", "$success", Colors.green, textColor, subTextColor),
          Container(width: 1, height: 40, color: subTextColor.withValues(alpha: 0.2)),
          _statItem("Échecs", "${total - success}", Colors.red, textColor, subTextColor),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color? color, Color textColor, Color subTextColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color ?? textColor)),
        Text(label, style: TextStyle(fontSize: 12, color: subTextColor)),
      ],
    );
  }
}