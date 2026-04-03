import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

void main() {
  group('WalletSummary.fromJson', () {
    test('parsea correctamente un JSON válido', () {
      final json = {
        'version': '1.1.2',
        'build': '4',
        'exportedAt': '2026-04-01T10:00:00.000',
        'month': '2026-04',
        'balance': 3240.50,
        'income': 5200.0,
        'expenses': 1959.50,
        'currency': 'PEN',
      };

      final summary = WalletSummary.fromJson(json);

      expect(summary.version, '1.1.2');
      expect(summary.month, '2026-04');
      expect(summary.balance, 3240.50);
      expect(summary.income, 5200.0);
      expect(summary.expenses, 1959.50);
      expect(summary.currency, 'PEN');
    });

    test('usa valores por defecto cuando faltan campos', () {
      final summary = WalletSummary.fromJson({});

      expect(summary.version, '');
      expect(summary.month, '');
      expect(summary.balance, 0.0);
      expect(summary.income, 0.0);
      expect(summary.expenses, 0.0);
      expect(summary.currency, 'PEN');
    });

    test('balance negativo es válido', () {
      final summary = WalletSummary.fromJson({
        'balance': -500.0,
        'income': 1000.0,
        'expenses': 1500.0,
        'currency': 'USD',
        'version': '1.0',
        'month': '2026-03',
        'exportedAt': '2026-03-31T00:00:00.000',
      });

      expect(summary.balance, -500.0);
      expect(summary.currency, 'USD');
    });

    test('exportedAt se parsea correctamente', () {
      final summary = WalletSummary.fromJson({
        'exportedAt': '2026-04-02T15:30:00.000',
        'version': '', 'month': '', 'balance': 0,
        'income': 0, 'expenses': 0, 'currency': 'PEN',
      });

      expect(summary.exportedAt.year, 2026);
      expect(summary.exportedAt.month, 4);
      expect(summary.exportedAt.day, 2);
    });

    test('exportedAt inválido usa DateTime.now aproximado', () {
      final before = DateTime.now();
      final summary = WalletSummary.fromJson({
        'exportedAt': 'fecha-invalida',
        'version': '', 'month': '', 'balance': 0,
        'income': 0, 'expenses': 0, 'currency': 'PEN',
      });
      final after = DateTime.now();

      expect(
        summary.exportedAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        summary.exportedAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('serialización JSON round-trip', () {
      final original = {
        'version': '2.0.0',
        'build': '10',
        'exportedAt': '2026-04-01T08:00:00.000',
        'month': '2026-04',
        'balance': 1500.0,
        'income': 3000.0,
        'expenses': 1500.0,
        'currency': 'PEN',
      };

      final summary = WalletSummary.fromJson(original);
      expect(summary.balance, original['balance']);
      expect(summary.income, original['income']);
      expect(summary.expenses, original['expenses']);
    });
  });
}
