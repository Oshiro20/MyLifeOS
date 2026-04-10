# Prevención de Problemas Críticos - Guía de Mantenimiento

## ⚠️ Problemas Históricos y Cómo Evitarlos

Este documento registra TODOS los problemas críticos que ocurrieron en MyLifeOS desde v1.0.0 hasta v3.5.5, con sus causas raíz y cómo prevenirlos en el futuro.

---

## 🔑 1. API Keys Expuestas / Desincronizadas

### Problema (v3.5.3)
- **Síntoma**: Chef IA devolvía "Gemini devolvió una respuesta vacía"
- **Causa raíz 1**: La API key de Gemini estaba **hardcodeada** en `ai_service.dart`
- **Causa raíz 2**: `apps/mobile/.env` tenía una key DIFERENTE al root `.env`
- **Causa raíz 3**: La key fue expuesta en commits de Git y tuvo que ser revocada

### Cómo se Manifestó
| Versión | Problema |
|---------|----------|
| v3.4.8-v3.5.2 | API key no se cargaba, respuesta vacía |
| v3.5.3 | Key hardcodeada expuesta en Git |
| v3.5.4 | `.env` desincronizado entre root y apps/mobile |

### ✅ Prevención

**REGLA DE ORO: NUNCA hardcodear API keys en el código**

1. **Las API keys SOLO van en `apps/mobile/.env`**
2. **NUNCA commitear `.env` a Git** (verificar `.gitignore`)
3. **Sincronizar** `apps/mobile/.env` con el root `.env` si ambos existen
4. **Si una key se expone**, revocarla inmediatamente en el proveedor y generar una nueva

**Verificación antes de commitear:**
```bash
# Buscar API keys en código fuente
grep -r "AIzaSy" packages/ apps/
grep -r "sk-" packages/ apps/  # Para OpenAI
grep -r "gsk_" packages/ apps/ # Para Groq
```

**En `ai_service.dart` (CORRECTO):**
```dart
// Cargar desde .env (bundled en APK como asset)
String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
if (apiKey.isEmpty) {
  debugPrint('❌ GEMINI_API_KEY not configured');
}
// NUNCA hacer esto:
// apiKey = 'AIzaSy...';  ← ¡PROHIBIDO!
```

---

## 🤖 2. Chef IA Roto - Análisis Completo

### Problema (v3.1.0 - v3.5.3)
El Chef IA dejó de funcionar completamente después de v3.0.0.

### Causas Raíz Múltiples

| # | Causa | Versión que lo introdujo | Fix |
|---|-------|--------------------------|-----|
| 1 | Prompt simplificado (200→40 líneas) | v3.1.0 | Restaurar prompt detallado |
| 2 | Cambio a `List<String>? mediaPaths` | v3.1.0 | Volver a `String? mediaPath` |
| 3 | Sin timeout en llamadas a Gemini | v3.1.0 | Timeout de 60s |
| 4 | `extractRecipeFromImages()` eliminado | v3.1.0 | Restaurar método |
| 5 | Modelo cambiado a `gemini-1.5-flash` | v3.4.7 | Usar `gemini-2.5-flash` |
| 6 | Safety filters bloqueaban cocina | Siempre | Agregar `safetySettings` |
| 7 | Caché offline devolvía respuestas vacías | v3.1.0 | Desactivar caché para recipes |

### ✅ Checklist de Verificación del Chef IA

Antes de cualquier cambio en archivos relacionados con Chef IA:

- [ ] `packages/core/lib/src/services/ai_service.dart`
  - [ ] Modelo = `gemini-2.5-flash` (NO 1.5-flash)
  - [ ] Prompt detallado con 8 pasos de análisis
  - [ ] `safetySettings` con `HarmBlockThreshold.none`
  - [ ] Timeout de 60 segundos
  - [ ] NO usar `_generateWithCache` para `extractRecipe()`
  - [ ] `extractRecipe()` usa `String? mediaPath` (NO `List<String>`)
  - [ ] `extractRecipeFromImages()` existe y funciona

- [ ] `packages/core/lib/src/services/tiktok_service.dart`
  - [ ] Endpoint order: `/tiktok/info` primero
  - [ ] Timeout de 30s
  - [ ] Debug logging activo

- [ ] `packages/domain/lib/src/cocina/repositories/i_ai_recipe_extractor.dart`
  - [ ] Firma: `Future<String?> extractRecipeJson({String? textContext, String? mediaPath})`

- [ ] `apps/mobile/.env`
  - [ ] `GEMINI_API_KEY` configurada y válida
  - [ ] `TIKTOK_API_KEY` configurada y válida

**Ver automatizada:** Ejecutar `flutter test packages/features/cocina/test/` después de cambios.

---

## 🏷️ 3. Categoría de Receta que se Perdía

### Problema (v3.5.4)
- **Síntoma**: Al guardar una receta como "Postre", al cerrar/abrir la app aparecía sin categoría
- **Causa raíz**: La tabla `Recipes` en Drift NO tenía columna `mealType`
- **Impacto**: `tipoComida` se perdía en cada save/load cycle

