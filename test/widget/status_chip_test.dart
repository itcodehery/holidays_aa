import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holidays/core/widgets/status_chip.dart';
import 'package:holidays/features/leave/domain/leave_status.dart';

void main() {
  testWidgets(
    'StatusChip renders an icon and a label for every status (accessibility)',
    (tester) async {
      for (final status in LeaveStatus.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(child: StatusChip(status: status)),
            ),
          ),
        );

        expect(find.text(status.label), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
      }
    },
  );
}
