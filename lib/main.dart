import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- OBLIGATOIRE
import 'theme_manager.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/purchase_service.dart';
import 'services/notification_service.dart';
import 'pages/intro_page.dart'; // Assure-toi que ce fichier existe !

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialisation des services
  try {
    await Firebase.initializeApp();
    await PurchaseService.init();
    await NotificationService.init();
  } catch (e) {
    debugPrint("Erreur Firebase: $e");
  }

  // 2. VÉRIFICATION : Est-ce la première ouverture ?
  final prefs = await SharedPreferences.getInstance();
  // On regarde si la case 'seenIntro' est cochée. Si elle n'existe pas, c'est que c'est false (jamais vu).
  final bool showIntro = !(prefs.getBool('seenIntro') ?? false);

  // 3. On lance l'app en lui donnant l'info
  runApp(MyApp(showIntro: showIntro));
}

class MyApp extends StatelessWidget {
  final bool showIntro; // On reçoit l'info ici

  // On demande l'info au constructeur
  const MyApp({super.key, required this.showIntro});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
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
          themeMode: currentMode,
          // C'EST ICI QUE ÇA SE JOUE :
          // Si showIntro est vrai -> IntroPage
          // Sinon -> AuthWrapper (Connexion ou Accueil)
          home: showIntro ? const IntroPage() : const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("Erreur: Firebase non configuré.")),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}