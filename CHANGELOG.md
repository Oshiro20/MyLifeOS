# Changelog

Todos los cambios notables en este proyecto serán documentados aquí.
El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

## [1.2.5+21] - 2026-04-05 - RELEASE

### Added
- **Navegación desde Sugeridas a Detalle de Receta** - Tap en tarjeta abre vista completa
- **Botón "Cocinar esta receta"** en tarjetas de sugerencias
- **Eliminar items individuales** de la lista de compras
- **Limpiar lista completa de compras** con confirmación
- **Limpiar solo items comprados** de la lista de compras
- **Action bar con contadores** en lista de compras (total, pendientes)
- **Ver detalle completo de receta** desde sugerencias (ingredientes + instrucciones)

### Fixed
- **Chef IA FAB visibility** - Reposicionado para evitar overlap con bottomNavigationBar
- FABs ahora en `bottom: 160` (Chef IA) y `bottom: 96` (Agregar receta)

---

## [1.2.4+20] - 2026-04-05

### Added
- Pull-to-refresh en Finanzas y Recetas tabs
- Image compression utility (`ImageCompressionUtil`) para reducir tamaño de fotos
- Unit tests para BackupService (10 tests)
- Export de utilidades de compresión en barrel file de core

### Changed
- **Versión actualizada:** 1.2.3+19 → 1.2.4+20
- Optimizado rendimiento de listas con ListView.builder
- Documentación actualizada con todos los cambios recientes

### Fixed
- Migración deprecated: `dialogBackgroundColor` → `dialogTheme`
- Migración deprecated: `Matrix4.scale()` → `Matrix4.diagonal3Values()`
- Async context safety en navegación de home screen y outfit builder
- String interpolation brace en dashboard_tab.dart

---

## [1.2.3+19] - 2026-04-05

### Added
- `package_info_plus` dependency to mobile app for version checking
- `go_router` dependency to cocina feature package
- `MealEvaluation` entity with `healthScore` and `FoodClassification` enum
- Proper error handling with `mounted` checks in async operations
- Auto-backup service initialization in main.dart

### Changed
- **Migrated from deprecated `dialogBackgroundColor` to `dialogTheme`** in main.dart
- **Fixed deprecated `Matrix4.scale()` → `Matrix4.diagonal3Values()`** in mannequin canvas
- **Updated `smartCasual` enum naming** (already compliant with lowerCamelCase)
- Consolidated duplicate `MealLog` entities into single `MealEvaluation` model
- Improved async context safety in home screen and outfit builder

### Fixed
- **Removed 8 compilation warnings** (unused imports, fields, elements)
- **Fixed broken unit tests** for domain, armario, and foodcoach packages
- **Resolved `use_build_context_synchronously` errors** in navigation flows
- **Fixed unnecessary brace** in string interpolation (dashboard_tab.dart)
- **Resolved ambiguous import conflicts** between Flutter and vector_math
- Removed obsolete entity files: `garment.dart`, `meal_log.dart`
- Deleted temporary/backup files from project root

### Removed
- Obsolete `packages/domain/lib/src/armario/entities/garment.dart` (replaced by `WardrobeGarment`)
- Obsolete `packages/domain/lib/src/foodcoach/entities/meal_log.dart` (duplicate of `MealEvaluation`)
- `apps/mobile/lib/screens/home_screen_backup.dart`
- `packages/core/test_gemini.dart`
- All analysis output `.txt` files from project root
- `fix_imports.py`, `DART_VALIDATION_REPORT.md`, `ERROR_CORRECTIONS.md`, `IMPROVEMENTS_IMPLEMENTED.md`

---

## [Unreleased] - MVP V1 Phase

### Added
- Multi-package folder structure (apps, core, data, domain, features).
- Drift Database scaffolding (`packages/data/lib/src/local/tables.dart`).
- Local Backup module structure for future encryption export.

### Changed
- Refactored Database schemas to avoid duplicate tables (Garments vs WardrobeGarments).

### Fixed
- Fixed duplicated test suites.
