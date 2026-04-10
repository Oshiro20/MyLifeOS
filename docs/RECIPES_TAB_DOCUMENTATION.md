# Pestaña Recetas - Documentación Técnica Completa

## 📋 Descripción

La pestaña **Recetas** permite al usuario:
- Ver todas las recetas guardadas (del Chef IA + 315 recetas locales)
- Filtrar por categoría de receta (Entrada, Sopa, Seco, Postre, etc.)
- Buscar recetas por nombre
- Marcar recetas como favoritas
- Ver detalle completo de cada receta

---

## 🏗️ Arquitectura de Datos

### 1. Fuentes de Recetas

| Fuente | Cantidad | Persistencia | `tipoComida` |
|--------|----------|--------------|--------------|
| **Chef IA** | Variable | Drift DB | Extraído por Gemini AI |
| **315 Recetas Locales** | 315 fijas | JSON Asset (`local_recipes.json`) | Definido en `convert_recipes.dart` |
| **Recetas Importadas** | Variable | Drift DB | Extraído por Gemini AI |

### 2. Estructura de la Tabla Recipes (Drift)

```dart
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
  
  // Hybrid System Columns
  IntColumn get sourceIndex => integer().withDefault(const Constant(0))();
  TextColumn get region => text().withDefault(const Constant(''))();
  TextColumn get difficulty => text().withDefault(const Constant('Media'))();
  TextColumn get sourceUrl => text().nullable()();
  
  // v3.5.4: Recipe category (CRÍTICO)
  TextColumn get mealType => text().nullable()();
}
```

---

## 🏷️ Sistema de Categorías (MealType)

### Enum MealType Completo

```dart
enum MealType {
  // Períodos de comida (NO son categorías de receta)
  desayuno('Desayuno', '🌅'),    // ← NO mostrar en filtros de Recetas
  almuerzo('Almuerzo', '🍛'),    // ← NO mostrar en filtros de Recetas
  cena('Cena', '🌙'),            // ← NO mostrar en filtros de Recetas
  
  // Categorías de receta SÍ se muestran en Recetas
  entrada('Entrada', '🥗'),
  sopa('Sopa', '🍲'),
  seco('Seco', '🥘'),            // ← Plato fuerte (antes "almuerzo")
  postre('Postre', '🍰'),
  mazamorra('Mazamorra', '🍮'),
  bebida('Bebida', '🥤'),
  snack('Snack', '🍿'),
  jugo('Jugo', '🧃'),
  otro('Otro', '🍽️');
}
```

### Mapeo de Archivos JSON → MealType

| Archivo JSON | Categoría | MealType |
|--------------|-----------|----------|
| `Entradas_*.json` | Entradas | `entrada` |
| `Sopas_*.json` | Sopas | `sopa` |
| `Segundo_*.json` / `Segundos_*.json` | Segundos/Platos de Fondo | `seco` ✅ |
| `Postre_*.json` / `Postres_*.json` | Postres | `postre` |
| `Bebidas_*.json` | Bebidas | `bebida` |

**NOTA CRÍTICA (v3.5.6):**
- ❌ `Segundos` → `'almuerzo'` ← **INCORRECTO** (almuerzo es período de comida)
- ✅ `Segundos` → `'seco'` ← **CORRECTO** (seco = plato fuerte en cocina peruana)

### Filtros en UI (recipes_tab.dart)

```dart
// CORRECTO: Solo categorías de receta
MealType.values.where((t) =>
    t != MealType.otro &&
    t != MealType.desayuno &&   // ← Excluir períodos
    t != MealType.almuerzo &&    // ← Excluir períodos
    t != MealType.cena)          // ← Excluir períodos
    .map((type) => FilterChip(...))

// RESULTADO: Todas | Entrada | Sopa | Seco | Postre | Mazamorra | Bebida | Snack | Jugo
```

---

## 🔄 Flujo de Datos Completo

### 1. Generación de 315 Recetas Locales

**Script:** `scripts/convert_recipes.dart`

```dart
final Map<String, String> categoriaToTipoComida = {
  'Entradas': 'entrada',
  'Sopas': 'sopa',
  'Segundos / Platos de Fondo': 'seco',  // ✅ CORRECTO
  'Postres': 'postre',
  'Postre': 'postre',
  'Bebidas': 'bebida',
};

Map<String, dynamic> _convertRecipe(...) {
  return {
    ...
    'tipoComida': categoriaToTipoComida[categoria] ?? 'otro',
    'cuisineStyle': regionToCuisineStyle[region],
    ...
  };
}
```

