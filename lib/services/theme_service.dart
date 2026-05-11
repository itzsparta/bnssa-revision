import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';

class ThemeService {
  final FirebaseFirestore _db;

  ThemeService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Stream temps réel de tous les thèmes.
  Stream<QuerySnapshot> themesStream() =>
      _db.collection('themes').orderBy('order').snapshots();

  /// Lecture one-shot de tous les thèmes.
  Future<QuerySnapshot> getAllThemes() =>
      _db.collection('themes').orderBy('order').get();

  /// Compte le nombre de questions d'un thème via requête aggregate.
  Future<int> getThemeQuestionCount(String themeId) => _db
      .collection('themes')
      .doc(themeId)
      .collection('questions')
      .count()
      .get()
      .then((snap) => snap.count ?? 0);

  /// Récupère les questions d'un thème.
  /// Si [limit] est fourni, limite le nombre de questions retournées.
  Future<List<Question>> getThemeQuestions(
    String themeId,
    String themeTitle, {
    int? limit,
  }) async {
    Query query = _db
        .collection('themes')
        .doc(themeId)
        .collection('questions');

    if (limit != null) query = query.limit(limit);

    final snap = await query.get();
    return snap.docs
        .map((doc) => Question.fromFirestore(doc, theme: themeTitle))
        .toList();
  }
}
