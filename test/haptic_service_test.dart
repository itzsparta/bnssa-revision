import 'package:flutter_test/flutter_test.dart';
import 'package:bnssa/services/haptic_service.dart';

// Compteurs d'appels par type de vibration
class _HapticCounts {
  int light = 0;
  int heavy = 0;
  int medium = 0;
  int selection = 0;

  int get total => light + heavy + medium + selection;

  void reset() {
    light = 0;
    heavy = 0;
    medium = 0;
    selection = 0;
  }
}

HapticService _makeService(_HapticCounts c, {bool enabled = true}) {
  return HapticService(
    enabled: enabled,
    lightImpact: () => c.light++,
    heavyImpact: () => c.heavy++,
    mediumImpact: () => c.medium++,
    selectionClick: () => c.selection++,
  );
}

void main() {
  group('HapticService — triggerAnswer', () {
    test('bonne réponse → light (→ mediumImpact en prod)', () {
      final c = _HapticCounts();
      _makeService(c).triggerAnswer(true);
      expect(c.light, 1);
      expect(c.heavy, 0);
    });

    test('mauvaise réponse → heavy (→ heavyImpact en prod)', () {
      final c = _HapticCounts();
      _makeService(c).triggerAnswer(false);
      expect(c.heavy, 1);
      expect(c.light, 0);
    });

    test('désactivé → aucun retour haptique', () {
      final c = _HapticCounts();
      _makeService(c, enabled: false).triggerAnswer(true);
      _makeService(c, enabled: false).triggerAnswer(false);
      expect(c.total, 0);
    });
  });

  group('HapticService — triggerExamResult', () {
    test('examen réussi → light (→ mediumImpact en prod)', () {
      final c = _HapticCounts();
      _makeService(c).triggerExamResult(true);
      expect(c.light, 1);
      expect(c.heavy, 0);
    });

    test('examen échoué → heavy (→ heavyImpact en prod)', () {
      final c = _HapticCounts();
      _makeService(c).triggerExamResult(false);
      expect(c.heavy, 1);
      expect(c.light, 0);
    });

    test('désactivé → aucun retour haptique', () {
      final c = _HapticCounts();
      final svc = _makeService(c, enabled: false);
      svc.triggerExamResult(true);
      svc.triggerExamResult(false);
      expect(c.total, 0);
    });
  });

  group('HapticService — triggerAnkiReview', () {
    test('qualité 0 (raté) → heavyImpact', () {
      final c = _HapticCounts();
      _makeService(c).triggerAnkiReview(0);
      expect(c.heavy, 1);
      expect(c.medium, 0);
    });

    test('qualité 1 (dur) → heavyImpact', () {
      final c = _HapticCounts();
      _makeService(c).triggerAnkiReview(1);
      expect(c.heavy, 1);
      expect(c.medium, 0);
    });

    test('qualité 2 (correct) → mediumImpact', () {
      final c = _HapticCounts();
      _makeService(c).triggerAnkiReview(2);
      expect(c.medium, 1);
      expect(c.heavy, 0);
    });

    test('qualité 3 (facile) → mediumImpact', () {
      final c = _HapticCounts();
      _makeService(c).triggerAnkiReview(3);
      expect(c.medium, 1);
      expect(c.heavy, 0);
    });

    test('désactivé → aucun retour haptique', () {
      final c = _HapticCounts();
      final svc = _makeService(c, enabled: false);
      svc.triggerAnkiReview(0);
      svc.triggerAnkiReview(3);
      expect(c.total, 0);
    });
  });

  group('HapticService — triggerSelection', () {
    test('activé → selection (→ lightImpact en prod)', () {
      final c = _HapticCounts();
      _makeService(c).triggerSelection();
      expect(c.selection, 1);
    });

    test('désactivé → aucun retour haptique', () {
      final c = _HapticCounts();
      _makeService(c, enabled: false).triggerSelection();
      expect(c.total, 0);
    });
  });

  group('HapticService — setEnabled', () {
    test('activation → joue selection (→ lightImpact en prod) pour confirmer', () {
      final c = _HapticCounts();
      final svc = _makeService(c, enabled: false);
      svc.setEnabled(true);
      expect(svc.enabled, true);
      expect(c.selection, 1);
    });

    test('désactivation → aucun retour haptique, enabled false', () {
      final c = _HapticCounts();
      final svc = _makeService(c);
      svc.setEnabled(false);
      expect(svc.enabled, false);
      expect(c.total, 0);
    });

    test('après désactivation, triggerAnswer ne vibre plus', () {
      final c = _HapticCounts();
      final svc = _makeService(c);
      svc.setEnabled(false);
      svc.triggerAnswer(true);
      svc.triggerAnswer(false);
      expect(c.total, 0);
    });

    test('après ré-activation, triggerAnswer vibre à nouveau', () {
      final c = _HapticCounts();
      final svc = _makeService(c);
      svc.setEnabled(false);
      c.reset();
      svc.setEnabled(true); // joue selectionClick
      c.reset();            // on remet à zéro pour tester triggerAnswer seul
      svc.triggerAnswer(true);
      expect(c.light, 1);
    });
  });
}
