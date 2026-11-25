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
  final String? suggestedCategory;
  final String? suggestedSubCategory;

  const WalletGroceryCandidate({
    required this.transactionKey,
    required this.rawDescription,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.totalPrice,
    this.currency = 'PEN',
    this.date,
    this.suggestedCategory,
    this.suggestedSubCategory,
  });

  double? get unitPrice =>
      (totalPrice != null && totalPrice! > 0 && quantity > 0)
          ? totalPrice! / quantity
          : null;
}

/// Prenda detectada automáticamente en una transacción de WalletAI para Armario.
class WalletWardrobeCandidate {
  final String transactionKey;
  final String itemName;
  final double? price;
  final String currency;
  final int garmentTypeIndex;
  final String? date;

  const WalletWardrobeCandidate({
    required this.transactionKey,
    required this.itemName,
    required this.garmentTypeIndex,
    this.price,
    this.currency = 'PEN',
    this.date,
  });
}

/// Utensilio o electrodoméstico detectado en WalletAI para Cocina (`Appliances`).
class WalletApplianceCandidate {
  final String transactionKey;
  final String name;
  final String type;
  final String? date;

  const WalletApplianceCandidate({
    required this.transactionKey,
    required this.name,
    required this.type,
    this.date,
  });
}

/// Compra de pollo entero / presas pendiente de desglosar en Cocina.
class PendingPoultryBreakdown {
  final String id;
  final String itemName;
  final double quantity;
  final String unit;
  final double? totalPrice;
  final String currency;
  final bool isWholeChicken;
  final DateTime createdAt;

  const PendingPoultryBreakdown({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.totalPrice,
    this.currency = 'PEN',
    required this.isWholeChicken,
    required this.createdAt,
  });

  factory PendingPoultryBreakdown.fromCandidate(WalletGroceryCandidate c) =>
      PendingPoultryBreakdown(
        id: c.transactionKey,
        itemName: c.itemName,
        quantity: c.quantity,
        unit: c.unit,
        totalPrice: c.totalPrice,
        currency: c.currency,
        isWholeChicken:
            WalletPantryBridgeService.isWholeChickenName(c.itemName),
        createdAt: DateTime.now(),
      );

