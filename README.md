# BNSSA Révision

Application mobile Flutter pour préparer l'épreuve théorique du BNSSA (Brevet
National de Sécurité et de Sauvetage Aquatique). Je l'ai écrite en tant que
sauveteur BNSSA, pour réviser le QCM et pour permettre aux formateurs de suivre
leurs élèves.

## Fonctionnalités

**Pour l'élève**
- Entraînement par thème, avec une sélection des questions par répétition
  espacée (algorithme de type Anki).
- Examens blancs chronométrés, correction détaillée question par question.
- Révision quotidienne et carnet des erreurs.
- Statistiques de progression : précision par thème, activité sur 7 jours,
  réussite aux examens blancs.
- Clans et classement par équipe, remis à zéro chaque semaine.

**Pour le formateur**
- Tableau de bord des élèves : points, cartes révisées, examens passés.
- Génération de codes licence en lot, activés ensuite par les élèves.

**Modèle économique** : crédits et abonnement via RevenueCat, thèmes premium,
bannières AdMob.

## Architecture

Pattern **Page → Controller → Service → Firestore**, sans framework de
navigation.

| Dossier | Rôle |
|---|---|
| `lib/pages/` | Écrans, regroupés par domaine (auth, entraînement, examen, stats, communauté, formateur) |
| `lib/controllers/` | `TrainingController` (`ChangeNotifier`), déroulé d'une session d'entraînement |
| `lib/services/` | Logique métier et accès Firebase : répétition espacée, stats, crédits, licences, notifications |
| `lib/models/` | `Question` et sa factory `fromFirestore` |
| `scripts/` | Scripts Node d'administration de la base de questions (Firebase Admin) |

Les opérations sensibles (débit de crédits, activation de licence, création de
codes en lot) passent par des transactions ou des batchs Firestore atomiques.

Collections Firestore :

- `users/{uid}` : profil, statistiques globales, crédits
- `users/{uid}/anki_cards` : état de répétition espacée de chaque question
- `users/{uid}/mistakes` : erreurs enregistrées
- `themes/{themeId}/questions` : banque de questions

Plus de détails dans [`architecture.md`](architecture.md).

## Stack

Flutter, Firebase (Auth, Firestore, Messaging, Crashlytics), RevenueCat,
Google Mobile Ads, `fl_chart`, `flutter_local_notifications`.

## Lancer le projet

Prérequis : Flutter 3.x et un projet Firebase avec Firestore.

```bash
flutter pub get
cp lib/services/secrets.dart.example lib/services/secrets.dart
# Placer le google-services.json du projet Firebase dans android/app/
flutter run
```

## Tests

```bash
flutter test
```

Tests unitaires des services (licences, signalements, thème, utilisateur,
achats, retour haptique) et d'un widget.
