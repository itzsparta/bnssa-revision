// lib/main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'controllers/theme_notifier.dart';
import 'pages/home_page.dart';
import 'pages/intro_page.dart';
import 'pages/login_page.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialisation des services
  try {
    await Firebase.initializeApp();
    await GoogleSignIn.instance.initialize(
      serverClientId: '607880278780-cihcnn3mnanf53c7vql0rgbau7od0v8k.apps.googleusercontent.com',
    );
    await PurchaseService.init();
    await NotificationService.init();
  } catch (e) {
    debugPrint('Erreur Firebase: $e');
  }

  // Vérification abonnement formateur (en arrière-plan, non bloquant)
  PurchaseService.checkTrainerSubscription().catchError(
    (e) => debugPrint('checkTrainerSubscription: $e'),
  );

  // 2. Vérification première ouverture
  final prefs = await SharedPreferences.getInstance();
  final bool showIntro = !(prefs.getBool('seenIntro') ?? false);

  // 3. Lancement avec ProviderScope
  runApp(
    ProviderScope(
      child: MyApp(showIntro: showIntro),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final bool showIntro;

  const MyApp({super.key, required this.showIntro});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'BNSSA Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      themeMode: themeMode,
      home: showIntro ? const IntroPage() : const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Erreur: Firebase non configuré.')),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}
