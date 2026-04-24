// lib/providers/data_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/question.dart';

part 'data_providers.g.dart';

@riverpod
Stream<DocumentSnapshot<Map<String, dynamic>>> userDoc(Ref ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots();
}

@riverpod
Future<List<Question>> questions(
  Ref ref,
  ({String themeId, String themeTitle}) params,
) async {
  final snap = await FirebaseFirestore.instance
      .collection('themes')
      .doc(params.themeId)
      .collection('questions')
      .get();
  return snap.docs
      .map((doc) => Question.fromFirestore(doc, theme: params.themeTitle))
      .toList();
}
