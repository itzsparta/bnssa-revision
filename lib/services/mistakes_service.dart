import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question.dart';

class MistakesService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. AJOUTER UNE ERREUR
  static Future<void> addMistake(Question question) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('mistakes')
        .doc(question.id)
        .set(question.toMap());
  }

  // 2. RÉCUPÉRER TOUTES LES ERREURS
  static Future<List<Question>> getMistakes() async {
    User? user = _auth.currentUser;
    if (user == null) return [];

    var snapshot = await _db
        .collection('users')
        .doc(user.uid)
        .collection('mistakes')
        .get();

    return snapshot.docs.map((doc) {
      return Question.fromMap(doc.data());
    }).toList();
  }

  // 3. SUPPRIMER UNE ERREUR
  static Future<void> removeMistake(String questionId) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('mistakes')
        .doc(questionId)
        .delete();
  }
}
