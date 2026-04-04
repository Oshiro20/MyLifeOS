import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

void main() {
  group('WalletSummary', () {
    test('balance positivo cuando ingresos > gastos', () {
      final s = WalletSummary.fromJson({
        'version': '1.0',
        'month': '2026-04',
        'balance': 3240.50,
        'income': 5200.0,
        'expenses': 1959.50,
        'currency': 'PEN',
        'exportedAt': '2026-04-01T00:00:00.000',
      });
      expect(s.balance, greaterThan(0));
    });

    test('balance negativo cuando gastos > ingresos', () {
      final s = WalletSummary.fromJson({
        'version': '1.0',
        'month': '2026-04',
        'balance': -200.0,
        'income': 800.0,
        'expenses': 1000.0,
        'currency': 'PEN',
        'exportedAt': '2026-04-01T00:00:00.000',
      });
      expect(s.balance, lessThan(0));
    });

    test('currency por defecto es PEN', () {
      final s = WalletSummary.fromJson({});
      expect(s.currency, 'PEN');
    });
  });
}
