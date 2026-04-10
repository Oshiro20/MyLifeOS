# MyLifeOS v3.3.0 - Creador de Menú Personalizado + Fixes

**Fecha:** 2026-04-09  
**Versión:** 3.3.0+69

---

## 🎯 CAMBIO PRINCIPAL: Creador de Menú con IA

### Antes ❌
- Botonera extensa y enredada ("Ahora", "Menú", "Todas", "Selvática", "Desayuno", "Almuerzo"...)
- Sin personalización real de componentes
- Menús completos no se mostraban correctamente
- Lista de sugerencias no se actualizaba al regenerar

### Ahora ✅
- **Interfaz limpia en 4 pasos:**
  1. **¿Qué comida es?** → Desayuno 🌅 / Almuerzo 🍛 / Cena 🌙
  2. **¿Qué partes quieres?** → Chips seleccionables: Entrada 🥗, Sopa 🍲, Plato Fuerte 🥘, Refresco 🥤, Postre 🍰
  3. **¿Cuántos menús?** → 2, 3 o 4 opciones
  4. **Tipo de cocina** → Dropdown: Todas, Selvática, Serrana, Costeña, Italiana, Asiática, Mexicana

- **La IA genera menús completos** con EXACTAMENTE los componentes que elegiste
- Ejemplo: Si eliges Almuerzo + [Sopa, Plato Fuerte, Refresco] × 3 menús = 9 recetas organizadas en 3 menús
- Cada menú muestra: nombre del plato, tipo, tiempo, si tienes todos los ingredientes o faltan algunos
- Botones "Guardar todo" y "Cocinar" por menú

---

## 🐛 FIX: Importador de TikTok

### Problema
La API de TikTok (RapidAPI) devuelve diferentes formatos de respuesta y el código solo manejaba uno.

### Solución
- **3 estrategias de extracción:**
  1. Busca en `data` wrapper → `video_link_nwm`, `play`, `wmplay`, `hdplay`
  2. Busca `url` directo en root
  3. Busca keys de video directamente en root
- **Debug logging mejorado** para diagnóstico
- **Mensajes de error descriptivos** con posibles causas

---

## ✨ UX Mejoras

### SnackBar "Deshacer" ahora se oculta automáticamente
- **Antes:** 3-5 segundos (interrumpía la lectura)
- **Ahora:** 1.5 segundos (flujo fluido)
- Aplicado en:
  - Cocinar recetas (antojos, sugeridas)
  - Eliminar elementos del inventario
  - Plan semanal
  - Shopping list

---

## 📊 Base de Datos de Recetas

- **315 recetas validadas** en la base de datos local:
  - 🥗 Entradas: 60
  - 🍲 Sopas: 60
  - 🍛 Almuerzo: 90
  - 🍰 Postres: 45
  - 🥤 Bebidas: 60

---

## 📦 Archivos Modificados (8)

1. `packages/features/cocina/lib/src/screens/suggestions_tab.dart` - Creador de Menú completo
2. `packages/features/cocina/lib/src/providers/what_can_i_cook_provider.dart` - Soporte para menú personalizado
3. `packages/domain/lib/src/cocina/usecases/what_can_i_cook_use_case.dart` - Método executeWithMenu
4. `packages/features/cocina/lib/src/providers/recipe_importer_provider.dart` - Fix TikTok multi-formato
5. `packages/features/cocina/lib/src/screens/widgets/recipe_detail_sheet.dart` - Widget compartido
6. `packages/features/cocina/lib/src/screens/antojos_tab.dart` - SnackBar 1.5s
7. `packages/features/cocina/lib/src/screens/recipes_tab.dart` - SnackBar 1.5s
8. `packages/features/cocina/lib/src/screens/weekly_plan_screen.dart` - SnackBar 1.5s

---

## ✅ Verificación

- Dart analyzer: **0 errores**
- Flutter build release: **Exitoso**
- APK: **91.9 MB**

---

**¡Listo para instalar!** 🚀
