import 'dart:convert';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'wallet_summary_reader.dart';

/// Precio unitario histórico de un ingrediente para estimar presupuestos de compra.
class IngredientPriceEntry {
  final String nameKey;
  final String displayName;
  final double unitPrice;
  final String unit;
  final String currency;
  final DateTime updatedAt;
  final String source;

  const IngredientPriceEntry({
    required this.nameKey,
    required this.displayName,
    required this.unitPrice,
    required this.unit,
    this.currency = 'PEN',
    required this.updatedAt,
    this.source = 'manual',
  });

  factory IngredientPriceEntry.fromJson(Map<String, dynamic> json) =>
      IngredientPriceEntry(
        nameKey: json['nameKey'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] as String? ?? 'unidades',
        currency: json['currency'] as String? ?? 'PEN',
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        source: json['source'] as String? ?? 'manual',
      );

  Map<String, dynamic> toJson() => {
        'nameKey': nameKey,
        'displayName': displayName,
        'unitPrice': unitPrice,
        'unit': unit,
        'currency': currency,
        'updatedAt': updatedAt.toIso8601String(),
        'source': source,
      };
}

/// Resultado de estimación de costo para una lista de compras o menú semanal.
class GroceryBudgetEstimate {
  final double totalEstimated;
  final int pricedCount;
  final int totalCount;
  final String currency;

  const GroceryBudgetEstimate({
    required this.totalEstimated,
    required this.pricedCount,
    required this.totalCount,
    this.currency = 'PEN',
  });

  bool get hasAnyPrice => pricedCount > 0;
}

/// Candidato detectado desde una transacción de WalletAI listo para enviar a Despensa.
class WalletGroceryCandidate {
  final String transactionKey;
  final String rawDescription;
  final String itemName;
  final double quantity;
  final String unit;
  final double? totalPrice;
  final String currency;
  final String? date;

  const WalletGroceryCandidate({
    required this.transactionKey,
    required this.rawDescription,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.totalPrice,
    this.currency = 'PEN',
    this.date,
  });

  double? get unitPrice =>
      (totalPrice != null && totalPrice! > 0 && quantity > 0)
          ? totalPrice! / quantity
          : null;
}

/// Catálogo persistente de precios unitarios históricos por ingrediente.
class IngredientPriceService {
  static const _catalogKey = 'ingredient_price_catalog_v1';

