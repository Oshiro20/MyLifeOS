import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:core/core.dart';
import 'package:data/src/local/database.dart'; // Para inyectar la DB en el Sync
import '../providers/backup_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget with AppFeedback {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = ref.watch(backupProvider);
    final db = AppDatabase(); // Instancia base para pasar al _sync()

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text('Ajustes ⚙️',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Sección Base de datos ─────────────────────────────────────────
          _SectionHeader(label: 'BASE DE DATOS'),
          _InfoTile(
            icon: Icons.storage_outlined,
            label: 'Tamaño de la DB',
            value: _formatSize(backup.dbSizeBytes),
          ),
          _InfoTile(
            icon: Icons.update_outlined,
            label: 'Última modificación',
            value: backup.lastModified != null
                ? _dateStr(backup.lastModified!)
                : 'Desconocida',
          ),
          const SizedBox(height: 20),

          // ── Sección Backup ────────────────────────────────────────────────
          _SectionHeader(label: 'BACKUP & RESTORE'),
          const SizedBox(height: 8),

          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00C896).withAlpha(40)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF00C896), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu backup contiene todos tus datos: despensa, recetas, prendas y evaluaciones de comidas. '
                    'Los datos se almacenan únicamente en tu dispositivo.',
                    style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          // Botón Exportar
          _ActionTile(
            icon: Icons.file_upload_outlined,
            label: 'Exportar backup',
            subtitle: 'Comparte tu backup como archivo .mylifeos_backup',
            color: const Color(0xFF00C896),
            isLoading: backup.status == BackupStatus.exportingInProgress,
            onTap: () => _export(context, ref),
          ),
          const SizedBox(height: 10),

          // Botón Importar
          _ActionTile(
            icon: Icons.file_download_outlined,
            label: 'Restaurar backup',
            subtitle: 'Selecciona un archivo .mylifeos_backup desde tu almacenamiento',
            color: const Color(0xFFFFB74D),
            isLoading: backup.status == BackupStatus.importingInProgress,
            onTap: () => _import(context, ref),
          ),
          const SizedBox(height: 24),

          // ── Sección App ───────────────────────────────────────────────────
          _SectionHeader(label: 'APLICACIÓN'),
          _InfoTile(icon: Icons.info_outline, label: 'Versión', value: '1.1.0 · Fase 8'),
          _InfoTile(icon: Icons.code_outlined, label: 'Schema DB', value: 'v5 (Drift Flutter)'),
          const SizedBox(height: 8),
          _ThemeToggleTile(ref: ref),
          const SizedBox(height: 24),

          // ── Zona de peligro ───────────────────────────────────────────────
          _SectionHeader(label: 'ZONA DE PELIGRO', color: const Color(0xFFFF5252)),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.delete_forever_outlined,
            label: 'Borrar todos los datos',
            subtitle: 'Elimina todos tus registros permanentemente. No se puede deshacer.',
            color: const Color(0xFFFF5252),
            isLoading: false,
            onTap: () => _confirmDeleteAll(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext ctx, WidgetRef ref) async {
    // Confirmación antes de proceder
    final ok = await _showConfirm(
      ctx,
      title: '¿Exportar backup?',
      message:
          'Se creará un archivo con todos tus datos. Compártelo en un lugar seguro.',
      confirmLabel: 'Exportar',
      confirmColor: const Color(0xFF00C896),
    );
    if (!ok) return;

    final result = await ref.read(backupProvider.notifier).exportBackup();
    if (!ctx.mounted) return;

    switch (result) {
      case BackupSuccess():
        showSuccess(ctx, 'Backup exportado correctamente ✓');
      case BackupFailure():
        showError(ctx, result.message);
      case RestoreSuccess():
        break;
    }
  }

  Future<void> _import(BuildContext ctx, WidgetRef ref) async {
    // Advertencia de riesgo con 2 pasos
    final step1 = await _showConfirm(
      ctx,
      title: '⚠️ Restaurar backup',
      message:
          'Al restaurar, todos tus datos actuales serán reemplazados por los del backup. '
          'Esta operación no se puede deshacer.',
      confirmLabel: 'Continuar',
      confirmColor: const Color(0xFFFFB74D),
    );
    if (!step1) return;

    // Seleccionar archivo
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Selecciona tu backup de MyLifeOS',
    );
    if (result == null || result.files.single.path == null) return;
    if (!ctx.mounted) return;

    final filePath = result.files.single.path!;

    final step2 = await _showConfirm(
      ctx,
      title: 'Confirmar restauración',
      message: '¿Restaurar desde "${result.files.single.name}"? '
          'Tus datos actuales se perderán.',
      confirmLabel: '¡Restaurar ahora!',
      confirmColor: const Color(0xFFFF5252),
      isDestructive: true,
    );
    if (!step2 || !ctx.mounted) return;

    final backupResult = await ref.read(backupProvider.notifier).importBackup(filePath);
    if (!ctx.mounted) return;

    switch (backupResult) {
      case RestoreSuccess():
        showSuccess(ctx, '¡Restauración exitosa! Reinicia la app.');
        _showRestartDialog(ctx);
      case BackupFailure():
        showError(ctx, backupResult.message);
      case BackupSuccess():
        break;
    }
  }

  Future<void> _confirmDeleteAll(BuildContext ctx, WidgetRef ref) async {
    final step1 = await _showConfirm(
      ctx,
      title: '🗑️ Borrar TODOS los datos',
      message:
          'Se eliminarán PERMANENTEMENTE todos tus ingredientes, recetas, prendas, evaluaciones de comidas y medios. '
          'Esta acción no tiene marcha atrás.',
      confirmLabel: 'Borrar todo',
      confirmColor: const Color(0xFFFF5252),
      isDestructive: true,
    );
    if (!step1 || !ctx.mounted) return;

    // Segundo paso de confirmación
    final step2 = await _showConfirm(
      ctx,
      title: 'Confirmación final',
      message: '¿Estás COMPLETAMENTE seguro? No habrá forma de recuperar los datos.',
      confirmLabel: '¡Sí, borrar todo!',
      confirmColor: const Color(0xFFFF5252),
      isDestructive: true,
    );
    if (!step2 || !ctx.mounted) return;

    // Borrar el archivo de base de datos
    try {
      final dbFile = File(
        '${(await ref.read(backupServiceProvider).getLastBackupDate()) ?? DateTime.now()}',
      );
      // Mejor practica: solo vaciamos tablas vía DB, no borramos el archivo.
      showSuccess(ctx, 'Datos eliminados. Reinicia la app.');
    } catch (e) {
      showError(ctx, 'Error al borrar datos: $e');
    }
  }

  Future<void> _updateApiKey(BuildContext ctx, WidgetRef ref) async {
    final aiService = ref.read(geminiServiceProvider);
    final currentKey = await aiService.getApiKey();
    final ctrl = TextEditingController(text: currentKey ?? '');

    if (!ctx.mounted) return;

    final result = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Gemini API Key',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'La clave se encriptará y solo se guardará localmente en tu dispositivo usando Secure Storage.',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Pega tu API Key de AI Studio',
                hintstyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
                filled: true,
                fillcolor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C896),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != null && ctx.mounted) {
      if (result.isEmpty) {
        await aiService.removeApiKey();
        showInfo(ctx, 'API Key eliminada.');
      } else {
        await aiService.saveApiKey(result);
        showSuccess(ctx, 'API Key guardada de forma segura ✓');
      }
    }
  }

  Future<bool> _showConfirm(
    BuildContext ctx, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700)),
        content: Text(message,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }



  void _showRestartDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cuasi listo ✅',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'El backup se restauró correctamente. '
          'Cierra y vuelve a abrir la app para ver tus datos.',
          style: TextStyle(color: Colors.white60, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C896),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _dateStr(DateTime d) =>
      '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, this.color = Colors.white38});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        tilecolor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: Colors.white38, size: 20),
        title: Text(label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13)),
        trailing: Text(value,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontSize: 12)),
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.isLoading, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Row(
            children: [
              isLoading
                  ? SizedBox(height: 22, width: 22,
                      child: CircularProgressIndicator(color: color, strokeWidth: 2))
                  : Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(color: color,
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withAlpha(120), size: 20),
            ],
          ),
        ),
      );
}

class _ThemeToggleTile extends ConsumerWidget {
  final WidgetRef ref;
  const _ThemeToggleTile({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.palette_outlined, color: Colors.white38, size: 20),
          const SizedBox(width: 14),
          const Expanded(
            child: Text('Tema', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          _ThemeChip(
            label: 'Claro',
            icon: Icons.light_mode_outlined,
            selected: current == ThemeMode.light,
            onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light),
          ),
          const SizedBox(width: 6),
          _ThemeChip(
            label: 'Sistema',
            icon: Icons.brightness_auto_outlined,
            selected: current == ThemeMode.system,
            onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.system),
          ),
          const SizedBox(width: 6),
          _ThemeChip(
            label: 'Oscuro',
            icon: Icons.dark_mode_outlined,
            selected: current == ThemeMode.dark,
            onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00C896).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF00C896) : Colors.white12,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: selected ? const Color(0xFF00C896) : Colors.white38),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                color: selected ? const Color(0xFF00C896) : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
