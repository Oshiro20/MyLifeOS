import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life_os/services/mylifeos_update_service.dart';
import 'package:my_life_os/widgets/update_dialog.dart';

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
}
