import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  final FirebaseFirestore _db;

  ReportService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> sendReport({
    required String questionId,
    required String questionText,
    required String? userId,
    required String reason,
  }) =>
      _db.collection('reports').add({
        'questionId': questionId,
        'questionText': questionText,
        'userId': userId ?? 'anonymous',
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
}
