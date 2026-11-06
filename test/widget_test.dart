import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holidays/app.dart';

void main() {
  testWidgets('App boots to LoginScreen with Quick Demo Accounts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    expect(find.text('HOLIDAY'), findsOneWidget);
    expect(find.text('Quick Demo Accounts'), findsOneWidget);
  });
}
