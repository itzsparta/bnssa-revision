import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stats_chart.dart';

class SpeedStatsView extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Color color;

  const SpeedStatsView({super.key, required this.userData, required this.color});

  @override
  Widget build(BuildContext context) {
    // --- GESTION DES COULEURS ---
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // On force les couleurs pour éviter le mélange noir/blanc
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color titleColor = isDark ? Colors.white : Colors.black87;
    Color subTextColor = isDark ? Colors.white70 : Colors.grey[700]!;

    // 1. Données globales
    var speedData = userData['stats_speed'];
    int totalMs = 0;
    int count = 0;
    if (speedData is Map<String, dynamic>) {
      totalMs = speedData['total_ms'] ?? 0;
      count = speedData['count'] ?? 0;
    }
    double avgSeconds = count > 0 ? (totalMs / count) / 1000 : 0.0;
    String avgStr = avgSeconds.toStringAsFixed(1);

    // 2. Historique
    Map<String, dynamic> rawHistory = userData['stats_history_speed'] ?? {};
    Map<String, dynamic> chartHistory = {};

    rawHistory.forEach((key, value) {
      if (value is int) {
        chartHistory[key] = (value / 1000);
      }
    });

    // 3. Limite BNSSA
    const double limitBnssa = 67.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // EN-TÊTE
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.speed, color: color, size: 40),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(avgStr, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 4),
                        child: Text("secondes", style: TextStyle(fontWeight: FontWeight.bold, color: subTextColor)),
                      ),
                    ],
                  ),
                  Text("Moyenne sur $count questions", style: TextStyle(color: subTextColor, fontSize: 12)),
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 20),

        // TITRE DU GRAPHIQUE
        Text("Évolution (7 derniers jours)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor)),
        const SizedBox(height: 5),
        const Text(
          "Zone verte : Rythme suffisant pour finir en 45 min.",
          style: TextStyle(fontSize: 12, color: Colors.green, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 10),

        // GRAPHIQUE
        chartHistory.isEmpty
            ? Container(
          height: 200,
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
          alignment: Alignment.center,
          child: Text("Répondez à des questions pour voir la courbe.", style: TextStyle(color: subTextColor)),
        )
            : StatsChart(
          history: chartHistory,
          color: color,
          limitY: limitBnssa,
          limitLabel: "Max (45min)",
          isSafeBelow: true,
        ),

        const SizedBox(height: 20),
        Text("Détail par jour", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor)),
        const SizedBox(height: 10),

        // LISTE HISTORIQUE
        _buildHistoryList(rawHistory, color, cardColor, titleColor, subTextColor, isDark),
      ],
    );
  }

  Widget _buildHistoryList(Map<String, dynamic> history, Color color, Color cardColor, Color titleColor, Color subColor, bool isDark) {
    if (history.isEmpty) {
      return const SizedBox();
    }

    var sortedKeys = history.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: List.generate(sortedKeys.length > 7 ? 7 : sortedKeys.length, (index) {
          String key = sortedKeys[index];
          DateTime day = DateTime.parse(key);
          String dateLabel = DateFormat('dd/MM/yyyy').format(day);

          DateTime now = DateTime.now();
          if (day.year == now.year && day.month == now.month && day.day == now.day) {
            dateLabel = "Aujourd'hui";
          } else if (day.year == now.year && day.month == now.month && day.day == now.day - 1) {
            dateLabel = "Hier";
          }

          int ms = history[key] ?? 0;
          double seconds = ms / 1000;
          String secondsStr = seconds.toStringAsFixed(1);

          Color perfColor = Colors.green;
          // CORRECTION ICI : Ajout des accolades pour satisfaire le linter
          if (seconds > 67.5) {
            perfColor = Colors.red;
          } else if (seconds > 45) {
            perfColor = Colors.orange;
          }

          return Column(
            children: [
              ListTile(
                leading: Icon(Icons.calendar_today, size: 16, color: color),
                title: Text(dateLabel, style: TextStyle(color: titleColor)),
                trailing: Text("$secondsStr s", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: perfColor)),
              ),
              if (index < (sortedKeys.length > 7 ? 6 : sortedKeys.length - 1))
                Divider(height: 1, indent: 20, endIndent: 20, color: isDark ? Colors.white10 : Colors.grey[200]),
            ],
          );
        }),
      ),
    );
  }
}