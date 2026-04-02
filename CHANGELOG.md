# Changelog

Todos los cambios notables en este proyecto serán documentados aquí.
El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

## [Unreleased] - MVP V1 Phase

### Added
- Multi-package folder structure (apps, core, data, domain, features).
- Drift Database scaffolding (`packages/data/lib/src/local/tables.dart`).
- Local Backup module structure for future encryption export.

### Changed
- Refactored Database schemas to avoid duplicate tables (Garments vs WardrobeGarments).

### Fixed
- Fixed duplicated test suites.
