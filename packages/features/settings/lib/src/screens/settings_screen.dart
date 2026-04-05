import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:core/core.dart';
import '../providers/backup_provider.dart';
import '../providers/theme_provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = 'v${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = 'v1.0.4');
    }
  }

  @override
  Widget build(BuildContext context) {
    final backup = ref.watch(backupProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F0D) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Ajustes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white54),
            onPressed: () => _showAboutDialog(context),
            tooltip: 'Acerca de',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Perfil y App Info ─────────────────────────────────────────────
          _ProfileCard(isDark: isDark, appVersion: _appVersion),
          const SizedBox(height: 16),

          // ── Apariencia ────────────────────────────────────────────────────
          _AppearanceSection(ref: ref, isDark: isDark),
          const SizedBox(height: 16),

          // ── Backup & Datos ────────────────────────────────────────────────
          _BackupSection(backup: backup, ref: ref, isDark: isDark),
          const SizedBox(height: 16),

          // ── Módulos ───────────────────────────────────────────────────────
          _ModulesSection(isDark: isDark),
          const SizedBox(height: 16),

          // ── Preferencias Avanzadas ────────────────────────────────────────
          _AdvancedSection(isDark: isDark),
          const SizedBox(height: 24),

          // ── Zona de Peligro ──────────────────────────────────────────────
          _DangerZone(context, ref),
        ],
      ),
    );
  }

  Future<void> _showAboutDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C896), Color(0xFF4CAF82)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(Icons.dashboard, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'MyLifeOS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _appVersion,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tu sistema operativo personal potenciado por IA. Centraliza tu vida: finanzas, armario, cocina y nutrición en un solo lugar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C896),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile Card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final bool isDark;
  final String appVersion;
  const _ProfileCard({required this.isDark, required this.appVersion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2017), Color(0xFF1A3A28)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                const Icon(Icons.person_outline, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MyLifeOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appVersion,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00C896),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Fase 8',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Appearance Section ────────────────────────────────────────────────────────

class _AppearanceSection extends ConsumerWidget {
  final WidgetRef ref;
  final bool isDark;
  const _AppearanceSection({required this.ref, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);

    return _SectionCard(
      isDark: isDark,
      icon: Icons.palette_outlined,
      title: 'Apariencia',
      child: Row(
        children: [
          _ThemeChip(
            label: 'Claro',
            icon: Icons.light_mode_outlined,
            selected: current == ThemeMode.light,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light),
          ),
          const SizedBox(width: 8),
          _ThemeChip(
            label: 'Sistema',
            icon: Icons.brightness_auto_outlined,
            selected: current == ThemeMode.system,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.system),
          ),
          const SizedBox(width: 8),
          _ThemeChip(
            label: 'Oscuro',
            icon: Icons.dark_mode_outlined,
            selected: current == ThemeMode.dark,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF00C896).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF00C896)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? const Color(0xFF00C896) : Colors.white54,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? const Color(0xFF00C896) : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Backup Section ────────────────────────────────────────────────────────────

class _BackupSection extends StatelessWidget {
  final BackupState backup;
  final WidgetRef ref;
  final bool isDark;
  const _BackupSection(
      {required this.backup, required this.ref, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      isDark: isDark,
      icon: Icons.cloud_sync_outlined,
      title: 'Backup & Datos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00C896).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00C896).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF00C896), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tamaño actual: ${_formatSize(backup.dbSizeBytes)}',
                    style: const TextStyle(
                      color: Color(0xFF00C896),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Auto backup toggle
          FutureBuilder<bool>(
            future: AutoBackupService.isEnabled(),
            builder: (context, snapshot) {
              final isEnabled = snapshot.data ?? false;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB74D).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.autorenew,
                      color: Color(0xFFFFB74D), size: 18),
                ),
                title: const Text(
                  'Backup automático',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Cada 24 horas en background',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                trailing: Switch(
                  value: isEnabled,
                  activeThumbColor: const Color(0xFF00C896),
                  onChanged: (val) async {
                    if (val) {
                      await AutoBackupService.enable();
                    } else {
                      await AutoBackupService.disable();
                    }
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Export button
          _BackupActionTile(
            icon: Icons.file_upload_outlined,
            label: 'Exportar backup',
            subtitle: 'Crear archivo .mylifeos_backup',
            color: const Color(0xFF00C896),
            isLoading: backup.status == BackupStatus.exportingInProgress,
            onTap: () => _exportBackup(context, ref),
          ),
          const SizedBox(height: 8),

          // Import button
          _BackupActionTile(
            icon: Icons.file_download_outlined,
            label: 'Restaurar backup',
            subtitle: 'Seleccionar archivo .mylifeos_backup',
            color: const Color(0xFFFFB74D),
            isLoading: backup.status == BackupStatus.importingInProgress,
            onTap: () => _importBackup(context, ref),
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

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final ok = await _showConfirmDialog(
      context,
      title: '¿Exportar backup?',
      message:
          'Se creará un archivo con todos tus datos. Guárdalo en un lugar seguro.',
      confirmLabel: 'Exportar',
      confirmColor: const Color(0xFF00C896),
    );
    if (!ok) return;

    final result = await ref.read(backupProvider.notifier).exportBackup();
    if (!context.mounted) return;

    if (result is BackupSuccess) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup exportado correctamente'),
            backgroundColor: Color(0xFF00C896),
          ),
        );
      }
    } else if (result is BackupFailure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final step1 = await _showConfirmDialog(
      context,
      title: '⚠️ Restaurar backup',
      message:
          'Todos tus datos actuales serán reemplazados. Esta operación no se puede deshacer.',
      confirmLabel: 'Continuar',
      confirmColor: const Color(0xFFFFB74D),
    );
    if (!step1) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Selecciona tu backup de MyLifeOS',
    );
    if (result == null || result.files.single.path == null) return;
    if (!context.mounted) return;

    final step2 = await _showConfirmDialog(
      context,
      title: 'Confirmar restauración',
      message:
          '¿Restaurar desde "${result.files.single.name}"? Tus datos actuales se perderán.',
      confirmLabel: '¡Restaurar ahora!',
      confirmColor: Colors.red,
      isDestructive: true,
    );
    if (!step2 || !context.mounted) return;

    final backupResult = await ref
        .read(backupProvider.notifier)
        .importBackup(result.files.single.path!);
    if (!context.mounted) return;

    if (backupResult is RestoreSuccess) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ¡Restauración exitosa! Reinicia la app.'),
            backgroundColor: Color(0xFF00C896),
          ),
        );
      }
    } else if (backupResult is BackupFailure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${backupResult.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          message,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _BackupActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _BackupActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child:
                        CircularProgressIndicator(color: color, strokeWidth: 2),
                  )
                : Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLoading)
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ── Modules Section ───────────────────────────────────────────────────────────

class _ModulesSection extends StatelessWidget {
  final bool isDark;
  const _ModulesSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      isDark: isDark,
      icon: Icons.apps_outlined,
      title: 'Módulos',
      child: Column(
        children: [
          _ModuleTile(
            emoji: '💰',
            icon: Icons.account_balance_wallet_outlined,
            name: 'Finanzas',
            description: 'WalletAI con análisis inteligente',
            color: const Color(0xFFFFC107),
          ),
          const Divider(height: 1, color: Colors.white10),
          _ModuleTile(
            emoji: '👗',
            icon: Icons.checkroom_outlined,
            name: 'Armario',
            description: 'Gestión de prendas con IA',
            color: const Color(0xFF29B6F6),
          ),
          const Divider(height: 1, color: Colors.white10),
          _ModuleTile(
            emoji: '🍽️',
            icon: Icons.soup_kitchen_outlined,
            name: 'Cocina',
            description: 'Despensa y recetas',
            color: const Color(0xFFFF7043),
          ),
          const Divider(height: 1, color: Colors.white10),
          _ModuleTile(
            emoji: '🥗',
            icon: Icons.restaurant_outlined,
            name: 'Food Coach',
            description: 'Evaluación nutricional',
            color: const Color(0xFFFF5252),
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final String emoji;
  final IconData icon;
  final String name;
  final String description;
  final Color color;

  const _ModuleTile({
    required this.emoji,
    required this.icon,
    required this.name,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Icon(icon, size: 10, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ],
      ),
    );
  }
}

// ── Advanced Section ──────────────────────────────────────────────────────────

class _AdvancedSection extends StatelessWidget {
  final bool isDark;
  const _AdvancedSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      isDark: isDark,
      icon: Icons.build_outlined,
      title: 'Preferencias Avanzadas',
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF29B6F6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.widgets_outlined,
                  color: Color(0xFF29B6F6), size: 18),
            ),
            title: const Text(
              'Widget de Home Screen',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Configurar widget en pantalla de inicio',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: () async {
              // Abrir configuración de widgets de Android
              final uri = Uri.parse('package:com.mylifeos.app/widget_config');
              if (!await launchUrl(uri)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Mantén presionado el widget en la pantalla de inicio para configurarlo'),
                      backgroundColor: Color(0xFF00C896),
                    ),
                  );
                }
              }
            },
          ),
          const Divider(height: 1, color: Colors.white10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_sweep_outlined,
                  color: Color(0xFFFF5252), size: 18),
            ),
            title: const Text(
              'Limpiar caché',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Eliminar imágenes temporales',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: () => _clearCache(context),
          ),
        ],
      ),
    );
  }
}

