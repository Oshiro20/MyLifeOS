import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _notifSettingsPrefsKey = 'mylifeos_notification_settings_v1';

class DailyNotificationTime {
  final int hour;
  final int minute;

  const DailyNotificationTime(this.hour, this.minute);

  String format24h() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  factory DailyNotificationTime.fromJson(
    Map<String, dynamic>? json, {
    required DailyNotificationTime fallback,
  }) {
    if (json == null) return fallback;
    final h = (json['hour'] as num?)?.toInt();
    final m = (json['minute'] as num?)?.toInt();
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return fallback;
    }
    return DailyNotificationTime(h, m);
  }

  @override
  bool operator ==(Object other) =>
      other is DailyNotificationTime &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

class NotificationSettings {
  final bool mealsEnabled;
  final DailyNotificationTime breakfastTime;
  final DailyNotificationTime lunchTime;
  final DailyNotificationTime dinnerTime;
  final bool expiryAlertsEnabled;
  final DailyNotificationTime expiryAlertTime;
  final bool cookingTimerEnabled;
  final bool laundryReminderEnabled;
  final DailyNotificationTime laundryTime;

  const NotificationSettings({
    this.mealsEnabled = true,
    this.breakfastTime = const DailyNotificationTime(7, 30),
    this.lunchTime = const DailyNotificationTime(11, 30),
    this.dinnerTime = const DailyNotificationTime(18, 30),
    this.expiryAlertsEnabled = true,
    this.expiryAlertTime = const DailyNotificationTime(9, 30),
    this.cookingTimerEnabled = true,
    this.laundryReminderEnabled = true,
    this.laundryTime = const DailyNotificationTime(19, 30),
  });

  NotificationSettings copyWith({
    bool? mealsEnabled,
    DailyNotificationTime? breakfastTime,
    DailyNotificationTime? lunchTime,
    DailyNotificationTime? dinnerTime,
    bool? expiryAlertsEnabled,
    DailyNotificationTime? expiryAlertTime,
    bool? cookingTimerEnabled,
    bool? laundryReminderEnabled,
    DailyNotificationTime? laundryTime,
  }) =>
      NotificationSettings(
        mealsEnabled: mealsEnabled ?? this.mealsEnabled,
        breakfastTime: breakfastTime ?? this.breakfastTime,
        lunchTime: lunchTime ?? this.lunchTime,
        dinnerTime: dinnerTime ?? this.dinnerTime,
        expiryAlertsEnabled: expiryAlertsEnabled ?? this.expiryAlertsEnabled,
        expiryAlertTime: expiryAlertTime ?? this.expiryAlertTime,
        cookingTimerEnabled: cookingTimerEnabled ?? this.cookingTimerEnabled,
        laundryReminderEnabled:
            laundryReminderEnabled ?? this.laundryReminderEnabled,
        laundryTime: laundryTime ?? this.laundryTime,
      );

  Map<String, dynamic> toJson() => {
        'mealsEnabled': mealsEnabled,
        'breakfastTime': breakfastTime.toJson(),
        'lunchTime': lunchTime.toJson(),
        'dinnerTime': dinnerTime.toJson(),
        'expiryAlertsEnabled': expiryAlertsEnabled,
        'expiryAlertTime': expiryAlertTime.toJson(),
        'cookingTimerEnabled': cookingTimerEnabled,
        'laundryReminderEnabled': laundryReminderEnabled,
        'laundryTime': laundryTime.toJson(),
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        mealsEnabled: json['mealsEnabled'] as bool? ?? true,
        breakfastTime: DailyNotificationTime.fromJson(
          json['breakfastTime'] as Map<String, dynamic>?,
          fallback: const DailyNotificationTime(7, 30),
        ),
        lunchTime: DailyNotificationTime.fromJson(
          json['lunchTime'] as Map<String, dynamic>?,
          fallback: const DailyNotificationTime(11, 30),
        ),
        dinnerTime: DailyNotificationTime.fromJson(
          json['dinnerTime'] as Map<String, dynamic>?,
          fallback: const DailyNotificationTime(18, 30),
        ),
        expiryAlertsEnabled: json['expiryAlertsEnabled'] as bool? ?? true,
        expiryAlertTime: DailyNotificationTime.fromJson(
          json['expiryAlertTime'] as Map<String, dynamic>?,
          fallback: const DailyNotificationTime(9, 30),
        ),
        cookingTimerEnabled: json['cookingTimerEnabled'] as bool? ?? true,
        laundryReminderEnabled: json['laundryReminderEnabled'] as bool? ?? true,
        laundryTime: DailyNotificationTime.fromJson(
          json['laundryTime'] as Map<String, dynamic>?,
          fallback: const DailyNotificationTime(19, 30),
        ),
      );
}

