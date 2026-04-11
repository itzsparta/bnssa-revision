import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StatsChart extends StatelessWidget {
  final Map<String, dynamic> history;
  final Color color;
  final double? fixedMaxY;
  final double? limitY;
  final String? limitLabel;
  final bool isSafeBelow;

  const StatsChart({
    super.key,
    required this.history,
    required this.color,
    this.fixedMaxY,
    this.limitY,
    this.limitLabel,
    this.isSafeBelow = true,
  });

  @override
  Widget build(BuildContext context) {
    // --- CORRECTIF MODE SOMBRE ---
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color axisColor = isDark ? Colors.white54 : Colors.grey[700]!;
    Color gridColor = isDark ? Colors.white10 : Colors.grey[200]!;
    // -----------------------------

    List<FlSpot> spots = [];
    DateTime today = DateTime.now();
    double currentMax = 0;
    List<String> xLabels = [];

    // 1. Transformation des données
    for (int i = 6; i >= 0; i--) {
      DateTime day = today.subtract(Duration(days: i));
      String key = DateFormat('yyyy-MM-dd').format(day);
      double value = (history[key] ?? 0).toDouble();

      if (value > currentMax) currentMax = value;
      spots.add(FlSpot((6 - i).toDouble(), value));
      xLabels.add(DateFormat('dd/MM').format(day));
    }

    // 2. Calcul de l'échelle Y
    double targetY;
    double interval;

    if (fixedMaxY != null) {
      targetY = fixedMaxY!;
      interval = targetY / 4;
    } else {
      if (currentMax < 5) currentMax = 5;

      // On n'agrandit l'échelle pour la limite que si elle est "raisonnablement" proche
      // Sinon on garde l'échelle de l'utilisateur pour voir ses progrès
      double maxToUse = currentMax;
      if (limitY != null && limitY! > currentMax && limitY! < currentMax * 1.5) {
        maxToUse = limitY!;
      }

      // Arrondi au multiple de 5 supérieur
      targetY = (maxToUse * 1.2 / 5).ceil() * 5.0;
      interval = targetY / 5;
    }

    // 3. Calcul des Zones de Couleur (Fix Bug Visuel)
    List<HorizontalRangeAnnotation> annotations = [];
    if (limitY != null) {
      double safeY1 = isSafeBelow ? 0 : limitY!;
      double safeY2 = isSafeBelow ? limitY! : 99999;
      double dangerY1 = isSafeBelow ? limitY! : 0;
      double dangerY2 = isSafeBelow ? 99999 : limitY!;

      // IMPORTANT : On coupe (.clamp) la zone verte si elle dépasse le haut du graphique
      // Cela évite qu'elle "écrase" tout visuellement quand l'échelle est petite (ex: 1.2s)
      if (safeY1 < targetY) {
        annotations.add(HorizontalRangeAnnotation(
          y1: safeY1,
          y2: safeY2 > targetY ? targetY : safeY2, // On coupe ici
          color: Colors.green.withValues(alpha: isDark ? 0.15 : 0.1),
        ));
      }

      if (dangerY1 < targetY) {
        annotations.add(HorizontalRangeAnnotation(
          y1: dangerY1,
          y2: dangerY2 > targetY ? targetY : dangerY2, // On coupe ici
          color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.1),
        ));
      }
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: BoxDecoration(
        color: bgColor, // Utilisation de la couleur dynamique
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(color: gridColor, strokeWidth: 1)
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < xLabels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(xLabels[index], style: TextStyle(fontSize: 10, color: axisColor)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: interval > 0 ? interval : 1,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value > targetY) return const SizedBox();
                  if (value == 0) return const SizedBox();
                  return Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(fontSize: 10, color: axisColor, fontWeight: FontWeight.bold)
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0, maxX: 6,
          minY: 0, maxY: targetY,

          rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: annotations),

          // Ligne rouge (Seulement si visible dans l'échelle actuelle)
          extraLinesData: (limitY != null && limitY! <= targetY) ? ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: limitY!,
                color: Colors.redAccent,
                strokeWidth: 2,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 5, bottom: 5),
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10),
                  labelResolver: (line) => limitLabel ?? "Limite",
                ),
              ),
            ],
          ) : null,

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