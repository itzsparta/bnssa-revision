import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/team_service.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with AutomaticKeepAliveClientMixin {
  final TeamService _teamService = TeamService();
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _codeController = TextEditingController();

  int _viewMode = 1;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _joinTeam() async {
    if (_codeController.text.isEmpty) return;

    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
        int currentScore = (userDoc.data() as Map<String, dynamic>)['score_total'] ?? 0;

        if (currentScore > 0) {
          if (!mounted) return;
          bool confirm = await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(children: [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 10), Text("Attention")]),
                content: const Text("Pour des raisons d'équité, rejoindre un nouveau clan réinitialisera uniquement vos **POINTS DE CLASSEMENT** à 0.\n\nVos crédits et votre progression personnelle (Anki, Thèmes) ne seront pas impactés.\n\nVoulez-vous continuer ?"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("J'accepte")
                  ),
                ],
              )
          ) ?? false;

          if (!confirm) return;
        }
      } catch (e) {
        // Ignorer erreur
      }
    }

    setState(() => _isLoading = true);
    try {
      bool success = await _teamService
          .joinTeam(_codeController.text.trim().toUpperCase());

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Bienvenue dans l'équipe !"),
            backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Code introuvable."), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erreur: $e")));
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _createTeam() async {
    if (_codeController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      String code = await _teamService.createTeam(_codeController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Clan créé ! Code: $code"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erreur: $e")));
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _leaveTeam() async {
    bool confirm = await showDialog(
        context: context,
        builder: (c) => AlertDialog(
            title: const Text("Quitter le clan ?"),
            content:
            const Text("Vous ne participerez plus au classement de cette équipe."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text("Annuler")),
              TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text("QUITTER",
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold)))
            ])) ??
        false;

    if (confirm) {
      await _teamService.leaveTeam();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (user == null) {
      return const Center(child: Text("Connectez-vous"));
    }

    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgCard = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
        String? teamCode = userData['teamCode'];

        // --- ÉCRAN : PAS DE CLAN ---
        if (teamCode == null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10))
                          ]),
                      child: const Column(children: [
                        Icon(Icons.shield, size: 60, color: Colors.white),
                        SizedBox(height: 15),
                        Text("Rejoins la bataille !",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        SizedBox(height: 10),
                        Text("Seul on va plus vite,\nEnsemble on va plus loin.",
                            textAlign: TextAlign.center,
                            style:
                            TextStyle(color: Colors.white70, fontSize: 14))
                      ])),
                  const SizedBox(height: 40),
                  TextField(
                      controller: _codeController,
                      style: TextStyle(color: textCol),
                      decoration: InputDecoration(
                          hintText: "Code du Clan (ex: MNS24)",
                          prefixIcon:
                          const Icon(Icons.vpn_key, color: Colors.blue),
                          filled: true,
                          fillColor:
                          isDark ? Colors.grey[900] : Colors.grey[200],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none))),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: _joinTeam,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15))),
                      child: _isLoading
                          ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white))
                          : const Text("REJOINDRE UN CLAN",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 15),
                  TextButton(
                      onPressed: _createTeam,
                      child: const Text("Ou créer mon propre clan",
                          style:
                          TextStyle(decoration: TextDecoration.underline)))
                ]),
          );
        }

        // --- ÉCRAN : MON CLAN ---
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('teams')
              .doc(teamCode)
              .snapshots(),
          builder: (context, teamSnap) {
            if (teamSnap.hasError) {
              return const Center(child: Text("Erreur d'accès au clan.", textAlign: TextAlign.center));
            }
            if (!teamSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!teamSnap.data!.exists) {
              _teamService.leaveTeam();
              return const SizedBox();
            }
            var myTeamData = teamSnap.data!.data() as Map<String, dynamic>;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(children: [
                _buildMyTeamHeader(myTeamData, teamCode, isDark),
                Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: isDark ? Colors.black45 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Expanded(
                          child: _buildTabButton(
                              "Classement",
                              1,
                              _viewMode == 1,
                              isDark,
                                  () => setState(() => _viewMode = 1))),
                      Expanded(
                          child: _buildTabButton("Membres", 0, _viewMode == 0,
                              isDark, () => setState(() => _viewMode = 0))),
                    ]),
                  ),
                ),
                _viewMode == 1
                    ? _buildGlobalRanking(teamCode, isDark, bgCard, textCol)
                    : _buildMembersList(
                    teamCode, user!.uid, isDark, bgCard, textCol),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _buildTabButton(String text, int index, bool isSelected, bool isDark,
      VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF3b82f6) : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isSelected && !isDark
                    ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4)
                ]
                    : null),
            child: Center(
                child: Text(text,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.grey,
                        fontSize: 13)))));
  }

  Widget _buildMyTeamHeader(
      Map<String, dynamic> data, String code, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF141E30), Color(0xFF243B55)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
          borderRadius:
          const BorderRadius.vertical(bottom: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ]),
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
                  child: Text("CODE: $code",
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)))
            ]),
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 2)),
                child: const Icon(Icons.shield, color: Colors.amber, size: 30))
          ]),
          const SizedBox(height: 20),

          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [
                  Icon(Icons.timer_outlined,
                      color: Colors.blueAccent, size: 16),
                  SizedBox(width: 5),
                  // UTILISATION DU WIDGET ISOLÉ AVEC CONST
                  _CountdownTimer(),
                ]),

                IconButton(
                  onPressed: _leaveTeam,
                  icon: const Icon(Icons.exit_to_app, size: 18, color: Colors.redAccent),
                  tooltip: "Quitter le clan",
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(8)
                  ),
                )
              ]
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalRanking(String myTeamCode, bool isDark, Color bgCard, Color textCol) {
    return StreamBuilder<QuerySnapshot>(
      // 1. LA REQUÊTE OPTIMISÉE
        stream: FirebaseFirestore.instance
            .collection('teams')
            .orderBy('score', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {

          // 2. GESTION DES ERREURS (Important pour voir le problème)
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 10),
                  const Text("Erreur de chargement", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  // Ceci affichera le lien pour créer l'index si nécessaire
                  Text(snapshot.error.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.red)),
                ],
              ),
            );
          }

          // 3. CHARGEMENT
          if (!snapshot.hasData) {
            return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
          }

          var docs = snapshot.data!.docs;

          // Si aucune équipe n'a de score (liste vide)
          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Text("Aucun classement disponible.", style: TextStyle(fontStyle: FontStyle.italic)),
            );
          }

          // 4. LOGIQUE D'AFFICHAGE
          // On cherche si JE suis dans le Top 20 pour afficher le rival
          int myRankIndex = docs.indexWhere((d) => d.id == myTeamCode);

          Widget rivalryWidget = const SizedBox();
          // Le rival ne s'affiche que si je suis dans le Top 20 et pas premier
          if (myRankIndex > 0) {
            var rivalDoc = docs[myRankIndex - 1];
            var myDoc = docs[myRankIndex];
            var rivalData = rivalDoc.data() as Map<String, dynamic>;
            var myData = myDoc.data() as Map<String, dynamic>;
            int diff = (rivalData['score'] ?? 0) - (myData['score'] ?? 0);

            rivalryWidget = Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFed213a), Color(0xFF93291e)]),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Row(
                children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("PROCHAINE CIBLE", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(rivalData['name'] ?? "Rival", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text("+$diff pts pour dépasser", style: const TextStyle(color: Colors.white, fontSize: 12))
                      ])),
                  const Icon(Icons.my_location, color: Colors.white54, size: 40)
                ],
              ),
            );
          }

          List<DocumentSnapshot> top3 = docs.take(3).toList();
          List<DocumentSnapshot> rest = docs.skip(3).toList();

          return Column(
            children: [
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
                        if (top3.length > 1) Expanded(child: _buildPodiumStep(2, top3[1], isDark)),
                        if (top3.isNotEmpty) Expanded(child: _buildPodiumStep(1, top3[0], isDark)),
                        if (top3.length > 2) Expanded(child: _buildPodiumStep(3, top3[2], isDark)),
                      ],
                    ),
                  ),
                ),
              // ... (Le début de votre fonction avec rivalryWidget et podium reste pareil) ...

              // AJOUT : Petit message si pas d'autres équipes
              if (rest.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("Pas d'autres équipes pour le moment.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)
                  ),
                ),

              // LISTE DES AUTRES (Rangs 4 à 20)
              ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), // Marge en bas
                  itemCount: rest.length,
                  itemBuilder: (context, index) {
                    var t = rest[index].data() as Map<String, dynamic>;
                    int rank = index + 4; // On commence au rang 4
                    bool isMyTeam = rest[index].id == myTeamCode;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                          color: isMyTeam ? Colors.blue.withValues(alpha: 0.1) : bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: isMyTeam ? Border.all(color: Colors.blue, width: 1) : null,
                          // AJOUT DE L'OMBRE (IMPORTANT pour la visibilité)
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2)
                            )
                          ]
                      ),
                      child: ListTile(
                        leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.grey[200],
                                shape: BoxShape.circle
                            ),
                            child: Text("#$rank", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 14))
                        ),
                        title: Text(t['name'] ?? "Team", style: TextStyle(fontWeight: FontWeight.bold, color: textCol)),
                        trailing: Text("${t['score'] ?? 0} pts", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                      ),
                    );
                  })
            ],
          );
        });
  }

  Widget _buildPodiumStep(int rank, DocumentSnapshot doc, bool isDark) {
    var data = doc.data() as Map<String, dynamic>;
    String name = data['name'] ?? "?";
    int score = data['score'] ?? 0;

    double targetHeight = rank == 1 ? 180 : (rank == 2 ? 140 : 110);

    List<Color> gradientColors;
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
              child:
              Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 30)),
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
                        offset: const Offset(0, -2))
                  ]),
              alignment: Alignment.bottomCenter,
              child: value > 50 ? child : null,
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("#$rank",
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 20)),
                Text("$score",
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersList(
      String teamCode, String myUid, bool isDark, Color bgCard, Color textCol) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('teamCode', isEqualTo: teamCode)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data!.docs;

          // Tri par score décroissant
          docs.sort((a, b) => ((b.data() as Map)['score_total'] ?? 0)
              .compareTo((a.data() as Map)['score_total'] ?? 0));

          return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var m = docs[index].data() as Map<String, dynamic>;
                String uid = docs[index].id;
                bool isMe = uid == myUid;

                // --- LOGIQUE MODIFIÉE : PRIORITÉ AU PSEUDO ---
                String firstName = m['firstName'] ?? "";
                String lastName = m['lastName'] ?? "";
                String pseudo = m['pseudo'] ?? "";
                String email = m['email'] ?? "Inconnu";

                String displayName;

                // 1. Si le Pseudo existe, on l'affiche AVANT tout le reste
                if (pseudo.isNotEmpty) {
                  displayName = pseudo;
                }
                // 2. Sinon, on essaie Nom + Prénom
                else if (firstName.isNotEmpty && lastName.isNotEmpty) {
                  displayName = "$firstName $lastName";
                }
                // 3. Sinon, on se rabat sur l'email
                else {
                  displayName = email.split('@')[0];
                }
                // -------------------------------------------

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
                      border: isMe
                          ? Border.all(color: Colors.blue, width: 1.5)
                          : null,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2))
                      ]),
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor:
                        isDark ? Colors.grey[800] : Colors.grey[200],
                        child: Text("${index + 1}",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600]))),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight:
                                  isMe ? FontWeight.w900 : FontWeight.w600,
                                  color: textCol)),
                        ),
                        if (badge != null) ...[const SizedBox(width: 8), badge],
                      ],
                    ),
                    trailing: Text("${m['score_total'] ?? 0} pts",
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.grey[600])),
                  ),
                );
              });
        });
  }
}

class _CountdownTimer extends StatefulWidget {
  const _CountdownTimer();

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Timer _timer;
  String _timeUntilReset = "--:--:--";

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    DateTime now = DateTime.now();

    // Calcul pour trouver le prochain Lundi à minuit
    // Si on est Lundi (1), on ajoute 7 jours. Si Dimanche (7), on ajoute 1 jour.
    int daysUntilMonday = 8 - now.weekday;

    DateTime nextReset = DateTime(now.year, now.month, now.day)
        .add(Duration(days: daysUntilMonday)); // On tombe à 00:00:00

    Duration diff = nextReset.difference(now);

    // Formatage propre avec des zéros (ex: 04h 05m)
    String days = diff.inDays.toString();
    String hours = (diff.inHours % 24).toString().padLeft(2, '0');
    String minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');

    if (mounted) {
      setState(() => _timeUntilReset = "${days}j ${hours}h ${minutes}m");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      "Reset dans $_timeUntilReset",
      style: const TextStyle(
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
          fontSize: 12),
    );
  }
}