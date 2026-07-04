import 'package:flutter_test/flutter_test.dart';
import 'package:manikutti_flutter/main.dart';
import 'package:manikutti_flutter/screens/login_screen.dart';

void main() {
  testWidgets('App renders LoginScreen when not logged in', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(isLoggedIn: false));

    // Verify that the login screen is displayed
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
