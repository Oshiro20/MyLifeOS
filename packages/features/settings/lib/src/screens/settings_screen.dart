import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
      if (mounted) setState(() => _appVersion = 'Versión local');
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
        title: Text(
          'Ajustes',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0A1F16),
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline,
                color: isDark
                    ? Colors.white54
                    : const Color(0xFF4A7A65).withValues(alpha: 0.6)),
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

          // ── Notificaciones y Recordatorios ────────────────────────────────
          _NotificationsSection(isDark: isDark),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF0A1F16);
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
              Text(
                'MyLifeOS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _appVersion,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tu sistema operativo personal potenciado por IA. Centraliza tu vida: finanzas, armario, cocina y nutrición en un solo lugar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.75),
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

class _ProfileCard extends ConsumerWidget {
  final bool isDark;
  final String appVersion;
  const _ProfileCard({required this.isDark, required this.appVersion});

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Editar nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Tu nombre',
            hintText: 'Ej: Joel',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName != null && newName.isNotEmpty) {
      await ref.read(userDisplayNameProvider.notifier).setName(newName);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userDisplayNameProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF0F2017), Color(0xFF1A3A28)]
              : const [Color(0xFFE0F7F0), Color(0xFFB2DFDB)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : const Color(0xFF00A37A).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.person_outline,
              color: isDark ? Colors.white : const Color(0xFF0A1F16),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              onTap: () => _editName(context, ref, userName),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          userName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF0A1F16),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : const Color(0xFF4A7A65),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MyLifeOS · $appVersion',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : const Color(0xFF4A7A65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00C896),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Personal OS',
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
            isDark: isDark,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light),
          ),
          const SizedBox(width: 8),
          _ThemeChip(
            label: 'Sistema',
            icon: Icons.brightness_auto_outlined,
            selected: current == ThemeMode.system,
            isDark: isDark,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.system),
          ),
          const SizedBox(width: 8),
          _ThemeChip(
            label: 'Oscuro',
            icon: Icons.dark_mode_outlined,
            selected: current == ThemeMode.dark,
            isDark: isDark,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _NotificationsSection extends ConsumerWidget {
  final bool isDark;

  const _NotificationsSection({required this.isDark});

  Future<void> _pickTime(
    BuildContext context,
    DailyNotificationTime current,
    Future<void> Function(DailyNotificationTime next) onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    await onPicked(DailyNotificationTime(picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final textColor = isDark ? Colors.white : const Color(0xFF0A1F16);
    final muted = isDark ? Colors.white60 : const Color(0xFF4A7A65);

    return _SectionCard(
      isDark: isDark,
      icon: Icons.notifications_active_outlined,
      title: 'Notificaciones y Recordatorios',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Comidas diarias (Desayuno / Almuerzo / Cena)',
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Recordatorios con tu plan, sobras en refri o sugerencias rápidas',
              style: TextStyle(color: muted, fontSize: 11.5),
            ),
            value: settings.mealsEnabled,
            activeTrackColor: const Color(0xFF00C896),
            onChanged: (v) =>
                notifier.update(settings.copyWith(mealsEnabled: v)),
          ),
          if (settings.mealsEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Text('🌅', style: TextStyle(fontSize: 13)),
                    label: Text(
                      'Desayuno ${settings.breakfastTime.format24h()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _pickTime(
                      context,
                      settings.breakfastTime,
                      (t) => notifier.update(settings.copyWith(breakfastTime: t)),
                    ),
                  ),
                  ActionChip(
                    avatar: const Text('🍛', style: TextStyle(fontSize: 13)),
                    label: Text(
                      'Almuerzo ${settings.lunchTime.format24h()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _pickTime(
                      context,
                      settings.lunchTime,
                      (t) => notifier.update(settings.copyWith(lunchTime: t)),
                    ),
                  ),
                  ActionChip(
                    avatar: const Text('🌙', style: TextStyle(fontSize: 13)),
                    label: Text(
                      'Cena ${settings.dinnerTime.format24h()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _pickTime(
                      context,
                      settings.dinnerTime,
                      (t) => notifier.update(settings.copyWith(dinnerTime: t)),
                    ),
                  ),
                ],
              ),
            ),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Alertas de caducidad (Despensa y refri)',
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Aviso diario a las ${settings.expiryAlertTime.format24h()} si algo vence pronto',
              style: TextStyle(color: muted, fontSize: 11.5),
            ),
            value: settings.expiryAlertsEnabled,
            activeTrackColor: const Color(0xFF00C896),
            onChanged: (v) =>
                notifier.update(settings.copyWith(expiryAlertsEnabled: v)),
          ),
          if (settings.expiryAlertsEnabled)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _pickTime(
                  context,
                  settings.expiryAlertTime,
                  (t) => notifier.update(settings.copyWith(expiryAlertTime: t)),
                ),
                icon: const Icon(Icons.schedule,
                    size: 15, color: Color(0xFF00C896)),
                label: Text(
                  'Cambiar hora (${settings.expiryAlertTime.format24h()})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00C896),
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Temporizador de cocción',
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Notificación real cuando termina el tiempo de una receta activa',
              style: TextStyle(color: muted, fontSize: 11.5),
            ),
            value: settings.cookingTimerEnabled,
            activeTrackColor: const Color(0xFF00C896),
            onChanged: (v) =>
                notifier.update(settings.copyWith(cookingTimerEnabled: v)),
          ),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Recordatorio de lavado (Armario)',
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Aviso a las ${settings.laundryTime.format24h()} si tienes prendas por lavar',
              style: TextStyle(color: muted, fontSize: 11.5),
            ),
            value: settings.laundryReminderEnabled,
            activeTrackColor: const Color(0xFF00C896),
            onChanged: (v) =>
                notifier.update(settings.copyWith(laundryReminderEnabled: v)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await ref
                    .read(appNotificationsServiceProvider)
                    .sendTestNotification();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? '🔔 Notificación de prueba enviada al dispositivo'
                          : '⚠️ Activa el permiso de notificaciones para MyLifeOS en Android',
                    ),
                    backgroundColor:
                        ok ? const Color(0xFF00C896) : Colors.orange,
                  ),
                );
              },
              icon: const Icon(Icons.notifications_outlined,
                  size: 16, color: Color(0xFF00C896)),
              label: const Text(
                'Enviar notificación de prueba',
                style: TextStyle(
                  color: Color(0xFF00C896),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00C896)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
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
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedColor = isDark ? Colors.white54 : const Color(0xFF4A7A65);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF00C896).withValues(alpha: 0.2)
                : isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFF00A37A).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF00C896)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFF00A37A).withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? const Color(0xFF00C896) : unselectedColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? const Color(0xFF00C896) : unselectedColor,
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
                    backup.lastModified != null
                        ? 'Tamaño actual: ${_formatSize(backup.dbSizeBytes)} · Último: ${backup.lastModified!.day.toString().padLeft(2, '0')}/${backup.lastModified!.month.toString().padLeft(2, '0')} ${backup.lastModified!.hour.toString().padLeft(2, '0')}:${backup.lastModified!.minute.toString().padLeft(2, '0')}'
                        : 'Tamaño actual: ${_formatSize(backup.dbSizeBytes)}',
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

          // Estado real de backup automático
          Builder(
            builder: (context) {
              final textColor = isDark ? Colors.white : const Color(0xFF0A1F16);
              final subtitleColor =
                  isDark ? Colors.white54 : const Color(0xFF4A7A65);
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
                title: Text(
                  'Backup automático',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'En desarrollo · Usa Exportar backup para respaldar tus datos',
                  style: TextStyle(color: subtitleColor, fontSize: 11),
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB74D).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Pronto',
                    style: TextStyle(
                      color: Color(0xFFFFB74D),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
    final fg = isDark ? Colors.white : const Color(0xFF0A1F16);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        content: Text(
          message,
          style: TextStyle(
            color: fg.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: fg.withValues(alpha: 0.5))),
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.5)
                          : const Color(0xFF4A7A65),
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
    final dividerColor = isDark
        ? Colors.white10
        : const Color(0xFF00A37A).withValues(alpha: 0.12);
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
            isDark: isDark,
          ),
          Divider(height: 1, color: dividerColor),
          _ModuleTile(
            emoji: '👗',
            icon: Icons.checkroom_outlined,
            name: 'Armario',
            description: 'Gestión de prendas con IA',
            color: const Color(0xFF29B6F6),
            isDark: isDark,
          ),
          Divider(height: 1, color: dividerColor),
          _ModuleTile(
            emoji: '🍽️',
            icon: Icons.soup_kitchen_outlined,
            name: 'Cocina',
            description: 'Despensa y recetas',
            color: const Color(0xFFFF7043),
            isDark: isDark,
          ),
          Divider(height: 1, color: dividerColor),
          _ModuleTile(
            emoji: '🥗',
            icon: Icons.restaurant_outlined,
            name: 'Food Coach',
            description: 'Evaluación nutricional',
            color: const Color(0xFFFF5252),
            isDark: isDark,
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
  final bool isDark;

  const _ModuleTile({
    required this.emoji,
    required this.icon,
    required this.name,
    required this.description,
    required this.color,
    this.isDark = true,
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
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0A1F16),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF4A7A65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF00C896), size: 18),
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
    final textColor = isDark ? Colors.white : const Color(0xFF0A1F16);
    final subtitleColor = isDark ? Colors.white54 : const Color(0xFF4A7A65);
    final dividerColor = isDark
        ? Colors.white10
        : const Color(0xFF00A37A).withValues(alpha: 0.12);
    final chevronColor = isDark
        ? Colors.white24
        : const Color(0xFF4A7A65).withValues(alpha: 0.4);
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
            title: Text(
              'Widget de Home Screen',
              style: TextStyle(
                  color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Configurar widget en pantalla de inicio',
              style: TextStyle(color: subtitleColor, fontSize: 11),
            ),
            trailing: Icon(Icons.chevron_right, color: chevronColor),
            onTap: () {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚧 Widget de Home Screen - Próximamente'),
                    backgroundColor: Color(0xFF00C896),
                  ),
                );
              }
            },
          ),
          Divider(height: 1, color: dividerColor),
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
            title: Text(
              'Limpiar caché',
              style: TextStyle(
                  color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Eliminar imágenes temporales',
              style: TextStyle(color: subtitleColor, fontSize: 11),
            ),
            trailing: Icon(Icons.chevron_right, color: chevronColor),
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fg = isDark ? Colors.white : const Color(0xFF0A1F16);
  final step1 = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('🗑️ Borrar TODO',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
      content: Text(
        'Se eliminarán PERMANENTEMENTE todos tus datos. Esta acción no tiene marcha atrás.',
        style: TextStyle(color: fg.withValues(alpha: 0.7), height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancelar',
              style: TextStyle(color: fg.withValues(alpha: 0.5))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fg = isDark ? Colors.white : const Color(0xFF0A1F16);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(ctx).cardColor,
      title: const Text('⚠️ Confirmar borrado total',
          style: TextStyle(color: Colors.red)),
      content: Text(
        'Esto eliminará TODOS tus datos locales: ingredientes, recetas, menú semanal, prendas, outfits, evaluaciones nutricionales y ajustes. ¿Estás completamente seguro?',
        style: TextStyle(color: fg.withValues(alpha: 0.75)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancelar',
              style: TextStyle(color: fg.withValues(alpha: 0.5))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Borrar todo'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    try {
      final clearDbCallback = ref.read(clearAllDataCallbackProvider);
      if (clearDbCallback != null) {
        await clearDbCallback();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await ref.read(secureStorageProvider).deleteAll();
      await ref.read(userDisplayNameProvider.notifier).reset();
      ref.invalidate(themeModeProvider);
      await ref.read(backupProvider.notifier).refreshInfo();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Todos los datos locales fueron eliminados.'),
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

    // Directorio temporal (incluye APKs descargados, miniaturas de video y capturas temporales)
    final tempDir = await getTemporaryDirectory();
    if (await tempDir.exists()) {
      await for (final entity
          in tempDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
          await entity.delete();
          fileCount++;
        }
      }
    }

    // Caché legado de imágenes comprimidas (nunca borramos media/ que guarda fotos persistentes)
    final docDir = await getApplicationDocumentsDirectory();
    final compressedDir = Directory('${docDir.path}/compressed');
    if (await compressedDir.exists()) {
      await for (final entity
          in compressedDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
          await entity.delete();
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
    final textColor = isDark ? Colors.white : const Color(0xFF0A1F16);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111814) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.08)),
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
                style: TextStyle(
                  color: textColor,
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
