# Pendientes — MyLifeOS v3.2.0

> **Fecha:** 2026-04-09
> **Estado:** Corrección de bugs + mejoras funcionales del módulo Cocina

---

## 🔴 Bugs Críticos (4)

### Bug 1 · Sección "Qué almorzamos hoy" rota
**Ubicación:** `packages/features/cocina/lib/src/screens/suggestions_tab.dart`

**Problema:**
- Error: `Exception: Error al generar sugerencias con IA: Exception: La IA no pudo generar sugerencias`
- Los botones de la sección no funcionan
- Hay demasiados botones redundantes

**Posible causa:** El prompt de Gemini en `what_can_i_cook_use_case.dart` está fallando después de los cambios de serialización.

**Plan:**
- Debuggear el prompt de Gemini
- Simplificar botones (quitar redundantes)
- Mejorar manejo de error con retry

---

### Bug 2 · No hay sección "Lista"
**Ubicación:** `packages/features/cocina/lib/src/screens/`

**Problema:**
- Cuando el usuario agrega "faltantes a la lista" desde una receta, no hay dónde verla
- Los ingredientes se guardan pero no se muestran en ninguna pestaña

**Implementación sugerida:**
- Agregar pestaña "Lista" al navigation bar de Cocina
- O reutilizar la pestaña "Shopping" que ya existe (`shopping_tab.dart`)

---

### Bug 3 · Antojos > Snack vacío
**Ubicación:** `packages/features/cocina/lib/src/screens/antojos_tab.dart`

**Problema:**
- Al seleccionar categoría "Snack" no aparece ninguna receta
- Las otras categorías sí muestran recetas

**Posible causa:** Filtro por `tipoComida` no encuentra recetas con `MealType.snack`

---

### Bug 4 · Importador TikTok roto (regression v3.0.2)
**Ubicación:** `packages/features/cocina/lib/src/screens/recipe_importer_screen.dart`

**Problema:**
- Error: `"Error: Exception: La IA no pudo estructurar la receta. Intenta con otro video más claro"`
- En v3.0.2 funcionaba correctamente

**Posible causa:** Cambio de `extractRecipeFromImages` → `extractRecipe(mediaPath: ...)` alteró el comportamiento

**Plan:**
- Revertir a la lógica que funcionaba en v3.0.2
- O adaptar el nuevo método para soportar múltiples videos

---

## 🟡 Bugs Menores (1)

### Bug 5 · Plan > pantalla gris al ver receta
**Ubicación:** `packages/features/cocina/lib/src/screens/weekly_plan_screen.dart`

**Problema:**
- Al tocar una receta del plan semanal, aparece pantalla gris
- El widget de detalle no se renderiza correctamente

---

## 🟢 Mejoras Funcionales (4)

### Mejora 1 · Botón "Añadir faltantes a lista" en Plan Semanal
**Prioridad:** Alta

**Problema:** El usuario quiere comprar todos los ingredientes de la semana de una vez.

**Implementación:**
- Agregar botón en la pantalla del Plan Semanal
- Recopilar todos los ingredientes faltantes de las recetas del plan
- Agregarlos masivamente a la lista de compras

---

### Mejora 2 · Categorizar recetas guardadas en Recetas
**Prioridad:** Media

**Problema:** Las recetas guardadas no están organizadas por categorías.

**Implementación:**
- Agregar chips de filtrado por categoría (Entrada, Sopa, Segundo, Postre, Bebida, etc.)
- Auto-categorizar recetas existentes según `tipoComida`

---

### Mejora 3 · Menús completos en Sugeridas
**Prioridad:** Media

**Problema:** Las sugerencias muestran recetas individuales, no menús completos.

**Implementación:**
- Para hora de desayuno: mostrar Desayuno 1 (plato + bebida), Desayuno 2, etc.
- Para almuerzo: Entrada + Sopa + Segundo + Refresco
- Para cena: platos ligeros

**Estructura sugerida:**
```
Almuerzo 1:
  • Ceviche (Entrada)
  • Aguadito (Sopa)
  • Arroz con pollo (Segundo)
  • Chicha morada (Refresco)
```

---

### Mejora 4 · Auto-actualizar Plan Semanal al cocinar fuera del plan
**Prioridad:** Media

**Problema:** Si el usuario cocina una receta distinta a la del plan, el plan no se actualiza.

**Implementación:**
- Detectar cuando se cocina una receta fuera del plan
- Preguntar: "¿Deseas reemplazar la receta del plan con esta?"
- Si acepta, actualizar la entrada del día correspondiente

---

## 📝 Para implementación futura

### VoiceService (comandos de voz)
**Estado:** Código definido pero deshabilitado por incompatibilidad con Android

**Uso previsto:**
- Búsqueda por voz en despensa
- Comandos de voz en Cocina
- Registro de gastos por voz

**Nota:** No es esencial para ahora. Reactivar cuando haya un paquete compatible.

---

## Estado General

| Métrica | Valor |
|---------|-------|
| Bugs críticos | 4 |
| Bugs menores | 1 |
| Mejoras | 4 |
| Implementación futura | 1 |
| **Total pendientes** | **10** |

---

> **Nota:** El banner de cocina ya fue corregido (auto-end después del tiempo de preparación + 30min).