  /// Normaliza el nombre de ingrediente para emparejar singular/plural y acentos.
  static String normalizeKey(String rawName) {
    var s = rawName
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9ñ\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (s.length > 4 && s.endsWith('es') && !s.endsWith('tes')) {
      s = s.substring(0, s.length - 2);
    } else if (s.length > 3 && s.endsWith('s')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Future<Map<String, IngredientPriceEntry>> loadCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_catalogKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, IngredientPriceEntry>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map<String, dynamic>) {
          result[entry.key.toString()] =
              IngredientPriceEntry.fromJson(entry.value as Map<String, dynamic>);
        } else if (entry.value is Map) {
          result[entry.key.toString()] = IngredientPriceEntry.fromJson(
              Map<String, dynamic>.from(entry.value as Map));
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveCatalog(Map<String, IngredientPriceEntry> catalog) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      for (final e in catalog.entries) e.key: e.value.toJson(),
    });
    await prefs.setString(_catalogKey, encoded);
  }

  Future<void> recordPurchase({
    required String name,
    required double quantity,
    required String unit,
    required double totalPrice,
    String currency = 'PEN',
    String source = 'walletai',
  }) async {
    if (name.trim().isEmpty || quantity <= 0 || totalPrice <= 0) return;
    final key = normalizeKey(name);
    if (key.isEmpty) return;

    final catalog = await loadCatalog();
    final normalizedUnit = MeasurementUnit.fromString(unit).label;
    final newUnitPrice = totalPrice / quantity;

    final existing = catalog[key];
    double effectiveUnitPrice = newUnitPrice;
    if (existing != null) {
      final convertedUnitPrice = convertUnitPrice(
        unitPrice: newUnitPrice,
        fromUnit: normalizedUnit,
        toUnit: existing.unit,
      );
      if (convertedUnitPrice != null) {
        // Promedio ponderado: 70% precio reciente + 30% histórico
        effectiveUnitPrice =
            (convertedUnitPrice * 0.7) + (existing.unitPrice * 0.3);
        catalog[key] = IngredientPriceEntry(
          nameKey: key,
          displayName: name.trim(),
          unitPrice: effectiveUnitPrice,
          unit: existing.unit,
          currency: currency,
          updatedAt: DateTime.now(),
          source: source,
        );
        await _saveCatalog(catalog);
        return;
      }
    }

    catalog[key] = IngredientPriceEntry(
      nameKey: key,
      displayName: name.trim(),
      unitPrice: newUnitPrice,
      unit: normalizedUnit,
      currency: currency,
      updatedAt: DateTime.now(),
      source: source,
    );
    await _saveCatalog(catalog);
  }

  /// Convierte un precio por [fromUnit] a precio por [toUnit].
  static double? convertUnitPrice({
    required double unitPrice,
    required String fromUnit,
    required String toUnit,
  }) {
    final from = MeasurementUnit.fromString(fromUnit);
    final to = MeasurementUnit.fromString(toUnit);
    if (from == to) return unitPrice;
    // Cuántas [from] caben en 1 [to]
    final factor = IngredientUnitNormalizer.convert(1.0, to, from);
    if (factor == null || factor <= 0) return null;
    return unitPrice * factor;
  }

  /// Estima el precio para [quantity] en [unit] de un ingrediente dentro de [catalog].
  static ({double estimatedPrice, String currency, IngredientPriceEntry entry})?
      estimateItem({
    required Map<String, IngredientPriceEntry> catalog,
    required String name,
    required double quantity,
    required String unit,
  }) {
    if (catalog.isEmpty || quantity <= 0) return null;
    final key = normalizeKey(name);
    if (key.isEmpty) return null;

    var entry = catalog[key];
    if (entry == null) {
      for (final e in catalog.entries) {
        if (e.key.length >= 4 &&
            (key.contains(e.key) || e.key.contains(key))) {
          entry = e.value;
          break;
        }
      }
    }
    if (entry == null) return null;

    final convertedQty = IngredientUnitNormalizer.convert(
      quantity,
      MeasurementUnit.fromString(unit),
      MeasurementUnit.fromString(entry.unit),
    );
    if (convertedQty == null) return null;

    return (
      estimatedPrice: convertedQty * entry.unitPrice,
      currency: entry.currency,
      entry: entry,
    );
  }

  static GroceryBudgetEstimate estimateList({
    required Map<String, IngredientPriceEntry> catalog,
    required Iterable<({String name, double quantity, String unit})> items,
    String defaultCurrency = 'PEN',
  }) {
    double total = 0.0;
    int priced = 0;
    int count = 0;
    var currency = defaultCurrency;

    for (final item in items) {
      count++;
      final est = estimateItem(
        catalog: catalog,
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
      );
      if (est != null) {
        total += est.estimatedPrice;
        priced++;
        currency = est.currency;
      }
    }

    return GroceryBudgetEstimate(
      totalEstimated: total,
      pricedCount: priced,
      totalCount: count,
      currency: currency,
    );
  }
}

/// Estado reactivo del catálogo de precios históricos.
class IngredientPriceCatalogState {
  final Map<String, IngredientPriceEntry> catalog;
  final bool isLoaded;

  const IngredientPriceCatalogState({
    this.catalog = const {},
    this.isLoaded = false,
  });
}

class IngredientPriceCatalogNotifier
    extends Notifier<IngredientPriceCatalogState> {
  final _service = IngredientPriceService();

  @override
  IngredientPriceCatalogState build() {
    Future.microtask(load);
    return const IngredientPriceCatalogState();
  }

  Future<void> load() async {
    final map = await _service.loadCatalog();
    state = IngredientPriceCatalogState(catalog: map, isLoaded: true);
  }

  Future<void> recordPurchase({
    required String name,
    required double quantity,
    required String unit,
    required double totalPrice,
    String currency = 'PEN',
    String source = 'walletai',
  }) async {
    await _service.recordPurchase(
      name: name,
      quantity: quantity,
      unit: unit,
      totalPrice: totalPrice,
      currency: currency,
      source: source,
    );
    await load();
  }
}

final ingredientPriceCatalogProvider = NotifierProvider<
    IngredientPriceCatalogNotifier, IngredientPriceCatalogState>(
  IngredientPriceCatalogNotifier.new,
);

/// Puente inteligente entre WalletAI y los módulos de MyLifeOS (Finanzas, Despensa, Armario).
class WalletPantryBridgeService {
  static const _importedTxKey = 'wallet_pantry_imported_tx_ids_v1';
  static const _hideAmountsPrefKey = 'finanzas_hide_amounts_v1';

  static const _foodKeywords = [
    'alimentacion',
    'alimentación',
    'supermercado',
    'mercado',
    'despensa',
    'viveres',
    'víveres',
    'abarrotes',
    'fruta',
    'verdura',
    'carniceria',
    'carnicería',
    'polleria',
    'panaderia',
    'panadería',
    'compras',
  ];

