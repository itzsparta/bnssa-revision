import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StatsService {

  static Future<void> updateDailyActivity(String type, {int? ankiQuality, bool isSuccess = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DateTime now = DateTime.now();
    String dateKey = DateFormat('yyyy-MM-dd').format(now);

    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    Map<String, dynamic> updates = {
      'stats_history.$dateKey': FieldValue.increment(1),
      'stats_history_$type.$dateKey': FieldValue.increment(1),
    };

    if (type == 'anki') {
      updates['stats_anki_total_reviews'] = FieldValue.increment(1);
      if (ankiQuality != null) {
        updates['stats_history_anki_$ankiQuality.$dateKey'] = FieldValue.increment(1);
      }
      if (isSuccess) {
        updates['stats_history_anki_success.$dateKey'] = FieldValue.increment(1);
      }
    } else if (type == 'qcm') {
      updates['stats_qcm_total'] = FieldValue.increment(1);
    } else if (type == 'exam') {

    }

    await userRef.update(updates).catchError((e) {});
  }

  static Future<void> updateThemeStats(String themeId, bool isCorrect) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DateTime now = DateTime.now();
    String dateKey = DateFormat('yyyy-MM-dd').format(now);

    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    if (isCorrect) {
      await userRef.update({
        'stats_qcm_correct': FieldValue.increment(1),
        'stats_history_qcm_correct.$dateKey': FieldValue.increment(1)
      });
    }
  }

  static Future<void> updateAverageTime(int ms) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DateTime now = DateTime.now();
    String dateKey = DateFormat('yyyy-MM-dd').format(now);

    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      var data = snapshot.data() as Map<String, dynamic>;
      var speedData = data['stats_speed'] as Map<String, dynamic>? ?? {};
      int totalMs = speedData['total_ms'] ?? 0;
      int count = speedData['count'] ?? 0;

      transaction.update(userRef, {
        'stats_speed': { 'total_ms': totalMs + ms, 'count': count + 1 },
        'stats_history_speed.$dateKey': ms
      });
    });
  }

  // --- MODIFICATION ICI : Ajout du paramètre 'details' ---
  static Future<void> saveExamResult(String uid, int score, int total, bool passed, List<Map<String, dynamic>> details) async {
    // 1. Compteurs globaux
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'stats_exam_total': FieldValue.increment(1),
      'stats_exam_success': FieldValue.increment(passed ? 1 : 0),
    });

    // 2. Historique détaillé avec les questions
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('exam_history')
        .add({
      'date': FieldValue.serverTimestamp(),
      'score': score,
      'total': total,
      'passed': passed,
      'details': details, // On stocke la copie ici
    });

    // 3. Activité
    await updateDailyActivity('exam');
  }

  static Future<void> setExamDate(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'exam_date': Timestamp.fromDate(date)
    });
  }

  /// Stream des copies d'examen de l'utilisateur.
  static Stream<QuerySnapshot> examHistoryStream(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('exam_history')
          .orderBy('date', descending: true)
          .snapshots();
}