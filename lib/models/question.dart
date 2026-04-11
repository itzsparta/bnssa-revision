import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String themeName;
  final String? imageUrl;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    required this.themeName,
    this.imageUrl,
  });

  factory Question.fromFirestore(DocumentSnapshot doc,
      {required String theme}) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // --- CORRECTION GRÂCE À VOTRE CAPTURE D'ÉCRAN ---
    // On met 'questionText' en premier car c'est ce que votre base utilise !
    String qText = data['questionText'] ??
        data['question'] ??
        data['text'] ??
        data['label'] ??
        'Question sans texte';

    List<String> opts = [];
    if (data['options'] is List) {
      opts = List<String>.from(data['options']);
    }

    return Question(
      id: doc.id,
      questionText: qText,
      options: opts,
      correctAnswerIndex:
          data['correctAnswerIndex'] ?? data['correct_index'] ?? 0,
      explanation: data['explanation'] ?? '',
      imageUrl: data['imageUrl'],
      themeName: theme,
    );
  }

  factory Question.fromMap(Map<String, dynamic> data) {
    return Question(
      id: data['id'] ?? '',
      questionText: data['questionText'] ?? data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
      explanation: data['explanation'] ?? '',
      imageUrl: data['imageUrl'],
      themeName: data['themeName'] ?? 'Inconnu',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'imageUrl': imageUrl,
      'themeName': themeName,
    };
  }
}
