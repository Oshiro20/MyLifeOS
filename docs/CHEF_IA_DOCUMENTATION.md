# Chef IA - Documentación Técnica Completa

## 📋 Descripción

El **Chef IA** es la funcionalidad de MyLifeOS que permite importar recetas desde:
- **Enlaces de TikTok** (y otras redes sociales)
- **Videos subidos desde la galería**
- **Fotos de recetas** (libros, pantallazos, etc.)

Utiliza **Google Gemini AI** (modelo vision) para analizar contenido multimedia y extraer recetas estructuradas en formato JSON.

---

## 🏗️ Arquitectura del Pipeline

```
TikTok URL / Video / Foto
        ↓
┌──────────────────────┐
│  TikTokService       │ ← Solo para URLs de TikTok
│  (RapidAPI)          │   Descarga video sin marca de agua
└──────────────────────┘
        ↓
┌──────────────────────┐
│  VideoThumbnail      │ ← Extrae thumbnail JPEG del video
│  (1080p, quality 85) │   (NO envía videos a Gemini)
└──────────────────────┘
        ↓
┌──────────────────────┐
│  GeminiService       │ ← API de Google Gemini AI
│  .extractRecipe()    │   Modelo: gemini-2.5-flash
└──────────────────────┘
        ↓
┌──────────────────────┐
│  ExtractRecipeUseCase│ ← Parsea JSON a Recipe entity
│  .parseFromJson()    │   Soporta formatos EN y ES
└──────────────────────┘
        ↓
   Recipe Object → Drift DB
```

---

## 📁 Archivos Clave

| Archivo | Función | **NO CAMBIAR** |
|---------|---------|----------------|
| `packages/core/lib/src/services/ai_service.dart` | Servicio Gemini AI, prompts, safety settings | ⚠️ Modelo, prompt, safetySettings |
| `packages/core/lib/src/services/tiktok_service.dart` | Descarga de videos TikTok via RapidAPI | ⚠️ Endpoint order, API host |
| `packages/features/cocina/lib/src/providers/recipe_importer_provider.dart` | State machine del importador | ⚠️ Flujo de thumbnail → Gemini |
| `packages/domain/lib/src/cocina/usecases/extract_recipe_use_case.dart` | Parser JSON → Recipe entity | ⚠️ Formato JSON esperado |
| `packages/domain/lib/src/cocina/repositories/i_ai_recipe_extractor.dart` | Interfaz del extractor AI | ⚠️ Firma `String? mediaPath` |
| `apps/mobile/.env` | API Keys embebidas en el APK | ⚠️ GEMINI_API_KEY, TIKTOK_API_KEY |

---

## 🔑 Configuración Crítica

### 1. API Keys (en `apps/mobile/.env`)

```env
# Gemini AI API Key (Google) - OBLIGATORIO
GEMINI_API_KEY=AIzaSyDk4QD-c8ti_96tsClL4O3V8QuK0u9b7qs

# TikTok API Key (RapidAPI) - OBLIGATORIO para importar desde URLs
TIKTOK_API_KEY=5bef8f8804msh689bebc06557fa2p1f4126jsn0b7a9680766c
```

**IMPORTANTE:**
- El archivo `.env` de `apps/mobile/` es el que se empaqueta en el APK
- **NO** usar el `.env` de la raíz del proyecto
- Las API keys deben estar sincronizadas en ambos archivos

### 2. Modelo Gemini

```dart
// packages/core/lib/src/services/ai_service.dart
static const String _defaultModel = 'gemini-2.5-flash';
```

**Modelos que funcionan:**
- ✅ `gemini-2.5-flash` ← **ÚSAR ESTE**
- ✅ `gemini-1.5-pro` (alternativa si 2.5 falla)

**Modelos que NO funcionan:**
- ❌ `gemini-1.5-flash` (deprecado)
- ❌ `gemini-2.0-flash` (deprecado)
- ❌ `gemini-pro` (no soporta vision)

### 3. Safety Settings

```dart
safetySettings: [
  SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
  SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
  SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
  SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
],
```

**IMPORTANTE:** Los videos de cocina contienen cuchillos, fuego, etc. Sin estos settings, Gemini bloquea las solicitudes con `DataInspectionFailed`.

---

## 🔧 Prompt del Chef IA

El prompt está en `ai_service.dart` en el método `extractRecipe()`. Es un prompt detallado de ~200 líneas que incluye:

1. **Rol del sistema:** Chef Profesional + Analista de Video
2. **8 pasos de análisis:** Contexto, plato, ingredientes, pasos, tiempos, utensilios, clasificación, calorías
3. **Formato JSON esperado:** Con TODOS los campos obligatorios
4. **17 reglas obligatorias:** Campos numéricos, unidades en español, tiempos realistas, etc.

**NO simplificar el prompt.** Versiones anteriores con prompts genéricos (~40 líneas) causaron que Gemini devolviera respuestas vacías o JSON inválido.

---

## 🚫 Errores Históricos y Soluciones

### Error 1: "Gemini devolvió una respuesta vacía"
**Causa:** API key no se cargaba correctamente en producción
**Solución:** 
- Sincronizar `apps/mobile/.env` con el root `.env`
- Fallback hardcodeado en `geminiProvider`
- Desactivar caché offline para `extractRecipe()`