  static const _wardrobeKeywords = [
    'ropa',
    'calzado',
    'vestuario',
    'zapato',
    'zapatilla',
    'prenda',
    'moda',
  ];

  static const _healthKeywords = [
    'salud',
    'farmacia',
    'gimnasio',
    'nutricion',
    'nutrición',
    'medico',
    'médico',
  ];

  static const _restaurantNoiseKeywords = [
    'restaurante',
    'restaurant',
    'menu del dia',
    'menú del día',
    'delivery',
    'rappi',
    'pedidosya',
    'uber eats',
    'chifa',
    'cevicher',
    'cafeteria',
    'cafetería',
    'starbucks',
    'kfc',
    'mcdonald',
    'pizza',
    'almuerzo en',
    'cena en',
  ];

  /// Clasifica una transacción en `'cocina'`, `'armario'`, `'salud'` o `null` (irrelevante/privada).
  static String? classifyRelevantModule(Map<String, dynamic> tx) {
    final category = (tx['category'] ?? '').toString().toLowerCase();
    final name = (tx['name'] ?? tx['description'] ?? '').toString().toLowerCase();
    final combined = '$category $name';

    if (tx['items'] is List && (tx['items'] as List).isNotEmpty) {
      return 'cocina';
    }
    if (_foodKeywords.any(combined.contains)) return 'cocina';
    if (_wardrobeKeywords.any(combined.contains)) return 'armario';
    if (_healthKeywords.any(combined.contains)) return 'salud';
    return null;
  }

  static bool isRelevantToMyLifeOS(Map<String, dynamic> tx) =>
      classifyRelevantModule(tx) != null;

