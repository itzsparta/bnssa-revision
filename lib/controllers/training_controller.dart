// lib/controllers/training_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';
import '../providers/service_providers.dart';
import '../services/anki_service.dart';
import '../services/mistakes_service.dart';
import '../services/stats_service.dart';
import 'training_state.dart';

part 'training_controller.g.dart';

@riverpod
class TrainingController extends _$TrainingController {
  static const int _kQuestionsPerSession = 10;

  @override
  TrainingState build() => TrainingState.initial();

  // ─── Test helper ─────────────────────────────────────────────────────────────
  void setStateForTest(TrainingState s) => state = s;

  // ─── Ad ──────────────────────────────────────────────────────────────────────
  void initAdService() => ref.read(adServiceProvider).loadAd();

  // ─── Profile ─────────────────────────────────────────────────────────────────
  Future<void> createUserProfileIfNeeded(String uid, String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('profile_created_v2') ?? false) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final snapshot = await userRef.get();
    if (!snapshot.exists) {
      await userRef.set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'credits': 10,
        'xp': 0,
        'score_total': 0,
        'role': 'student',
        'isPremium': false,
        'stats_exam_total': 0,
        'stats_exam_success': 0,
        'stats_qcm_total': 0,
        'stats_qcm_correct': 0,
        'unlocked_themes': [],
      });
    }
    await prefs.setBool('profile_created_v2', true);
  }

  Future<bool> hasMistakes(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('mistakes')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> resetAnki(String uid) async => AnkiService.resetAll(uid);

  // ─── Quiz logic ───────────────────────────────────────────────────────────────
  Future<void> loadQuestions(String themeId, String themeTitle) async {
    state = state.copyWith(loading: true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('themes')
          .doc(themeId)
          .collection('questions')
          .get();

      List<Question> loaded = snapshot.docs
          .map((doc) => Question.fromFirestore(doc, theme: themeTitle))
          .toList();

      // Mélange les options de chaque question en conservant la bonne réponse
      loaded = loaded.map((q) {
        final String correctText = (q.options.isNotEmpty &&
                q.correctAnswerIndex < q.options.length)
            ? q.options[q.correctAnswerIndex]
            : '';
        final List<String> shuffled = List.from(q.options)..shuffle();
        final int newIndex =
            shuffled.indexOf(correctText).clamp(0, shuffled.length - 1);
        return Question(
          id: q.id,
          questionText: q.questionText,
          options: shuffled,
          correctAnswerIndex: newIndex,
          explanation: q.explanation,
          themeName: q.themeName,
          imageUrl: q.imageUrl,
        );
      }).toList();

      loaded.shuffle();
      if (loaded.length > _kQuestionsPerSession) {
        loaded = loaded.take(_kQuestionsPerSession).toList();
      }

      state = state.copyWith(
        questions: loaded,
        currentIndex: 0,
        score: 0,
        answered: false,
        clearSelectedOption: true,
        loading: false,
        questionStartTime: DateTime.now(),
      );
    } catch (e) {
      debugPrint('loadQuestions error: $e');
      state = state.copyWith(loading: false);
    }
  }

  Future<void> submitAnswer(int optionIndex, String themeId) async {
    if (state.answered) return;

    final int elapsedMs = state.questionStartTime != null
        ? DateTime.now().difference(state.questionStartTime!).inMilliseconds
        : 0;

    state = state.copyWith(answered: true, selectedOption: optionIndex);

    final q = state.questions[state.currentIndex];
    final bool isCorrect = optionIndex == q.correctAnswerIndex;

    if (isCorrect) {
      state = state.copyWith(score: state.score + 1);
      ref.read(teamServiceProvider).updateUserScoreInTeam(1);
    } else {
      MistakesService.addMistake(q);
    }

    final user = FirebaseAuth.instance.currentUser;
    try {
      await Future.wait([
        StatsService.updateThemeStats(themeId, isCorrect),
        StatsService.updateDailyActivity('qcm'),
        if (elapsedMs > 0) StatsService.updateAverageTime(elapsedMs),
        if (user != null) ...[
          AnkiService.saveFlashcardReview(user.uid, q, isCorrect ? 3 : 1),
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'last_reviewed': FieldValue.serverTimestamp()}),
          if (isCorrect)
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('theme_stats')
                .doc(themeId)
                .set({
              'correct_ids': FieldValue.arrayUnion([q.id]),
              'last_updated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)),
        ],
      ]);
    } catch (e) {
      debugPrint('submitAnswer Firestore error: $e');
    }
  }

  /// Retourne true s'il reste une question, false si la session est terminée.
  bool nextQuestion() {
    if (state.currentIndex < state.questions.length - 1) {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        answered: false,
        clearSelectedOption: true,
        questionStartTime: DateTime.now(),
      );
      return true;
    }
    return false;
  }
}
