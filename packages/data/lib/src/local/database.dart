import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  // v1
  MealLogs,
  // v2
  // v2 (antiguo MediaAssets eliminado)
  // v3 Cocina
  InventoryIngredients, Recipes, RecipeIngredients, Appliances, ShoppingItems,
  // v4 Armario
  WardrobeGarments, Outfits, UserProfile,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // if (from < 2) ... (mediaAssets eliminado)
          if (from < 3) {
            await m.createTable(inventoryIngredients);
            await m.createTable(recipes);
            await m.createTable(recipeIngredients);
            await m.createTable(appliances);
            await m.createTable(shoppingItems);
          }
          if (from < 4) {
            await m.createTable(wardrobeGarments);
            await m.createTable(outfits);
            await m.createTable(userProfile);
          }
          if (from < 5) {
            try {
              await m.addColumn(userProfile, userProfile.weight);
            } catch (_) {}
          }
          if (from < 6) {
            try {
              await m.addColumn(wardrobeGarments, wardrobeGarments.hasRemovableHood);
            } catch (_) {}
          }
          if (from < 7) {
            try {
              await m.addColumn(wardrobeGarments, wardrobeGarments.rating);
              await m.addColumn(wardrobeGarments, wardrobeGarments.size);
              await m.addColumn(wardrobeGarments, wardrobeGarments.brand);
              await m.addColumn(wardrobeGarments, wardrobeGarments.price);
            } catch (_) {}
          }
          if (from < 8) {
            try {
              await m.addColumn(wardrobeGarments, wardrobeGarments.imageDetailsPath);
            } catch (_) {}
          }
          if (from < 9) {
            try {
              await m.addColumn(userProfile, userProfile.colorimetry);
              await m.addColumn(userProfile, userProfile.bodyShape);
            } catch (_) {}
          }
          if (from < 10) {
            try {
              // ignore: experimental_member_use
              await m.alterTable(TableMigration(inventoryIngredients));
            } catch (e) {
              debugPrint('Error migrando v10: $e');
            }
          }
          if (from < 11) {
            try {
              await m.addColumn(inventoryIngredients, inventoryIngredients.storageArea);
            } catch (e) {
              debugPrint('Error migrando v11: $e');
            }
          }
        },
      );
}

/// Usa drift_flutter que maneja sqlite3_flutter_libs automáticamente.
QueryExecutor _openConnection() {
  return driftDatabase(name: 'mylifeos');
}
