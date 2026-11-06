import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holidays/features/leave/domain/leave_status.dart';
import 'package:holidays/features/leave/presentation/employee/apply_leave_screen.dart';

void main() {
  testWidgets(
    'Apply screen shows two-stage approval banner when range exceeds 3 working days',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ApplyLeaveScreen(
                initialStartDate: DateTime(2026, 11, 9), // Monday
                initialEndDate: DateTime(2026, 11, 13), // Friday (5 days)
              ),
            ),
          ),
        ),
      );

      expect(find.text('Working days: 5'), findsOneWidget);
      expect(
        find.byKey(const Key('two_stage_approval_banner')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'This request needs approval from your manager and HR',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Submit button is disabled and validation message appears when proof is required and no file is attached',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ApplyLeaveScreen(
                initialLeaveType: LeaveType.sick,
                initialStartDate: DateTime(2026, 11, 9),
                initialEndDate: DateTime(2026, 11, 11), // 3 working days -> required
              ),
            ),
          ),
        ),
      );

      expect(
        find.text('Supporting documents are required for this leave.'),
        findsOneWidget,
      );

      final submitFinder = find.byKey(const Key('submit_leave_button'));
      expect(submitFinder, findsOneWidget);

      final submitWidget = tester.widget<ButtonStyleButton>(submitFinder);
      expect(submitWidget.onPressed, isNull);
    },
  );
}
