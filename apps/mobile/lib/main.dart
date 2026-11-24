import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:data/data.dart';
import 'package:finanzas/finanzas.dart';
import 'package:cocina/cocina.dart';
import 'package:armario/armario.dart';
import 'package:foodcoach/foodcoach.dart';
import 'package:settings/settings.dart';
import 'package:core/core.dart';
import 'package:domain/domain.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';

final _notifications = FlutterLocalNotificationsPlugin();
final _appNotifications = AppNotificationsService(_notifications);
void Function(int tab)? _onSelectCocinaTab;

// ── Router ───────────────────────────────────────────────────────────────────
final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    // Splash y onboarding fuera del ShellRoute (sin bottom nav)
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/armario',
            builder: (context, state) => const ArmarioScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/cocina',
            builder: (context, state) => const CocinaScreen(),
            routes: [
              GoRoute(
                path: 'import',
                builder: (context, state) => const RecipeImporterScreen(),
              ),
              GoRoute(
                path: 'weekly-plan',
                builder: (context, state) => const WeeklyPlanScreen(),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/finanzas',
            builder: (context, state) => const FinanzasScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/foodcoach',
            builder: (context, state) => const FoodCoachScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ]),
      ],
    ),
  ],
);

// ── Entry Point ──────────────────────────────────────────────────────────────
final _db = AppDatabase();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar manejo de errores global
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      'Flutter Error: ${details.exception}',
      name: 'MyLifeOS.Error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Capturar errores de Zone (errores asíncronos no manejados)
  runZonedGuarded(
    () async {
      // Inicializar zonas horarias y notificaciones locales con handler de navegación
      AppNotificationsService.ensureTimeZonesInitialized();
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload ?? '';
          if (payload == 'update_walletai') {
            _router.go('/finanzas');
          } else if (payload == 'update_mylifeos') {
            _router.go('/home');
          } else if (payload.startsWith('/cocina')) {
            final uri = Uri.tryParse(payload);
            final tab = int.tryParse(uri?.queryParameters['tab'] ?? '');
            if (tab != null) _onSelectCocinaTab?.call(tab);
            _router.go('/cocina');
          } else if (payload.startsWith('/')) {
            _router.go(payload);
          }
        },
      );
      unawaited(_appNotifications.requestPermissions());

      // Inicializar backup automático
      await AutoBackupService.initialize();

      // Verificar actualizaciones de WalletAI en background
      WalletUpdateNotifier(_notifications).checkForUpdates();
      // Verificar actualizaciones de MyLifeOS en background
      MyLifeOSUpdateNotifier(_notifications).checkForUpdates();

      runApp(
        ProviderScope(
          overrides: [
            appNotificationsServiceProvider.overrideWithValue(_appNotifications),
            cocinaRepositoryProvider.overrideWithValue(CocinaRepository(_db)),
            armarioRepositoryProvider.overrideWithValue(ArmarioRepository(_db)),
            foodCoachRepositoryProvider.overrideWith(
                (ref) => FoodCoachRepository(_db, ref.watch(geminiProvider))),
            pantryIngredientsFeedProvider.overrideWith((ref) =>
                ref.read(cocinaRepositoryProvider).getAllIngredients),
            recipesFeedProvider.overrideWith(
                (ref) => ref.read(cocinaRepositoryProvider).getAllRecipes),
            todayMealStatsFeedProvider.overrideWith(
                (ref) => ref.read(foodCoachRepositoryProvider).getWeeklyStats),
            // Register cocina providers
            inventoryProvider.overrideWith(InventoryNotifier.new),
            recipesProvider.overrideWith(RecipesNotifier.new),
            walletPantryDirectImportProvider.overrideWith((ref) =>
                ref.read(inventoryProvider.notifier).importGroceryCandidates),
            // Real clear-all-data callback for SettingsScreen
            clearAllDataCallbackProvider.overrideWith((ref) => () async {
                  await _db.clearAllUserData();
                  ref.invalidate(armarioProvider);
                  ref.invalidate(inventoryProvider);
                  ref.invalidate(recipesProvider);
                  ref.invalidate(foodCoachProvider);
                  ref.invalidate(whatCanICookProvider);
                  ref.invalidate(walletSummaryProvider);
                  ref.read(aiChatProvider.notifier).clearHistory();
                }),
            // BackupService wired with WAL checkpoint and DB close callbacks
            backupServiceProvider.overrideWith((ref) => BackupService(
                  checkpointDbFn: () => _db.checkpointWal(),
                  closeDbFn: () => _db.close(),
                )),
          ],
          child: const MyLifeOSApp(),
        ),
      );
    },
    (error, stackTrace) {
      developer.log(
        'Uncaught Zone Error: $error',
        name: 'MyLifeOS.Error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}

class MyLifeOSApp extends ConsumerStatefulWidget {
  const MyLifeOSApp({super.key});

  @override
  ConsumerState<MyLifeOSApp> createState() => _MyLifeOSAppState();
}

class _MyLifeOSAppState extends ConsumerState<MyLifeOSApp>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription? _intentDataStreamSubscription;
  Timer? _notifSyncDebounce;
  bool _runningWalletAutoSync = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onSelectCocinaTab = (tab) {
      if (mounted) ref.read(cocinaTabProvider.notifier).setTab(tab);
    };
    _scheduleNotificationsSync();

    // Listen to media sharing incoming links while the app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      _handleSharedMedia(value);
    });

    // Listen to media sharing incoming links when the app is closed
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      _handleSharedMedia(value);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(walletSummaryProvider);
      _scheduleNotificationsSync();
    }
  }

  void _scheduleNotificationsSync() {
    _notifSyncDebounce?.cancel();
    _notifSyncDebounce = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      unawaited(_syncSmartNotifications());
    });
  }

  Future<void> _syncSmartNotifications() async {
    try {
      final settings = ref.read(notificationSettingsProvider);
      final rawPantry = ref
          .read(inventoryProvider)
          .ingredients
          .where((i) =>
              i.subCategory != 'Porción guardada' &&
              i.subCategory != 'Extra listo')
          .toList();
      final expiringItems =
          rawPantry.where((i) => i.isExpiringSoon || i.isExpired).toList();
      final preparedMeals = ref.read(preparedMealsProvider);
      final dirtyCount =
          ref.read(armarioProvider).garments.where((g) => !g.isClean).length;
      final recipes = ref.read(recipesProvider).recipes;
      final weeklyState = ref.read(weeklyMenuProvider);

      String? todayBreakfast;
      String? todayLunch;
      String? todayDinner;
      if (weeklyState is WeeklyMenuLoaded) {
        final today = DateTime.now().weekday;
        String? nameFor(int mealType) {
          final entry = weeklyState.entries
              .where((e) => e.dayOfWeek == today && e.mealType == mealType)
              .firstOrNull;
          if (entry == null) return null;
          return recipes
              .where((r) => r.id == entry.recipeId)
              .firstOrNull
              ?.name;
        }

        todayBreakfast = nameFor(0);
        todayLunch = nameFor(1);
        todayDinner = nameFor(2);
      }

      await ref.read(appNotificationsServiceProvider).syncScheduledNotifications(
            settings: settings,
            context: SmartNotificationContext(
              expiringPantryCount: expiringItems.length,
              expiringPantryNames: expiringItems.map((e) => e.name).toList(),
              preparedMealsCount: preparedMeals.length,
              firstPreparedMealName: preparedMeals.firstOrNull?.recipeName,
              dirtyGarmentsCount: dirtyCount,
              todayBreakfastName: todayBreakfast,
              todayLunchName: todayLunch,
              todayDinnerName: todayDinner,
            ),
          );
    } catch (e) {
      developer.log('Smart notifications sync error: $e',
          name: 'MyLifeOS.Notifications');
    }
  }

  Future<void> _autoSyncWalletPurchases(WalletSummary summary) async {
    if (_runningWalletAutoSync || !mounted) return;
    _runningWalletAutoSync = true;
    try {
      final bridge = ref.read(walletGroceryBridgeProvider);
      final batch = await bridge.extractPendingAutoSyncBatch(summary);
      if (batch.baselineJustInitialized || !batch.hasAny) return;

      final addedLabels = <String>[];

      if (batch.poultryBreakdowns.isNotEmpty) {
        await ref
            .read(pendingPoultryBreakdownsProvider.notifier)
            .enqueue(batch.poultryBreakdowns);
        addedLabels.add(
          '🍗 ${batch.poultryBreakdowns.first.itemName}: toca Despensa para dividir en presas',
        );
      }

      if (batch.groceries.isNotEmpty) {
        final count = await ref
            .read(inventoryProvider.notifier)
            .importGroceryCandidates(batch.groceries);
        if (count > 0) {
          final names =
              batch.groceries.map((g) => g.itemName).take(2).join(', ');
          addedLabels.add(
            '🛒 Despensa: $names${batch.groceries.length > 2 ? ' (+${batch.groceries.length - 2})' : ''}',
          );
        }
      }

      if (batch.wardrobe.isNotEmpty) {
        final armarioState = ref.read(armarioProvider);
        final armarioNotifier = ref.read(armarioProvider.notifier);
        final existingNames = armarioState.garments
            .map((g) => g.name.trim().toLowerCase())
            .toSet();
        int wardrobeCount = 0;
        for (final w in batch.wardrobe) {
          if (existingNames.contains(w.itemName.trim().toLowerCase())) continue;
          final idx = w.garmentTypeIndex.clamp(0, GarmentType.values.length - 1);
          await armarioNotifier.addGarment(WardrobeGarment(
            id: 'wal_${DateTime.now().microsecondsSinceEpoch}_$wardrobeCount',
            name: w.itemName,
            type: GarmentType.values[idx],
            primaryColor: '#4A5568',
            price: w.price,
            addedAt: DateTime.now(),
          ));
          existingNames.add(w.itemName.trim().toLowerCase());
          wardrobeCount++;
        }
        if (wardrobeCount > 0) {
          addedLabels.add(
            '👕 Armario: ${batch.wardrobe.first.itemName}',
          );
        }
      }

      if (batch.appliances.isNotEmpty) {
        int appCount = 0;
        for (final a in batch.appliances) {
          final inserted = await _db.upsertApplianceIfMissing(
            id: 'app_${DateTime.now().microsecondsSinceEpoch}_$appCount',
            name: a.name,
            type: a.type,
          );
          if (inserted) appCount++;
        }
        if (appCount > 0) {
          addedLabels.add(
            '🍳 Utensilio: ${batch.appliances.first.name}',
          );
        }
      }

      for (final key in batch.allProcessedKeys) {
        await bridge.markTxProcessed(key);
      }
      ref.read(walletPendingGroceryRefreshProvider.notifier).bump();

      if (addedLabels.isNotEmpty && mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('WalletAI → ${addedLabels.join(' · ')}'),
            backgroundColor: const Color(0xFF00C896),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      developer.log('WalletAI auto-sync error: $e', name: 'MyLifeOS.Wallet');
    } finally {
      _runningWalletAutoSync = false;
    }
  }

  void _handleSharedMedia(List<SharedMediaFile> value) {
    if (value.isNotEmpty) {
      final textOrUrl = value.first.path; // Url/Text defaults to path
      ReceiveSharingIntent.instance.reset();
      if (textOrUrl.isNotEmpty) {
        _router.go('/cocina/import');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          ref
              .read(recipeImportProvider.notifier)
              .importFromTikTokUrl(textOrUrl);
        });
      }
    }
  }

  @override
  void dispose() {
    _notifSyncDebounce?.cancel();
    _onSelectCocinaTab = null;
    WidgetsBinding.instance.removeObserver(this);
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<WalletSummary?>>(walletSummaryProvider, (_, next) {
      final summary = next.asData?.value;
      if (summary != null) {
        unawaited(_autoSyncWalletPurchases(summary));
      }
    });
    ref.listen<NotificationSettings>(
        notificationSettingsProvider, (_, __) => _scheduleNotificationsSync());
    ref.listen<InventoryState>(
        inventoryProvider, (_, __) => _scheduleNotificationsSync());
    ref.listen<List<PreparedMeal>>(
        preparedMealsProvider, (_, __) => _scheduleNotificationsSync());
    ref.listen<ArmarioState>(
        armarioProvider, (_, __) => _scheduleNotificationsSync());
    ref.listen<WeeklyMenuState>(
        weeklyMenuProvider, (_, __) => _scheduleNotificationsSync());
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'MyLifeOS',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }

  // ── Emerald Night (modo oscuro) ──────────────────────────────────────────
  ThemeData _buildDarkTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C896),
          brightness: Brightness.dark,
          surface: const Color(0xFF0A0F0D),
          primary: const Color(0xFF00C896),
          secondary: const Color(0xFFE0F7F0),
          tertiary: const Color(0xFFFF6B6B),
          onSurface: const Color(0xFFF0FFF8),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0F0D),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1A14),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFFF0FFF8),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: Color(0xFF00C896)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0F1A14),
          indicatorColor: const Color(0x3300C896),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(color: Color(0xFFA8C5B8), fontSize: 11),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF00C896));
            }
            return const IconThemeData(color: Color(0xFFA8C5B8));
          }),
        ),
        cardColor: const Color(0xFF152019),
        dividerColor: const Color(0xFF00C896).withValues(alpha: 0.1),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFA8C5B8)),
          bodyLarge: TextStyle(color: Color(0xFFF0FFF8)),
          titleLarge:
              TextStyle(color: Color(0xFFF0FFF8), fontWeight: FontWeight.w700),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF00C896),
          foregroundColor: Color(0xFF0A0F0D),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF152019),
          selectedColor: const Color(0xFF00C896).withValues(alpha: 0.2),
          labelStyle: const TextStyle(color: Color(0xFFA8C5B8)),
          side: const BorderSide(color: Color(0xFF00C896), width: 0.5),
        ),
      );

  // ── Emerald Day (modo claro) ─────────────────────────────────────────────
  ThemeData _buildLightTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A37A),
          brightness: Brightness.light,
          surface: const Color(0xFFF4FBF8),
          primary: const Color(0xFF00A37A),
          secondary: const Color(0xFF4A7A65),
          tertiary: const Color(0xFFD32F2F),
          onSurface: const Color(0xFF0A1F16),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4FBF8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF0A1F16),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: Color(0xFF00A37A)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFFFFFFF),
          indicatorColor: const Color(0x2200A37A),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(color: Color(0xFF4A7A65), fontSize: 11),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF00A37A));
            }
            return const IconThemeData(color: Color(0xFF4A7A65));
          }),
        ),
        cardColor: const Color(0xFFFFFFFF),
        dividerColor: const Color(0xFF00A37A).withValues(alpha: 0.15),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF4A7A65)),
          bodyLarge: TextStyle(color: Color(0xFF0A1F16)),
          titleLarge:
              TextStyle(color: Color(0xFF0A1F16), fontWeight: FontWeight.w700),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF00A37A),
          foregroundColor: Color(0xFFFFFFFF),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFE0F7F0),
          selectedColor: const Color(0xFF00A37A).withValues(alpha: 0.15),
          labelStyle: const TextStyle(color: Color(0xFF0A1F16)),
          side: const BorderSide(color: Color(0xFF00A37A), width: 0.5),
        ),
        // Ensure dialogs and alerts have proper light mode text
        dialogTheme: const DialogThemeData(backgroundColor: Color(0xFFFFFFFF)),
        listTileTheme: const ListTileThemeData(
          textColor: Color(0xFF0A1F16),
          iconColor: Color(0xFF4A7A65),
        ),
        snackBarTheme: const SnackBarThemeData(
          contentTextStyle: TextStyle(color: Color(0xFFFFFFFF)),
        ),
      );
}

// ── App Shell con NavigationBar ──────────────────────────────────────────────
class _AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _AppShell({required this.navigationShell});

  static const _tabs = [
    (Icons.home_outlined, 'Inicio'),
    (Icons.checkroom_outlined, 'Armario'),
    (Icons.soup_kitchen_outlined, 'Cocina'),
    (Icons.account_balance_wallet_outlined, 'Finanzas'),
    (Icons.restaurant_menu_outlined, 'FoodCoach'),
    (Icons.settings_outlined, 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: _tabs
            .map((t) => NavigationDestination(icon: Icon(t.$1), label: t.$2))
            .toList(),
      ),
    );
  }
}
