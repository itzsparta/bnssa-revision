import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service centralisé pour le retour haptique.
///
/// L'état activé/désactivé est stocké dans un champ statique partagé
/// entre toutes les instances, et persisté dans SharedPreferences.
///
/// Les callbacks sont injectables pour permettre les tests unitaires
/// sans dépendance aux canaux de la plateforme Flutter.
/// Le paramètre [enabled] du constructeur permet de forcer l'état initial
/// en test (override du statique).
class HapticService {
  static const _prefKey = 'haptic_enabled';
  static bool _globalEnabled = true;
  static bool _initialized = false;

  /// À appeler au démarrage de l'app pour restaurer la préférence.
  static Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _globalEnabled = prefs.getBool(_prefKey) ?? true;
    _initialized = true;
  }

  final void Function() _lightImpact;
  final void Function() _heavyImpact;
  final void Function() _mediumImpact;
  final void Function() _selectionClick;

  HapticService({
    bool? enabled, // Override statique (usage test uniquement)
    void Function()? lightImpact,
    void Function()? heavyImpact,
    void Function()? mediumImpact,
    void Function()? selectionClick,
  })  : _lightImpact = lightImpact ?? HapticFeedback.mediumImpact,
        _heavyImpact = heavyImpact ?? HapticFeedback.heavyImpact,
        _mediumImpact = mediumImpact ?? HapticFeedback.heavyImpact,
        _selectionClick = selectionClick ?? HapticFeedback.lightImpact {
    if (enabled != null) _globalEnabled = enabled;
  }

  bool get enabled => _globalEnabled;

  /// Active ou désactive le retour haptique et persiste le choix.
  void setEnabled(bool value) {
    _globalEnabled = value;
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_prefKey, value))
        .ignore(); // Silencieux en environnement de test
    if (value) _selectionClick();
  }

  /// Réponse QCM : medium si correct, heavy si faux.
  void triggerAnswer(bool isCorrect) {
    if (!_globalEnabled) return;
    isCorrect ? _lightImpact() : _heavyImpact();
  }

  /// Résultat examen : medium si reçu, heavy si échoué.
  void triggerExamResult(bool passed) {
    if (!_globalEnabled) return;
    passed ? _lightImpact() : _heavyImpact();
  }

  /// Révision Anki : heavy si qualité ≤ 1 (Dur/Raté), medium sinon.
  void triggerAnkiReview(int quality) {
    if (!_globalEnabled) return;
    quality <= 1 ? _heavyImpact() : _mediumImpact();
  }

  /// Sélection légère (retournement de carte, tap…).
  void triggerSelection() {
    if (!_globalEnabled) return;
    _selectionClick();
  }
}
