import 'package:flutter/material.dart';
import '../../services/user_service.dart';

class TeamStatusCard extends StatelessWidget {
  final String? userId;

  const TeamStatusCard({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: userId == null ? null : UserService().userStream(userId!),
      builder: (context, snapshot) {
        String? teamCode;
        if (snapshot.hasData && snapshot.data!.exists) {
          teamCode = (snapshot.data!.data() as Map<String, dynamic>)['teamCode'];
        }

        if (teamCode == null) {
          return Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: const Row(children: [
              Icon(Icons.emoji_events_outlined, color: Colors.white, size: 40),
              SizedBox(width: 15),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Rejoins ta promotion !",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Rends-toi dans l'onglet Social.",
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          );
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("CLAN : $teamCode",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const Icon(Icons.shield, color: Colors.amber, size: 28),
            ]),
            const SizedBox(height: 10),
            const Text("Fais gagner ton Clan !",
                style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text("+1 Point par bonne réponse.",
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        );
      },
    );
  }
}
