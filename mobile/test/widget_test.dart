import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tracker_mobile/main.dart';
import 'package:tracker_mobile/services/auth_service.dart';
import 'package:tracker_mobile/services/finance_service.dart';
import 'package:tracker_mobile/services/theme_service.dart';

void main() {
  testWidgets('MyApp renders login screen when not authenticated',
      (tester) async {
    final authService = AuthService();
    final themeService = ThemeService();
    final financeService = FinanceService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<ThemeService>.value(value: themeService),
          ChangeNotifierProvider<FinanceService>.value(value: financeService),
        ],
        child: const MyApp(isLoggedIn: false),
      ),
    );

    expect(find.textContaining('Student'), findsOneWidget);
  });
}
