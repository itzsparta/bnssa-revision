import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ExamScoreChart extends StatelessWidget {
  final List<int> scores;
  final Color color;

  const ExamScoreChart({super.key, required this.scores, required this.color});

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) return const SizedBox();

    // --- COULEURS DYNAMIQUES ---
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color axisColor = isDark ? Colors.white54 : Colors.grey;
    Color gridColor = isDark ? Colors.white10 : Colors.grey[200]!;
    // ---------------------------

    double average = scores.reduce((a, b) => a + b) / scores.length;

    List<FlSpot> spots = [];
    for (int i = 0; i < scores.length; i++) {
      spots.add(FlSpot(i.toDouble(), scores[i].toDouble()));
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(10, 25, 20, 10),
      decoration: BoxDecoration(
        color: bgColor, // Fond dynamique
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: gridColor, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 10,
                getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: axisColor)
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0, maxX: (scores.length - 1).toDouble(),
          minY: 0, maxY: 40,

          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: average,
                color: Colors.blueAccent,
                strokeWidth: 2,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    labelResolver: (line) => "Moy: ${average.toStringAsFixed(1)}",
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 10)
                ),
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
            ),
          ],
        ),
      ),
    );
  }
}