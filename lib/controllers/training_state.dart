// lib/controllers/training_state.dart
import '../models/question.dart';

class TrainingState {
  final List<Question> questions;
  final int currentIndex;
  final bool loading;
  final bool answered;
  final int? selectedOption;
  final int score;
  final DateTime? questionStartTime;

  const TrainingState({
    required this.questions,
    required this.currentIndex,
    required this.loading,
    required this.answered,
    required this.selectedOption,
    required this.score,
    required this.questionStartTime,
  });

  factory TrainingState.initial() => const TrainingState(
        questions: [],
        currentIndex: 0,
        loading: true,
        answered: false,
        selectedOption: null,
        score: 0,
        questionStartTime: null,
      );

  TrainingState copyWith({
    List<Question>? questions,
    int? currentIndex,
    bool? loading,
    bool? answered,
    int? selectedOption,
    bool clearSelectedOption = false,
    int? score,
    DateTime? questionStartTime,
  }) {
    return TrainingState(
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      loading: loading ?? this.loading,
      answered: answered ?? this.answered,
      selectedOption:
          clearSelectedOption ? null : selectedOption ?? this.selectedOption,
      score: score ?? this.score,
      questionStartTime: questionStartTime ?? this.questionStartTime,
    );
  }

  bool get isLastQuestion => currentIndex >= questions.length - 1;
  Question? get currentQuestion =>
      questions.isNotEmpty ? questions[currentIndex] : null;
}
