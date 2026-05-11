# Architecture du Projet BNSSA

## Aperçu Général
Le projet BNSSA est une application mobile développée en **Flutter** destinée à l'entraînement pour le Brevet National de Sécurité et de Sauvetage Aquatique (BNSSA). L'application propose des QCM, des examens blancs, un suivi des statistiques et intègre des achats intégrés. 

L'architecture de l'application suit une structure modulaire classique pour Flutter, séparant clairement l'interface utilisateur, la logique métier et l'accès aux données.

## Technologies Principales
*   **Frontend**: Flutter / Dart
*   **Backend & Base de données**: Firebase (Authentication, Cloud Firestore, Crashlytics, Messaging)
*   **Monétisation**: RevenueCat (`purchases_flutter`) pour les achats In-App et Abonnements, Google Mobile Ads.
*   **Notifications**: `flutter_local_notifications`

## Structure de l'Application (`/lib`)

### 1. `main.dart`
Le point d'entrée de l'application. Il est responsable de :
*   L'initialisation de Firebase et du Crashlytics pour la gestion des erreurs.
*   L'initialisation des préférences utilisateur (SharedPreferences).
*   La configuration du thème dynamique (clair/sombre).
*   La gestion du routage initial (Redirection vers `IntroPage`, `HomePage` ou `LoginPage` selon l'état d'authentification).
*   Le lancement en arrière-plan des services secondaires (Publicité, Achats, Notifications, Haptique).

### 2. `pages/` (Interface Utilisateur - Vues)
Contient les différents écrans entiers de l'application.
*   **Authentification & Accueil** : `login_page.dart`, `intro_page.dart`, `onboarding_page.dart`, `home_page.dart`.
*   **Entraînement & Examens** : `training_page.dart`, `exam_page.dart`, `exam_intro_page.dart`, `daily_review_page.dart`.
*   **Statistiques & Résultats** : `exam_result_details_page.dart`, `detailed_stats_page.dart`, `mistakes_page.dart`.
*   **Fonctionnalités annexes** : `profile_page.dart`, `shop_page.dart`, `community_page.dart`, `trainer_dashboard_page.dart`.

### 3. `services/` (Logique Métier & APIs)
Gère l'accès aux données, les opérations complexes et la communication avec des services tiers (Firebase, RevenueCat, etc.).
*   `ad_service.dart` : Gestion de l'affichage des publicités Google AdMob.
*   `purchase_service.dart` : Gestion des achats intégrés et des crédits via RevenueCat.
*   `anki_service.dart` : Algorithme de répétition espacée (type Anki) pour la mémorisation des questions.
*   `stats_service.dart` & `progression_service.dart` : Calcul et sauvegarde des performances de l'utilisateur sur Firebase Firestore.
*   `notification_service.dart` : Gestion des notifications locales.
*   `mistakes_service.dart` : Enregistrement et récupération des erreurs des étudiants.

### 4. `controllers/` (Gestion d'état)
Sert de pont entre la Vue (`pages`) et les Modèles/Services, en gérant l'état spécifique d'un écran ou d'un flux.
*   `training_controller.dart` : Gère le déroulement de la session d'entraînement, le passage des questions et les réponses de l'utilisateur.

### 5. `models/` (Structure des données)
Définition des classes d'objets manipulés dans l'app, garantissant le typage des données.
*   `question.dart` : Représente une question d'examen, incluant son libellé, ses propositions de réponses et la bonne réponse.

### 6. `widgets/` (Composants UI Réutilisables)
Contient des éléments d'interface qui sont utilisés à plusieurs endroits dans l'application pour garder un code DRY (Don't Repeat Yourself) (par ex. boutons personnalisés, cartes de statistiques, dialogues).

### 7. `utils/` (Utilitaires)
Fonctions d'aide, constantes, formatage de dates, et autres outils partagés.
*   `theme_manager.dart` (à la racine de lib) : Gestion du thème de l'application (ValueNotifier).

## Flux de Données Typique (Exemple : Entraînement)
1. L'utilisateur lance un entraînement (`training_page.dart`).
2. La vue instancie ou appelle le `training_controller.dart`.
3. Le contrôleur s'appuie potentiellement sur `anki_service.dart` pour sélectionner les prochaines questions.
4. Les questions sont récupérées depuis Firestore sous forme d'objets `Question` (`question.dart`).
5. Lorsque l'utilisateur répond :
   - Le `training_controller.dart` met à jour l'état de l'écran.
   - `progression_service.dart` et `mistakes_service.dart` sont appelés pour sauvegarder les résultats dans Firestore.
