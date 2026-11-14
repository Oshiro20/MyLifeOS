import 'dart:io';
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
  // v5 Menú Semanal
  WeeklyMenuEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          debugPrint('🗄️ [DB] Creating all tables...');
          await m.createAll();
          debugPrint('✅ [DB] Database created successfully');
        },
        onUpgrade: (m, from, to) async {
          debugPrint('🔄 [DB] Migrating from version $from to $to');

          if (from < 3) {
            debugPrint('📦 [DB v3] Creating cocina tables...');
            await m.createTable(inventoryIngredients);
            await m.createTable(recipes);
            await m.createTable(recipeIngredients);
            await m.createTable(appliances);
            await m.createTable(shoppingItems);
          }
          if (from < 4) {
            debugPrint('👔 [DB v4] Creating armario tables...');
            await m.createTable(wardrobeGarments);
            await m.createTable(outfits);
            await m.createTable(userProfile);
          }
          if (from < 5) {
            await _safeAddColumn(
                m, userProfile, 'user_profile', userProfile.weight);
          }
          if (from < 6) {
            await _safeAddColumn(m, wardrobeGarments, 'wardrobe_garments',
                wardrobeGarments.hasRemovableHood);
          }
          if (from < 7) {
            await _safeAddColumn(
                m, wardrobeGarments, 'wardrobe_garments', wardrobeGarments.rating);
            await _safeAddColumn(
                m, wardrobeGarments, 'wardrobe_garments', wardrobeGarments.size);
            await _safeAddColumn(
                m, wardrobeGarments, 'wardrobe_garments', wardrobeGarments.brand);
            await _safeAddColumn(
                m, wardrobeGarments, 'wardrobe_garments', wardrobeGarments.price);
          }
          if (from < 8) {
            await _safeAddColumn(m, wardrobeGarments, 'wardrobe_garments',
                wardrobeGarments.imageDetailsPath);
          }
          if (from < 9) {
            await _safeAddColumn(
                m, userProfile, 'user_profile', userProfile.colorimetry);
            await _safeAddColumn(
                m, userProfile, 'user_profile', userProfile.bodyShape);
          }
          if (from < 10 && from >= 3) {
            try {
              // ignore: experimental_member_use
              await m.alterTable(TableMigration(inventoryIngredients));
            } catch (e) {
              debugPrint('⚠️ [DB v10] TableMigration warning: $e');
            }
          }
          if (from < 11) {
            await _safeAddColumn(m, inventoryIngredients, 'inventory_ingredients',
                inventoryIngredients.storageArea);
          }
          if (from < 12) {
            await _safeAddColumn(m, inventoryIngredients, 'inventory_ingredients',
                inventoryIngredients.preparation);
          }
          if (from < 13) {
            await m.createTable(weeklyMenuEntries);
          }
          if (from < 14) {
            await _safeAddColumn(m, recipes, 'recipes', recipes.sourceIndex);
            await _safeAddColumn(m, recipes, 'recipes', recipes.region);
            await _safeAddColumn(m, recipes, 'recipes', recipes.difficulty);
            await _safeAddColumn(m, recipes, 'recipes', recipes.sourceUrl);
          }
          if (from < 15) {
            await _safeAddColumn(m, recipes, 'recipes', recipes.mealType);
          }
          if (from < 16) {
            await _safeAddColumn(m, mealLogs, 'meal_logs', mealLogs.healthScore);
            await _safeAddColumn(m, recipes, 'recipes', recipes.rating);
            await _safeAddColumn(m, wardrobeGarments, 'wardrobe_garments',
                wardrobeGarments.timesWorn);
            await _safeAddColumn(
                m, outfits, 'outfits', outfits.lastWornDate);

            // Depurar duplicados de menú semanal antes de crear índice UNIQUE
            await customStatement('''
              DELETE FROM weekly_menu_entries
              WHERE rowid NOT IN (
                SELECT MAX(rowid)
                FROM weekly_menu_entries
                GROUP BY day_of_week, meal_type
              )
            ''');

            // Crear índices reales (antes declarados sin @TableIndex)
            const indexStatements = [
              'CREATE INDEX IF NOT EXISTS idx_meallogs_timestamp ON meal_logs (timestamp)',
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_menu_day_type ON weekly_menu_entries (day_of_week, meal_type)',
              'CREATE INDEX IF NOT EXISTS idx_ingredients_category ON inventory_ingredients (primary_category)',
              'CREATE INDEX IF NOT EXISTS idx_ingredients_expiry ON inventory_ingredients (expiration_date)',
              'CREATE INDEX IF NOT EXISTS idx_recipes_source ON recipes (source_index)',
              'CREATE INDEX IF NOT EXISTS idx_recipes_region ON recipes (region)',
              'CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe_id ON recipe_ingredients (recipe_id)',
              'CREATE INDEX IF NOT EXISTS idx_garments_type ON wardrobe_garments (type_index)',
              'CREATE INDEX IF NOT EXISTS idx_garments_favorite ON wardrobe_garments (is_favorite)',
              'CREATE INDEX IF NOT EXISTS idx_garments_clean ON wardrobe_garments (is_clean)',
            ];
            for (final sql in indexStatements) {
              await customStatement(sql);
            }
          }

          debugPrint('✅ [DB] Migration completed from v$from to v$to');
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          if (kDebugMode) {
            debugPrint('🔍 [DB] Opening database (v${details.versionNow})');
          }
        },
      );

  Future<void> _safeAddColumn(
    Migrator m,
    TableInfo<Table, dynamic> table,
    String tableName,
    GeneratedColumn column,
  ) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    final exists =
        rows.any((r) => r.read<String>('name') == column.name);
    if (!exists) {
      await m.addColumn(table, column);
    }
  }

  /// Ejecuta WAL checkpoint antes de backup para asegurar consistencia en archivo único.
  Future<void> checkpointWal() async {
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  /// Borra de disco un archivo de imagen local si no es URL remota.
  static Future<void> deleteLocalFileIfPresent(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    if (path.startsWith('http://') || path.startsWith('https://')) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('⚠️ [DB] No se pudo borrar archivo local $path: $e');
    }
  }

  /// Elimina todos los registros de usuario y sus archivos locales asociados.
  Future<void> clearAllUserData() async {
    final garments = await select(wardrobeGarments).get();
    final ingredients = await select(inventoryIngredients).get();
    final recipeRows = await select(recipes).get();
    final logs = await select(mealLogs).get();

    final pathsToDelete = <String?>{
      for (final g in garments) ...[g.imageAssetId, g.imageDetailsPath],
      for (final i in ingredients) i.imageAssetId,
      for (final r in recipeRows) r.imageAssetId,
      for (final m in logs) m.photoPath,
    };

    await transaction(() async {
      await delete(weeklyMenuEntries).go();
      await delete(recipeIngredients).go();
      await delete(recipes).go();
      await delete(inventoryIngredients).go();
      await delete(appliances).go();
      await delete(shoppingItems).go();
      await delete(outfits).go();
      await delete(wardrobeGarments).go();
      await delete(userProfile).go();
      await delete(mealLogs).go();
    });

    for (final path in pathsToDelete) {
      await deleteLocalFileIfPresent(path);
    }
  }
}

/// Usa drift_flutter que maneja sqlite3_flutter_libs automáticamente.
QueryExecutor _openConnection() {
  return driftDatabase(name: 'mylifeos');
}