// ── Danger Zone ───────────────────────────────────────────────────────────────

Widget _DangerZone(BuildContext context, WidgetRef ref) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text(
              'Zona de Peligro',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _confirmDeleteAll(context, ref),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.delete_forever_outlined,
                    color: Colors.red, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borrar todos los datos',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Elimina permanentemente todos tus registros',
                        style: TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.red),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
  final step1 = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('🗑️ Borrar TODO',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
      content: const Text(
        'Se eliminarán PERMANENTEMENTE todos tus datos. Esta acción no tiene marcha atrás.',
        style: TextStyle(color: Colors.white60, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child:
              const Text('Cancelar', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Borrar todo',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (step1 == true && context.mounted) {
    _confirmDeleteAllFinal(context, ref);
  }
}

Future<void> _confirmDeleteAllFinal(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF152019),
      title: const Text('⚠️ Confirmar borrado total',
          style: TextStyle(color: Colors.red)),
      content: const Text(
        'Esto eliminará TODOS los datos: transacciones, cuentas, categorías, recetas, prendas, perfiles y ajustes. ¿Estás completamente seguro?',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child:
              const Text('Cancelar', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Borrar todo'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠️ Para borrar todos los datos, ve a Ajustes > Aplicación > Borrar datos de la app en la configuración del sistema.'),
            backgroundColor: Color(0xFF00C896),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

/// Limpia el caché de la app
Future<void> _clearCache(BuildContext context) async {
  try {
    int totalSize = 0;
    int fileCount = 0;

    // Directorio temporal
    final tempDir = await getTemporaryDirectory();
    if (await tempDir.exists()) {
      await for (final file in tempDir.list()) {
        if (file is File) {
          totalSize += await file.length();
          await file.delete();
          fileCount++;
        }
      }
    }

    // Caché de imágenes comprimidas
    final docDir = await getApplicationDocumentsDirectory();
    final compressedDir = Directory('${docDir.path}/compressed');
    if (await compressedDir.exists()) {
      await for (final file in compressedDir.list()) {
        if (file is File) {
          totalSize += await file.length();
          await file.delete();
          fileCount++;
        }
      }
      if (await compressedDir.list().isEmpty) {
        await compressedDir.delete();
      }
    }

    if (context.mounted) {
      final sizeStr = totalSize < 1024
          ? '$totalSize B'
          : totalSize < 1024 * 1024
              ? '${(totalSize / 1024).toStringAsFixed(1)} KB'
              : '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('✅ $fileCount archivos eliminados ($sizeStr liberados)'),
          backgroundColor: const Color(0xFF00C896),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al limpiar caché: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

// ── Section Card Wrapper ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111814) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00C896), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
