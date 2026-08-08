import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firesight_mobile/main.dart';
import 'package:firesight_mobile/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        return 'none';
      },
    );
    await AuthService().initialize();
  });

  testWidgets('App load test', (WidgetTester tester) async {
    await tester.pumpWidget(const FireSightApp());
    expect(find.byType(FireSightApp), findsOneWidget);
  });
}
