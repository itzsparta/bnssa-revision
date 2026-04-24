// lib/providers/auth_providers.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

@riverpod
Stream<User?> authState(Ref ref) =>
    FirebaseAuth.instance.authStateChanges();

@riverpod
User? currentUser(Ref ref) => FirebaseAuth.instance.currentUser;
