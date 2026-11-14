import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

void main() {
  group('WalletSummary', () {
    test('serializes and deserializes rich ecosystem fields cleanly', () {
      final json = {
        'version': '1.4.0',
        'month': '2026-11',
        'balance': 1250.5,
        'income': 3000.0,
        'expenses': 1749.5,
        'currency': 'PEN',
        'exportedAt': '2026-11-13T12:00:00.000',
        'source': 'cloud',
        'byCategory': [
          {'name': 'Alimentación', 'icon': '🍔', 'amount': 900.0, 'percentage': 51.4},
        ],
        'weeklyExpenses': [50.0, 120.0, 0.0, 80.0, 200.0, 95.0, 40.0],
        'recentTransactions': [
          {
            'id': 'tx1',
            'name': 'Supermercado',
            'category': 'Alimentación',
            'amount': -120.0,
            'type': 'expense',
            'date': '2026-11-12',
          },
        ],
      };

      final summary = WalletSummary.fromJson(json);

      expect(summary.balance, 1250.5);
      expect(summary.source, 'cloud');
      expect(summary.byCategory.length, 1);
      expect(summary.byCategory.first.name, 'Alimentación');
      expect(summary.byCategory.first.percentage, 51.4);
      expect(summary.weeklyExpenses, [50.0, 120.0, 0.0, 80.0, 200.0, 95.0, 40.0]);
      expect(summary.recentTransactions.length, 1);
      expect(summary.recentTransactions.first['name'], 'Supermercado');

      final encoded = summary.toJson();
      expect(encoded['byCategory'], isNotEmpty);
      expect(encoded['weeklyExpenses'], hasLength(7));
    });

    test('maintains backwards compatibility with minimal v1.2 payload', () {
      final summary = WalletSummary.fromJson({
        'version': '1.2.0',
        'month': '2026-04',
        'balance': 100,
        'income': 500,
        'expenses': 400,
        'currency': 'PEN',
      });

      expect(summary.balance, 100.0);
      expect(summary.byCategory, isEmpty);
      expect(summary.weeklyExpenses, isEmpty);
      expect(summary.recentTransactions, isEmpty);
      expect(summary.source, 'local');
    });
  });
}
