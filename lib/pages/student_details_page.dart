import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StudentDetailsPage extends StatelessWidget {
  final String studentUid;
  final String studentName;

  const StudentDetailsPage(
      {super.key, required this.studentUid, required this.studentName});

  @override
  Widget build(BuildContext context) {
    // --- COULEURS ADAPTATIVES ---
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9);
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white; // Gris demandé
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color subTextColor = isDark ? Colors.white54 : Colors.grey;
    // ----------------------------

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(studentUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return Center(child: Text("Utilisateur introuvable.", style: TextStyle(color: textColor)));
            }

            var data = snapshot.data!.data() as Map<String, dynamic>;

            // --- RÉCUPÉRATION DES DONNÉES ---
            int examTotal = data['stats_exam_total'] ?? 0;
            int examSuccess = data['stats_exam_success'] ?? 0;
            double examRate = examTotal > 0 ? (examSuccess / examTotal) : 0.0;

            int qcmTotal = data['stats_qcm_total'] ?? 0;
            int qcmCorrect = data['stats_qcm_correct'] ?? 0;
            double qcmRate = qcmTotal > 0 ? (qcmCorrect / qcmTotal) : 0.0;

            // Récupération des cartes apprises (si dispo) ou total général
            int ankiTotal = data['stats_anki_total_reviews'] ?? (data['stats_anki_total'] ?? 0);
            int score = data['score_total'] ?? 0;

            // Historique d'activité
            Map<String, dynamic> history = data['stats_history'] ?? {};

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. CARTE RÉSUMÉ (Points, Cartes, Examens)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: cardColor, // Couleur dynamique
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
                        ],
                        border: isDark ? Border.all(color: Colors.white10) : null
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(Icons.stars, Colors.amber, "$score", "Points", textColor, subTextColor),
                        _buildStatItem(Icons.psychology, Colors.purple, "$ankiTotal", "Cartes", textColor, subTextColor),
                        _buildStatItem(Icons.timer, Colors.blue, "$examTotal", "Examens", textColor, subTextColor),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  Text("Activité Récente (7 Jours)",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  const SizedBox(height: 15),

                  // 2. GRAPHIQUE D'ACTIVITÉ
                  Container(
                    height: 220,
                    padding: const EdgeInsets.fromLTRB(10, 25, 20, 10),
                    decoration: BoxDecoration(
                      color: cardColor, // Couleur dynamique
                      borderRadius: BorderRadius.circular(20),
                      border: isDark ? Border.all(color: Colors.white10) : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: _buildActivityChart(history, isDark),
                  ),

                  const SizedBox(height: 25),
                  Text("Performance",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  const SizedBox(height: 15),

                  // 3. CARTES DE PERFORMANCE
                  Row(
                    children: [
                      Expanded(
                          child: _buildPerformanceCard(
                              "Examens Blancs",
                              "${(examRate * 100).toInt()}%",
                              examRate > 0.75
                                  ? Colors.green
                                  : (examRate > 0.5 ? Colors.orange : Colors.red),
                              "$examSuccess réussis sur $examTotal",
                              cardColor,
                              textColor
                          )),
                      const SizedBox(width: 15),
                      Expanded(
                          child: _buildPerformanceCard(
                              "Précision QCM",
                              "${(qcmRate * 100).toInt()}%",
                              qcmRate > 0.75
                                  ? Colors.green
                                  : (qcmRate > 0.5 ? Colors.orange : Colors.red),
                              "$qcmCorrect bonnes rép.",
                              cardColor,
                              textColor
                          )),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // BOUTON ACTION
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Fonctionnalité 'Envoyer un message' à venir")));
                    },
                    icon: const Icon(Icons.send),
                    label: const Text("ENCOURAGER L'ÉLÈVE"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                  )
                ],
              ),
            );
          }),
    );
  }

  Widget _buildStatItem(IconData icon, Color iconColor, String value, String label, Color textColor, Color subTextColor) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 30),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
        Text(label, style: TextStyle(color: subTextColor, fontSize: 12)),
      ],
    );
  }

  Widget _buildPerformanceCard(String title, String value, Color accentColor, String subtitle, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: cardColor, // Fond de la carte
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5) // Bordure colorée
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.w900, fontSize: 24)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: TextStyle(color: accentColor.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildActivityChart(Map<String, dynamic> history, bool isDark) {
    List<FlSpot> spots = [];
    DateTime today = DateTime.now();
    double maxY = 0;

    // Construction des points du graphique
    for (int i = 6; i >= 0; i--) {
      DateTime day = today.subtract(Duration(days: i));
      String key = DateFormat('yyyy-MM-dd').format(day);

      // On s'assure que la valeur est un double
      num rawValue = history[key] ?? 0;
      double value = rawValue.toDouble();

      if (value > maxY) maxY = value;
      spots.add(FlSpot((6 - i).toDouble(), value));
    }

    if (maxY == 0) maxY = 5; // Échelle minimum

    Color gridColor = isDark ? Colors.white10 : Colors.grey[300]!;
    Color labelColor = isDark ? Colors.white54 : Colors.grey;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: gridColor, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                DateTime date = today.subtract(Duration(days: 6 - value.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(DateFormat('dd').format(date),
                      style: TextStyle(color: labelColor, fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: maxY * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue[600],
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                    colors: [
                      Colors.blue[600]!.withValues(alpha: 0.3),
                      Colors.blue[600]!.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter
                )
            ),
          ),
        ],
      ),
    );
  }
}