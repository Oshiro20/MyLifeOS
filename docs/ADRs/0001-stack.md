# ADR 0001: Technology Stack (Flutter, Riverpod, Drift)

## Status
Accepted

## Context
MyLifeOS requiere un ecosistema confiable, offline-first y altamente modular para ser mantenible a futuro y permitir un desarrollo iterativo de funcionalidades independientes (Armario, Cocina, Food Coach).

## Decision
Se seleccionó la siguiente combinación (Stack):
1. **Flutter (Material 3):** Framework cross-platform nativo que acelera el desarrollo móvil.
2. **Riverpod:** Gestor de estado sólido, tipado de forma segura y orientado a fácil testing. Permite inyección de dependencias `ProviderScope.overrides`.
3. **Drift (SQLite):** Persistencia en base de datos local robusta, de buen soporte relacional (tablas y joins) y offline puro.
4. **GoRouter:** Navegación por rutas y deeplinking para un enrutamiento por pestañas predecible (`ShellRoute`).

## Consequences
- **Positivas:** Altamente modular, las implementaciones concretas viven en `packages/data` y la UI en UI, comunicados únicamente a través de interfaces puras en `packages/domain`.
- **Negativas:** La curva de aprendizaje inicial de Drift es moderada por la auto-generación de código y el uso de Riverpod requiere boilerplate inicial.
