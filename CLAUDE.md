# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commandes essentielles

```bash
flutter pub get           # Installer les dépendances
flutter analyze           # Linting statique
flutter test              # Tous les tests
flutter test test/haptic_service_test.dart  # Un test spécifique
flutter run               # Lancer en développement
flutter build apk         # Build Android release
flutter build ipa         # Build iOS App Store
flutter pub run flutter_launcher_icons  # Regénérer les icônes launcher
```

## Architecture

L'app suit un pattern **Page → Controller → Service → Firestore** sans framework de state management externe ni routeur dédié.

### State management
- `ChangeNotifier` pour la logique de session d'entraînement (`TrainingController`)
- `ValueNotifier<ThemeMode>` pour le thème global (`lib/theme_manager.dart`)
- `StatefulWidget` + `setState` pour l'état local des pages
- Pas de Riverpod, Bloc, Provider ou GetX

### Navigation
- Navigation manuelle via `Navigator.push()` avec `SlideRightRoute` (transition personnalisée dans `lib/utils/page_transition.dart`)
- Pas de go_router ni de routes nommées
- Routage initial basé sur l'état d'auth Firebase (`authStateChanges()`) : IntroPage → LoginPage ou HomePage

### Structure `lib/`
- **`pages/`** — Écrans complets (27 fichiers). Groupés par domaine : auth, entraînement/examen, stats, communauté, profil
- **`services/`** — Toute la logique métier et accès Firebase/tiers. Instanciés au démarrage dans `main.dart`
- **`controllers/`** — Pont View↔Service avec état. Actuellement : `TrainingController` (ChangeNotifier)
- **`models/`** — Modèles Firestore (`Question` avec factory `fromFirestore`)
- **`widgets/`** — Composants réutilisables (cartes stats, widgets communauté, widgets entraînement)
- **`utils/`** — Utilitaires partagés, constantes, transitions de page

### Firebase / Firestore
Structure des collections :
- `users/{uid}` — profil, stats globales, crédits
- `users/{uid}/anki_cards` — état répétition espacée par question
- `users/{uid}/mistakes` — erreurs enregistrées
- `themes/{themeId}/questions` — base de données des questions

### Services clés
- **`AnkiService`** — algorithme de répétition espacée pour sélectionner les questions
- **`StatsService`** + **`ProgressionService`** — écriture des performances dans Firestore après chaque réponse
- **`PurchaseService`** — intégration RevenueCat (abonnements + crédits)
- **`AdService`** — Google AdMob (bannières/interstitiels)
- **`NotificationService`** — notifications locales + Firebase Messaging

### Initialisation (`main.dart`)
- **Synchrone** : Firebase Core, Crashlytics, SharedPreferences, thème
- **Asynchrone en arrière-plan** : AdService, PurchaseService, NotificationService, HapticService

## Conventions

- Les clés API RevenueCat sont dans `lib/services/secrets.dart` (ne pas committer de vraies clés)
- Android : `compileSdk 36`, `minSdk` défini par Flutter, JVM 17, desugaring activé, multidex activé
- Bundle ID : `com.studiotsi.bnssa`
- Le thème utilise Material Design 3
