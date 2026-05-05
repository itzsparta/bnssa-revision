// lib/controllers/training_controller.dart
import '../services/user_service.dart';
import '../services/theme_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  final _userService = UserService();
  final _themeService = ThemeService();

  // ─── Test helper ─────────────────────────────────────────────────────────────
  void setStateForTest(TrainingState s) => state = s;

  // ─── Ad ──────────────────────────────────────────────────────────────────────
  void initAdService() => ref.read(adServiceProvider).loadAd();

  // ─── Profile ─────────────────────────────────────────────────────────────────
  Future<void> createUserProfileIfNeeded(String uid, String? email) =>
      _userService.createUserProfileIfNeeded(uid, email);

  Future<bool> hasMistakes(String uid) => _userService.hasMistakes(uid);

  Future<void> resetAnki(String uid) async => AnkiService.resetAll(uid);

  // ─── Quiz logic ───────────────────────────────────────────────────────────────
  Future<void> loadQuestions(String themeId, String themeTitle) async {
    state = state.copyWith(loading: true);
    try {
      List<Question> loaded = await _themeService.getThemeQuestions(themeId, themeTitle);

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
          _userService.updateLastReviewed(user.uid),
          if (isCorrect) _userService.updateThemeStat(user.uid, themeId, q.id),
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