**Para regenerar las 315 recetas:**
```bash
cd d:\Proyectos_Flutter\Aplicativo_Personal
dart run scripts/convert_recipes.dart
```

**Output:** `packages/core/assets/recipes/local_recipes.json`

### 2. Guardado de Recetas (saveRecipe)

**Archivo:** `packages/data/lib/src/repositories/cocina_repository_impl.dart`

```dart
@override
Future<Recipe> saveRecipe(Recipe recipe) async {
  await _db.into(_db.recipes).insertOnConflictUpdate(RecipesCompanion(
    ...
    mealType: Value(recipe.tipoComida?.name),  // ✅ Persistir categoría
  ));
  // ... guardar ingredientes
}
```

### 3. Carga de Recetas (_toRecipe mapper)

```dart
Recipe _toRecipe(RecipeEntry r, List<RecipeIngredientEntry> ings) => Recipe(
  ...
  tipoComida: r.mealType != null && r.mealType!.isNotEmpty
      ? MealType.values.firstWhere(
          (m) => m.name == r.mealType,
          orElse: () => MealType.otro,
        )
      : null,  // ✅ Cargar categoría
);
```

### 4. Carga de Recetas Locales desde JSON

**Archivo:** `packages/core/lib/src/services/local_recipe_database_service.dart`

```dart
MealType? mealType;
final tipoComidaStr = json['tipoComida'] as String?;
if (tipoComidaStr != null) {
  mealType = MealType.values.cast<MealType?>().firstWhere(
        (m) => m!.name == tipoComidaStr,
        orElse: () => null,
      );
}
return Recipe(
  ...
  tipoComida: mealType,  // ✅ Cargar categoría del JSON
);
```

---

## 🚨 Problemas Históricos y Soluciones

### Problema 1: Categoría se Perdía al Cerrar/Abrir App (v3.5.4)

**Síntoma:**
- Usuario guardaba receta como "Postre"
- Cerraba la app
- Reabría y la categoría era `null`
- Filtros no funcionaban para recetas de usuario

**Causa Raíz:**
| Capa | Estado |
|------|--------|
| Entidad `Recipe` | ✅ Campo `tipoComida` existía |
| Tabla Drift `Recipes` | ❌ **NO tenía columna `mealType`** |
| `saveRecipe` | ❌ No guardaba el campo |
| `_toRecipe` mapper | ❌ No leía el campo |

**Solución (v3.5.4):**
1. Añadir columna `mealType` a la tabla `Recipes`
2. Crear migración DB v15
3. Actualizar `saveRecipe` y `updateRecipe`
4. Actualizar mapper `_toRecipe`

**Checklist para Añadir Campos Nuevos:**
- [ ] Añadir columna en `tables.dart`
- [ ] Incrementar `schemaVersion` en `database.dart`
- [ ] Crear migración `onUpgrade`
- [ ] Actualizar mapper `_toXxx`
- [ ] Actualizar `saveXxx` y `updateXxx`
- [ ] Ejecutar `build_runner` en paquete `data`
- [ ] Verificar con `flutter analyze`

### Problema 2: 'almuerzo' en lugar de 'seco' (v3.5.6)

**Síntoma:**
- Las 315 recetas locales tenían `tipoComida: 'almuerzo'`
- "Almuerzo" es un período de comida, NO una categoría de receta
- Confusión semántica en la clasificación

**Causa Raíz:**
En `scripts/convert_recipes.dart`:
```dart
// ❌ ANTES
'Segundos / Platos de Fondo': 'almuerzo',  // ¡INCORRECTO!
```

**Solución (v3.5.6):**
```dart
// ✅ AHORA
'Segundos / Platos de Fondo': 'seco',  // Plato fuerte = Seco
```

**Acción:**
1. Corregir `convert_recipes.dart`
2. Ejecutar `dart run scripts/convert_recipes.dart`
3. Regenerar `local_recipes.json`
4. Rebuild APK

### Problema 3: Filtros Mostraban Desayuno/Almuerzo/Cena (v3.5.4)

**Síntoma:**
La pestaña Recetas mostraba chips:
```
Todas | Desayuno | Almuerzo | Cena | Entrada | Sopa | Seco | Postre | ...
```

**Causa Raíz:**
Se filtraba por `MealType.values.where((t) => t != MealType.otro)`

