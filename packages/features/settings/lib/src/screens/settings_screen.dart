import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          _BackupSection(backup: backup, isDark: isDark),
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
      if (await WalletCloudService.isSignedIn()) {
        await WalletCloudService.updateProfile(displayName: newName);
      }
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

class _NotificationsSection extends ConsumerStatefulWidget {
  final bool isDark;

  const _NotificationsSection({required this.isDark});

  @override
  ConsumerState<_NotificationsSection> createState() =>
      _NotificationsSectionState();
}

class _NotificationsSectionState extends ConsumerState<_NotificationsSection>
    with WidgetsBindingObserver {
  bool _notificationsGranted = true;
  bool _exactAlarmsGranted = true;
  bool _batteryUnrestricted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final service = ref.read(appNotificationsServiceProvider);
    final notif = await service.areNotificationsEnabled();
    final exact = await service.canScheduleExactAlarms();
    final battery = await service.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _notificationsGranted = notif;
      _exactAlarmsGranted = exact;
      _batteryUnrestricted = battery;
    });
  }

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
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
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
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFF00C896).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00C896).withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _notificationsGranted
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      size: 17,
                      color: _notificationsGranted
                          ? const Color(0xFF00C896)
                          : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _notificationsGranted
                            ? 'Permiso de notificaciones activo'
                            : 'Falta permiso de notificaciones',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!_notificationsGranted)
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(appNotificationsServiceProvider)
                              .requestPermissions();
                          await _refreshPermissions();
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Activar',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _exactAlarmsGranted ? Icons.alarm_on : Icons.alarm_off,
                      size: 17,
                      color: _exactAlarmsGranted
                          ? const Color(0xFF00C896)
                          : Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _exactAlarmsGranted
                            ? 'Alarmas exactas activas (puntuales con app cerrada)'
                            : 'Alarmas exactas desactivadas (pueden retrasarse)',
                        style: TextStyle(color: muted, fontSize: 11.5),
                      ),
                    ),
                    if (!_exactAlarmsGranted)
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(appNotificationsServiceProvider)
                              .requestExactAlarmPermission();
                          await _refreshPermissions();
                          // Re-disparar sync al habilitar alarmas exactas
                          if (_exactAlarmsGranted) {
                            await notifier.update(settings);
                          }
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Permitir',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _batteryUnrestricted
                          ? Icons.battery_charging_full
                          : Icons.battery_alert,
                      size: 17,
                      color: _batteryUnrestricted
                          ? const Color(0xFF00C896)
                          : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _batteryUnrestricted
                            ? 'Segundo plano sin restricciones activo'
                            : 'Segundo plano restringido por batería',
                        style: TextStyle(color: muted, fontSize: 11.5),
                      ),
                    ),
                    if (!_batteryUnrestricted)
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(appNotificationsServiceProvider)
                              .requestIgnoreBatteryOptimizations();
                          await _refreshPermissions();
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Activar',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'En Xiaomi/Honor/Oppo, toca "Ajustes Android" y activa Inicio automático para que el sistema no mate las alarmas al cerrar recientes.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
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
                      (t) =>
                          notifier.update(settings.copyWith(breakfastTime: t)),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await ref
                        .read(appNotificationsServiceProvider)
                        .scheduleTestNotificationIn(
                          delay: const Duration(seconds: 10),
                        );
                    await _refreshPermissions();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? '⏱️ Prueba programada en 10s. Sal con Home o bloquea la pantalla para comprobar.'
                              : '⚠️ Activa el permiso de notificaciones para MyLifeOS en Android',
                        ),
                        backgroundColor:
                            ok ? const Color(0xFF00C896) : Colors.orange,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  },
                  icon: const Icon(Icons.timer_outlined,
                      size: 16, color: Color(0xFF00C896)),
                  label: const Text(
                    'Probar en 10s',
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
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(appNotificationsServiceProvider)
                    .openAppSettings(),
                icon: Icon(Icons.settings_outlined, size: 16, color: muted),
                label: Text(
                  'Ajustes',
                  style: TextStyle(color: muted, fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: muted.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                final ok = await ref
                    .read(appNotificationsServiceProvider)
                    .sendTestNotification();
                await _refreshPermissions();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? '🔔 Notificación inmediata enviada al dispositivo'
                          : '⚠️ Activa el permiso de notificaciones para MyLifeOS en Android',
                    ),
                    backgroundColor:
                        ok ? const Color(0xFF00C896) : Colors.orange,
                  ),
                );
              },
              icon: Icon(Icons.notifications_outlined, size: 16, color: muted),
              label: Text(
                'Enviar prueba inmediata',
                style: TextStyle(color: muted, fontSize: 12.5),
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

// ── Cuenta del Ecosistema + Backup Nube & Local ──────────────────────────────

class _BackupSection extends ConsumerStatefulWidget {
  final BackupState backup;
  final bool isDark;
  const _BackupSection({required this.backup, required this.isDark});

  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  String? _cloudUsername;
  String? _cloudDisplayName;
  String? _cloudEmail;
  bool _cloudHasRecoveryKey = false;
  MyLifeOSCloudBackupMeta? _cloudBackupMeta;
  bool _loadingCloud = false;

  bool _includePhotos = false;
  bool _autoBackupEnabled = false;
  String _autoBackupDest = 'cloud';
  String? _autoLastRunIso;
  String? _autoLastStatus;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final session = await WalletCloudService.getSession();
    final autoEnabled = await AutoBackupService.isEnabled();
    final autoDest = await AutoBackupService.getDestination();
    final includePhotos = await AutoBackupService.getIncludePhotos();
    final lastRun = await AutoBackupService.getLastRunInfo();

    if (!mounted) return;
    setState(() {
      _cloudUsername = session.username;
      _cloudDisplayName = session.displayName;
      _cloudEmail = session.email;
      _cloudHasRecoveryKey = session.hasRecoveryKey;
      _autoBackupEnabled = autoEnabled;
      _autoBackupDest = autoDest;
      _includePhotos = includePhotos;
      _autoLastRunIso = lastRun.lastRunIso;
      _autoLastStatus = lastRun.lastStatus;
    });

    if (session.token != null && session.token!.isNotEmpty) {
      await _refreshCloudInfo();
    }
  }

  Future<void> _refreshCloudInfo() async {
    if (!mounted) return;
    setState(() => _loadingCloud = true);
    await WalletCloudService.fetchProfile();
    final session = await WalletCloudService.getSession();
    final status = await WalletCloudService.fetchMyLifeOSBackupStatus();
    if (!mounted) return;
    setState(() {
      _loadingCloud = false;
      _cloudUsername = session.username;
      _cloudDisplayName = session.displayName;
      _cloudEmail = session.email;
      _cloudHasRecoveryKey = session.hasRecoveryKey;
      if (status.success) {
        _cloudBackupMeta = status.latestBackup;
      }
    });
    if (session.displayName != null && session.displayName!.trim().isNotEmpty) {
      final currentLocal = ref.read(userDisplayNameProvider);
      if (currentLocal == 'Usuario' || currentLocal.trim().isEmpty) {
        await ref
            .read(userDisplayNameProvider.notifier)
            .setName(session.displayName!.trim());
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF00C896),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatIso(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showRecoveryKeyDialog(String recoveryKey) async {
    if (!mounted) return;
    final fg = widget.isDark ? Colors.white : const Color(0xFF0A1F16);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.vpn_key, color: Color(0xFFFFB74D)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Guarda tu Clave de Recuperación',
                style: TextStyle(color: fg, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta clave se muestra una sola vez. Guárdala en un lugar seguro: te sirve para recuperar tu contraseña o usuario tanto en MyLifeOS como en WalletAI.',
              style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB74D).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: SelectableText(
                recoveryKey,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: recoveryKey));
              _snack('Clave copiada al portapapeles');
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar clave'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C896),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Ya la guardé',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRecoverPasswordDialog() async {
    final idCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscure = true;
    bool submitting = false;
    String? errorMsg;

    final recoveredUser = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: Color(0xFFFFB74D)),
              SizedBox(width: 8),
              Flexible(child: Text('Recuperar contraseña')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa tu usuario o correo vinculado, tu clave de recuperación (MLO-...) y tu nueva contraseña.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Usuario o correo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: keyCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Clave de recuperación',
                    hintText: 'MLO-XXXX-XXXX-XXXX',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    hintText: 'Mínimo 6 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () =>
                          setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      if (idCtrl.text.trim().isEmpty ||
                          keyCtrl.text.trim().length < 8 ||
                          passCtrl.text.length < 6) {
                        setDialogState(() {
                          errorMsg =
                              'Completa todos los campos (contraseña mín. 6).';
                        });
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        errorMsg = null;
                      });
                      final res = await WalletCloudService.recoverPassword(
                        identifier: idCtrl.text.trim(),
                        recoveryKey: keyCtrl.text.trim(),
                        newPassword: passCtrl.text,
                      );
                      if (!ctx.mounted) return;
                      if (res.success) {
                        Navigator.pop(ctx, res.username ?? idCtrl.text.trim());
                      } else {
                        setDialogState(() {
                          submitting = false;
                          errorMsg = res.message;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Restablecer',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (recoveredUser != null) {
      _snack(
          '✅ Contraseña actualizada para @$recoveredUser. Ya puedes iniciar sesión.');
    }
  }

  Future<void> _openRecoverUsernameDialog() async {
    final emailCtrl = TextEditingController();
    final secretCtrl = TextEditingController();
    bool useKey = false;
    bool submitting = false;
    String? errorMsg;

    final found = await showDialog<({String username, String? displayName})>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.person_search, color: Color(0xFF00C896)),
              SizedBox(width: 8),
              Flexible(child: Text('Recuperar usuario')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa tu correo vinculado y verifica con tu contraseña o clave de recuperación.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo vinculado',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Usar clave de recuperación',
                      style: TextStyle(fontSize: 12.5)),
                  value: useKey,
                  onChanged: (v) => setDialogState(() {
                    useKey = v;
                    secretCtrl.clear();
                    errorMsg = null;
                  }),
                ),
                TextField(
                  controller: secretCtrl,
                  obscureText: !useKey,
                  textCapitalization: useKey
                      ? TextCapitalization.characters
                      : TextCapitalization.none,
                  decoration: InputDecoration(
                    labelText: useKey
                        ? 'Clave de recuperación (MLO-...)'
                        : 'Contraseña',
                    prefixIcon: Icon(
                        useKey ? Icons.vpn_key_outlined : Icons.lock_outline),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      if (!emailCtrl.text.contains('@') ||
                          secretCtrl.text.trim().isEmpty) {
                        setDialogState(() {
                          errorMsg =
                              'Ingresa un correo válido y tu verificación.';
                        });
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        errorMsg = null;
                      });
                      final res = await WalletCloudService.recoverUsername(
                        email: emailCtrl.text.trim(),
                        password: useKey ? null : secretCtrl.text,
                        recoveryKey: useKey ? secretCtrl.text.trim() : null,
                      );
                      if (!ctx.mounted) return;
                      if (res.success && res.username != null) {
                        Navigator.pop(ctx, (
                          username: res.username!,
                          displayName: res.displayName,
                        ));
                      } else {
                        setDialogState(() {
                          submitting = false;
                          errorMsg = res.message;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Consultar',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (found != null && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('Usuario encontrado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (found.displayName != null && found.displayName!.isNotEmpty)
                Text('Nombre: ${found.displayName}'),
              const SizedBox(height: 6),
              SelectableText(
                'Usuario: @${found.username}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: found.username));
                Navigator.pop(ctx);
                _snack('Usuario "${found.username}" copiado');
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copiar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Listo', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openAuthDialog({required bool isRegister}) async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final displayCtrl = TextEditingController(
      text: isRegister ? ref.read(userDisplayNameProvider) : '',
    );
    if (displayCtrl.text == 'Usuario') displayCtrl.clear();
    final emailCtrl = TextEditingController();
    bool obscure = true;
    bool submitting = false;
    String? errorMsg;

    final result = await showDialog<
        ({
          bool success,
          String message,
          String username,
          String? recoveryKey,
          MyLifeOSCloudBackupMeta? myLifeOSBackup,
        })>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.account_circle_outlined,
                  color: Color(0xFF00C896)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(isRegister
                    ? 'Crear cuenta del Ecosistema'
                    : 'Iniciar sesión (MyLifeOS + WalletAI)'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isRegister
                      ? 'Usa una sola cuenta para respaldar MyLifeOS y WalletAI y sincronizar ambos aplicativos.'
                      : 'Ingresa tu usuario o correo vinculado y contraseña.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                if (isRegister) ...[
                  TextField(
                    controller: displayCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre visible (opcional)',
                      hintText: 'Ej: Joel Orbezo',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: userCtrl,
                  decoration: InputDecoration(
                    labelText: isRegister
                        ? 'Nombre de usuario (@)'
                        : 'Usuario o correo',
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                if (isRegister) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo de recuperación (opcional)',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Mínimo 6 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () =>
                          setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
                if (!isRegister) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(
                        onPressed: submitting
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _openRecoverPasswordDialog();
                              },
                        child: const Text('¿Olvidaste contraseña?',
                            style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: submitting
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _openRecoverUsernameDialog();
                              },
                        child: const Text('¿Olvidaste usuario?',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      final u = userCtrl.text.trim();
                      final p = passCtrl.text;
                      if (u.length < 3 || p.length < 6) {
                        setDialogState(() {
                          errorMsg =
                              'Usuario mínimo 3 caracteres y contraseña mínimo 6.';
                        });
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        errorMsg = null;
                      });
                      final res = await WalletCloudService.authenticate(
                        username: u,
                        password: p,
                        isRegister: isRegister,
                        displayName: displayCtrl.text.trim().isEmpty
                            ? null
                            : displayCtrl.text.trim(),
                        email: emailCtrl.text.trim().isEmpty
                            ? null
                            : emailCtrl.text.trim(),
                      );
                      if (!ctx.mounted) return;
                      if (res.success) {
                        Navigator.pop(ctx, (
                          success: true,
                          message: res.message,
                          username: res.username ?? u.toLowerCase(),
                          recoveryKey: res.recoveryKey,
                          myLifeOSBackup: res.myLifeOSBackup,
                        ));
                      } else {
                        setDialogState(() {
                          submitting = false;
                          errorMsg = res.message;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isRegister ? 'Registrar' : 'Entrar',
                      style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == null || !result.success || !mounted) return;
    await _loadState();
    _snack('✅ ${result.message}');

    if (result.recoveryKey != null && result.recoveryKey!.isNotEmpty) {
      await _showRecoveryKeyDialog(result.recoveryKey!);
    }

    final cloudBackup = result.myLifeOSBackup;
    if (cloudBackup != null && cloudBackup.exists && mounted) {
      final restoreNow = await _showConfirmDialog(
        context,
        title: '☁️ Respaldo de MyLifeOS encontrado',
        message:
            'Encontramos un respaldo en tu cuenta (@${result.username}):\n\n'
            '• Dispositivo: ${cloudBackup.deviceName ?? "Otro equipo"}\n'
            '• Fecha: ${_formatIso(cloudBackup.updatedAt)}\n'
            '• Tamaño: ${_formatSize(cloudBackup.sizeBytes)}'
            '${cloudBackup.includesPhotos ? " (con fotos)" : ""}\n\n'
            '¿Deseas restaurarlo ahora en este dispositivo?',
        confirmLabel: 'Restaurar ahora',
        confirmColor: const Color(0xFF00C896),
      );
      if (restoreNow && mounted) {
        await _restoreFromCloud(skipConfirm: true);
      }
    }
  }

  Future<void> _openManageAccountDialog() async {
    final displayCtrl = TextEditingController(
      text: _cloudDisplayName ?? ref.read(userDisplayNameProvider),
    );
    final emailCtrl = TextEditingController(text: _cloudEmail ?? '');
    final userCtrl = TextEditingController(text: _cloudUsername ?? '');
    final userPwdCtrl = TextEditingController();
    final curPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final regenPwdCtrl = TextEditingController();
    bool saving = false;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final usernameChanged = userCtrl.text.trim().toLowerCase() !=
              (_cloudUsername ?? '').toLowerCase();
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.manage_accounts, color: Color(0xFF00C896)),
                SizedBox(width: 8),
                Flexible(child: Text('Perfil y Seguridad')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cuenta compartida con WalletAI',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: displayCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre visible',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo de recuperación (opcional)',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: userCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario (@)',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  if (usernameChanged) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: userPwdCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña actual (para cambiar @usuario)',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C896),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              if (usernameChanged && userPwdCtrl.text.isEmpty) {
                                setDialogState(() {
                                  errorMsg =
                                      'Ingresa tu contraseña actual para cambiar tu usuario.';
                                });
                                return;
                              }
                              setDialogState(() {
                                saving = true;
                                errorMsg = null;
                              });
                              final res =
                                  await WalletCloudService.updateProfile(
                                displayName: displayCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                username: usernameChanged
                                    ? userCtrl.text.trim()
                                    : null,
                                currentPassword:
                                    usernameChanged ? userPwdCtrl.text : null,
                              );
                              if (!ctx.mounted) return;
                              setDialogState(() => saving = false);
                              if (res.success) {
                                if (displayCtrl.text.trim().isNotEmpty) {
                                  await ref
                                      .read(userDisplayNameProvider.notifier)
                                      .setName(displayCtrl.text.trim());
                                }
                                await _loadState();
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                _snack('✅ ${res.message}');
                              } else {
                                setDialogState(() => errorMsg = res.message);
                              }
                            },
                      icon: const Icon(Icons.save_outlined,
                          size: 18, color: Colors.white),
                      label: const Text('Guardar perfil',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Cambiar contraseña',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: curPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña actual',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña (mín. 6)',
                      prefixIcon: Icon(Icons.lock_reset),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (curPassCtrl.text.isEmpty ||
                                  newPassCtrl.text.length < 6) {
                                setDialogState(() {
                                  errorMsg =
                                      'Ingresa contraseña actual y nueva (mín. 6).';
                                });
                                return;
                              }
                              setDialogState(() {
                                saving = true;
                                errorMsg = null;
                              });
                              final res =
                                  await WalletCloudService.changePassword(
                                currentPassword: curPassCtrl.text,
                                newPassword: newPassCtrl.text,
                              );
                              if (!ctx.mounted) return;
                              setDialogState(() => saving = false);
                              if (res.success) {
                                Navigator.pop(ctx);
                                _snack('✅ ${res.message}');
                              } else {
                                setDialogState(() => errorMsg = res.message);
                              }
                            },
                      child: const Text('Actualizar contraseña'),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(
                        _cloudHasRecoveryKey
                            ? Icons.verified_user
                            : Icons.warning_amber,
                        size: 18,
                        color: _cloudHasRecoveryKey
                            ? const Color(0xFF00C896)
                            : const Color(0xFFFFB74D),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _cloudHasRecoveryKey
                              ? 'Clave de recuperación activa'
                              : 'Genera tu clave de recuperación',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: regenPwdCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña actual para (re)generar clave',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              if (regenPwdCtrl.text.isEmpty) {
                                setDialogState(() {
                                  errorMsg =
                                      'Escribe tu contraseña actual para generar la clave.';
                                });
                                return;
                              }
                              setDialogState(() {
                                saving = true;
                                errorMsg = null;
                              });
                              final res = await WalletCloudService
                                  .regenerateRecoveryKey(
                                currentPassword: regenPwdCtrl.text,
                              );
                              if (!ctx.mounted) return;
                              setDialogState(() => saving = false);
                              if (res.success && res.recoveryKey != null) {
                                await _loadState();
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                await _showRecoveryKeyDialog(res.recoveryKey!);
                              } else {
                                setDialogState(() => errorMsg = res.message);
                              }
                            },
                      icon: const Icon(Icons.vpn_key, size: 17),
                      label: Text(_cloudHasRecoveryKey
                          ? 'Regenerar clave de recuperación'
                          : 'Generar clave de recuperación ahora'),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMsg!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _uploadToCloud({bool force = false}) async {
    final res = await ref.read(backupProvider.notifier).uploadToCloud(
          includePhotos: _includePhotos,
          force: force,
        );
    if (!mounted) return;

    if (res.hasConflict && res.serverBackup != null) {
      final b = res.serverBackup!;
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Row(
            children: [
              Icon(Icons.sync_problem, color: Color(0xFFFFB74D)),
              SizedBox(width: 8),
              Flexible(child: Text('Conflicto entre dispositivos')),
            ],
          ),
          content: Text(
            'Otro equipo (${b.deviceName ?? "Otro celular"}) subió un respaldo más reciente el ${_formatIso(b.updatedAt)} (${_formatSize(b.sizeBytes)}).\n\n'
            '¿Qué deseas hacer?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'download'),
              child: const Text('Descargar nube'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB74D),
              ),
              onPressed: () => Navigator.pop(ctx, 'force'),
              child: const Text('Sobrescribir nube',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (action == 'download') {
        await _restoreFromCloud(skipConfirm: true);
      } else if (action == 'force') {
        await _uploadToCloud(force: true);
      }
      return;
    }

    await _refreshCloudInfo();
    _snack(
      res.success
          ? '${res.message} (${_formatSize(res.sizeBytes)}${res.photosCount > 0 ? ', ${res.photosCount} fotos' : ''})'
          : res.message,
      isError: !res.success,
    );
  }

  Future<void> _restoreFromCloud({bool skipConfirm = false}) async {
    if (!skipConfirm) {
      final ok = await _showConfirmDialog(
        context,
        title: '☁️ Restaurar desde la nube',
        message:
            'Se restaurará tu base de datos, preferencias, perfil corporal, equivalencias y fotos incluidas desde tu Cuenta del Ecosistema.\n\n'
            'Tus datos actuales en este dispositivo serán reemplazados.',
        confirmLabel: '¡Restaurar ahora!',
        confirmColor: Colors.red,
        isDestructive: true,
      );
      if (!ok || !mounted) return;
    }

    final result = await ref.read(backupProvider.notifier).restoreFromCloud();
    if (!mounted) return;
    if (result is RestoreSuccess) {
      _snack(
        '✅ Restaurado (${result.prefsRestored} ajustes'
        '${result.photosRestored > 0 ? ', ${result.photosRestored} fotos' : ''}). Reinicia la app para aplicar todos los cambios.',
      );
    } else if (result is BackupFailure) {
      _snack('❌ ${result.message}', isError: true);
    }
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    if (enabled &&
        (_autoBackupDest == 'cloud' || _autoBackupDest == 'both') &&
        _cloudUsername == null) {
      _snack(
        'Inicia sesión primero con tu Cuenta del Ecosistema o cambia el destino a Local.',
        isError: true,
      );
      return;
    }
    if (enabled) {
      await AutoBackupService.enable(
        destination: _autoBackupDest,
        includePhotos: _includePhotos,
      );
      _snack('✅ Backup automático diario activado ($_autoBackupDest)');
    } else {
      await AutoBackupService.disable();
      _snack('Backup automático desactivado');
    }
    await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final backup = widget.backup;
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : const Color(0xFF0A1F16);
    final muted = isDark ? Colors.white54 : const Color(0xFF4A7A65);

    return _SectionCard(
      isDark: isDark,
      icon: Icons.cloud_sync_outlined,
      title: 'Cuenta & Backup en Nube',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cuenta única del Ecosistema ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00C896).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00C896).withValues(alpha: 0.25),
              ),
            ),
            child: _cloudUsername == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cuenta única (MyLifeOS + WalletAI)',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Inicia sesión para respaldar tu despensa, recetas, armario, perfil y preferencias en la nube.',
                        style: TextStyle(color: muted, fontSize: 11.5),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C896),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () =>
                                  _openAuthDialog(isRegister: false),
                              icon: const Icon(Icons.login,
                                  size: 16, color: Colors.white),
                              label: const Text('Entrar',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Color(0xFF00C896)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () =>
                                  _openAuthDialog(isRegister: true),
                              icon: const Icon(Icons.person_add_alt_1,
                                  size: 16, color: Color(0xFF00C896)),
                              label: const Text('Crear cuenta',
                                  style: TextStyle(color: Color(0xFF00C896))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: _openRecoverPasswordDialog,
                          child: const Text(
                            '¿Olvidaste tu contraseña o usuario?',
                            style: TextStyle(
                                fontSize: 11.5, color: Color(0xFFFFB74D)),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                const Color(0xFF00C896).withValues(alpha: 0.2),
                            child: const Icon(Icons.verified_user,
                                color: Color(0xFF00C896), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (_cloudDisplayName != null &&
                                          _cloudDisplayName!.isNotEmpty)
                                      ? _cloudDisplayName!
                                      : '@$_cloudUsername',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '@$_cloudUsername'
                                  '${(_cloudEmail != null && _cloudEmail!.isNotEmpty) ? ' · $_cloudEmail' : ''}',
                                  style:
                                      TextStyle(color: muted, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.manage_accounts_outlined,
                                color: Color(0xFF00C896), size: 20),
                            tooltip: 'Editar perfil y seguridad',
                            onPressed: _openManageAccountDialog,
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout,
                                color: Colors.redAccent, size: 19),
                            tooltip: 'Cerrar sesión',
                            onPressed: () async {
                              await WalletCloudService.signOut();
                              await _loadState();
                              _snack('Sesión cerrada');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _loadingCloud
                            ? 'Consultando respaldo en la nube...'
                            : (_cloudBackupMeta?.exists == true
                                ? '☁️ Último respaldo nube: ${_formatIso(_cloudBackupMeta!.updatedAt)} '
                                    '(${_formatSize(_cloudBackupMeta!.sizeBytes)}'
                                    '${_cloudBackupMeta!.includesPhotos ? ', con fotos' : ''})'
                                : 'Sin respaldo de MyLifeOS subido aún'),
                        style: const TextStyle(
                          color: Color(0xFF00C896),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!_cloudHasRecoveryKey) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _openManageAccountDialog,
                          child: const Text(
                            '⚠️ Recomendado: genera tu clave de recuperación en Perfil y Seguridad →',
                            style: TextStyle(
                              color: Color(0xFFFFB74D),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // ── Switch incluir fotos del Armario y FoodCoach ─────────────────
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Incluir fotos (Armario / FoodCoach)',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Respaldo V2 incluye DB + preferencias + fotos opcionales',
              style: TextStyle(color: muted, fontSize: 11),
            ),
            value: _includePhotos,
            activeTrackColor: const Color(0xFF00C896),
            onChanged: (v) async {
              setState(() => _includePhotos = v);
              await AutoBackupService.setIncludePhotos(v);
            },
          ),

          if (_cloudUsername != null) ...[
            const SizedBox(height: 6),
            _BackupActionTile(
              icon: Icons.cloud_upload_outlined,
              label: 'Subir copia a la nube ahora',
              subtitle:
                  'DB (${_formatSize(backup.dbSizeBytes)}) + ajustes${_includePhotos ? ' + fotos' : ''}',
              color: const Color(0xFF00C896),
              isLoading: backup.status == BackupStatus.exportingInProgress,
              onTap: () => _uploadToCloud(),
            ),
            const SizedBox(height: 8),
            _BackupActionTile(
              icon: Icons.cloud_download_outlined,
              label: 'Restaurar desde la nube',
              subtitle: _cloudBackupMeta?.exists == true
                  ? 'Equipo: ${_cloudBackupMeta!.deviceName ?? "Otro equipo"}'
                  : 'Disponible al subir tu primer respaldo',
              color: const Color(0xFF42A5F5),
              isLoading: backup.status == BackupStatus.importingInProgress,
              onTap: _cloudBackupMeta?.exists == true
                  ? () => _restoreFromCloud()
                  : () => _snack('Aún no tienes una copia en la nube.',
                      isError: true),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Backup automático diario (WorkManager real) ──────────────────
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Backup automático diario (24h)',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _autoBackupEnabled
                  ? 'Activo · Destino: ${_autoBackupDest == 'cloud' ? 'Nube' : _autoBackupDest == 'local' ? 'Local' : 'Nube + Local'}'
                      '${_autoLastRunIso != null ? '\nÚltimo: ${_formatIso(_autoLastRunIso)} (${_autoLastStatus ?? "OK"})' : ''}'
                  : 'Desactivado · Se ejecuta en segundo plano cada 24h',
              style: TextStyle(color: muted, fontSize: 11),
            ),
            value: _autoBackupEnabled,
            activeTrackColor: const Color(0xFF00C896),
            onChanged: _toggleAutoBackup,
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _autoBackupDest,
            decoration: InputDecoration(
              labelText: 'Destino del backup automático',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'cloud', child: Text('Nube (Cuenta Ecosistema)')),
              DropdownMenuItem(
                  value: 'local', child: Text('Local (en el dispositivo)')),
              DropdownMenuItem(value: 'both', child: Text('Nube + Local')),
            ],
            onChanged: (val) async {
              if (val == null) return;
              setState(() => _autoBackupDest = val);
              await AutoBackupService.setDestination(val);
            },
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Backup local archivo .mylifeos_backup ────────────────────────
          _BackupActionTile(
            icon: Icons.file_upload_outlined,
            label: 'Exportar archivo local',
            subtitle: 'Crear .mylifeos_backup V2 (DB + ajustes)',
            color: const Color(0xFF00C896),
            isLoading: backup.status == BackupStatus.exportingInProgress,
            onTap: () => _exportBackup(context),
          ),
          const SizedBox(height: 8),
          _BackupActionTile(
            icon: Icons.file_download_outlined,
            label: 'Restaurar archivo local',
            subtitle: 'Seleccionar archivo .mylifeos_backup',
            color: const Color(0xFFFFB74D),
            isLoading: backup.status == BackupStatus.importingInProgress,
            onTap: () => _importBackup(context),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    final ok = await _showConfirmDialog(
      context,
      title: '¿Exportar backup?',
      message:
          'Se creará un archivo V2 con tu base de datos, perfil, preferencias${_includePhotos ? ' y fotos' : ''}.',
      confirmLabel: 'Exportar',
      confirmColor: const Color(0xFF00C896),
    );
    if (!ok) return;

    final result = await ref
        .read(backupProvider.notifier)
        .exportBackup(includePhotos: _includePhotos);
    if (!mounted) return;

    if (result is BackupSuccess) {
      _snack(
          '✅ Backup exportado (${_formatSize(result.sizeBytes)}, ${result.prefsCount} ajustes)');
    } else if (result is BackupFailure) {
      _snack('❌ ${result.message}', isError: true);
    }
  }

  Future<void> _importBackup(BuildContext context) async {
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
    if (!mounted) return;

    if (backupResult is RestoreSuccess) {
      _snack('✅ ¡Restauración exitosa! Reinicia la app para aplicar cambios.');
    } else if (backupResult is BackupFailure) {
      _snack('❌ ${backupResult.message}', isError: true);
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
    final fg = widget.isDark ? Colors.white : const Color(0xFF0A1F16);
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
