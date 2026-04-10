import 'package:drift/drift.dart';

@DataClassName('MealLogEntry')
class MealLogs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get photoPath => text()();
  IntColumn get classificationIndex => integer()();
  TextColumn get feedback => text()();
  TextColumn get detectedIngredientsCsv =>
      text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

// ───────────────────────── COCINA ────────────────────────────────────────────

@DataClassName('WeeklyMenuEntry')
class WeeklyMenuEntries extends Table {
  TextColumn get id => text()();
  // 1=Mon, 2=Tue, ..., 7=Sun
  IntColumn get dayOfWeek => integer()();
  // 0=Breakfast, 1=Lunch, 2=Dinner
  IntColumn get mealType => integer()();
  // Reference to the recipe
  TextColumn get recipeId => text().references(Recipes, #id)();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  List<TableIndex> get indexes => [
        TableIndex(
            name: 'idx_menu_day_type',
            columns: {dayOfWeek, mealType},
            unique: true),
      ];
}

@DataClassName('InventoryIngredientEntry')
class InventoryIngredients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get primaryCategory =>
      text().withDefault(const Constant('Otros'))();
  TextColumn get subCategory => text().nullable()();
  TextColumn get preparation => text().withDefault(
      const Constant(''))(); // entero, licuado, molido, fresco, etc.
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  DateTimeColumn get expirationDate => dateTime().nullable()();
  TextColumn get imageAssetId => text().nullable()();
  TextColumn get storageArea => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  List<TableIndex> get indexes => [
        TableIndex(
            name: 'idx_ingredients_category', columns: {primaryCategory}),
        TableIndex(name: 'idx_ingredients_expiry', columns: {expirationDate}),
      ];
}

@DataClassName('RecipeEntry')
class Recipes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get durationMinutes => integer().withDefault(const Constant(30))();
  IntColumn get servings => integer().withDefault(const Constant(2))();
  TextColumn get instructionsJson => text().withDefault(const Constant('[]'))();
  TextColumn get tagsCsv => text().withDefault(const Constant(''))();
  TextColumn get imageAssetId => text().nullable()();
  IntColumn get goalIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  // Hybrid System Columns (v2.7.0)
  // 0 = Local/Curated, 1 = API (TheMealDB), 2 = AI Generated
  IntColumn get sourceIndex => integer().withDefault(const Constant(0))();
  // Region for local recipes (e.g., Costa, Sierra, Selva, Internacional)
  TextColumn get region => text().withDefault(const Constant(''))();
  // Difficulty (Fácil, Media, Difícil)
  TextColumn get difficulty => text().withDefault(const Constant('Media'))();
  // External URL for attribution (API source)
  TextColumn get sourceUrl => text().nullable()();
  // Recipe category/meal type (v3.5.4): desayuno, almuerzo, cena, entrada, sopa, seco, postre, mazamorra, bebida, snack, jugo, otro
  TextColumn get mealType => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  List<TableIndex> get indexes => [
        TableIndex(name: 'idx_recipes_source', columns: {sourceIndex}),
        TableIndex(name: 'idx_recipes_region', columns: {region}),
      ];
}

@DataClassName('RecipeIngredientEntry')
class RecipeIngredients extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId => text().references(Recipes, #id)();
  TextColumn get ingredientName => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ApplianceEntry')
class Appliances extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get imageAssetId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ShoppingItemEntry')
class ShoppingItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  BoolColumn get bought => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ───────────────────────── ARMARIO ───────────────────────────────────────────

/// Prendas del armario personal
@DataClassName('WardrobeGarmentEntry')
class WardrobeGarments extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get typeIndex => integer()(); // GarmentType
  TextColumn get primaryColor => text()(); // hex
  TextColumn get secondaryColor => text().withDefault(const Constant(''))();
  IntColumn get styleIndex => integer()(); // GarmentStyle
  TextColumn get material => text().withDefault(const Constant(''))();
  TextColumn get season => text()
      .withDefault(const Constant('all'))(); // all|spring|summer|autumn|winter
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isClean => boolean().withDefault(const Constant(true))();
  BoolColumn get hasRemovableHood =>
      boolean().withDefault(const Constant(false))();
  IntColumn get rating => integer().withDefault(const Constant(0))();
  TextColumn get size => text().nullable()();
  TextColumn get brand => text().nullable()();
  RealColumn get price => real().nullable()();
  TextColumn get imageAssetId => text().nullable()();
  TextColumn get imageDetailsPath => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  List<TableIndex> get indexes => [
        TableIndex(name: 'idx_garments_type', columns: {typeIndex}),
        TableIndex(name: 'idx_garments_favorite', columns: {isFavorite}),
        TableIndex(name: 'idx_garments_clean', columns: {isClean}),
      ];
}

/// Outfits guardados (combinación de prendas)
@DataClassName('OutfitEntry')
class Outfits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get garmentIdsCsv => text()(); // CSV de IDs de WardrobeGarments
  TextColumn get occasion =>
      text().withDefault(const Constant('casual'))(); // casual|formal|sport
  TextColumn get season => text().withDefault(const Constant('all'))();
  IntColumn get timesWorn => integer().withDefault(const Constant(0))();
  DateTime? get lastWornDate => null;
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Atributos físicos del usuario (consentimiento explícito, opcional)
@DataClassName('UserProfileEntry')
class UserProfile extends Table {
  TextColumn get id => text()();
  // Los valores son opcionales — el usuario elige qué ingresar
  TextColumn get skinTone => text().nullable()(); // claro|medio|trigueño|oscuro
  TextColumn get bodyType =>
      text().nullable()(); // delgado|atlético|promedio|robusto
  TextColumn get height => text().nullable()(); // ej: "170"
  TextColumn get weight => text().nullable()(); // ej: "70"
  TextColumn get hairType => text().nullable()(); // lacio|ondulado|rizado
  TextColumn get colorimetry =>
      text().nullable()(); // ej: "invierno", "otoño", "verano", "primavera"
  TextColumn get bodyShape => text()
      .nullable()(); // ej: "triángulo invertido", "reloj de arena", "rectángulo"
  BoolColumn get consentGranted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
