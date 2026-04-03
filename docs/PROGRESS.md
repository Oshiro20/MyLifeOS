# MyLifeOS — Progress Log & Bitácora

Este documento mantiene un registro **en vivo** de las tareas, checkpoints y decisiones de ingeniería durante el ciclo de vida del desarrollo.

## Checkpoints Activos

- [x] Establecer estructura de carpetas Multi-Package (Clean Architecture).
- [x] Generar / Consolidar estructura base de UI en `mobile/`.
- [x] Remover tablas redundantes y generar Drift models V3.
- [x] Módulo **Cocina**: Implementar casos de uso `CalculateRecipeViabilityUseCase` y `GenerateShoppingListUseCase`.
- [x] Tests Core: Unit tests para normalización y Motor de Viabilidad en Cocina.
- [ ] **[Idea Externa]**: Integración Cloud Sync (Stub Firebase).
- [ ] **[Idea Externa]**: Importador AI de Recetas (TikTok / Facebook Videos).

## Bitácora Diaria

### [Fecha Actual] - Initial Scaffolding Cleanup
- **Objetivo:** Refinar el esquema heredado y configurar el proyecto para arrancar motor MVP (Cocina y Armario).
- **Lo Hecho:**
  - Limpieza de `packages/data/lib/src/local/tables.dart` eliminando las entidades redundantes `Garments` e `Ingredients`.
  - Construcción del archivo Root `README.md` y `CHANGELOG.md`.
- **Riesgos/Obstáculos:** Riesgo mínimo. Recrear correctamente el motor de Drift con `build_runner`.
- **Decisiones Importantes:** Ver `ADRs/0001-stack.md` (Pendiente).
