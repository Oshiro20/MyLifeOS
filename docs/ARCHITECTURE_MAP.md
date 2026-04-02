# MyLifeOS — Mapa de Arquitectura

## Árbol de Módulos

```text
D:\Proyectos_Flutter\Aplicativo_Personal\
├── apps/
│   └── mobile/                          # App Flutter principal (entry point)
│       ├── lib/
│       │   └── main.dart                # Bootstrap, GoRouter, ThemeData, ProviderScope + overrides de DI
│       ├── test/
│       │   └── widget_test.dart
│       └── pubspec.yaml                 # Deps: flutter_riverpod, go_router, + paquetes locales
│
├── packages/
│   ├── core/                            # Design system, temas, logging, utilidades globales
│   │   └── lib/core.dart               # (próxima fase: colores, tipografías, componentes)
│   │
│   ├── domain/                          # Entidades + reglas de negocio + interfaces de repos
│   │   └── lib/
│   │       ├── domain.dart              # Barrel de exportación
│   │       └── src/
│   │           ├── cocina/entities/ingredient.dart
│   │           ├── armario/entities/garment.dart
│   │           ├── foodcoach/entities/meal_log.dart
│   │           └── media/
│   │               ├── entities/media_asset.dart
│   │               ├── repositories/i_media_repository.dart   # Puerto hexagonal
│   │               └── usecases/save_media_use_case.dart
│   │
│   ├── data/                            # Implementaciones concretas: DB, repositorios
│   │   └── lib/
│   │       ├── data.dart                # Barrel de exportación
│   │       └── src/
│   │           ├── local/
│   │           │   ├── tables.dart      # Definición de tablas Drift
│   │           │   ├── database.dart    # AppDatabase (schema v2, migraciones)
│   │           │   └── database.g.dart  # Código auto-generado por Drift (NO editar)
│   │           └── repositories/
│   │               └── media_repository_impl.dart  # Implementación de IMediaRepository
│   │
│   └── features/
│       ├── cocina/      # (Fase 4) Inventario + Recetas + Sugerencias
│       ├── armario/     # (Fase 5) Prendas + Outfits + Atributos del usuario
│       ├── foodcoach/   # (Fase 6) Evaluación de comida: saludable/chatarra/balanceado
│       ├── media/       # ✅ COMPLETO — Galería de fotos, mejora, color dominante
│       │   └── lib/
│       │       ├── media.dart                               # Barrel de exportación
│       │       └── src/
│       │           ├── providers/media_provider.dart        # Riverpod StateNotifier
│       │           └── screens/media_screen.dart            # UI: grid + bottom sheet
│       └── backup/      # (Fase 7) Exportación/importación cifrada
│
├── docs/
│   └── ARCHITECTURE_MAP.md              # ← ESTE ARCHIVO
└── tools/               # Scripts de build/migración (próximas fases)
```

---

## Flujo de Datos (Clean Architecture)

```
UI (Widget)
  └──> StateNotifier (Riverpod)
         └──> UseCase (domain)
                └──> IRepository interface (domain)
                       └──> ConcreteRepository (data)
                              └──> AppDatabase (Drift/SQLite)
```

### Ejemplo: Guardar una foto (Módulo Media)

1. Usuario toca FAB en `MediaScreen` → llama a `_pickImage()`
2. `ImagePicker` devuelve un `File`
3. Se llama `mediaNotifierProvider.notifier.addFromFile(file)`
4. `MediaNotifier` → `_repo.saveAsset(sourceFile: file)` (interfaz en domain)
5. `MediaRepository.saveAsset()` (impl en data):
   - Copia el archivo a `Documents/mylifeos_media/photos/`
   - Genera thumbnail (256px, q60) en `Documents/mylifeos_media/thumbnails/`
   - Extrae color dominante por muestreo de píxeles
   - Inserta en tabla `media_assets` vía Drift
6. `MediaNotifier` actualiza el estado → UI re-renderiza con la nueva foto

---

## Inyección de Dependencias

Los providers se declaran en `packages/features/*/providers/` con un `Provider<IRepository>` que lanza `UnimplementedError` si no se hace override.

En `apps/mobile/lib/main.dart`, el `ProviderScope` hace el override real:

```dart
ProviderScope(
  overrides: [
    mediaRepositoryProvider.overrideWithValue(MediaRepository(_db)),
  ],
  child: const MyLifeOSApp(),
)
```

Esto permite que los features sean completamente independientes y testeables.

---

## Guía de Debugging

| Síntoma | Dónde mirar |
|---|---|
| UI no actualiza | `packages/features/<mod>/providers/` — revisar el StateNotifier |
| Datos no se guardan | `packages/data/src/repositories/` — revisar el repositorio |
| Error de schema/migration | `packages/data/src/local/database.dart` — schemaVersion + onUpgrade |
| Error de permisos de cámara | `apps/mobile/android/` → `AndroidManifest.xml` |
| Color dominante incorrecto | `MediaRepository.extractDominantColor()` en data |
| Ruta no encontrada | `apps/mobile/lib/main.dart` → `_router` GoRouter |
| Provider no inyectado | `main.dart` → `ProviderScope.overrides` |

---

## Base de Datos (Drift SQLite)

**Archivo**: `packages/data/lib/src/local/database.dart`  
**Schema Version**: **2**  
**Ubicación del archivo SQLite**: `getApplicationDocumentsDirectory()/mylifeos.sqlite`

| Tabla | Paquete Owner | Descripción |
|---|---|---|
| `ingredients` | cocina | Inventario de ingredientes |
| `garments` | armario | Prendas del armario |
| `meal_logs` | foodcoach | Registros de comidas evaluadas |
| `media_assets` | media | Fotos gestionadas localmente |

---

## Fases del Proyecto

| Fase | Estado | Descripción |
|---|---|---|
| 1 | ✅ | Discovery + stack (Flutter + Riverpod + Drift) |
| 2 | ✅ | Estructura base + modelos + DB |
| 3 | ✅ | Módulo Media (foto, mejora, color) |
| 4 | 🔲 | Módulo Cocina |
| 5 | 🔲 | Módulo Armario |
| 6 | 🔲 | Food Coach (evaluación saludable/chatarra) |
| 7 | 🔲 | Backup & Export cifrado |
| 8 | 🔲 | Optimización + docs finales |
| 9 | 🔲 | Preparación nube (ports/adapters stub) |
