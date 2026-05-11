import 'package:flutter/material.dart';

import 'countdown_timer.dart';

class TeamHeader extends StatelessWidget {
  final Map<String, dynamic> data;
  final String teamCode;
  final VoidCallback onLeave;

  const TeamHeader({
    super.key,
    required this.data,
    required this.teamCode,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['name']?.toUpperCase() ?? "CLAN",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4)),
                child: Text("CODE: $teamCode",
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ),
            ]),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber, width: 2)),
              child:
                  const Icon(Icons.shield, color: Colors.amber, size: 30),
            ),
          ]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [
                Icon(Icons.timer_outlined, color: Colors.blueAccent, size: 16),
                SizedBox(width: 5),
                CountdownTimer(),
              ]),
              IconButton(
                onPressed: onLeave,
                icon: const Icon(Icons.exit_to_app,
                    size: 18, color: Colors.redAccent),
                tooltip: "Quitter le clan",
                style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
