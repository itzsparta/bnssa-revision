import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnkiStatsView extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Color color;

  const AnkiStatsView({super.key, required this.userData, required this.color});

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    int totalReviews = userData['stats_anki_total_reviews'] ?? 0;

    // Récupération des données
    Map<String, dynamic> h0 = (userData['stats_history_anki_0'] as Map?)?.cast<String, dynamic>() ?? {};
    Map<String, dynamic> h1 = (userData['stats_history_anki_1'] as Map?)?.cast<String, dynamic>() ?? {};
    Map<String, dynamic> h2 = (userData['stats_history_anki_2'] as Map?)?.cast<String, dynamic>() ?? {};
    Map<String, dynamic> h3 = (userData['stats_history_anki_3'] as Map?)?.cast<String, dynamic>() ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader("Révisions Totales", "$totalReviews", cardColor, color, isDark),

        const SizedBox(height: 25),
        Text("Qualité Mémoire (7 derniers jours)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 15),

        // --- GRAPHIQUE MAISON EMPILÉ ---
        Container(
          height: 220,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(15),
            // CORRECTION 1 : withValues au lieu de withOpacity
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: _buildManualStackedChart(h0, h1, h2, h3, isDark),
        ),

        // Légende
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _legendItem("Oubli", Colors.red, isDark),
            _legendItem("Dur", Colors.orange, isDark),
            _legendItem("Bon", Colors.blue, isDark),
            _legendItem("Facile", Colors.green, isDark),
          ],
        ),

        const SizedBox(height: 25),
        Text("Détail par jour", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 10),
        _buildHistoryList(h0, h1, h2, h3, cardColor, textColor, isDark),
      ],
    );
  }

  Widget _buildManualStackedChart(Map h0, Map h1, Map h2, Map h3, bool isDark) {
    DateTime today = DateTime.now();
    List<Map<String, dynamic>> dailyData = [];
    double maxTotal = 0;

    for (int i = 6; i >= 0; i--) {
      DateTime day = today.subtract(Duration(days: i));
      String key = DateFormat('yyyy-MM-dd').format(day);

      double v0 = _safeDouble(h0[key]);
      double v1 = _safeDouble(h1[key]);
      double v2 = _safeDouble(h2[key]);
      double v3 = _safeDouble(h3[key]);

      double total = v0 + v1 + v2 + v3;
      // CORRECTION 2 : Accolades ajoutées
      if (total > maxTotal) {
        maxTotal = total;
      }

      dailyData.add({
        'day': DateFormat('dd/MM').format(day),
        'total': total,
        'v0': v0, 'v1': v1, 'v2': v2, 'v3': v3
      });
    }

    // CORRECTION 2 : Accolades ajoutées
    if (maxTotal == 0) {
      maxTotal = 5;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: dailyData.map((data) {
        double total = data['total'];
        double heightPercentage = total / maxTotal;
        double barHeight = heightPercentage * 140;

        // CORRECTION 2 : Accolades ajoutées
        if (barHeight == 0) {
          barHeight = 4;
        }

        int f0 = (data['v0'] as double).toInt();
        int f1 = (data['v1'] as double).toInt();
        int f2 = (data['v2'] as double).toInt();
        int f3 = (data['v3'] as double).toInt();

        bool isEmpty = total == 0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 18,
                height: barHeight,
                // CORRECTION 1 : withValues
                color: isEmpty ? Colors.grey.withValues(alpha: 0.1) : null,
                child: isEmpty
                    ? null
                    : Column(
                  children: [
                    if (f3 > 0) Expanded(flex: f3, child: Container(color: Colors.green)),
                    if (f2 > 0) Expanded(flex: f2, child: Container(color: Colors.blue)),
                    if (f1 > 0) Expanded(flex: f1, child: Container(color: Colors.orange)),
                    if (f0 > 0) Expanded(flex: f0, child: Container(color: Colors.red)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data['day'],
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.grey,
                  fontWeight: FontWeight.bold
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildHistoryList(Map h0, Map h1, Map h2, Map h3, Color bgColor, Color textColor, bool isDark) {
    Set<String> allKeys = {};
    allKeys.addAll(h0.keys.cast<String>());
    allKeys.addAll(h1.keys.cast<String>());
    allKeys.addAll(h2.keys.cast<String>());
    allKeys.addAll(h3.keys.cast<String>());

    if (allKeys.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
        child: Center(child: Text("Aucune révision pour le moment.", style: TextStyle(color: textColor))),
      );
    }

    var sortedKeys = allKeys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: sortedKeys.map((key) {
          DateTime day = DateTime.parse(key);
          String dateLabel = DateFormat('dd/MM').format(day);

          DateTime now = DateTime.now();

          // CORRECTION 2 : Accolades ajoutées pour les if/else
          if (day.year == now.year && day.month == now.month && day.day == now.day) {
            dateLabel = "Aujourd'hui";
          } else if (day.year == now.year && day.month == now.month && day.day == now.day - 1) {
            dateLabel = "Hier";
          }

          int v0 = _safeDouble(h0[key]).toInt();
          int v1 = _safeDouble(h1[key]).toInt();
          int v2 = _safeDouble(h2[key]).toInt();
          int v3 = _safeDouble(h3[key]).toInt();
          int total = v0 + v1 + v2 + v3;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  children: [
                    SizedBox(width: 90, child: Text(dateLabel, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13))),

                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            children: [
                              if(v0>0) Expanded(flex: v0, child: Container(color: Colors.red)),
                              if(v1>0) Expanded(flex: v1, child: Container(color: Colors.orange)),
                              if(v2>0) Expanded(flex: v2, child: Container(color: Colors.blue)),
                              if(v3>0) Expanded(flex: v3, child: Container(color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text("$total", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _legendItem(String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
      ],
    );
  }

  Widget _buildHeader(String label, String value, Color bgColor, Color iconColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            // CORRECTION 1 : withValues
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.psychology, color: iconColor, size: 40),
          ),
          const SizedBox(width: 20),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: iconColor)),
            Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
          ])
        ],
      ),
    );
  }
}