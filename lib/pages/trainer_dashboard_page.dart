import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Pour le presse-papier
import '../utils/page_transition.dart';
import 'student_details_page.dart';

class TrainerDashboardPage extends StatelessWidget {
  const TrainerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9);
    Color appBarBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Erreur auth")));
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("Tableau de Bord", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: appBarBg,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Bouton Licences amélioré
          Container(
            margin: const EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.confirmation_number_outlined, color: Colors.blue),
              tooltip: "Gérer les Licences",
              onPressed: () {
                Navigator.push(context, SlideRightRoute(page: const TrainerLicensesPage()));
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            var data = snapshot.data!.data() as Map<String, dynamic>;
            String? teamCode = data['teamCode'];

            // Si le formateur n'a pas encore créé de clan
            if (teamCode == null) return _buildNoTeamState(isDark);

            return _buildDashboardContent(context, teamCode, isDark);
          }),
    );
  }

  Widget _buildNoTeamState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_add, size: 80, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 20),
          Text("Aucune promotion active",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[700])),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            child: Text("Allez dans l'onglet 'Social' pour créer votre premier clan et inviter vos élèves.",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, String teamCode, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('teamCode', isEqualTo: teamCode).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;
          int studentCount = docs.length;
          double totalScore = 0;
          int inactiveCount = 0;

          // Tri par score décroissant
          docs.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;
            int scoreA = dataA['score_total'] ?? 0;
            int scoreB = dataB['score_total'] ?? 0;
            return scoreB.compareTo(scoreA);
          });

          // Calcul des stats
          for (var doc in docs) {
            var d = doc.data() as Map<String, dynamic>;
            totalScore += (d['score_total'] ?? 0);
            Timestamp? lastAct = d['last_reviewed']; // ou un autre champ 'last_activity'
            // Considéré inactif si pas d'activité depuis 3 jours
            if (lastAct == null || DateTime.now().difference(lastAct.toDate()).inDays > 3) {
              inactiveCount++;
            }
          }
          double averageScore = studentCount > 0 ? totalScore / studentCount : 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. HEADER DU CLAN
                _buildTeamHeader(context, teamCode),

                const SizedBox(height: 25),

                // 2. GRID DES KPIS
                Row(
                  children: [
                    Expanded(child: _buildKpiCard("Élèves", "$studentCount", Icons.groups, Colors.blue, isDark)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildKpiCard("Moyenne", "${averageScore.toInt()}", Icons.insights, Colors.purple, isDark)),
                  ],
                ),
                const SizedBox(height: 15),
                // Carte alerte pleine largeur
                _buildAlertCard(inactiveCount, isDark),

                const SizedBox(height: 30),

                // 3. LISTE DES ÉLÈVES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Classement & Suivi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    Text("${docs.length} membres", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 15),

                if (docs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200], borderRadius: BorderRadius.circular(15)),
                    child: const Center(child: Text("En attente d'élèves...\nPartagez le code ci-dessus !", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                  ),

                ...docs.map((doc) {
                  return _StudentListTile(uid: doc.id, data: doc.data() as Map<String, dynamic>);
                }),
              ],
            ),
          );
        });
  }

  Widget _buildTeamHeader(BuildContext context, String code) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          const Text("CODE DE PROMOTION", style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 3),
              ),
              const SizedBox(width: 15),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copié dans le presse-papier !"), backgroundColor: Colors.green));
                },
                icon: const Icon(Icons.copy, color: Colors.cyanAccent),
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 15),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(int inactiveCount, bool isDark) {
    if (inactiveCount == 0) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 15),
            Text("Tous les élèves sont actifs !", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$inactiveCount élèves inactifs", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const Text("Pas de révision depuis 3 jours", style: TextStyle(color: Colors.redAccent, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentListTile extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _StudentListTile({required this.uid, required this.data});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    // --- LOGIQUE : AFFICHER NOM ET PSEUDO ---
    String firstName = data['firstName'] ?? "";
    String lastName = data['lastName'] ?? "";
    String pseudo = data['pseudo'] ?? "";
    String email = data['email'] ?? "Inconnu";

    String displayName;  // Principal (Gros)
    String displaySub;   // Secondaire (Petit)

    // 1. On privilégie "Prénom Nom" en principal
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      displayName = "$firstName $lastName";
      // Si un pseudo existe, on l'affiche en dessous, sinon rien
      displaySub = pseudo.isNotEmpty ? "@$pseudo" : "";
    }
    // 2. Si pas de nom, le pseudo devient principal
    else if (pseudo.isNotEmpty) {
      displayName = pseudo;
      displaySub = email; // On affiche l'email en petit pour aider le formateur
    }
    // 3. Sinon, l'email
    else {
      displayName = email.split('@')[0];
      displaySub = "";
    }

    // Initiale pour l'avatar
    String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";
    // -------------------------------------------

    int score = data['score_total'] ?? 0;
    Timestamp? lastAct = data['last_reviewed'];
    int daysInactive = lastAct != null ? DateTime.now().difference(lastAct.toDate()).inDays : 99;
    bool isAlert = daysInactive > 3;

    double progress = (score / 2000).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5, offset: const Offset(0, 2))],
        border: isAlert ? Border.all(color: Colors.red.withValues(alpha: 0.3)) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            Navigator.push(context, SlideRightRoute(page: StudentDetailsPage(studentUid: uid, studentName: displayName)));
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isAlert ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                      child: Text(initial, style: TextStyle(fontWeight: FontWeight.bold, color: isAlert ? Colors.red : Colors.blue, fontSize: 20)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: isAlert ? Colors.red : Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: cardColor, width: 2),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(width: 15),

                // Infos élève
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NOM COMPLET
                      Text(displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),

                      // PSEUDO (Affiché juste en dessous en bleu)
                      if (displaySub.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(displaySub, style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                        ),

                      const SizedBox(height: 6),

                      // Barre de progression
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                          color: isAlert ? Colors.red.shade300 : Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(isAlert ? "Inactif ($daysInactive j)" : "Actif récemment", style: TextStyle(fontSize: 10, color: isAlert ? Colors.red : Colors.grey)),
                    ],
                  ),
                ),

                // Score
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("$score pts", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor)),
                    const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- PAGE LICENCES AMÉLIORÉE ---
class TrainerLicensesPage extends StatelessWidget {
  const TrainerLicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text("Mes Licences Élèves")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('license_codes').where('createdBy', isEqualTo: user.uid).orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var codes = snapshot.data!.docs;

          if (codes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.style, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text("Aucune licence achetée.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context), // En vrai il faudrait aller vers le shop
                      child: const Text("Acheter des licences")
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: codes.length,
            itemBuilder: (context, index) {
              var data = codes[index].data() as Map<String, dynamic>;
              bool isUsed = data['isUsed'] ?? false;
              String code = data['code'];

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  gradient: isUsed
                      ? const LinearGradient(colors: [Colors.grey, Colors.black38]) // Grisé si utilisé
                      : const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFDB931)]), // Or si dispo
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Licence copiée !"), duration: Duration(seconds: 1)));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isUsed ? "LICENCE UTILISÉE" : "LICENCE PREMIUM", style: TextStyle(color: isUsed ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5)),
                              const SizedBox(height: 5),
                              Text(code, style: TextStyle(color: isUsed ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), shape: BoxShape.circle),
                            child: Icon(isUsed ? Icons.check : Icons.copy, color: isUsed ? Colors.white : Colors.black87),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}