import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CreditService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Tente de déduire [cost] crédits via transaction atomique.
  /// Retourne null en cas de succès (ou si l'utilisateur est premium).
  /// Retourne le montant manquant si crédits insuffisants.
  /// Retourne -1 en cas d'erreur réseau.
  static Future<int?> tryDeductCredits(String uid, int cost) async {
    try {
      final userRef = _db.collection('users').doc(uid);
      return await _db.runTransaction<int?>((txn) async {
        final doc = await txn.get(userRef);
        if (!doc.exists) return cost;
        final data = doc.data() as Map<String, dynamic>;
        if (data['isPremium'] ?? false) return null;
        final int current = data['credits'] ?? 0;
        if (current >= cost) {
          txn.update(userRef, {'credits': FieldValue.increment(-cost)});
          return null;
        }
        return cost - current;
      });
    } catch (e) {
      debugPrint('CreditService.tryDeductCredits error: $e');
      return -1;
    }
  }

  /// Débloque un thème premium de manière atomique (déduction + ajout).
  /// Retourne null en cas de succès (ou si déjà débloqué / premium).
  /// Retourne le montant manquant si crédits insuffisants.
  /// Retourne -1 en cas d'erreur réseau.
  static Future<int?> unlockTheme(String uid, String themeId, int cost) async {
    try {
      final userRef = _db.collection('users').doc(uid);
      return await _db.runTransaction<int?>((txn) async {
        final doc = await txn.get(userRef);
        if (!doc.exists) return cost;
        final data = doc.data() as Map<String, dynamic>;
        if (data['isPremium'] ?? false) return null;
        final List<dynamic> unlocked = data['unlocked_themes'] ?? [];
        if (unlocked.contains(themeId)) return null;
        final int current = data['credits'] ?? 0;
        if (current >= cost) {
          txn.update(userRef, {
            'credits': FieldValue.increment(-cost),
            'unlocked_themes': FieldValue.arrayUnion([themeId]),
          });
          return null;
        }
        return cost - current;
      });
    } catch (e) {
      debugPrint('CreditService.unlockTheme error: $e');
      return -1;
    }
  }
}