class SmartNotificationContext {
  final int expiringPantryCount;
  final List<String> expiringPantryNames;
  final int preparedMealsCount;
  final String? firstPreparedMealName;
  final int dirtyGarmentsCount;
  final String? todayBreakfastName;
  final String? todayLunchName;
  final String? todayDinnerName;

  const SmartNotificationContext({
    this.expiringPantryCount = 0,
    this.expiringPantryNames = const [],
    this.preparedMealsCount = 0,
    this.firstPreparedMealName,
    this.dirtyGarmentsCount = 0,
    this.todayBreakfastName,
    this.todayLunchName,
    this.todayDinnerName,
  });
}

/// Motor centralizado de notificaciones locales programadas de MyLifeOS:
/// comidas diarias, caducidad de despensa/refri, temporizador de cocción y armario.
class AppNotificationsService {
  static const int breakfastId = 2001;
  static const int lunchId = 2002;
  static const int dinnerId = 2003;
  static const int expiryId = 2004;
  static const int laundryId = 2005;
  static const int cookingTimerId = 2010;
  static const int testNotificationId = 2099;

  static const _mealsChannel = AndroidNotificationDetails(
    'mylifeos_meals',
    'Recordatorios de comidas',
    channelDescription:
        'Sugerencias diarias para Desayuno, Almuerzo y Cena según tu despensa.',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _pantryChannel = AndroidNotificationDetails(
    'mylifeos_pantry_alerts',
    'Alertas de despensa y refri',
    channelDescription:
        'Avisos de ingredientes por vencer y comidas listas en el refrigerador.',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _timerChannel = AndroidNotificationDetails(
    'mylifeos_cooking_timer',
    'Temporizador de cocina',
    channelDescription: 'Aviso cuando termina el tiempo de una receta activa.',
    importance: Importance.max,
    priority: Priority.max,
  );

  static const _wardrobeChannel = AndroidNotificationDetails(
    'mylifeos_wardrobe',
    'Recordatorios de Armario',
    channelDescription: 'Avisos de prendas pendientes de lavado.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static bool _tzInitialized = false;

  final FlutterLocalNotificationsPlugin? _plugin;

  const AppNotificationsService([this._plugin]);

  /// Inicializa la base de zonas horarias y configura `tz.local` según el offset real.
  static void ensureTimeZonesInitialized() {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    final location = resolveLocationForOffset(DateTime.now().timeZoneOffset);
    tz.setLocalLocation(location);
    _tzInitialized = true;
  }

  /// Mapea el offset horario del dispositivo a una `tz.Location` válida sin plugin nativo.
  static tz.Location resolveLocationForOffset(Duration offset) {
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
    final hours = offset.inHours;
    final preferred = switch (hours) {
      -5 => 'America/Lima',
      -6 => 'America/Mexico_City',
      -4 => 'America/La_Paz',
      -3 => 'America/Argentina/Buenos_Aires',
      -7 => 'America/Denver',
      -8 => 'America/Los_Angeles',
      0 => 'UTC',
      1 => 'Europe/Madrid',
      2 => 'Europe/Madrid',
      _ => null,
    };
    if (preferred != null) {
      try {
        return tz.getLocation(preferred);
      } catch (_) {}
    }
    // POSIX Etc/GMT usa signo invertido: UTC-5 -> Etc/GMT+5
    if (hours >= -12 && hours <= 14) {
      final posixSign = hours <= 0 ? '+${-hours}' : '-$hours';
      try {
        return tz.getLocation('Etc/GMT$posixSign');
      } catch (_) {}
    }
    return tz.UTC;
  }

  /// Solicita permiso POST_NOTIFICATIONS en Android 13+.
  Future<bool> requestPermissions() async {
    final plugin = _plugin;
    if (plugin == null) return false;
    try {
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (e) {
      debugPrint('[AppNotificationsService] requestPermissions error: $e');
      return false;
    }
  }

  /// Construye el texto contextual para Desayuno, Almuerzo o Cena.
  static ({String title, String body}) buildMealCopy({
    required int mealSlot, // 0=desayuno, 1=almuerzo, 2=cena
    required SmartNotificationContext ctx,
  }) {
    if (mealSlot == 0) {
      final body = ctx.todayBreakfastName != null
          ? 'Plan de hoy: ${ctx.todayBreakfastName}. Toca para ver ingredientes.'
          : 'Abre tu lista rápida de desayunos listos con tu despensa actual.';
      return (title: '🌅 Hora del desayuno', body: body);
    }
    if (mealSlot == 1) {
      final urgentHint = ctx.expiringPantryNames.isNotEmpty
          ? ' Aprovecha ${ctx.expiringPantryNames.take(2).join(' y ')} antes de que venzan.'
          : '';
      final body = ctx.todayLunchName != null
          ? 'Plan de hoy: ${ctx.todayLunchName}.$urgentHint'
          : 'Revisa tus sugerencias rápidas de almuerzo.$urgentHint';
      return (title: '🍛 ¿Qué almorzamos hoy?', body: body);
    }
    if (ctx.firstPreparedMealName != null && ctx.preparedMealsCount > 0) {
      return (
        title: '🌙 Tienes comida lista en refri',
        body:
            'Te queda ${ctx.firstPreparedMealName} listo para recalentar y servir hoy.',
      );
    }
    final body = ctx.todayDinnerName != null
        ? 'Plan de hoy: ${ctx.todayDinnerName}. Toca para comenzar.'
        : 'Mira tus opciones ligeras y rápidas para cenar hoy.';
    return (title: '🌙 Sugerencias para la cena', body: body);
  }

  static tz.TZDateTime nextInstanceOfTime(
    DailyNotificationTime time, {
    tz.TZDateTime? now,
  }) {
    ensureTimeZonesInitialized();
    final refNow = now ?? tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      refNow.year,
      refNow.month,
      refNow.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(refNow)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Sincroniza todas las notificaciones programadas diarias según preferencias y contexto real.
  Future<void> syncScheduledNotifications({
    required NotificationSettings settings,
    SmartNotificationContext context = const SmartNotificationContext(),
  }) async {
    final plugin = _plugin;
    if (plugin == null) return;
    ensureTimeZonesInitialized();

    try {
      // 1. Comidas diarias (Desayuno, Almuerzo, Cena)
      if (settings.mealsEnabled) {
        final b = buildMealCopy(mealSlot: 0, ctx: context);
        await _scheduleDaily(
          id: breakfastId,
          time: settings.breakfastTime,
          title: b.title,
          body: b.body,
          details: const NotificationDetails(android: _mealsChannel),
          payload: '/cocina?tab=2',
        );

        final l = buildMealCopy(mealSlot: 1, ctx: context);
        await _scheduleDaily(
          id: lunchId,
          time: settings.lunchTime,
          title: l.title,
          body: l.body,
          details: const NotificationDetails(android: _mealsChannel),
          payload: '/cocina?tab=2',
        );

        final d = buildMealCopy(mealSlot: 2, ctx: context);
        await _scheduleDaily(
          id: dinnerId,
          time: settings.dinnerTime,
          title: d.title,
          body: d.body,
          details: const NotificationDetails(android: _mealsChannel),
          payload: '/cocina?tab=2',
        );
      } else {
        await plugin.cancel(breakfastId);
        await plugin.cancel(lunchId);
        await plugin.cancel(dinnerId);
      }

      // 2. Alerta consolidada de caducidad (Despensa + Comidas Listas)
      if (settings.expiryAlertsEnabled &&
          (context.expiringPantryCount > 0 || context.preparedMealsCount > 0)) {
        final parts = <String>[
          if (context.expiringPantryCount > 0)
            '${context.expiringPantryCount} ingrediente(s) por vencer'
                '${context.expiringPantryNames.isNotEmpty ? ' (${context.expiringPantryNames.take(2).join(', ')})' : ''}',
          if (context.preparedMealsCount > 0)
            '${context.preparedMealsCount} comida(s) lista(s) en refri',
        ];
        await _scheduleDaily(
          id: expiryId,
          time: settings.expiryAlertTime,
          title: '⚠️ Revisa tu despensa y refri',
          body: '${parts.join(' · ')}. ¡Evita desperdicios hoy!',
          details: const NotificationDetails(android: _pantryChannel),
          payload: context.expiringPantryCount > 0
              ? '/cocina?tab=0'
              : '/cocina?tab=2',
        );
      } else {
        await plugin.cancel(expiryId);
      }

      // 3. Recordatorio de Armario (prendas por lavar)
      if (settings.laundryReminderEnabled && context.dirtyGarmentsCount > 0) {
        await _scheduleDaily(
          id: laundryId,
          time: settings.laundryTime,
          title: '🧺 Tienes ropa por lavar',
          body:
              '${context.dirtyGarmentsCount} prenda(s) esperando lavado en tu Armario.',
          details: const NotificationDetails(android: _wardrobeChannel),
          payload: '/armario',
        );
      } else {
        await plugin.cancel(laundryId);
      }
    } catch (e) {
      debugPrint('[AppNotificationsService] sync error: $e');
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required DailyNotificationTime time,
    required String title,
    required String body,
    required NotificationDetails details,
    required String payload,
  }) async {
    final plugin = _plugin;
    if (plugin == null) return;
    await plugin.zonedSchedule(
      id,
      title,
      body,
      nextInstanceOfTime(time),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// Programa una notificación real para cuando termine el tiempo de cocción.
  Future<void> scheduleCookingTimer({
    required String recipeName,
    required int minutes,
  }) async {
    final plugin = _plugin;
    if (plugin == null || minutes <= 0) return;
    ensureTimeZonesInitialized();
    try {
      final fireAt =
          tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
      await plugin.zonedSchedule(
        cookingTimerId,
        '⏰ ¡Tiempo cumplido en Cocina!',
        '"$recipeName" ya debería estar listo. Toca para finalizar o guardar sobras.',
        fireAt,
        const NotificationDetails(android: _timerChannel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '/cocina?tab=2',
      );
    } catch (e) {
      debugPrint('[AppNotificationsService] scheduleCookingTimer error: $e');
    }
  }

  Future<void> cancelCookingTimer() async {
    final plugin = _plugin;
    if (plugin == null) return;
    try {
      await plugin.cancel(cookingTimerId);
    } catch (_) {}
  }

  /// Envía una notificación inmediata de prueba para confirmar permisos en Android.
  Future<bool> sendTestNotification() async {
    final plugin = _plugin;
    if (plugin == null) return false;
    final granted = await requestPermissions();
    if (!granted) return false;
    try {
      await plugin.show(
        testNotificationId,
        '✅ Notificaciones activas en MyLifeOS',
        'Recibirás recordatorios de tus comidas, despensa y temporizador de cocina.',
        const NotificationDetails(android: _mealsChannel),
        payload: '/cocina?tab=2',
      );
      return true;
    } catch (e) {
      debugPrint('[AppNotificationsService] sendTestNotification error: $e');
      return false;
    }
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  bool _loaded = false;
  Future<void>? _loadFuture;

  @override
  NotificationSettings build() {
    Future.microtask(load);
    return const NotificationSettings();
  }

  Future<void> load() => _loadFuture ??= _readFromPrefs();

  Future<void> _readFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_notifSettingsPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          state = NotificationSettings.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> update(NotificationSettings next) async {
    if (!_loaded) await load();
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notifSettingsPrefsKey, jsonEncode(next.toJson()));
    } catch (_) {}
    await ref
        .read(appNotificationsServiceProvider)
        .syncScheduledNotifications(settings: next);
  }
}

final appNotificationsServiceProvider = Provider<AppNotificationsService>(
  (ref) => const AppNotificationsService(),
);

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  NotificationSettingsNotifier.new,
);
