import 'package:flutter/material.dart';
import '../../services/team_service.dart';

class MembersList extends StatelessWidget {
  final String teamCode;
  final String myUid;
  final bool isDark;

  const MembersList({
    super.key,
    required this.teamCode,
    required this.myUid,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgCard = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;

    return StreamBuilder(
      stream: TeamService().teamMembersStream(teamCode),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text("Erreur: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) =>
            ((b.data() as Map)['score_total'] ?? 0)
                .compareTo((a.data() as Map)['score_total'] ?? 0));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final m = docs[index].data() as Map<String, dynamic>;
            final String uid = docs[index].id;
            final bool isMe = uid == myUid;

            final String pseudo = m['pseudo'] ?? "";
            final String firstName = m['firstName'] ?? "";
            final String lastName = m['lastName'] ?? "";
            final String email = m['email'] ?? "Inconnu";

            final String displayName;
            if (pseudo.isNotEmpty) {
              displayName = pseudo;
            } else if (firstName.isNotEmpty && lastName.isNotEmpty) {
              displayName = "$firstName $lastName";
            } else {
              displayName = email.split('@')[0];
            }

            Widget? badge;
            if (index == 0) {
              badge = const Icon(Icons.military_tech, color: Colors.amber);
            } else if (index == 1) {
              badge = const Icon(Icons.shield, color: Colors.blueGrey);
            } else if (index == 2) {
              badge = const Icon(Icons.star, color: Colors.orangeAccent);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF3b82f6).withValues(alpha: 0.1)
                    : bgCard,
                borderRadius: BorderRadius.circular(15),
                border:
                    isMe ? Border.all(color: Colors.blue, width: 1.5) : null,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isDark ? Colors.grey[800] : Colors.grey[200],
                  child: Text("${index + 1}",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600])),
                ),
                title: Row(children: [
                  Expanded(
                    child: Text(displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight:
                                isMe ? FontWeight.w900 : FontWeight.w600,
                            color: textCol)),
                  ),
                  if (badge != null) ...[const SizedBox(width: 8), badge],
                ]),
                trailing: Text("${m['score_total'] ?? 0} pts",
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.grey[600])),
              ),
            );
          },
        );
      },
    );
  }
}