  static Future<bool> getHideAmounts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hideAmountsPrefKey) ?? false;
  }

  static Future<void> setHideAmounts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideAmountsPrefKey, value);
  }

  static String txStableKey(Map<String, dynamic> tx) {
    final explicitId = tx['id']?.toString().trim();
    if (explicitId != null && explicitId.isNotEmpty) return explicitId;
    final date = tx['date']?.toString().trim() ?? '';
    final name = (tx['name'] ?? tx['description'] ?? '').toString().trim();
    final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    return '${date}_${name.toLowerCase()}_${amt.toStringAsFixed(2)}';
  }

  Future<Set<String>> loadProcessedTxKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_importedTxKey) ?? const []).toSet();
  }

  Future<void> markTxProcessed(String txKey) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_importedTxKey) ?? const []).toList();
    if (!current.contains(txKey)) {
      current.add(txKey);
      // Conservar últimos 300 registros para evitar crecimiento ilimitado
      final trimmed = current.length > 300
          ? current.sublist(current.length - 300)
          : current;
      await prefs.setStringList(_importedTxKey, trimmed);
    }
  }

  /// Parsea texto libre de compra de supermercado (ej. `"Compra de tomates 10 unidades"`,
  /// `"2 kg de arroz"` o `"Tomates x10"`). Retorna `null` si parece comida preparada o genérica.
  static ({String name, double quantity, String unit})? parseGroceryDescription(
    String rawText,
  ) {
    final original = rawText.trim();
    if (original.isEmpty) return null;
    final lower = original.toLowerCase();

    if (_restaurantNoiseKeywords.any(lower.contains)) return null;
    if (lower.startsWith('compra despensa') ||
        lower == 'supermercado' ||
        lower == 'mercado') {
      return null;
    }

    var cleaned = original
        .replaceFirst(
            RegExp(r'^(?:compra|compras|compre|compré|gasto)\s+(?:de\s+|en\s+)?',
                caseSensitive: false),
            '')
        .trim();
    if (cleaned.isEmpty) return null;

    const unitGroup =
        r'(?:unidades|unidad|uds?|kilos?|kg|gramos?|gr?|litros?|lt?|ml|mililitros?|paquetes?|paq|botellas?|latas?|cajas?|bolsas?|docenas?|tazas?)';

    // Patrón 1: "2 kg de arroz" o "10 unidades tomate"
    final prefixQtyRegex = RegExp(
      '^(\\d+(?:[.,]\\d+)?)\\s*($unitGroup)?\\s*(?:de\\s+)?(.+)\$',
      caseSensitive: false,
    );
    final m1 = prefixQtyRegex.firstMatch(cleaned);
    if (m1 != null) {
      final qty = double.tryParse(m1.group(1)!.replaceAll(',', '.'));
      final rawUnit = m1.group(2) ?? 'unidades';
      final name = _cleanProductName(m1.group(3) ?? '');
      if (qty != null && qty > 0 && name.length >= 2) {
        return (
          name: _capitalize(name),
          quantity: qty,
          unit: MeasurementUnit.fromString(rawUnit).label,
        );
      }
    }

    // Patrón 2: "Tomates 10 unidades" / "Tomates x 10" / "Pollo 2.5 kg"
    final suffixQtyRegex = RegExp(
      '^(.+?)\\s+(?:x\\s*)?(\\d+(?:[.,]\\d+)?)\\s*($unitGroup)?\$',
      caseSensitive: false,
    );
    final m2 = suffixQtyRegex.firstMatch(cleaned);
    if (m2 != null) {
      final name = _cleanProductName(m2.group(1) ?? '');
      final qty = double.tryParse(m2.group(2)!.replaceAll(',', '.'));
      final rawUnit = m2.group(3) ?? 'unidades';
      if (qty != null && qty > 0 && name.length >= 2) {
        return (
          name: _capitalize(name),
          quantity: qty,
          unit: MeasurementUnit.fromString(rawUnit).label,
        );
      }
    }

    return null;
  }

  static String _cleanProductName(String raw) => raw
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(RegExp(r'^de\s+', caseSensitive: false), '')
      .trim();

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Extrae ítems comprados de una sola transacción (para botón rápido en Finanzas).
  static List<WalletGroceryCandidate> extractCandidatesForTx(
    Map<String, dynamic> tx, {
    String currency = 'PEN',
  }) {
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount > 0 && tx['items'] == null) return const [];
    if (classifyRelevantModule(tx) != 'cocina') return const [];

    final key = txStableKey(tx);
    final date = tx['date']?.toString();
    final desc =
        (tx['name'] ?? tx['description'] ?? 'Compra WalletAI').toString();
    final rawItems = tx['items'];
    if (rawItems is List && rawItems.isNotEmpty) {
      final list = <WalletGroceryCandidate>[];
      for (final item in rawItems) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final itemName = (map['name'] ?? map['ingredientName'] ?? '')
            .toString()
            .trim();
        final qty = (map['quantity'] as num?)?.toDouble() ?? 1.0;
        final unit = MeasurementUnit.fromString(
          (map['unit'] ?? 'unidades').toString(),
        ).label;
        final itemPrice = (map['totalPrice'] as num?)?.toDouble() ??
            (map['price'] as num?)?.toDouble();

        if (itemName.isNotEmpty && qty > 0) {
          list.add(WalletGroceryCandidate(
            transactionKey: key,
            rawDescription: desc,
            itemName: _capitalize(itemName),
            quantity: qty,
            unit: unit,
            totalPrice: itemPrice ??
                (rawItems.length == 1 && amount != 0 ? amount.abs() : null),
            currency: currency,
            date: date,
          ));
        }
      }
      return list;
    }

    final parsed = parseGroceryDescription(desc);
    if (parsed == null) return const [];
    return [
      WalletGroceryCandidate(
        transactionKey: key,
        rawDescription: desc,
        itemName: parsed.name,
        quantity: parsed.quantity,
        unit: parsed.unit,
        totalPrice: amount != 0 ? amount.abs() : null,
        currency: currency,
        date: date,
      ),
    ];
  }

  /// Extrae ítems comprados en WalletAI que pueden ingresar a Despensa.
  Future<List<WalletGroceryCandidate>> extractPendingGroceryCandidates(
    WalletSummary? summary,
  ) async {
    if (summary == null) return const [];
    final processed = await loadProcessedTxKeys();
    final candidates = <WalletGroceryCandidate>[];

    final allTx = <Map<String, dynamic>>[
      ...summary.recentTransactions,
      if (summary.rawMetadata?['pantryCandidates'] is List)
        for (final raw in summary.rawMetadata!['pantryCandidates'] as List)
          if (raw is Map) Map<String, dynamic>.from(raw),
    ];

    for (final tx in allTx) {
      final key = txStableKey(tx);
      if (processed.contains(key)) continue;
      candidates.addAll(
        extractCandidatesForTx(tx, currency: summary.currency),
      );
    }

    return candidates;
  }
}

final walletGroceryBridgeProvider =
    Provider<WalletPantryBridgeService>((_) => WalletPantryBridgeService());

class _RefreshCounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final walletPendingGroceryRefreshProvider =
    NotifierProvider<_RefreshCounterNotifier, int>(_RefreshCounterNotifier.new);

final walletGroceryCandidatesProvider =
    FutureProvider.autoDispose<List<WalletGroceryCandidate>>((ref) async {
  ref.watch(walletPendingGroceryRefreshProvider);
  final summary = await ref.watch(walletSummaryProvider.future);
  final bridge = ref.watch(walletGroceryBridgeProvider);
  return bridge.extractPendingGroceryCandidates(summary);
});
