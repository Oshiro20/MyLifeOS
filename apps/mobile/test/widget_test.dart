import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life_os/screens/splash_screen.dart';
import 'package:my_life_os/services/mylifeos_update_service.dart';
import 'package:my_life_os/widgets/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('MyLifeOSUpdateService.isVersionGreater compara versiones semánticas correctamente', () {
    expect(MyLifeOSUpdateService.isVersionGreater('v3.6.0', '3.5.1'), isTrue);
    expect(MyLifeOSUpdateService.isVersionGreater('3.5.1', '3.5.1+1'), isFalse);
    expect(MyLifeOSUpdateService.isVersionGreater('3.6.0', '3.6'), isFalse);
    expect(MyLifeOSUpdateService.isVersionGreater('3.6.1', '3.6'), isTrue);
    expect(MyLifeOSUpdateService.isVersionGreater('3.4.9', '3.5.0'), isFalse);
  });

  testWidgets('MyLifeOSUpdateDialog muestra versión y notas formateadas sin romper modo claro',
      (WidgetTester tester) async {
    final release = GithubRelease(
      tagName: 'v3.6.0',
      body: '## Novedades\n- Mejora en cocina-salud\n- Soporte modo claro',
      apkUrl: 'https://example.com/app.apk',
      fileName: 'MyLifeOS-v3.6.0.apk',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(body: MyLifeOSUpdateDialog(release: release)),
      ),
    );

    expect(find.text('✨ Actualización disponible'), findsOneWidget);
    expect(find.text('Nueva versión v3.6.0'), findsOneWidget);
    expect(find.textContaining('Mejora en cocina-salud'), findsOneWidget);
  });

  testWidgets('SplashScreen navega desde /splash hacia /home tras 2s',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME_OK')),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(body: Text('ONBOARDING_OK')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('MyLifeOS'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();

    expect(find.text('HOME_OK'), findsOneWidget);
  });
}