### Cómo se Detectó
1. Usuario guardaba receta con categoría
2. Cerraba la app
3. Reabría y la categoría era `null`
4. Los filtros de categoría no funcionaban para recetas de usuario

### ✅ Prevención

**Cuando se añade un campo nuevo a una entidad:**

1. **Actualizar la tabla Drift** (`tables.dart`):
   ```dart
   TextColumn get mealType => text().nullable()();
   ```

2. **Crear migración** (`database.dart`):
   ```dart
   if (from < 15) {
     await m.addColumn(recipes, recipes.mealType);
   }
   ```

3. **Actualizar schemaVersion**: Incrementar en 1

4. **Actualizar el mapper** `_toRecipe`:
   ```dart
   tipoComida: r.mealType != null ? MealType.values.firstWhere(...) : null,
   ```

5. **Actualizar save/update**: Incluir el campo en `RecipesCompanion`

6. **Regenerar código Drift**:
   ```bash
   cd packages/data && flutter pub run build_runner build --delete-conflicting-outputs
   ```

7. **Verificar**: `flutter analyze` debe pasar sin errores

---

##  4. Filtros de UI Incorrectos

### Problema (v3.5.4)
- **Síntoma**: La pestaña Recetas mostraba chips "Desayuno/Almuerzo/Cena"
- **Causa raíz**: Se filtraba por `MealType.values` incluyendo períodos de comida
- **Confusión**: Desayuno/Almuerzo/Cena son **períodos de comida**, no **categorías de receta**

### Categorías vs Períodos

| Tipo | Valores | Uso |
|------|---------|-----|
| **Categorías de Receta** | Entrada, Sopa, Seco, Postre, Mazamorra, Bebida, Snack, Jugo | Filtrar recetas en pestaña Recetas |
| **Períodos de Comida** | Desayuno, Almuerzo, Cena | Planificador semanal, FoodCoach |

### ✅ Prevención

Antes de mostrar `MealType.values` en UI:
```dart
// CORRECTO: Solo categorías de receta
MealType.values.where((t) =>
    t != MealType.otro &&
    t != MealType.desayuno &&
    t != MealType.almuerzo &&
    t != MealType.cena)

// INCORRECTO: Muestra períodos de comida
MealType.values.where((t) => t != MealType.otro)
```

---

## 📋 Checklist Pre-Release

Antes de lanzar CUALQUIER versión:

### Código
- [ ] `flutter analyze` pasa sin errores
- [ ] `flutter test` pasa (si hay tests)
- [ ] No hay API keys hardcodeadas (`grep -r "AIzaSy" packages/ apps/`)
- [ ] `apps/mobile/.env` tiene las keys correctas
- [ ] `.env` NO está en Git (`git ls-files | grep .env`)

### Base de Datos
- [ ] `schemaVersion` actualizado si hay cambios en tablas
- [ ] Migración `onUpgrade` incluye el nuevo campo
- [ ] `build_runner` ejecutado después de cambios en tablas
- [ ] Mapper `_toXxx` lee el nuevo campo
- [ ] `saveXxx` y `updateXxx` guardan el nuevo campo

### Funcionalidad Crítica
- [ ] Chef IA funciona (probar con video de TikTok)
- [ ] Chef IA funciona (probar con video de galería)
- [ ] Categorías de receta persisten al cerrar/abrir app
- [ ] Filtros de Recetas muestran solo categorías válidas

### Versionado
- [ ] `pubspec.yaml` version incrementado
- [ ] Git tag creado (`git tag v3.x.x`)
- [ ] APK compilado con la versión correcta
- [ ] Release en GitHub con APK adjunto

---

## 🚨 Protocolo de Emergencia: API Key Expuesta

Si una API key se expone en Git:

1. **INMEDIATAMENTE**: Revocar la key en el proveedor (Google AI Studio, RapidAPI, etc.)
2. **Eliminar** la key del código fuente
3. **Generar nueva key** en el proveedor
4. **Actualizar** `apps/mobile/.env` con la nueva key
5. **Rebuild** el APK
6. **Verificar** que no hay rastros de la key vieja:
   ```bash
   git log --all -p | grep "AIzaSy"  # Buscar en historial
   ```
7. **Considerar** limpiar el historial de Git:
   ```bash
   git filter-repo --replace-text <(echo "AIzaSyVIEJA==>AIzaSyNUEVA")
   git push --force
   ```

---

## 📞 Contacto de Emergencia

| Rol | Persona | Contacto |
|-----|---------|----------|
| Lead Developer | Oshiro20 | orbezorosas123@gmail.com |
| Documentación | Este archivo | `docs/CRITICAL_ISSUES_PREVENTION.md` |

---

**Última actualización:** 2026-04-10
**Versión:** v3.5.5
**Estado:** Activo - Actualizar con cada nuevo problema crítico
