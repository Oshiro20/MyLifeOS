import 'package:flutter_test/flutter_test.dart';
import 'package:my_life_os/main.dart';

void main() {
  testWidgets('MyLifeOS smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyLifeOSApp());
    expect(find.byType(MyLifeOSApp), findsOneWidget);
  });
}
