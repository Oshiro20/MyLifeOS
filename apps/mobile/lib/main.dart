import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';

final _notifications = FlutterLocalNotificationsPlugin();

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
    ShellRoute(
      builder: (ctx, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/finanzas',
          builder: (context, state) => const FinanzasScreen(),
        ),
        GoRoute(
          path: '/cocina',
          builder: (context, state) => const CocinaScreen(),
          routes: [
            GoRoute(
              path: 'import',
              builder: (context, state) => const RecipeImporterScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/armario',
          builder: (context, state) => const ArmarioScreen(),
        ),
        GoRoute(
          path: '/foodcoach',
          builder: (context, state) => const FoodCoachScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
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
      // Cargar variables de entorno desde .env
      await dotenv.load(fileName: '.env');

      // Inicializar notificaciones locales
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      // Inicializar backup automático
      await AutoBackupService.initialize();

      // Verificar actualizaciones de WalletAI en background
      WalletUpdateNotifier(_notifications).checkForUpdates();
      // Verificar actualizaciones de MyLifeOS en background
      MyLifeOSUpdateNotifier(_notifications).checkForUpdates();

      runApp(
        ProviderScope(
          overrides: [
            cocinaRepositoryProvider.overrideWithValue(CocinaRepository(_db)),
            armarioRepositoryProvider.overrideWithValue(ArmarioRepository(_db)),
            foodCoachRepositoryProvider.overrideWith((ref) =>
                FoodCoachRepository(_db, ref.watch(geminiServiceProvider))),
            // Register cocina providers
            inventoryProvider.overrideWith(InventoryNotifier.new),
            recipesProvider.overrideWith(RecipesNotifier.new),
            // BackupService no requiere override — usa el Provider estándar
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

class _MyLifeOSAppState extends ConsumerState<MyLifeOSApp> {
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();

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

  void _handleSharedMedia(List<SharedMediaFile> value) {
    if (value.isNotEmpty) {
      final textOrUrl = value.first.path; // Url/Text defaults to path
      if (textOrUrl.isNotEmpty) {
        _router.go('/cocina/import');
        Future.delayed(const Duration(milliseconds: 500), () {
          ref
              .read(recipeImportProvider.notifier)
              .importFromTikTokUrl(textOrUrl);
        });
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'MyLifeOS',
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
      );
}

// ── App Shell con NavigationBar ──────────────────────────────────────────────
class _AppShell extends StatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  static const _tabs = [
    ('/home', Icons.home_outlined, 'Inicio'),
    ('/armario', Icons.checkroom_outlined, 'Armario'),
    ('/cocina', Icons.soup_kitchen_outlined, 'Cocina'),
    ('/finanzas', Icons.account_balance_wallet_outlined, 'Finanzas'),
    ('/foodcoach', Icons.restaurant_menu_outlined, 'FoodCoach'),
    ('/settings', Icons.settings_outlined, 'Ajustes'),
  ];

  int _indexFromLocation(String location) {
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: _tabs
            .map((t) => NavigationDestination(icon: Icon(t.$2), label: t.$3))
            .toList(),
      ),
    );
  }
}