  factory PendingPoultryBreakdown.fromJson(Map<String, dynamic> json) =>
      PendingPoultryBreakdown(
        id: json['id'] as String? ?? '',
        itemName: json['itemName'] as String? ?? 'Pollo',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: json['unit'] as String? ?? 'unidades',
        totalPrice: (json['totalPrice'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'PEN',
        isWholeChicken: json['isWholeChicken'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemName': itemName,
        'quantity': quantity,
        'unit': unit,
        'totalPrice': totalPrice,
        'currency': currency,
        'isWholeChicken': isWholeChicken,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Comida consumida fuera detectada en WalletAI (Restaurante, Almuerzo, Menú, Delivery)
/// para sugerir registro en 1 toque en FoodCoach sin ensuciar la Despensa.
class PendingOutsideMeal {
  final String id;
  final String mealName;
  final double? price;
  final String currency;
  final String? date;
  final DateTime createdAt;

  const PendingOutsideMeal({
    required this.id,
    required this.mealName,
    this.price,
    this.currency = 'PEN',
    this.date,
    required this.createdAt,
  });

  factory PendingOutsideMeal.fromJson(Map<String, dynamic> json) =>
      PendingOutsideMeal(
        id: json['id']?.toString() ?? '',
        mealName: json['mealName']?.toString() ?? 'Comida fuera',
        price: (json['price'] as num?)?.toDouble(),
        currency: json['currency']?.toString() ?? 'PEN',
        date: json['date']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'mealName': mealName,
        'price': price,
        'currency': currency,
        'date': date,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Lote de registros NUEVOS detectados tras el punto de corte para auto-ingresar.
class WalletAutoSyncBatch {
  final bool baselineJustInitialized;
  final List<WalletGroceryCandidate> groceries;
  final List<PendingPoultryBreakdown> poultryBreakdowns;
  final List<WalletWardrobeCandidate> wardrobe;
  final List<WalletApplianceCandidate> appliances;
  final List<PendingOutsideMeal> outsideMeals;
  final List<String> allProcessedKeys;

  const WalletAutoSyncBatch({
    this.baselineJustInitialized = false,
    this.groceries = const [],
    this.poultryBreakdowns = const [],
    this.wardrobe = const [],
    this.appliances = const [],
    this.outsideMeals = const [],
    this.allProcessedKeys = const [],
  });

  bool get hasAny =>
      groceries.isNotEmpty ||
      poultryBreakdowns.isNotEmpty ||
      wardrobe.isNotEmpty ||
      appliances.isNotEmpty ||
      outsideMeals.isNotEmpty;
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
  static const _baselineCutoffKey = 'wallet_bridge_baseline_cutoff_v1';
  static const _pendingPoultryKey = 'wallet_pending_poultry_breakdowns_v1';
  static const _pendingOutsideMealsKey = 'wallet_pending_outside_meals_v1';

  static const _specificChickenCuts = [
    'pechuga',
    'pecho',
    'pierna',
    'entrepierna',
    'encuentro',
    'ala',
    'alita',
    'muslo',
    'filete',
    'molleja',
    'higado',
    'hígado',
    'menudencia',
    'carcasa',
  ];

  static bool isWholeChickenName(String rawName) {
    final norm = IngredientMatcher.normalizeText(rawName);
    return norm.contains('pollo entero') ||
        norm.contains('pollo completo') ||
        norm.contains('pollo sin trozar') ||
        norm == 'pollo';
  }

  static bool isPoultryBreakdownName(String rawName) {
    final norm = IngredientMatcher.normalizeText(rawName);
    if (!norm.contains('pollo')) return false;
    if (_specificChickenCuts.any((cut) => norm.contains(cut))) {
      // Si dijo "presas de pollo" o "pollo trozado" no menciona un corte único específico.
      return norm.contains('presa') || norm.contains('trozad');
    }
    return isWholeChickenName(norm) ||
        norm.contains('presa') ||
        norm.contains('trozad') ||
        norm.contains('cuartos de pollo');
  }

  /// Presas estándar al dividir [chickenCount] pollos enteros:
  /// - [breastInFour] == false → octavos (2 pechugas, 2 piernas, 2 entrepiernas, 2 alas).
  /// - [breastInFour] == true → 10 presas (4 presas de pecho, 2 piernas, 2 entrepiernas, 2 alas).
  static List<({String name, int count})> buildWholeChickenPieces(
    int chickenCount, {
    bool breastInFour = false,
    bool includeOffal = false,
  }) {
    final n = chickenCount < 1 ? 1 : chickenCount;
    return [
      if (breastInFour)
        (name: 'Presa de pecho de pollo', count: 4 * n)
      else
        (name: 'Pechuga de pollo', count: 2 * n),
      (name: 'Pierna de pollo', count: 2 * n),
      (name: 'Entrepierna de pollo', count: 2 * n),
      (name: 'Ala de pollo', count: 2 * n),
      if (includeOffal) (name: 'Menudencia / Carcasa de pollo', count: n),
    ];
  }

  Future<List<PendingPoultryBreakdown>> loadPendingPoultryBreakdowns() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingPoultryKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((e) => PendingPoultryBreakdown.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _savePendingPoultryBreakdowns(
      List<PendingPoultryBreakdown> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingPoultryKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> enqueuePendingPoultryBreakdowns(
      List<PendingPoultryBreakdown> incoming) async {
    if (incoming.isEmpty) return;
    final current = List<PendingPoultryBreakdown>.from(
        await loadPendingPoultryBreakdowns());
    final existingIds = current.map((e) => e.id).toSet();
    for (final item in incoming) {
      if (existingIds.add(item.id)) {
        current.add(item);
      }
    }
    await _savePendingPoultryBreakdowns(current);
  }

  Future<void> resolvePendingPoultryBreakdown(String id) async {
    final current = await loadPendingPoultryBreakdowns();
    final next = current.where((e) => e.id != id).toList();
    await _savePendingPoultryBreakdowns(next);
  }

  Future<List<PendingOutsideMeal>> loadPendingOutsideMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingOutsideMealsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((e) => PendingOutsideMeal.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _savePendingOutsideMeals(List<PendingOutsideMeal> list) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = list.length > 15 ? list.sublist(list.length - 15) : list;
    await prefs.setString(
      _pendingOutsideMealsKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> enqueuePendingOutsideMeals(
      List<PendingOutsideMeal> incoming) async {
    if (incoming.isEmpty) return;
    final current =
        List<PendingOutsideMeal>.from(await loadPendingOutsideMeals());
    final existingIds = current.map((e) => e.id).toSet();
    for (final item in incoming) {
      if (existingIds.add(item.id)) {
        current.add(item);
      }
    }
    await _savePendingOutsideMeals(current);
  }

  Future<void> dismissPendingOutsideMeal(String id) async {
    final current = await loadPendingOutsideMeals();
    final next = current.where((e) => e.id != id).toList();
    await _savePendingOutsideMeals(next);
  }

  static bool _matchesWord(String rawText, String keyword) {
    final text = IngredientMatcher.normalizeText(rawText);
    final k = IngredientMatcher.normalizeText(keyword);
    if (text.isEmpty || k.isEmpty) return false;
    final pattern = RegExp(
      '(^|[^a-z0-9ñ])${RegExp.escape(k)}(?:s|es)?(?=\$|[^a-z0-9ñ])',
    );
    return pattern.hasMatch(text);
  }

  static const _hardBlockedCategories = [
    'transporte',
    'movilidad',
    'pasaje',
    'combustible',
    'servicios',
    'vivienda',
    'alquiler',
    'educacion',
    'educación',
    'entretenimiento',
    'higiene',
    'cuidado personal',
    'limpieza',
    'farmacia',
    'salud',
    'mascotas',
    'regalos',
    'impuestos',
    'transferencia',
    'ahorro',
    'deuda',
    'suscripciones',
    'tecnologia',
    'tecnología',
  ];

  static const _nonPantryNoiseKeywords = [
    'pasaje',
    'colectivo',
    'metropolitano',
    'combi',
    'bus',
    'taxi',
    'uber',
    'indrive',
    'didi',
    'peaje',
    'gasolina',
    'combustible',
    'estacionamiento',
    'bolsa',
    'bolsa grande',
    'bolsa plastica',
    'bolsa reutilizable',
    'condon',
    'condón',
    'preservativo',
    'desodorante',
    'shampoo',
    'champu',
    'champú',
    'acondicionador',
    'jabon',
    'jabón',
    'pasta dental',
    'cepillo dental',
    'enjuague bucal',
    'papel higienico',
    'papel higiénico',
    'servilleta',
    'toalla',
    'pañal',
    'panal',
    'detergente',
    'suavizante',
    'lejia',
    'lejía',
    'lavavajilla',
    'limpiador',
    'esponja',
    'escoba',
    'trapeador',
    'ambientador',
    'insecticida',
    'bloqueador',
    'perfume',
    'colonia',
    'crema facial',
    'rasuradora',
    'gillette',
    'medicamento',
    'pastilla',
    'jarabe',
    'paracetamol',
    'ibuprofeno',
    'vitamina',
    'alcohol medicinal',
    'curita',
    'recarga',
    'internet',
    'luz',
    'alquiler',
    'matricula',
    'mensualidad',
    'cuaderno',
    'lapicero',
    'fotocopia',
    'impresion',
    'construccion',
    'ferreteria',
  ];

  static const _outsideMealSubcategoryKeywords = [
    'restaurante',
    'restaurant',
    'comida fuera',
    'delivery',
    'comida rapida',
    'comida rápida',
    'fast food',
    'cafeteria',
    'cafetería',
    'polleria',
    'pollería',
    'chifa',
    'cevicheria',
    'cevichería',
    'bar',
    'pub',
  ];

  static const _outsideMealNameKeywords = [
    'almuerzo',
    'desayuno',
    'cena',
    'menu',
    'menú',
    'menu del dia',
    'menú del día',
    'ensalada de frutas',
    'ensalada cesar',
    'ensalada césar',
    'pollo a la brasa',
    'ceviche',
    'chifa',
    'chaufa',
    'chaufita',
    'salchichaufa',
    'salchipapa',
    'salchipollo',
    'salchibroaster',
    'salchiburger',
    'mostrito',
    'aeropuerto',
    'combinado',
    'lomo saltado',
    'tallarin saltado',
    'arroz con pollo',
    'seco de res',
    'seco de pollo',
    'aji de gallina',
    'anticucho',
    'caldo de gallina',
    'sopa wantan',
    'causa rellena',
    'papa a la huancaina',
    'papa rellena',
    'tamal',
    'empanada',
    'pan con chicharron',
    'butifarra',
    'sanguche',
    'sandwich',
    'sándwich',
    'broaster',
    'alitas bbq',
    'tequeno',
    'tequeño',
    'makis',
    'sushi',
    'ramen',
    'shawarma',
    'burrito',
    'taco',
    'combo',
    'picarones',
    'pollada',
    'parrillada',
    'hamburguesa',
    'pizza',
    'kfc',
    'mcdonald',
    'bembos',
    'popeyes',
    'starbucks',
    'rappi',
    'pedidosya',
    'uber eats',
    'restaurante',
    'restaurant',
    'delivery',
  ];

  /// Retorna `true` si el texto corresponde claramente a un artículo NO comestible
  /// o a una comida ya servida fuera (nunca debe entrar ni permanecer en Despensa).
  static bool isNonPantryNoiseName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return true;
    if (_nonPantryNoiseKeywords.any((k) => _matchesWord(trimmed, k))) {
      return true;
    }
    if (isOutsideMealName(trimmed)) {
      return true;
    }
    return false;
  }

  /// Retorna `true` si corresponde a una comida servida/consumida fuera de casa.
  static bool isOutsideMealName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return false;
    if (_outsideMealNameKeywords.any((k) => _matchesWord(trimmed, k))) {
      return true;
    }
    // Platos compuestos peruanos tipo "salchichaufa", "salchipollo", "salchibroaster"
    // sin confundirlos con el insumo crudo "salchicha" o "salchichon".
    final norm = IngredientMatcher.normalizeText(trimmed);
    final compoundSalchi = RegExp(r'\bsalchi([a-zñ]{3,})\b').allMatches(norm);
    for (final m in compoundSalchi) {
      final full = m.group(0) ?? '';
      if (full != 'salchicha' &&
          full != 'salchichas' &&
          full != 'salchichon' &&
          full != 'salchichones') {
        return true;
      }
    }
    return false;
  }

  /// Expande multipacks de boleta/supermercado SOLO para el stock de Despensa
  /// (manteniendo WalletAI fiel a la cantidad de packs de la boleta).
  /// Ej: `"LECHE IDEAL 6 PACK 390G"` (qty: 1) -> `name: "Leche Ideal 390g"`,
  /// `quantity: 6`, `unit: "lata"`, `gramsPerUnit: 390`.
  static ({
    String cleanName,
    double expandedQuantity,
    String unit,
    double? gramsPerUnit,
    bool wasExpanded,
  }) expandMultipack(
    String rawName, {
    required double quantity,
    required String unit,
  }) {
    final original = rawName.trim();
    if (original.isEmpty || quantity <= 0) {
      return (
        cleanName: original,
        expandedQuantity: quantity,
        unit: unit,
        gramsPerUnit: null,
        wasExpanded: false,
      );
    }

    // 1. Extraer peso/volumen unitario si existe (ej. 390G, 90g, 1L, 500ML) para equivalencias
    double? gramsPerUnit;
    final weightMatch = RegExp(
      r'\b(\d+(?:[.,]\d+)?)\s*(g|gr|grs|gramos?|kg|ml|l|lt|litros?)\b',
      caseSensitive: false,
    ).firstMatch(original);
    if (weightMatch != null) {
      final val = double.tryParse(weightMatch.group(1)!.replaceAll(',', '.'));
      final u = (weightMatch.group(2) ?? '').toLowerCase();
      if (val != null && val > 0) {
        if (u == 'kg' || u == 'l' || u == 'lt' || u.startsWith('litro')) {
          gramsPerUnit = val * 1000.0;
        } else {
          gramsPerUnit = val;
        }
      }
    }

    // 2. Detectar multiplicador de multipack
    int? packSize;
    RegExpMatch? matchedPattern;

    final patterns = <({RegExp regex, int Function(RegExpMatch) extract})>[
      (
        regex: RegExp(r'\b(\d{1,2})\s*[-]?\s*packs?\b', caseSensitive: false),
        extract: (m) => int.tryParse(m.group(1) ?? '') ?? 0,
      ),
      (
        regex: RegExp(r'\bpacks?\s*(?:x|de)\s*(\d{1,2})\b', caseSensitive: false),
        extract: (m) => int.tryParse(m.group(1) ?? '') ?? 0,
      ),
      (
        regex: RegExp(r'\bsix\s*[-]?\s*pack\b', caseSensitive: false),
        extract: (_) => 6,
      ),
      (
        regex: RegExp(r'\btri\s*[-]?\s*pack\b', caseSensitive: false),
        extract: (_) => 3,
      ),
      (
        regex: RegExp(r'\bbi\s*[-]?\s*pack\b', caseSensitive: false),
        extract: (_) => 2,
      ),
      (
        regex: RegExp(r'\b(?:band(?:eja)?|caja|display|bolsa)\s*x\s*(\d{1,2})\b',
            caseSensitive: false),
        extract: (m) => int.tryParse(m.group(1) ?? '') ?? 0,
      ),
      (
        regex: RegExp(r'\bx\s*(\d{1,2})\s*(?:unds?|unid(?:ades)?|latas?|paqs?|sobres?|bots?)?\b',
            caseSensitive: false),
        extract: (m) => int.tryParse(m.group(1) ?? '') ?? 0,
      ),
      (
        regex: RegExp(r'\bmedia\s+docena\b', caseSensitive: false),
        extract: (_) => 6,
      ),
      (
        regex: RegExp(r'\bdocena\b', caseSensitive: false),
        extract: (_) => 12,
      ),
    ];

    for (final p in patterns) {
      final m = p.regex.firstMatch(original);
      if (m != null) {
        final count = p.extract(m);
        if (count >= 2 && count <= 60) {
          packSize = count;
          matchedPattern = m;
          break;
        }
      }
    }

    if (packSize == null || matchedPattern == null) {
      return (
        cleanName: original,
        expandedQuantity: quantity,
        unit: unit,
        gramsPerUnit: gramsPerUnit,
        wasExpanded: false,
      );
    }

    // Limpiar el token de multipack del nombre para evitar confusión
    final stripped = original
        .replaceRange(matchedPattern.start, matchedPattern.end, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cleanName = stripped.length >= 2 ? _toReadableTitle(stripped) : original;

    // Elegir la unidad real más natural para las unidades sueltas
    var resolvedUnit = MeasurementUnit.fromString(unit).label;
    final lower = cleanName.toLowerCase();
    final isCanned = _matchesWord(lower, 'leche') &&
            (gramsPerUnit != null && gramsPerUnit >= 300 && gramsPerUnit <= 450) ||
        _matchesWord(lower, 'atun') ||
        _matchesWord(lower, 'sardina') ||
        _matchesWord(lower, 'conserva') ||
        _matchesWord(lower, 'cerveza');
    final isPacket = _matchesWord(lower, 'galleta') ||
        _matchesWord(lower, 'wafer') ||
        _matchesWord(lower, 'fideo') ||
        _matchesWord(lower, 'cereal');
    if (isCanned) {
      resolvedUnit = MeasurementUnit.lata.label;
    } else if (isPacket && resolvedUnit == MeasurementUnit.unidades.label) {
      resolvedUnit = MeasurementUnit.paquete.label;
    }

    return (
      cleanName: cleanName,
      expandedQuantity: quantity * packSize,
      unit: resolvedUnit,
      gramsPerUnit: gramsPerUnit,
      wasExpanded: true,
    );
  }

  static String _toReadableTitle(String raw) {
    // Si viene todo en MAYÚSCULAS de boleta (ej. "LECHE IDEAL 390G"), pasarlo a formato legible
    final isAllCaps = raw == raw.toUpperCase() && raw != raw.toLowerCase();
    if (!isAllCaps) return raw;
    return raw.split(' ').map((w) {
      if (w.isEmpty) return w;
      if (RegExp(r'^\d+(?:[.,]\d+)?(?:g|gr|kg|ml|l|lt)$', caseSensitive: false)
          .hasMatch(w)) {
        return w.toLowerCase();
      }
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  static const _foodKeywords = [
    'alimentacion',
    'alimentación',
    'supermercado',
    'mercado',
    'despensa',
    'viveres',
    'víveres',
    'abarrotes',
    'bodega',
    'fruta',
    'verdura',
    'carniceria',
    'carnicería',
    'panaderia',
    'panadería',
    'snack',
    'snacks',
    'dulces',
    'golosinas',
  ];

  static const _wardrobeKeywords = [
    'ropa',
    'calzado',
    'vestuario',
    'zapato',
    'zapatilla',
    'sneaker',
    'prenda',
    'moda',
    'camisa',
    'polo',
    'camiseta',
    'pantalon',
    'pantalón',
    'jean',
    'jogger',
    'buzo',
    'polera',
    'hoodie',
    'casaca',
    'chaqueta',
    'abrigo',
    'chaleco',
    'vestido',
    'blusa',
    'falda',
    'short',
    'chompa',
    'sueter',
    'suéter',
    'bota',
    'botin',
    'sandalia',
    'mocasin',
    'media',
    'calcetin',
    'boxer',
    'pijama',
    'gorra',
    'correa',
    'cinturon',
    'mochila',
    'cartera',
  ];

  static const _applianceKeywords = [
    'licuadora',
    'freidora',
    'air fryer',
    'airfryer',
    'horno',
    'microondas',
    'sarten',
    'sartén',
    'olla',
    'batidora',
    'cafetera',
    'tostadora',
    'procesador',
    'exprimidor',
    'hervidor',
    'wok',
    'arrocer',
    'waflera',
    'extract',
  ];

  static const _genericStoreNames = [
    'supermercado',
    'mercado',
    'bodega',
    'tienda',
    'metro',
    'tottus',
    'wong',
    'plaza vea',
    'plazavea',
    'vivanda',
    'makro',
    'mass',
    'tambe',
    'tambo',
    'oxxo',
    'compras',
    'compra despensa',
    'alimentacion',
    'alimentación',
    'viveres',
    'víveres',
    'abarrotes',
    'movimiento',
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

  /// Clasifica una transacción en `'cocina'`, `'comida_fuera'`, `'armario'`, `'salud'` o `null` (irrelevante/privada).
  /// Respeta estrictamente la categoría, subcategoría y lista de exclusión (nunca asume que cualquier `items` es cocina).
  static String? classifyRelevantModule(Map<String, dynamic> tx) {
    final category = (tx['category'] ?? '').toString().toLowerCase().trim();
    final subcategory =
        (tx['subcategory'] ?? '').toString().toLowerCase().trim();
    final productName = (tx['productName'] ?? '').toString().trim();
    final name =
        (productName.isNotEmpty ? productName : (tx['name'] ?? tx['description'] ?? ''))
            .toString()
            .trim();
    final lowerName = name.toLowerCase();
    final combined = '$category $subcategory $lowerName';

    // 1. Prendas / calzado tienen prioridad si coincide por palabra completa
    if (_wardrobeKeywords.any((k) => _matchesWord(combined, k))) {
      return 'armario';
    }

    // 2. Bloquear explícitamente artículos no comestibles (pasaje, bolsa, condón, desodorante, higiene, etc.)
    if (_nonPantryNoiseKeywords.any((k) => _matchesWord(lowerName, k))) {
      return null;
    }

    // 3. Bloquear categorías ajenas a Despensa/Armario (Transporte, Servicios, Vivienda, Educación, Higiene, etc.)
    if (category.isNotEmpty &&
        _hardBlockedCategories.any((k) => _matchesWord(category, k))) {
      if (_healthKeywords.any((k) => _matchesWord(category, k))) return 'salud';
      return null;
    }

    // 4. Comidas servidas fuera de casa (Restaurante, Delivery, Almuerzo, Menú, Salchichaufa, Ensalada de frutas) -> FoodCoach, NO Despensa
    if (_outsideMealSubcategoryKeywords.any((k) => _matchesWord(subcategory, k)) ||
        isOutsideMealName(lowerName) ||
        _restaurantNoiseKeywords.any((k) => _matchesWord(lowerName, k))) {
      return 'comida_fuera';
    }

    // 5. Alimentación / Supermercado / Mercado / Snacks -> Despensa
    if (_foodKeywords.any((k) => _matchesWord(category, k)) ||
        _foodKeywords.any((k) => _matchesWord(subcategory, k))) {
      return 'cocina';
    }

    if (_healthKeywords.any((k) => _matchesWord(combined, k))) return 'salud';
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

  /// Extrae ítems comprados de una sola transacción (Despensa).
  /// Soporta `items`, `productName`+`quantity`+`unit`, texto con cantidad o producto directo (ej. "Plátano Seda").
  static List<WalletGroceryCandidate> extractCandidatesForTx(
    Map<String, dynamic> tx, {
    String currency = 'PEN',
  }) {
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount > 0 && tx['items'] == null && tx['productName'] == null) {
      return const [];
    }
    if (extractApplianceCandidateForTx(tx) != null) return const [];
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

        if (itemName.isNotEmpty &&
            qty > 0 &&
            !isNonPantryNoiseName(itemName)) {
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
      if (list.isNotEmpty) return list;
    }

    final productName = tx['productName']?.toString().trim();
    if (productName != null &&
        productName.isNotEmpty &&
        !isNonPantryNoiseName(productName)) {
      final qty = (tx['quantity'] as num?)?.toDouble() ?? 1.0;
      final unit = MeasurementUnit.fromString(
        (tx['unit'] ?? 'unidades').toString(),
      ).label;
      return [
        WalletGroceryCandidate(
          transactionKey: key,
          rawDescription: desc,
          itemName: _capitalize(productName),
          quantity: qty > 0 ? qty : 1.0,
          unit: unit,
          totalPrice: amount != 0 ? amount.abs() : null,
          currency: currency,
          date: date,
        ),
      ];
    }

    final parsed = parseGroceryDescription(desc);
    if (parsed != null) {
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

    // Si es compra de alimentos con nombre de producto directo sin dígitos (ej. "Plátano Seda")
    final lowerDesc = desc.trim().toLowerCase();
    final isNoise = _restaurantNoiseKeywords.any((k) => _matchesWord(lowerDesc, k)) ||
        isNonPantryNoiseName(desc);
    final isGenericStore =
        _genericStoreNames.any((g) => lowerDesc == g || lowerDesc.startsWith('$g '));
    if (desc.trim().length >= 2 && !isNoise && !isGenericStore) {
      return [
        WalletGroceryCandidate(
          transactionKey: key,
          rawDescription: desc,
          itemName: _capitalize(desc.trim()),
          quantity: 1.0,
          unit: 'unidades',
          totalPrice: amount != 0 ? amount.abs() : null,
          currency: currency,
          date: date,
        ),
      ];
    }

    return const [];
  }

  /// Detecta compra de ropa/calzado para auto-agregar al Armario.
  static WalletWardrobeCandidate? extractWardrobeCandidateForTx(
    Map<String, dynamic> tx, {
    String currency = 'PEN',
  }) {
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount > 0 && tx['productName'] == null) return null;
    if (classifyRelevantModule(tx) != 'armario') return null;

    final rawName =
        (tx['productName'] ?? tx['name'] ?? tx['description'] ?? '').toString().trim();
    if (rawName.length < 2) return null;
    final lower = rawName.toLowerCase();

    return WalletWardrobeCandidate(
      transactionKey: txStableKey(tx),
      itemName: _capitalize(rawName),
      price: amount != 0 ? amount.abs() : null,
      currency: currency,
      garmentTypeIndex: _inferGarmentTypeIndex(lower),
      date: tx['date']?.toString(),
    );
  }

  static int _inferGarmentTypeIndex(String lower) {
    // Índices alineados con `enum GarmentType` (packages/domain):
    // 0:shirt, 1:tshirt, 2:pants, 3:jeans, 4:shoes, 5:jacket, 6:accessories,
    // 7:dress, 8:shorts, 9:sweater, 10:hoodie, 11:skirt, 12:other,
    // 13:polo, 14:sneakers, 15:boots, 16:sandals
    if (lower.contains('polo')) return 13;
    if (lower.contains('camisa')) return 0;
    if (lower.contains('camiseta')) return 1;
    if (lower.contains('jean')) return 3;
    if (lower.contains('pantalon') || lower.contains('pantalón')) return 2;
    if (lower.contains('zapatilla') || lower.contains('sneaker')) return 14;
    if (lower.contains('bota')) return 15;
    if (lower.contains('sandalia')) return 16;
    if (lower.contains('zapato') || lower.contains('calzado')) return 4;
    if (lower.contains('polera') || lower.contains('hoodie')) return 10;
    if (lower.contains('casaca') || lower.contains('chaqueta') || lower.contains('abrigo')) {
      return 5;
    }
    if (lower.contains('chompa') || lower.contains('sueter') || lower.contains('suéter')) {
      return 9;
    }
    if (lower.contains('vestido')) return 7;
    if (lower.contains('falda')) return 11;
    if (lower.contains('short')) return 8;
    if (lower.contains('gorra') || lower.contains('lentes') || lower.contains('reloj') || lower.contains('cinturon') || lower.contains('accesorio')) {
      return 6;
    }
    return 12;
  }

  /// Detecta compra de electrodomésticos/utensilios de cocina (`Appliances`).
  static WalletApplianceCandidate? extractApplianceCandidateForTx(
    Map<String, dynamic> tx,
  ) {
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount > 0 && tx['productName'] == null) return null;

    final rawName =
        (tx['productName'] ?? tx['name'] ?? tx['description'] ?? '').toString().trim();
    if (rawName.length < 2) return null;
    final lower = rawName.toLowerCase();
    if (!_applianceKeywords.any(lower.contains)) return null;

    return WalletApplianceCandidate(
      transactionKey: txStableKey(tx),
      name: _capitalize(rawName),
      type: lower.contains('sart') || lower.contains('olla') || lower.contains('wok') || lower.contains('cuchillo')
          ? 'Utensilio'
          : 'Electrodoméstico',
      date: tx['date']?.toString(),
    );
  }

  Future<DateTime?> getBaselineCutoff() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_baselineCutoffKey);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  /// Asegura punto de corte inicial: marca las transacciones históricas actuales sin importarlas,
  /// para que SOLO los registros nuevos posteriores disparen auto-importación.
  Future<({DateTime cutoff, bool initializedNow})> ensureBaselineInitialized(
    WalletSummary summary,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final rawCutoff = prefs.getString(_baselineCutoffKey);
    if (rawCutoff != null) {
      final parsed = DateTime.tryParse(rawCutoff);
      if (parsed != null) {
        return (cutoff: parsed, initializedNow: false);
      }
    }

    final cutoff = DateTime.now();
    await prefs.setString(_baselineCutoffKey, cutoff.toIso8601String());
    for (final tx in summary.recentTransactions) {
      await markTxProcessed(txStableKey(tx));
    }
    return (cutoff: cutoff, initializedNow: true);
  }

  static bool _isNewSinceCutoff(Map<String, dynamic> tx, DateTime cutoff) {
    final createdAtRaw = tx['createdAt']?.toString();
    if (createdAtRaw != null && createdAtRaw.isNotEmpty) {
      final dt = DateTime.tryParse(createdAtRaw);
      if (dt != null) {
        return !dt.isBefore(cutoff);
      }
    }
    final dateRaw = tx['date']?.toString();
    if (dateRaw != null && dateRaw.isNotEmpty) {
      final d = DateTime.tryParse(dateRaw);
      if (d != null) {
        final cutoffDay = DateTime(cutoff.year, cutoff.month, cutoff.day);
        return !d.isBefore(cutoffDay);
      }
    }
    return false;
  }

  /// Extrae únicamente las compras NUEVAS posteriores al punto de corte para auto-ingreso.
  /// Usa enfoque híbrido: filtro determinista rápido + clasificador IA en lote opcional
  /// (con respaldo determinista seguro cuando no hay internet o la IA no responde).
  Future<WalletAutoSyncBatch> extractPendingAutoSyncBatch(
    WalletSummary? summary, {
    Future<String?> Function(String prompt)? aiClassifier,
  }) async {
    if (summary == null) return const WalletAutoSyncBatch();
    final baseline = await ensureBaselineInitialized(summary);
    if (baseline.initializedNow) {
      return const WalletAutoSyncBatch(baselineJustInitialized: true);
    }

    final processed = await loadProcessedTxKeys();
    final groceries = <WalletGroceryCandidate>[];
    final poultryBreakdowns = <PendingPoultryBreakdown>[];
    final wardrobe = <WalletWardrobeCandidate>[];
    final appliances = <WalletApplianceCandidate>[];
    final outsideMeals = <PendingOutsideMeal>[];
    final keys = <String>[];

    // Seleccionar solo gastos NUEVOS posteriores al punto de corte
    final newExpenses = <({String key, Map<String, dynamic> tx})>[];
    for (final tx in summary.recentTransactions) {
      final key = txStableKey(tx);
      if (processed.contains(key)) continue;
      if (!_isNewSinceCutoff(tx, baseline.cutoff)) continue;
      final type = (tx['type'] ?? '').toString().toLowerCase();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      if (type == 'income' || type == 'transfer' || amount > 0) {
        keys.add(key);
        continue;
      }

      // Descartar al instante categorías/nombres 100% ajenos (ahorra tokens y latencia)
      final cat = (tx['category'] ?? '').toString().toLowerCase();
      final rawName =
          (tx['productName'] ?? tx['name'] ?? tx['description'] ?? '')
              .toString()
              .trim();
      final isHardBlockedCat = cat.isNotEmpty &&
          _hardBlockedCategories.any((k) => _matchesWord(cat, k)) &&
          !_wardrobeKeywords.any((k) => _matchesWord(rawName, k));
      if (isHardBlockedCat ||
          _nonPantryNoiseKeywords.any((k) => _matchesWord(rawName, k))) {
        keys.add(key);
        continue;
      }

      newExpenses.add((key: key, tx: tx));
    }

    if (newExpenses.isEmpty) {
      return WalletAutoSyncBatch(allProcessedKeys: keys);
    }

    // Capa 2: clasificación inteligente en lote con IA (1 sola llamada para todo el lote nuevo)
    Map<String, Map<String, dynamic>> aiDecisions = const {};
    if (aiClassifier != null) {
      aiDecisions = await _classifyBatchWithAi(
        newExpenses,
        aiClassifier: aiClassifier,
      );
    }

    for (final entry in newExpenses) {
      final key = entry.key;
      final tx = entry.tx;
      final decision = aiDecisions[key];
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final absPrice = amount != 0 ? amount.abs() : null;
      final date = tx['date']?.toString();
      final rawName =
          (tx['productName'] ?? tx['name'] ?? tx['description'] ?? '')
              .toString()
              .trim();
      final qty = (tx['quantity'] as num?)?.toDouble() ?? 1.0;
      final unit = MeasurementUnit.fromString(
        (tx['unit'] ?? 'unidades').toString(),
      ).label;

      if (decision != null) {
        final dest = (decision['destino'] ?? '').toString().toLowerCase().trim();
        final cleanName = (decision['nombre']?.toString().trim().isNotEmpty == true)
            ? _capitalize(decision['nombre'].toString().trim())
            : _capitalize(rawName);

        if (dest == 'ignorar') {
          keys.add(key);
          continue;
        }
        if (dest == 'comida_fuera') {
          if (cleanName.length >= 2) {
            outsideMeals.add(PendingOutsideMeal(
              id: key,
              mealName: cleanName,
              price: absPrice,
              currency: summary.currency,
              date: date,
              createdAt: DateTime.now(),
            ));
          }
          keys.add(key);
          continue;
        }
        if (dest == 'armario') {
          final garmentTypeHint =
              (decision['tipo_prenda'] ?? cleanName).toString().toLowerCase();
          wardrobe.add(WalletWardrobeCandidate(
            transactionKey: key,
            itemName: cleanName,
            price: absPrice,
            currency: summary.currency,
            garmentTypeIndex: _inferGarmentTypeIndex('$garmentTypeHint $cleanName'),
            date: date,
          ));
          keys.add(key);
          continue;
        }
        if (dest == 'utensilio') {
          appliances.add(WalletApplianceCandidate(
            transactionKey: key,
            name: cleanName,
            type: decision['tipo_utensilio']?.toString().trim().isNotEmpty == true
                ? decision['tipo_utensilio'].toString().trim()
                : 'Utensilio',
            date: date,
          ));
          keys.add(key);
          continue;
        }
        if (dest == 'despensa') {
          // Guardrail final de seguridad: nunca meter ruido no-alimento aunque la IA se equivoque
          if (!isNonPantryNoiseName(cleanName) && cleanName.length >= 2) {
            final cand = WalletGroceryCandidate(
              transactionKey: key,
              rawDescription: rawName,
              itemName: cleanName,
              quantity: qty > 0 ? qty : 1.0,
              unit: unit,
              totalPrice: absPrice,
              currency: summary.currency,
              date: date,
              suggestedCategory: decision['categoria_despensa']?.toString().trim(),
              suggestedSubCategory:
                  decision['subcategoria_despensa']?.toString().trim(),
            );
            if (isPoultryBreakdownName(cand.itemName)) {
              poultryBreakdowns.add(PendingPoultryBreakdown.fromCandidate(cand));
            } else {
              groceries.add(cand);
            }
          }
          keys.add(key);
          continue;
        }
      }

      // Fallback determinista offline / si la IA no clasificó este ítem
      final appliance = extractApplianceCandidateForTx(tx);
      if (appliance != null) {
        appliances.add(appliance);
        keys.add(key);
        continue;
      }

      final garment = extractWardrobeCandidateForTx(
        tx,
        currency: summary.currency,
      );
      if (garment != null) {
        wardrobe.add(garment);
        keys.add(key);
        continue;
      }

      if (classifyRelevantModule(tx) == 'comida_fuera') {
        if (rawName.length >= 2) {
          outsideMeals.add(PendingOutsideMeal(
            id: key,
            mealName: _capitalize(rawName),
            price: absPrice,
            currency: summary.currency,
            date: date,
            createdAt: DateTime.now(),
          ));
        }
        keys.add(key);
        continue;
      }

      final gList = extractCandidatesForTx(tx, currency: summary.currency);
      if (gList.isNotEmpty) {
        for (final c in gList) {
          if (isPoultryBreakdownName(c.itemName)) {
            poultryBreakdowns.add(PendingPoultryBreakdown.fromCandidate(c));
          } else {
            groceries.add(c);
          }
        }
        keys.add(key);
      } else {
        keys.add(key);
      }
    }

    return WalletAutoSyncBatch(
      groceries: groceries,
      poultryBreakdowns: poultryBreakdowns,
      wardrobe: wardrobe,
      appliances: appliances,
      outsideMeals: outsideMeals,
      allProcessedKeys: keys,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _classifyBatchWithAi(
    List<({String key, Map<String, dynamic> tx})> items, {
    required Future<String?> Function(String prompt) aiClassifier,
  }) async {
    try {
      final compactList = items.take(15).map((e) {
        final tx = e.tx;
        return {
          'id': e.key,
          'producto': tx['productName'] ?? tx['name'] ?? tx['description'] ?? '',
          'descripcion': tx['name'] ?? tx['description'] ?? '',
          'categoria': tx['category'] ?? '',
          'subcategoria': tx['subcategory'] ?? '',
          'cantidad': tx['quantity'] ?? 1,
          'unidad': tx['unit'] ?? 'unidades',
          'monto': ((tx['amount'] as num?)?.abs() ?? 0).toStringAsFixed(2),
        };
      }).toList();

      final prompt = '''
Eres el enrutador inteligente de compras de MyLifeOS (Perú).
Clasifica cada transacción en su módulo exacto:
- "despensa": ingredientes crudos, alimentos de supermercado/mercado Y TAMBIÉN snacks/dulces empaquetados (galletas, chocolates, helados, barritas, cereales, café, bebidas) para control nutricional.
- "armario": cualquier ropa, calzado, zapatillas, prendas, buzos, medias, ropa interior o accesorios personales.
- "utensilio": utensilios o electrodomésticos de cocina (sartén, olla, licuadora, freidora, etc.).
- "comida_fuera": comidas/platos ya servidos o comprados para comer afuera (almuerzo, menú, cena, desayuno en restaurante, ensalada de frutas, chifa, ceviche, pollo a la brasa, pizza, delivery). NUNCA los mandes a "despensa".
- "ignorar": bolsas de supermercado (ej. "Bolsa grande Plaza Vea"), aseo/higiene (desodorante, shampoo, jabón, papel higiénico), farmacia/condones, limpieza, transporte/pasajes, servicios, papelería o gastos generales.

Categorías válidas para "categoria_despensa":
["Proteínas animales", "Lácteos", "Verduras", "Frutas", "Tubérculos y raíces", "Legumbres", "Cereales y granos", "Harinas y derivados", "Aceites y grasas", "Condimentos y especias", "Salsas", "Endulzantes", "Snacks y dulces", "Otros"]

Tipos válidos para "tipo_prenda":
["polo", "camisa", "camiseta", "pantalon", "jean", "zapatilla", "zapato", "bota", "sandalia", "casaca", "chompa", "polera", "short", "vestido", "falda", "accesorio", "otro"]

Transacciones:
${jsonEncode(compactList)}

Responde SOLO JSON válido con esta forma exacta (sin markdown):
{"items": [{"id": "...", "destino": "despensa|armario|utensilio|comida_fuera|ignorar", "nombre": "Nombre limpio", "categoria_despensa": null, "subcategoria_despensa": null, "tipo_prenda": null}]}
''';

      final raw = await aiClassifier(prompt);
      if (raw == null || raw.trim().isEmpty) return const {};

      final cleaned = raw
          .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end <= start) return const {};
      final decoded = jsonDecode(cleaned.substring(start, end + 1));
      if (decoded is! Map || decoded['items'] is! List) return const {};

      final map = <String, Map<String, dynamic>>{};
      for (final row in decoded['items'] as List) {
        if (row is Map) {
          final id = row['id']?.toString();
          if (id != null && id.isNotEmpty) {
            map[id] = Map<String, dynamic>.from(row);
          }
        }
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  /// Extrae ítems comprados en WalletAI que pueden ingresar a Despensa (manual / banner).
  Future<List<WalletGroceryCandidate>> extractPendingGroceryCandidates(
    WalletSummary? summary,
  ) async {
    if (summary == null) return const [];
    final baseline = await getBaselineCutoff();
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
      if (baseline != null && !_isNewSinceCutoff(tx, baseline)) continue;
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

/// Notifier para compras de pollo pendiente de despiece en octavos/presas.
class PendingPoultryNotifier extends Notifier<List<PendingPoultryBreakdown>> {
  final _bridge = WalletPantryBridgeService();

  @override
  List<PendingPoultryBreakdown> build() {
    Future.microtask(load);
    return const [];
  }

  Future<void> load() async {
    state = await _bridge.loadPendingPoultryBreakdowns();
  }

  Future<void> enqueue(List<PendingPoultryBreakdown> items) async {
    if (items.isEmpty) return;
    await _bridge.enqueuePendingPoultryBreakdowns(items);
    await load();
  }

  Future<void> resolve(String id) async {
    await _bridge.resolvePendingPoultryBreakdown(id);
    await load();
  }
}

final pendingPoultryBreakdownsProvider =
    NotifierProvider<PendingPoultryNotifier, List<PendingPoultryBreakdown>>(
  PendingPoultryNotifier.new,
);

/// Notifier para comidas consumidas fuera detectadas en WalletAI (sugeridas en FoodCoach).
class PendingOutsideMealsNotifier extends Notifier<List<PendingOutsideMeal>> {
  final _bridge = WalletPantryBridgeService();

  @override
  List<PendingOutsideMeal> build() {
    Future.microtask(load);
    return const [];
  }

  Future<void> load() async {
    state = await _bridge.loadPendingOutsideMeals();
  }

  Future<void> enqueue(List<PendingOutsideMeal> items) async {
    if (items.isEmpty) return;
    await _bridge.enqueuePendingOutsideMeals(items);
    await load();
  }

  Future<void> dismiss(String id) async {
    await _bridge.dismissPendingOutsideMeal(id);
    await load();
  }
}

final pendingOutsideMealsProvider =
    NotifierProvider<PendingOutsideMealsNotifier, List<PendingOutsideMeal>>(
  PendingOutsideMealsNotifier.new,
);

/// Equivalencias personalizadas peso ↔ unidades por ingrediente (gramos por 1 unidad)
/// persistidas en MyLifeOS (ej. 1 kg de papa = 6 unidades → 166.7 g/u).
class IngredientEquivalenceService {
  static const _prefKey = 'ingredient_grams_per_unit_v1';

  Future<Map<String, double>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is num && (entry.value as num) > 0)
            entry.key: (entry.value as num).toDouble(),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveGramsPerUnit(String ingredientName, double gramsPerUnit) async {
    if (gramsPerUnit <= 0) return;
    final key = IngredientMatcher.normalizeText(ingredientName);
    if (key.isEmpty) return;
    final current = Map<String, double>.from(await loadAll());
    current[key] = gramsPerUnit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(current));
  }
}

class IngredientEquivalenceNotifier extends Notifier<Map<String, double>> {
  final _service = IngredientEquivalenceService();

  @override
  Map<String, double> build() {
    Future.microtask(load);
    return const {};
  }

  Future<void> load() async {
    try {
      state = await _service.loadAll();
    } catch (_) {}
  }

  Future<void> setGramsPerUnit(String ingredientName, double gramsPerUnit) async {
    final key = IngredientMatcher.normalizeText(ingredientName);
    if (key.isEmpty || gramsPerUnit <= 0) return;
    state = {...state, key: gramsPerUnit};
    try {
      await _service.saveGramsPerUnit(ingredientName, gramsPerUnit);
    } catch (_) {}
  }
}

final ingredientEquivalencesProvider =
    NotifierProvider<IngredientEquivalenceNotifier, Map<String, double>>(
  IngredientEquivalenceNotifier.new,
);

/// Alias aprendidos persistentes (ingrediente de receta -> ingrediente real en despensa),
/// validados por Gemini AI o por el usuario para no repetir consultas a IA.
class IngredientAliasService {
  static const _prefKey = 'learned_ingredient_aliases_v1';

  Future<Map<String, String>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value != null && entry.value.toString().trim().isNotEmpty)
            entry.key: entry.value.toString().trim(),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveAliases(Map<String, String> updates) async {
    if (updates.isEmpty) return;
    final current = Map<String, String>.from(await loadAll());
    updates.forEach((k, v) {
      final nk = IngredientMatcher.normalizeText(k);
      if (nk.isNotEmpty && v.trim().isNotEmpty) {
        current[nk] = v.trim();
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(current));
  }
}

class LearnedIngredientAliasesNotifier extends Notifier<Map<String, String>> {
  final _service = IngredientAliasService();

  @override
  Map<String, String> build() {
    Future.microtask(load);
    return const {};
  }

  Future<void> load() async {
    try {
      state = await _service.loadAll();
    } catch (_) {}
  }

  Future<void> learnAll(Map<String, String> newAliases) async {
    if (newAliases.isEmpty) return;
    final next = Map<String, String>.from(state);
    newAliases.forEach((k, v) {
      final nk = IngredientMatcher.normalizeText(k);
      if (nk.isNotEmpty && v.trim().isNotEmpty) {
        next[nk] = v.trim();
      }
    });
    state = next;
    try {
      await _service.saveAliases(newAliases);
    } catch (_) {}
  }
}

final learnedIngredientAliasesProvider =
    NotifierProvider<LearnedIngredientAliasesNotifier, Map<String, String>>(
  LearnedIngredientAliasesNotifier.new,
);
