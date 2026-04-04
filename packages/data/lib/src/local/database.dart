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
        onCreate: (m) async {
          debugPrint('🗄️ [DB] Creating all tables...');
          await m.createAll();
          debugPrint('✅ [DB] Database created successfully');
        },
        onUpgrade: (m, from, to) async {
          debugPrint('🔄 [DB] Migrating from version $from to $to');

          // if (from < 2) ... (mediaAssets eliminado)
          if (from < 3) {
            debugPrint('📦 [DB v3] Creating cocina tables...');
            await m.createTable(inventoryIngredients);
            await m.createTable(recipes);
            await m.createTable(recipeIngredients);
            await m.createTable(appliances);
            await m.createTable(shoppingItems);
            debugPrint('✅ [DB v3] Cocina tables created');
          }
          if (from < 4) {
            debugPrint('👔 [DB v4] Creating armario tables...');
            await m.createTable(wardrobeGarments);
            await m.createTable(outfits);
            await m.createTable(userProfile);
            debugPrint('✅ [DB v4] Armario tables created');
          }
          if (from < 5) {
            try {
              debugPrint('📏 [DB v5] Adding weight column to userProfile...');
              await m.addColumn(userProfile, userProfile.weight);
            } catch (e) {
              debugPrint('⚠️ [DB v5] Migration failed: $e');
            }
          }
          if (from < 6) {
            try {
              debugPrint('🧥 [DB v6] Adding hasRemovableHood column...');
              await m.addColumn(
                  wardrobeGarments, wardrobeGarments.hasRemovableHood);
            } catch (e) {
              debugPrint('⚠️ [DB v6] Migration failed: $e');
            }
          }
          if (from < 7) {
            try {
              debugPrint(
                  '⭐ [DB v7] Adding rating, size, brand, price columns...');
              await m.addColumn(wardrobeGarments, wardrobeGarments.rating);
              await m.addColumn(wardrobeGarments, wardrobeGarments.size);
              await m.addColumn(wardrobeGarments, wardrobeGarments.brand);
              await m.addColumn(wardrobeGarments, wardrobeGarments.price);
            } catch (e) {
              debugPrint('⚠️ [DB v7] Migration failed: $e');
            }
          }
          if (from < 8) {
            try {
              debugPrint('🖼️ [DB v8] Adding imageDetailsPath column...');
              await m.addColumn(
                  wardrobeGarments, wardrobeGarments.imageDetailsPath);
            } catch (e) {
              debugPrint('⚠️ [DB v8] Migration failed: $e');
            }
          }
          if (from < 9) {
            try {
              debugPrint(
                  '🎨 [DB v9] Adding colorimetry and bodyShape columns...');
              await m.addColumn(userProfile, userProfile.colorimetry);
              await m.addColumn(userProfile, userProfile.bodyShape);
            } catch (e) {
              debugPrint('⚠️ [DB v9] Migration failed: $e');
            }
          }
          if (from < 10) {
            try {
              debugPrint('🔄 [DB v10] Altering inventoryIngredients table...');
              // ignore: experimental_member_use
              await m.alterTable(TableMigration(inventoryIngredients));
            } catch (e) {
              debugPrint('⚠️ [DB v10] Migration failed: $e');
            }
          }
          if (from < 11) {
            try {
              debugPrint('📍 [DB v11] Adding storageArea column...');
              await m.addColumn(
                  inventoryIngredients, inventoryIngredients.storageArea);
            } catch (e) {
              debugPrint('⚠️ [DB v11] Migration failed: $e');
            }
          }

          debugPrint('✅ [DB] Migration completed from v$from to v$to');
        },
        beforeOpen: (details) async {
          if (kDebugMode) {
            debugPrint('🔍 [DB] Opening database');
          }
        },
      );
}

/// Usa drift_flutter que maneja sqlite3_flutter_libs automáticamente.
QueryExecutor _openConnection() {
  return driftDatabase(name: 'mylifeos');
}
