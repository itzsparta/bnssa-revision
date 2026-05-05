import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int maxDailyTeamPoints = 50;

  // --- NOUVEAU : Fonction pour identifier la semaine actuelle ---
  String _getCurrentWeekKey() {
    DateTime now = DateTime.now();
    // On trouve le Lundi de la semaine en cours pour créer un identifiant unique (ex: "2024-5-20")
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    return "${monday.year}-${monday.month}-${monday.day}";
  }
  // -------------------------------------------------------------

  Future<void> updateUserScoreInTeam(int pointsToAdd) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (!userDoc.exists) return;

    final userData = userDoc.data()!;
    final String? teamCode = userData['teamCode'];

    // 1. Mise à jour du score PERSO (ne reset jamais)
    await userRef.update({
      'score_total': FieldValue.increment(pointsToAdd),
    });

    if (teamCode == null) return;

    // 2. Gestion du Plafond Quotidien
    DateTime now = DateTime.now();
    String todayKey = "${now.year}-${now.month}-${now.day}";

    String lastDate = userData['team_points_date'] ?? "";
    int dailyPoints = userData['team_points_daily'] ?? 0;

    if (lastDate != todayKey) {
      dailyPoints = 0; // Nouveau jour, on remet le compteur quotidien à 0
    }

    int remainingSpace = maxDailyTeamPoints - dailyPoints;
    if (remainingSpace <= 0) return; // Plafond atteint

    int realPointsToAdd = (pointsToAdd > remainingSpace) ? remainingSpace : pointsToAdd;

    // --- 3. LOGIQUE DU RESET HEBDOMADAIRE (LA VRAIE !) ---
    final teamRef = _db.collection('teams').doc(teamCode);

    // On doit lire l'équipe pour voir si on est dans une nouvelle semaine
    // On utilise une transaction pour être sûr que deux joueurs ne reset pas en même temps
    await _db.runTransaction((transaction) async {
      DocumentSnapshot teamSnapshot = await transaction.get(teamRef);
      if (!teamSnapshot.exists) return;

      Map<String, dynamic> teamData = teamSnapshot.data() as Map<String, dynamic>;

      String currentWeekKey = _getCurrentWeekKey();
      String lastResetWeek = teamData['last_reset_week'] ?? "";

      int currentScore = teamData['score'] ?? 0;
      int currentMonthScore = teamData['score_month'] ?? 0;

      // SI C'EST UNE NOUVELLE SEMAINE : ON RESET AVANT D'AJOUTER
      if (lastResetWeek != currentWeekKey) {
        currentScore = 0; // Remise à zéro !
        // On pourrait aussi archiver l'ancien score ici si on voulait
      }

      // On applique les points
      transaction.update(teamRef, {
        'score': currentScore + realPointsToAdd, // Score repart de 0 ou continue
        'score_month': currentMonthScore + realPointsToAdd, // Le mois n'est pas impacté par la semaine
        'last_reset_week': currentWeekKey, // On marque cette semaine comme "traitée"
      });
    });

    // 4. Mise à jour du compteur quotidien de l'utilisateur
    await userRef.update({
      'team_points_date': todayKey,
      'team_points_daily': dailyPoints + realPointsToAdd,
    });
  }

  Future<bool> joinTeam(String code) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final teamRef = _db.collection('teams').doc(code);
    final teamDoc = await teamRef.get();

    if (!teamDoc.exists) return false;

    await _db.collection('users').doc(user.uid).update({
      'teamCode': code,
      // On ne reset PAS le score_total global de l'user, juste son lien équipe
    });

    await teamRef.update({'member_count': FieldValue.increment(1)});
    return true;
  }

  Future<String> createTeam(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged");

    String code = name.substring(0, (name.length > 4 ? 4 : name.length)).toUpperCase();
    code += DateTime.now().millisecond.toString();

    // On initialise avec la clé de la semaine actuelle
    await _db.collection('teams').doc(code).set({
      'name': name,
      'created_by': user.uid,
      'created_at': FieldValue.serverTimestamp(),
      'score': 0,
      'score_month': 0,
      'member_count': 1,
      'last_reset_week': _getCurrentWeekKey(), // <-- Important pour le futur
    });

    await _db.collection('users').doc(user.uid).update({
      'teamCode': code,
      // 'score_total': 0 // Optionnel : remettre à 0 ou garder l'historique perso
    });

    return code;
  }

  Future<void> leaveTeam() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    String? currentTeam = userDoc.data()?['teamCode'];

    if (currentTeam != null) {
      await _db.collection('teams').doc(currentTeam).update({
        'member_count': FieldValue.increment(-1)
      });
    }

    await _db.collection('users').doc(user.uid).update({
      'teamCode': FieldValue.delete(),
    });
  }

  Stream<DocumentSnapshot> teamStream(String teamCode) =>
      _db.collection('teams').doc(teamCode).snapshots();

  Stream<QuerySnapshot> teamMembersStream(String teamCode) =>
      _db.collection('users').where('teamCode', isEqualTo: teamCode).snapshots();

  Stream<QuerySnapshot> globalRankingStream({int limit = 20}) =>
      _db.collection('teams').orderBy('score', descending: true).limit(limit).snapshots();
}