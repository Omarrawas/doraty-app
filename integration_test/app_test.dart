import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doraty/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('App starts and displays something', (tester) async {
      // شغل التطبيق الخاص بك
      app.main();
      
      // انتظر حتى تكتمل الرسوم المتحركة وإعدادات البداية (مثل شاشة Splash)
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // تحقق من أن التطبيق لم ينهار ويعرض ويدجت داخله بشكل صحيح
      // بناءً على هيكل تطبيقك، قد يعرض SplashScreen ثم يتنقل
      expect(find.byType(MaterialApp), findsOneWidget);
      
      // يمكنك هنا إضافة خطوط متقدمة للبريد الإلكتروني والباسورد وتسجيل الدخول:
      // await tester.enterText(find.byKey(const Key('email')), 'test@example.com');
      // await tester.tap(find.text('تسجيل الدخول'));
      // await tester.pumpAndSettle();
      
      // طالما لم ينهار هذا الاختبار، فهذا يعني أن التطبيق يعمل بشكل جيد على المحاكي!
    });
  });
}
