import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme_manager.dart';
import '../services/stats_service.dart';
import '../services/anki_service.dart';
import '../services/progression_service.dart';
import '../utils/page_transition.dart';
import 'login_page.dart';
import 'detailed_stats_page.dart';
import 'trainer_dashboard_page.dart';
import 'licenses_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AutomaticKeepAliveClientMixin {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  bool get wantKeepAlive => true;

  // --- LOGIQUE DES GRADES ---
  Map<String, dynamic> _getRankInfo(int level) {
    if (level < 5) return {'name': "Nageur Débutant", 'color': Colors.brown.shade300};
    if (level < 10) return {'name': "Sauveteur Stagiaire", 'color': Colors.grey.shade400};
    if (level < 20) return {'name': "Sauveteur Qualifié", 'color': Colors.amber};
    if (level < 30) return {'name': "Chef de Poste", 'color': Colors.cyanAccent};
    return {'name': "Instructeur BNSSA", 'color': Colors.redAccent};
  }

  void _changeThemeMode(ThemeMode? newMode) async {
    if (newMode == null) return;
    themeNotifier.value = newMode;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String modeStr = 'system';
    if (newMode == ThemeMode.light) modeStr = 'light';
    if (newMode == ThemeMode.dark) modeStr = 'dark';
    await prefs.setString('themeMode', modeStr);
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false
    );
  }

  // --- FONCTION DE VALIDATION DIRECTE ---
  Future<void> _completeQuestDirectly(String questId, int xpReward) async {
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final doc = await userRef.get();
    if (!doc.exists) return;

    List<dynamic> completed = doc.data()?['completed_quests'] ?? [];

    if (!completed.contains(questId)) {
      await userRef.update({
        'completed_quests': FieldValue.arrayUnion([questId]),
        'xp': FieldValue.increment(xpReward)
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Quête validée ! +$xpReward XP"), backgroundColor: Colors.green)
        );
      }
    }
  }

  void _pickDate() async {
    DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 30)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 730))
    );

    if (picked != null) {
      await StatsService.setExamDate(picked);
      if (!mounted) return;
      _completeQuestDirectly('profile_pic', 50); // Nom de code pour "Définir date"
      setState(() {});
    }
  }

  void _goToDetails(String title, String type, Color color) {
    if (type == 'speed' || type == 'qcm' || type == 'exam') {
      _completeQuestDirectly('daily_stats', 20);
    }
    Navigator.push(context, SlideRightRoute(page: DetailedStatsPage(title: title, type: type, color: color)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // CALCUL DES MINUTEURS (CORRECTION)
    DateTime now = DateTime.now();
    // Heures avant minuit
    int hoursLeft = 24 - now.hour;
    // Jours avant la fin de la semaine (Dimanche = 7)
    int daysLeftInWeek = 7 - now.weekday;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          StreamBuilder<DocumentSnapshot>(
              stream: user == null ? null : FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                // Dans ProfilePage.dart, à l'intérieur du StreamBuilder :

                var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

                String firstName = data['firstName'] ?? "";
                String lastName = data['lastName'] ?? "";
                String pseudo = data['pseudo'] ?? "Membre";

// Logique d'affichage : Si on a Nom+Prénom on les affiche, sinon on met le Pseudo
                String displayName = (firstName.isNotEmpty && lastName.isNotEmpty)
                    ? "$firstName $lastName"
                    : pseudo;

                String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";
                if (firstName.isNotEmpty) initial = firstName[0].toUpperCase();
                bool isTrainer = data['role'] == 'trainer';

                int xp = data['xp'] ?? 0;
                int level = ProgressionService.getLevel(xp);
                int nextLevelXp = (level + 1) * 100;
                int xpRemaining = nextLevelXp - xp;
                if (xpRemaining < 0) xpRemaining = 0;

                var rankInfo = _getRankInfo(level);
                String rankName = rankInfo['name'];
                Color rankColor = rankInfo['color'];

                DateTime? examDate = (data['exam_date'] as Timestamp?)?.toDate();
                int daysLeft = examDate != null ? examDate.difference(DateTime.now()).inDays : -1;

                // Stats & Graphique
                Map<String, dynamic> history = data['stats_history'] ?? {};
                int qcmTotal = data['stats_qcm_total'] ?? 0;
                int qcmCorrect = data['stats_qcm_correct'] ?? 0;
                double qcmRate = qcmTotal > 0 ? (qcmCorrect / qcmTotal) : 0.0;
                int examTotal = data['stats_exam_total'] ?? 0;
                int examSuccess = data['stats_exam_success'] ?? 0;
                String examStr = examTotal > 0 ? "$examSuccess / $examTotal" : "--";

                int totalMs = 0; int countMs = 0;
                var speedData = data['stats_speed'];
                if (speedData is Map<String, dynamic>) { totalMs = speedData['total_ms'] ?? 0; countMs = speedData['count'] ?? 0; }
                String avgTime = countMs > 0 ? "${(totalMs / countMs / 1000).toStringAsFixed(1)}s" : "--";

                int maxDailyValue = 1;
                DateTime today = DateTime.now();
                for (int i = 0; i < 7; i++) {
                  DateTime day = today.subtract(Duration(days: i));
                  String dateKey = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
                  int val = history[dateKey] ?? 0;
                  if (val > maxDailyValue) maxDailyValue = val;
                }

                List<dynamic> completedQuests = data['completed_quests'] ?? [];
                bool isQuestDone(String id) => completedQuests.contains(id);

                List<Map<String, dynamic>> dailyQuests = [
                  { 'id': 'daily_anki', 'title': "Réviser 10 cartes Anki", 'xp': 50, 'done': isQuestDone('daily_anki'), 'icon': Icons.psychology },
                  { 'id': 'daily_qcm', 'title': "Faire 1 série de QCM", 'xp': 30, 'done': isQuestDone('daily_qcm'), 'icon': Icons.quiz },
                  { 'id': 'daily_stats', 'title': "Consulter mes stats", 'xp': 20, 'done': isQuestDone('daily_stats'), 'icon': Icons.bar_chart },
                ];

                List<Map<String, dynamic>> weeklyQuests = [
                  { 'id': 'weekly_exam', 'title': "Réussir 1 Examen Blanc", 'xp': 200, 'done': isQuestDone('weekly_exam'), 'icon': Icons.timer },
                  { 'id': 'weekly_streak', 'title': "Série de 3 jours", 'xp': 100, 'done': isQuestDone('weekly_streak'), 'icon': Icons.local_fire_department },
                ];

                return Column(children: [

                  // HEADER PRO
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rankColor, width: 3), boxShadow: [BoxShadow(color: rankColor.withValues(alpha: 0.3), blurRadius: 8)]),
                        child: CircleAvatar(radius: 35, backgroundColor: cardColor, child: Text(initial, style: TextStyle(fontSize: 28, color: textColor, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(displayName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: rankColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: rankColor.withValues(alpha: 0.3), width: 1)),
                            child: Text("NIV. $level • $rankName".toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: rankColor, letterSpacing: 0.5)),
                          ),
                          const SizedBox(height: 6),
                          Text("$xpRemaining XP avant le prochain grade", style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                        ],
                        ),
                      ),
                      IconButton(
                          icon: const Icon(Icons.logout, color: Colors.redAccent),
                          onPressed: _logout
                      )
                    ],
                  ),

                  const SizedBox(height: 20),

                  // SELECTEUR THEME
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Apparence", style: TextStyle(fontWeight: FontWeight.bold)),
                        ValueListenableBuilder<ThemeMode>(
                            valueListenable: themeNotifier,
                            builder: (context, currentMode, _) {
                              return DropdownButton<ThemeMode>(
                                  value: currentMode,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.arrow_drop_down),
                                  items: const [DropdownMenuItem(value: ThemeMode.system, child: Text("Système")), DropdownMenuItem(value: ThemeMode.light, child: Text("Clair")), DropdownMenuItem(value: ThemeMode.dark, child: Text("Sombre"))],
                                  onChanged: _changeThemeMode
                              );
                            }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // BOUTONS ACCÈS RAPIDE
                  if (isTrainer) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, SlideRightRoute(page: const TrainerDashboardPage())),
                            child: Container(
                              height: 80,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [Colors.purple.shade700, Colors.deepPurple.shade500]),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("ESPACE FORMATEUR", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  SizedBox(height: 4),
                                  Text("Mes Élèves", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, SlideRightRoute(page: const LicensesPage())),
                            child: Container(
                              height: 80,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade800 : Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.purple.shade200, width: 1),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)]
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.card_membership, color: Colors.purple.shade400, size: 24),
                                  const SizedBox(height: 5),
                                  Text("LICENCES", style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: () => Navigator.push(context, SlideRightRoute(page: const LicensesPage())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade800 : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.purple.shade200, width: 1),
                            boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.05), blurRadius: 5)]
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("BOUTIQUE & CADEAUX", style: TextStyle(color: Colors.purple, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                const SizedBox(height: 4),
                                Text("Mes Licences", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.card_giftcard, color: Colors.purple, size: 24),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 15),

                  // CARTE OBJECTIF
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade600]),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("OBJECTIF BNSSA", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              Text(daysLeft >= 0 ? "J - $daysLeft" : "Définir une date", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // GRAPHIQUE ACTIVITÉ
                  Align(alignment: Alignment.centerLeft, child: Text("ACTIVITÉ (7 Jours)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor.withValues(alpha: 0.5), letterSpacing: 1.5))),
                  const SizedBox(height: 10),
                  Container(
                      height: 160,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5)]),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(7, (index) {
                            DateTime day = today.subtract(Duration(days: 6 - index));
                            String dateKey = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
                            int count = history[dateKey] ?? 0;
                            double maxHeightAvailable = 80.0;
                            double height = (count / maxDailyValue) * maxHeightAvailable;
                            if (count > 0 && height < 5) height = 5;
                            return Column(mainAxisAlignment: MainAxisAlignment.end, children: [Container(width: 8, height: height > 0 ? height : 2, decoration: BoxDecoration(color: height > 0 ? Colors.blue : Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4))), const SizedBox(height: 8), Text("${day.day}", style: TextStyle(fontSize: 10, color: Colors.grey[600]))]);
                          })
                      )
                  ),
                  const SizedBox(height: 25),

                  // STATISTIQUES
                  Align(alignment: Alignment.centerLeft, child: Text("STATISTIQUES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor.withValues(alpha: 0.5), letterSpacing: 1.5))),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.3,
                    children: [
                      StreamBuilder<Map<String, int>>(stream: AnkiService.getAnkiStatsStream(user?.uid), builder: (context, ankiSnap) { return _StatCard(title: "Anki", value: "${ankiSnap.data?['due'] ?? 0}", subtitle: "Cartes", icon: Icons.psychology, color: Colors.purple, isDark: isDark, onTap: () => _goToDetails("Mémoire", "anki", Colors.purple)); }),
                      _StatCard(title: "QCM", value: "${(qcmRate * 100).toInt()}%", subtitle: "Précision", icon: Icons.pie_chart, color: Colors.green, isDark: isDark, onTap: () => _goToDetails("Stats QCM", "qcm", Colors.green)),
                      _StatCard(title: "Examens", value: examStr, subtitle: "Réussis", icon: Icons.assignment, color: Colors.orange, isDark: isDark, onTap: () => _goToDetails("Examens", "exam", Colors.orange)),
                      _StatCard(title: "Vitesse", value: avgTime, subtitle: "par quest.", icon: Icons.speed, color: Colors.blue, isDark: isDark, onTap: () => _goToDetails("Vitesse", "speed", Colors.blue)),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // OBJECTIFS (Connectés)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("OBJECTIFS DU JOUR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor.withValues(alpha: 0.5), letterSpacing: 1.5)),
                    // CORRECTION ICI : MINUTEUR DYNAMIQUE
                    Row(children: [const Icon(Icons.access_time, size: 14, color: Colors.grey), const SizedBox(width: 4), Text("Fin dans ${hoursLeft}h", style: TextStyle(fontSize: 12, color: Colors.grey[600]))])
                  ]),
                  const SizedBox(height: 10),
                  Column(children: dailyQuests.map((q) => _QuestTile(title: q['title'], xp: q['xp'], isDone: q['done'], icon: q['icon'], cardColor: cardColor, textColor: textColor)).toList()),

                  const SizedBox(height: 20),

                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("CHALLENGE SEMAINE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor.withValues(alpha: 0.5), letterSpacing: 1.5)),
                    // CORRECTION ICI : JOURS RESTANTS DYNAMIQUES
                    Row(children: [const Icon(Icons.calendar_today, size: 14, color: Colors.blue), const SizedBox(width: 4), Text("J-$daysLeftInWeek", style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold))])
                  ]),
                  const SizedBox(height: 10),
                  Column(children: weeklyQuests.map((q) => _QuestTile(title: q['title'], xp: q['xp'], isDone: q['done'], icon: q['icon'], cardColor: cardColor, textColor: textColor, isWeekly: true)).toList()),

                  const SizedBox(height: 50),
                ]);
              }
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS INTERNES (Identiques, mais inclus pour la copie facile) ---
class _QuestTile extends StatelessWidget {
  final String title;
  final int xp;
  final bool isDone;
  final IconData icon;
  final Color cardColor;
  final Color textColor;
  final bool isWeekly;

  const _QuestTile({required this.title, required this.xp, required this.isDone, required this.icon, required this.cardColor, required this.textColor, this.isWeekly = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDone ? Colors.green.withValues(alpha: 0.3) : (isWeekly ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)]
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: isDone ? Colors.green : (isWeekly ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
                shape: BoxShape.circle
            ),
            child: Icon(isDone ? Icons.check : icon, color: isDone ? Colors.white : (isWeekly ? Colors.blue : Colors.grey), size: 20)
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? Colors.grey : textColor, decoration: isDone ? TextDecoration.lineThrough : null, fontSize: 14)),
        trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: isDone ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text("+$xp XP", style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? Colors.green : Colors.amber, fontSize: 10))
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _StatCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
              Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey.withValues(alpha: 0.5)),
            ]),
            const SizedBox(height: 5),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              ),
              const SizedBox(height: 2),
              Text(title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1, overflow: TextOverflow.ellipsis
              ),
              Text(subtitle,
                  style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : Colors.grey),
                  maxLines: 1, overflow: TextOverflow.ellipsis
              ),
            ])
          ],
        ),
      ),
    );
  }
}