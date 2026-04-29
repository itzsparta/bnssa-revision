import 'package:flutter_test/flutter_test.dart';
import 'package:bnssa/services/purchase_service.dart';

void main() {
  group('PurchaseService helpers', () {
    test('generateRandomCode retourne un code au format BNSSA-XXXXXX', () {
      final code = PurchaseService.generateRandomCode();
      expect(code, matches(r'^BNSSA-[A-Z0-9]{6}$'));
    });

    test('generateRandomCode génère des codes différents', () {
      final codes = List.generate(10, (_) => PurchaseService.generateRandomCode());
      final unique = codes.toSet();
      expect(unique.length, greaterThan(1));
    });
  });
}
