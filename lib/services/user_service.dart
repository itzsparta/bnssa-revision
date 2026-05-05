import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _db;

  UserService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Stream temps réel du document users/{uid}.
  Stream<DocumentSnapshot> userStream(String uid) =>
      _db.collection('users').doc(uid).snapshots();

  /// Vérifie si le profil est complet (pseudo + lastName renseignés).
  Future<bool> isProfileComplete(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;
    return data['pseudo'] != null && data['lastName'] != null;
  }

  /// Sauvegarde le profil utilisateur lors de l'onboarding (merge).
  Future<void> saveUserProfile(
    String uid, {
    required String lastName,
    required String firstName,
    required String pseudo,
  }) =>
      _db.collection('users').doc(uid).set({
        'lastName': lastName,
        'firstName': firstName,
        'pseudo': pseudo,
        'profile_completed': true,
      }, SetOptions(merge: true));

  /// Met à jour l'activité de connexion (last_connection, last_reviewed).
  Future<void> updateActivity(String uid) =>
      _db.collection('users').doc(uid).set({
        'last_connection': FieldValue.serverTimestamp(),
        'last_reviewed': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Vérifie et distribue le cadeau quotidien (1 crédit).
  /// Retourne true si un crédit a été accordé, false sinon.
  Future<bool> checkDailyReward(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists) return false;

    final data = doc.data() as Map<String, dynamic>;
    final lastGift = data['last_daily_gift'];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool shouldGive = false;

    if (lastGift == null) {
      shouldGive = true;
    } else {
      DateTime lastDate;
      if (lastGift is DateTime) {
        lastDate = lastGift;
      } else {
        lastDate = (lastGift as Timestamp).toDate();
      }
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      shouldGive = today.isAfter(lastDay);
    }

    if (shouldGive) {
      await ref.update({
        'credits': FieldValue.increment(1),
        'last_daily_gift': FieldValue.serverTimestamp(),
      });
    }
    return shouldGive;
  }

  /// Crée le profil utilisateur s'il n'existe pas encore.
  Future<void> createUserProfileIfNeeded(String uid, String? email) async {
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'email': email ?? '',
        'credits': 0,
        'score_total': 0,
        'isPremium': false,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Vérifie si l'utilisateur a des erreurs enregistrées.
  Future<bool> hasMistakes(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('mistakes')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Valide une quête et accorde les XP correspondants.
  Future<void> completeQuest(String uid, String questId, int xpReward) =>
      _db.collection('users').doc(uid).update({
        'completed_quests': FieldValue.arrayUnion([questId]),
        'score_total': FieldValue.increment(xpReward),
      });

  /// Débite des crédits à l'utilisateur.
  Future<void> deductCredit(String uid, int amount) =>
      _db.collection('users').doc(uid).update({
        'credits': FieldValue.increment(-amount),
      });

  /// Débloque un thème premium et débite les crédits correspondants.
  Future<void> unlockPremiumTheme(String uid, String themeId, int cost) =>
      _db.collection('users').doc(uid).update({
        'credits': FieldValue.increment(-cost),
        'unlocked_themes': FieldValue.arrayUnion([themeId]),
      });

  /// Met à jour last_reviewed après une réponse à une question.
  Future<void> updateLastReviewed(String uid) =>
      _db.collection('users').doc(uid).update({
        'last_reviewed': FieldValue.serverTimestamp(),
      });

  /// Enregistre une question correctement répondue dans les stats par thème.
  Future<void> updateThemeStat(String uid, String themeId, String questionId) =>
      _db.collection('users').doc(uid).collection('theme_stats').doc(themeId).set({
        'correct_ids': FieldValue.arrayUnion([questionId]),
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Ajoute des crédits après un achat in-app.
  Future<void> addCredits(String uid, int amount) =>
      _db.collection('users').doc(uid).update({
        'credits': FieldValue.increment(amount),
      });

  /// Active le statut premium et crédite 9999 crédits après un achat pack premium.
  Future<void> activatePremium(String uid) =>
      _db.collection('users').doc(uid).update({
        'isPremium': true,
        'credits': 9999,
      });
}
