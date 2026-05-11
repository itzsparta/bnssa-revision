import 'package:flutter/material.dart';

import '../../services/anki_service.dart';
import '../../utils/page_transition.dart';
import '../../pages/daily_review_page.dart';

class AnkiCard extends StatelessWidget {
  final String? userId;
  final VoidCallback onResetAnki;

  const AnkiCard({super.key, required this.userId, required this.onResetAnki});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: AnkiService.getAnkiStatsStream(userId),
      builder: (context, snapshot) {
        final int due = snapshot.data?['due'] ?? 0;
        final int total = snapshot.data?['total'] ?? 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF141E30), Color(0xFF243B55)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.psychology, size: 28, color: Colors.blueAccent),
                ),
                const SizedBox(width: 15),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Mémoire à Long Terme",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("$total cartes apprises",
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ]),
              ]),
              IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.white30),
                  onPressed: onResetAnki),
            ]),
            const SizedBox(height: 15),
            due == 0
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                          SizedBox(width: 10),
                          Text("Tout est mémorisé !",
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold)),
                        ]))
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                          context, SlideRightRoute(page: const DailyReviewPage())),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text("RÉVISER $due CARTES",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )),
          ]),
        );
      },
    );
  }
}
