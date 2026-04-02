# MyLifeOS

MyLifeOS es un aplicativo personal estructurado con Clean Architecture y principios Multi-Package. Sigue un modelo **Offline-First**, gestionado por Drift (SQLite), garantizando que las funcionalidades críticas operen sin requerir conexión a internet.

## Características Principales (Módulos)
- **Armario:** Gestión de prendas, outfits, y análisis de color vía extracción de imágenes.
- **Cocina / Despensa:** Inventario de ingredientes, motor de viabilidad de recetas ("¿Qué cocino hoy?") y lista de compras.
- **Food Coach:** Registro diario y semanal categorizado (💚 Saludable, 💛 Balanceado, 🔴 Chatarra).
- **Media:** Gestión local de assets (fotos) sin depender de la nube.
- **Respaldo (Backup):** Sistema de exportación e importación manual cifrada.

## Estructura del Repositorio (Clean Architecture)
```text
D:\Proyectos_Flutter\Aplicativo_Personal\
├── apps/
│   └── mobile/           # Entry point (Riverpod, Theme, GoRouter)
├── packages/
│   ├── core/             # Utilidades, error handling, logging, backups
│   ├── domain/           # Entidades limpias y puertos (IRepositories)
│   ├── data/             # Implementación Offline-first con Drift DB
│   └── features/         # Módulos aislados (armario, cocina, media...)
└── docs/                 # Bitácora, ADRs y MAPA DE ARQUITECTURA
```

## Requerimientos y Setup
1. **Flutter SDK:** >=3.0.0
2. **Dart SDK:** >=3.0.0

Para iniciar el proyecto, primero instala las dependencias e inicia el `build_runner` en el paquete de persistencia de datos:

```bash
# Entrar a la app principal
cd apps/mobile
flutter pub get

# Generar esquemas de base de datos
cd ../../packages/data
dart run build_runner build -d
```

## Documentación Técnica
- **[Mapa de Arquitectura](docs/ARCHITECTURE_MAP.md):** Contiene el detalle del flujo de dependencias.
- **[Bitácora de Progreso](docs/PROGRESS.md):** Checklist y log de cambios semanales.
- **[ADRs (Architecture Decision Records)](docs/ADRs/):** Registro de las decisiones tecnológicas más importantes.

## Principios de Contribución
- Mantener la separación estricta: UI -> Providers -> UseCases -> Repositories -> Data sources.
- Todo requerimiento listado como `[Idea Externa]` es una extensión a la versión MVP actual y debe quedar como un _stub_.
