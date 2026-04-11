import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stats_chart.dart';

class QcmStatsView extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Color color;

  const QcmStatsView({super.key, required this.userData, required this.color});

  @override
  Widget build(BuildContext context) {
    // --- CORRECTION COULEURS ---
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color subTextColor = isDark ? Colors.white70 : Colors.grey;

    int totalQuestions = userData['stats_qcm_total'] ?? 0;
    int correctAnswers = userData['stats_qcm_correct'] ?? 0;
    double successRate = totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0;

    Map<String, dynamic> rawHistory = userData['stats_history_qcm_correct'] ?? {};
    Map<String, dynamic> totalHistory = userData['stats_history_qcm'] ?? {};
    Map<String, dynamic> chartHistory = {};
    rawHistory.forEach((key, value) {
      int total = totalHistory[key] ?? 0;
      if (total > 0) chartHistory[key] = (value / total) * 100;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: _buildSummaryCard("Questions", "$totalQuestions", Icons.quiz, cardColor, color, subTextColor)),
          const SizedBox(width: 15),
          Expanded(child: _buildSummaryCard("Réussite", "${(successRate * 100).toStringAsFixed(0)}%", Icons.pie_chart, cardColor, color, subTextColor)),
        ]),
        const SizedBox(height: 20),
        Text("Taux de réussite (7 jours)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 10),

        chartHistory.isEmpty
            ? Container(height: 200, decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)), alignment: Alignment.center, child: Text("Pas assez de données.", style: TextStyle(color: subTextColor)))
            : StatsChart(history: chartHistory, color: color, fixedMaxY: 100, isSafeBelow: false),

        const SizedBox(height: 20),
        Text("Détail par jour", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 10),
        _buildHistoryList(rawHistory, totalHistory, color, cardColor, textColor, subTextColor, isDark),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color cardColor, Color iconColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
      child: Column(children: [
        Icon(icon, color: iconColor, size: 30),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: iconColor)),
        Text(label, style: TextStyle(color: subTextColor, fontSize: 12)),
      ]),
    );
  }

  Widget _buildHistoryList(Map correctHistory, Map totalHistory, Color color, Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    if (correctHistory.isEmpty) return const SizedBox();
    var sortedKeys = correctHistory.keys.toList()..sort((a, b) => b.compareTo(a));
    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
      child: Column(children: List.generate(sortedKeys.length > 7 ? 7 : sortedKeys.length, (index) {
        String key = sortedKeys[index];
        DateTime day = DateTime.parse(key);
        String dateLabel = DateFormat('dd/MM').format(day);
        int correct = correctHistory[key] ?? 0;
        int total = totalHistory[key] ?? 0;
        double rate = total > 0 ? correct / total : 0.0;
        return Column(children: [
          ListTile(
            title: Text(dateLabel, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            subtitle: Text("$correct / $total", style: TextStyle(color: subTextColor)),
            trailing: Text("${(rate * 100).toStringAsFixed(0)}%", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          if (index < (sortedKeys.length > 7 ? 6 : sortedKeys.length - 1)) Divider(height: 1, indent: 20, endIndent: 20, color: isDark ? Colors.white10 : Colors.grey[200]),
        ]);
      })),
    );
  }
}