**Solución:**
Excluir explícitamente los períodos de comida:
```dart
MealType.values.where((t) =>
    t != MealType.otro &&
    t != MealType.desayuno &&
    t != MealType.almuerzo &&
    t != MealType.cena)
```

---

## 📊 Categorías de Receta vs Períodos de Comida

| Concepto | Valores | Uso | Dónde se Usa |
|----------|---------|-----|--------------|
| **Categorías de Receta** | Entrada, Sopa, Seco, Postre, Mazamorra, Bebida, Snack, Jugo | Clasificar recetas por tipo de plato | Pestaña Recetas, filtros, búsqueda |
| **Períodos de Comida** | Desayuno, Almuerzo, Cena | Planificar comidas por momento del día | Plan Semanal, FoodCoach |

**REGLA DE ORO:** 
- **Recetas** se filtran por **categoría** (qué tipo de plato es)
- **Menú Semanal** se organiza por **período** (cuándo se come)

---

## 🧪 Checklist de Verificación

### Después de Cambios en Recetas

- [ ] `flutter analyze` pasa sin errores
- [ ] Las recetas guardadas mantienen su categoría al cerrar/abrir app
- [ ] Filtros de Recetas NO muestran Desayuno/Almuerzo/Cena
- [ ] Filtros muestran: Todas | Entrada | Sopa | Seco | Postre | Mazamorra | Bebida | Snack | Jugo
- [ ] Las 315 recetas locales tienen `tipoComida: 'seco'` (no 'almuerzo')
- [ ] Recetas importadas desde Chef IA guardan su categoría correctamente
- [ ] La búsqueda por categoría funciona correctamente

### Verificación de Datos en DB

```dart
// Verificar que las recetas tienen categoría
final recipes = await db.select(db.recipes).get();
for (final r in recipes) {
  debugPrint('${r.name}: ${r.mealType}');
}

// Estadísticas por categoría
final stats = <String, int>{};
for (final r in recipes) {
  final tipo = r.mealType ?? 'null';
  stats[tipo] = (stats[tipo] ?? 0) + 1;
}
stats.forEach((k, v) => debugPrint('$k: $v'));
```

---

## 📁 Archivos Clave

| Archivo | Función | **NO CAMBIAR SIN DOCUMENTAR** |
|---------|---------|-------------------------------|
| `packages/data/lib/src/local/tables.dart` | Definición de tabla Recipes | ⚠️ Columna `mealType` |
| `packages/data/lib/src/local/database.dart` | Migraciones DB | ⚠️ `schemaVersion`, `onUpgrade` |
| `packages/data/lib/src/repositories/cocina_repository_impl.dart` | Guardar/cargar recetas | ⚠️ `saveRecipe`, `_toRecipe` |
| `scripts/convert_recipes.dart` | Generar 315 recetas locales | ⚠️ `categoriaToTipoComida` map |
| `packages/core/assets/recipes/local_recipes.json` | 315 recetas embebidas | ⚠️ Generado automáticamente |
| `packages/features/cocina/lib/src/screens/recipes_tab.dart` | UI de Recetas | ⚠️ Filtros, chips |
| `packages/domain/lib/src/cocina/entities/recipe.dart` | Entidad Recipe | ⚠️ Campo `tipoComida` |

---

## 🔄 Procedimiento: Añadir Nueva Categoría de Receta

Si necesitas añadir una nueva categoría (ej: "Mazamorra"):

1. **Añadir al enum MealType:**
   ```dart
   // packages/domain/lib/src/cocina/entities/recipe.dart
   enum MealType {
     ...
     mazamorra('Mazamorra', '🍮'),
     ...
   }
   ```

2. **Actualizar filtros en UI:**
   ```dart
   // recipes_tab.dart - si es categoría de receta, NO excluir
   ```

3. **Actualizar convert_recipes.dart (si aplica):**
   ```dart
   categoriaToTipoComida['Mazamorras'] = 'mazamorra';
   ```

4. **Regenerar recetas:**
   ```bash
   dart run scripts/convert_recipes.dart
   ```

5. **Rebuild APK**

---

## 📞 Contacto

| Rol | Persona | Contacto |
|-----|---------|----------|
| Lead Developer | Oshiro20 | orbezorosas123@gmail.com |
| Documentación | Este archivo | `docs/RECIPES_TAB_DOCUMENTATION.md` |

---

**Última actualización:** 2026-04-10
**Versión:** v3.5.6
**Estado:** ✅ Todo corregido y documentado
