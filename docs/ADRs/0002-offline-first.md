# ADR 0002: Arquitectura Offline-First como Regla Principal

## Status
Accepted

## Context
MyLifeOS gestiona datos personales y cotidianos del usuario (inventario de cocina, ropa del armario, hábitos alimenticios). Requerir internet para crear o visualizar esto introduce fricción y dependencia innecesaria.

## Decision
La aplicación operará con el esquema **Offline-First**. Toda la lógica de lectura y escritura debe impactar `AppDatabase` (Drift/SQLite) antes que a cualquier otro API.
Cualquier sincronización ("Sync Familiar", "Subir imágenes a Cloud") que se introduzca en el futuro, operará secundariamente, leyendo de Drift como la *fuente única de verdad* ("Single Source of Truth").

- Todos los repositorios retornarán directamente Models de Dominio y no `Future` vinculados a un delay de latencia extremo, mejorando la UX.
- Las imágenes (del Módulo Media) se almacenarán en la memoria física local (`getApplicationDocumentsDirectory`) y la base de datos solo guardará sus paths relativos/absolutos.

## Consequences
- **Positivas:** Operación rápida, máxima privacidad del usuario (no hay datos en servidores de terceros al inicio).
- **Negativas:** Obliga a los "Backups" a ser un proceso local (archivo .zip o cifrado) que el usuario deberá mandar manualmente a su GDrive por ahora (ver Fase 7).
