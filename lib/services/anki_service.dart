import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../models/question.dart';
import 'stats_service.dart';

class AnkiService {

  static Future<Map<String, int>> getAnkiStats(String? uid) async {
    if (uid == null) return {'due': 0, 'total': 0};
    try {
      var snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('anki_cards').get();
      int total = snapshot.docs.length;
      int due = snapshot.docs.where((doc) {
        Timestamp? next = doc.data()['nextReview'];
        if (next == null) return true;
        return next.toDate().isBefore(DateTime.now());
      }).length;
      return {'due': due, 'total': total};
    } catch (e) {
      return {'due': 0, 'total': 0};
    }
  }

  static Stream<Map<String, int>> getAnkiStatsStream(String? uid) {
    if (uid == null) return Stream.value({'due': 0, 'total': 0});
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('anki_cards').snapshots().map((snapshot) {
      int total = snapshot.docs.length;
      int due = snapshot.docs.where((doc) {
        Timestamp? next = doc.data()['nextReview'];
        if (next == null) return true;
        return next.toDate().isBefore(DateTime.now());
      }).length;
      return {'due': due, 'total': total};
    });
  }

  static Future<List<Question>> getDueCards(String uid) async {
    try {
      DateTime now = DateTime.now();
      var snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('anki_cards').where('nextReview', isLessThanOrEqualTo: Timestamp.fromDate(now)).limit(20).get();
      List<Question> questions = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        questions.add(Question(
            id: data['questionId'] ?? doc.id,
            themeName: data['theme'] ?? 'Révision',
            questionText: data['questionText'] ?? 'Question chargée...',
            options: List<String>.from(data['options'] ?? []),
            correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
            explanation: data['explanation'] ?? '',
            imageUrl: null
        ));
      }
      return questions;
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveFlashcardReview(String uid, Question question, int quality) async {
    DocumentReference cardRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('anki_cards').doc(question.id);
    DocumentSnapshot doc = await cardRef.get();

    int interval = 1;
    double easeFactor = 2.5;
    int repetitions = 0;

    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      interval = data['interval'] ?? 1;
      easeFactor = (data['easeFactor'] ?? 2.5).toDouble();
      repetitions = data['repetitions'] ?? 0;
    }

    if (quality < 2) {
      repetitions = 0;
      interval = 1;
    } else {
      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * easeFactor).round();
      }
      repetitions++;
    }

    easeFactor = easeFactor + (0.1 - (3 - quality) * (0.08 + (3 - quality) * 0.02));
    if (easeFactor < 1.3) easeFactor = 1.3;

    DateTime nextReview = DateTime.now().add(Duration(days: interval));

    // 1. Sauvegarde de la carte
    await cardRef.set({
      'questionId': question.id,
      'nextReview': Timestamp.fromDate(nextReview),
      'interval': interval,
      'easeFactor': easeFactor,
      'repetitions': repetitions,
      'lastReview': FieldValue.serverTimestamp(),
      'questionText': question.questionText,
      'theme': question.themeName,
      'options': question.options,
      'explanation': question.explanation,
      'correctAnswerIndex': question.correctAnswerIndex,
    }, SetOptions(merge: true));

    // 2. Mise à jour des Stats & DE LA DATE D'ACTIVITÉ
    String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    await userRef.set({
      'stats_anki_total_reviews': FieldValue.increment(1),
      'last_reviewed': FieldValue.serverTimestamp(), // <--- CORRECTION CRUCIALE ICI
      'stats_history_anki_$quality': {
        todayKey: FieldValue.increment(1)
      }
    }, SetOptions(merge: true));

    await StatsService.updateDailyActivity('anki');
    _checkDailyAnkiQuest(uid, todayKey);
  }

  static Future<void> _checkDailyAnkiQuest(String uid, String todayKey) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!userDoc.exists) return;
      var data = userDoc.data() as Map<String, dynamic>;

      int totalToday = 0;
      for (int i = 0; i <= 3; i++) {
        var historyMap = data['stats_history_anki_$i'];
        if (historyMap != null && historyMap[todayKey] != null) {
          totalToday += (historyMap[todayKey] as int);
        }
      }

      List<dynamic> completed = data['completed_quests'] ?? [];
      if (totalToday >= 10 && !completed.contains('daily_anki')) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'completed_quests': FieldValue.arrayUnion(['daily_anki']),
          'xp': FieldValue.increment(50)
        });
      }
    } catch (e) {
      debugPrint("Erreur validation quête Anki: $e");
    }
  }

  static Future<void> resetAll(String uid) async {
    var collection = FirebaseFirestore.instance.collection('users').doc(uid).collection('anki_cards');
    var snapshots = await collection.get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }
}