import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holidays/app.dart';

void main() {
  testWidgets('App boots to LoginScreen without demo accounts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    expect(find.text('INTERLUDE'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Quick Demo Accounts'), findsNothing);
  });
}
