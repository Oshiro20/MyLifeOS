import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';

void main() {
  group('InventoryIngredient entity', () {
    test('ingrediente con fecha de vencimiento', () {
      final expiry = DateTime(2026, 12, 31);
      final i = InventoryIngredient(
        id: '1',
        name: 'Leche',
        primaryCategory: 'Lácteos',
        quantity: 1,
        unit: 'L',
        expirationDate: expiry,
      );
      expect(i.expirationDate, expiry);
    });

    test('AiJsonParser limpia bloques markdown y extrae JSON', () {
      const raw = '```json\n{"ok": true}\n```';
      expect(AiJsonParser.decodeMap(raw), {'ok': true});
    });
  });
}
