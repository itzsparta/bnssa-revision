import 'package:cloud_firestore/cloud_firestore.dart';

class LicenseService {
  final FirebaseFirestore _db;

  LicenseService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Stream des licences créées par un formateur (trié par date décroissante).
  Stream<QuerySnapshot> trainerLicensesStream(String trainerUid) => _db
      .collection('license_codes')
      .where('createdBy', isEqualTo: trainerUid)
      .orderBy('createdAt', descending: true)
      .snapshots();

  /// Crée [quantity] codes licence dans un batch atomique.
  Future<void> createLicenseCodes(String trainerUid, int quantity, String Function() generateCode) async {
    final batch = _db.batch();
    for (int i = 0; i < quantity; i++) {
      final ref = _db.collection('license_codes').doc();
      batch.set(ref, {
        'code': generateCode(),
        'createdBy': trainerUid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': null,
        'isUsed': false,
        'type': 'pack_reussite',
      });
    }
    await batch.commit();
  }

  /// Active un code licence pour un élève (transaction atomique).
  /// Throws [Exception] si le code est introuvable, déjà utilisé ou expiré.
  Future<void> redeemCode(String code, String userUid) async {
    final query = await _db
        .collection('license_codes')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw Exception('Code introuvable.');

    final licDoc = query.docs.first;
    final data = licDoc.data();

    if (data['isUsed'] == true) throw Exception('Ce code a déjà été utilisé.');

    final expiry = data['expiresAt'];
    if (expiry != null) {
      final expiryDate = (expiry as Timestamp).toDate();
      if (DateTime.now().isAfter(expiryDate)) throw Exception('Ce code a expiré (Fin du trimestre formateur).');
    }

    await _db.runTransaction((tx) async {
      tx.update(licDoc.reference, {
        'isUsed': true,
        'usedBy': userUid,
        'usedAt': FieldValue.serverTimestamp(),
      });
      tx.update(_db.collection('users').doc(userUid), {
        'isPremium': true,
        'credits': 9999,
        'premiumSource': 'trainer_license',
        'premiumGrantedBy': data['createdBy'],
      });
    });
  }
}