### Error 2: "models/gemini-1.5-flash is not found"
**Causa:** Modelo deprecado por Google
**Solución:** Cambiar a `gemini-2.5-flash`

### Error 3: "DataInspectionFailed: Output data may contain inappropriate content"
**Causa:** Filtros de seguridad de Gemini bloquean contenido de cocina
**Solución:** Agregar `safetySettings` con `HarmBlockThreshold.none`

### Error 4: "La IA no pudo estructurar la receta"
**Causa:** Prompt demasiado genérico, Gemini no entendía el contexto
**Solución:** Restaurar prompt detallado de v2.9.0 con 8 pasos de análisis

### Error 5: Caché devolvía respuestas vacías
**Causa:** `_generateWithCache()` guardaba respuestas vacías y las devolvía en llamadas futuras
**Solución:** Desactivar caché para `extractRecipe()`

---

## 📐 Formato JSON Esperado

Gemini debe devolver SIEMPRE este formato:

```json
{
  "nombre_receta": "Arroz Chaufa",
  "descripcion": "Clásico plato peruano-chino",
  "porciones": 4,
  "tiempo_preparacion_min": 15,
  "tiempo_coccion_min": 20,
  "tiempo_total_min": 35,
  "dificultad": "Fácil",
  "tipo_comida": "Almuerzo",
  "cocina": "Peruana",
  "ingredientes": [
    {"nombre": "Arroz", "cantidad": 2.0, "unidad": "tazas"}
  ],
  "ingredientes_inferidos": ["aceite", "sal", "pimienta"],
  "pasos": [
    {"numero": 1, "descripcion": "Calentar el wok a fuego alto"}
  ],
  "utensilios": ["wok", "cuchara de madera"],
  "calorias_aproximadas": 450,
  "tags": ["fácil", "rápido"],
  "video_context": "resumido",
  "observaciones": "Tiempos inferidos según técnica",
  "nivel_confianza": "Alto"
}
```

**Campos obligatorios:** TODOS los listados arriba
**Campos numéricos:** Deben ser `float`, NO strings
**Unidades:** En español ("tazas", "unidades", "gramos", etc.)

---

## 🔍 Debugging

### Logs Clave

Al probar el Chef IA, buscar estos logs en la consola:

```
🔑 Gemini API Key: LOADED (39 chars)    ← Verificar que la key se carga
🤖 Calling Gemini API with model: gemini-2.5-flash  ← Modelo correcto
📎 Media path: /data/.../thumb_XXX.jpg  ← Thumbnail generado
📦 Response status: 200                  ← TikTok API responde
🎬 Video URL found: https://...         ← URL de descarga encontrada
✅ Gemini response length: 2345 chars   ← Respuesta válida
📄 Full response: {"nombre_receta":...} ← JSON válido
```

### Errores Comunes en Logs

| Log | Significado | Solución |
|-----|-------------|----------|
| `🔑 Gemini API Key: MISSING` | API key no se carga | Verificar `.env` |
| `❌ Gemini model is null` | Modelo no existe | Cambiar a `gemini-2.5-flash` |
| `🚫 Gemini blocked request` | Safety filter activado | Verificar `safetySettings` |
| `⚠️ Gemini returned null` | Respuesta vacía | Revisar prompt, conexión |
| `❌ All endpoints failed` | TikTok API falla | Verificar `TIKTOK_API_KEY` |

---

## 🧪 Testing

### Checklist de Pruebas

- [ ] Importar desde URL de TikTok
- [ ] Importar desde video de galería
- [ ] Importar desde foto de receta
- [ ] Verificar que la receta tiene ingredientes
- [ ] Verificar que la receta tiene pasos
- [ ] Verificar que los tiempos son realistas (>0)
- [ ] Verificar que las unidades están en español

### Videos de Prueba Recomendados

- ✅ Video claro con ingredientes visibles
- ✅ Video con texto en pantalla (nombres, cantidades)
- ✅ Video de duración 1-3 minutos
- ❌ Video muy corto (<10 segundos)
- ❌ Video sin audio ni texto

---

## ⚠️ Reglas de Oro

1. **NUNCA cambiar el modelo** a menos que Google lo depreque oficialmente
2. **NUNCA simplificar el prompt** - la complejidad es necesaria
3. **NUNCA eliminar los safetySettings** - videos de cocina activan filtros
4. **NUNCA activar el caché** para `extractRecipe()` - causa respuestas vacías
5. **SIEMPRE sincronizar** `apps/mobile/.env` con el root `.env`
6. **SIEMPRE usar** `String? mediaPath` (NO `List<String>? mediaPaths`)
7. **SIEMPRE extraer thumbnail** del video - NO enviar videos directamente a Gemini

---

## 📚 Referencias

- [Google Gemini API Docs](https://ai.google.dev/)
- [RapidAPI TikTok Scraper](https://rapidapi.com/DataCrawler/api/tiktok-scraper7)
- [video_thumbnail package](https://pub.dev/packages/video_thumbnail)
- Historial de commits: `git log --oneline -- packages/core/lib/src/services/ai_service.dart`

---

**Última actualización:** 2026-04-10
**Versión funcional:** v3.5.3+84
**Contacto:** Oshiro20 (orbezorosas123@gmail.com)
