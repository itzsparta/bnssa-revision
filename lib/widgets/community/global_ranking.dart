import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/team_service.dart';

class GlobalRanking extends StatelessWidget {
  final String myTeamCode;
  final bool isDark;

  const GlobalRanking({
    super.key,
    required this.myTeamCode,
    required this.isDark,
  });

  Widget _buildPodiumStep(int rank, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String name = data['name'] ?? "?";
    final int score = data['score'] ?? 0;
    final double targetHeight = rank == 1 ? 180 : (rank == 2 ? 140 : 110);

    final List<Color> gradientColors;
    if (rank == 1) {
      gradientColors = [const Color(0xFFFFD700), const Color(0xFFFFA500)];
    } else if (rank == 2) {
      gradientColors = [const Color(0xFFC0C0C0), const Color(0xFF808080)];
    } else {
      gradientColors = [const Color(0xFFCD7F32), const Color(0xFFA0522D)];
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (rank == 1)
          const Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 30)),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87)),
        const SizedBox(height: 5),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: targetHeight),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.decelerate,
          builder: (context, value, child) {
            return Container(
              height: value,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors
                        .map((c) => c.withValues(alpha: 0.8))
                        .toList()),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                boxShadow: [
                  BoxShadow(
                      color: gradientColors[0].withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, -2)),
                ],
              ),
              alignment: Alignment.bottomCenter,
              child: value > 50 ? child : null,
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text("#$rank",
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 20)),
              Text("$score",
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color bgCard = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;

    return StreamBuilder(
      stream: TeamService().globalRankingStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              const Text("Erreur de chargement",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.red)),
            ]),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text("Aucun classement disponible.",
                style: TextStyle(fontStyle: FontStyle.italic)),
          );
        }

        final int myRankIndex =
            docs.indexWhere((d) => d.id == myTeamCode);

        Widget rivalryWidget = const SizedBox();
        if (myRankIndex > 0) {
          final rivalDoc = docs[myRankIndex - 1];
          final myDoc = docs[myRankIndex];
          final rivalData = rivalDoc.data() as Map<String, dynamic>;
          final myData = myDoc.data() as Map<String, dynamic>;
          final int diff =
              (rivalData['score'] ?? 0) - (myData['score'] ?? 0);

          rivalryWidget = Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFed213a), Color(0xFF93291e)]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PROCHAINE CIBLE",
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(rivalData['name'] ?? "Rival",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      Text("+$diff pts pour dépasser",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ]),
              ),
              const Icon(Icons.my_location, color: Colors.white54, size: 40),
            ]),
          );
        }

        final List<DocumentSnapshot> top3 = docs.take(3).toList();
        final List<DocumentSnapshot> rest = docs.skip(3).toList();

        return Column(children: [
          rivalryWidget,
          if (top3.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 30),
              child: SizedBox(
                height: 240,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (top3.length > 1)
                      Expanded(child: _buildPodiumStep(2, top3[1])),
                    if (top3.isNotEmpty)
                      Expanded(child: _buildPodiumStep(1, top3[0])),
                    if (top3.length > 2)
                      Expanded(child: _buildPodiumStep(3, top3[2])),
                  ],
                ),
              ),
            ),
          if (rest.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("Pas d'autres équipes pour le moment.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey, fontStyle: FontStyle.italic)),
            ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            itemCount: rest.length,
            itemBuilder: (context, index) {
              final t = rest[index].data() as Map<String, dynamic>;
              final int rank = index + 4;
              final bool isMyTeam = rest[index].id == myTeamCode;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isMyTeam
                      ? Colors.blue.withValues(alpha: 0.1)
                      : bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: isMyTeam
                      ? Border.all(color: Colors.blue, width: 1)
                      : null,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        shape: BoxShape.circle),
                    child: Text("#$rank",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                            fontSize: 14)),
                  ),
                  title: Text(t['name'] ?? "Team",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textCol)),
                  trailing: Text("${t['score'] ?? 0} pts",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black54)),
                ),
              );
            },
          ),
        ]);
      },
    );
  }
}
