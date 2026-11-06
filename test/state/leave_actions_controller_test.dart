import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holidays/core/errors/app_exception.dart';
import 'package:holidays/features/leave/data/leave_repository.dart';
import 'package:holidays/features/leave/domain/attachment.dart';
import 'package:holidays/features/leave/domain/leave_request.dart';
import 'package:holidays/features/leave/domain/leave_status.dart';
import 'package:holidays/features/leave/presentation/leave_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockLeaveRepository extends Mock implements LeaveRepository {}

class FakeNewLeaveRequest extends Fake implements NewLeaveRequest {}

NewLeaveRequest newRequest({required int days}) {
  return NewLeaveRequest(
    employeeId: 'usr-emp-1',
    leaveType: LeaveType.annual,
    startDate: DateTime(2026, 11, 9),
    endDate: DateTime(2026, 11, 9 + days - 1),
    reason: 'Controller test leave reason',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeNewLeaveRequest());
    registerFallbackValue(<PickedAttachment>[]);
  });

  test('submit failure surfaces AsyncError and does not invalidate list', () async {
    final mock = MockLeaveRepository();
    var listFetchCount = 0;

    when(() => mock.getMyRequests(any())).thenAnswer((_) async {
      listFetchCount++;
      return const [];
    });
    when(
      () => mock.submit(any(), any()),
    ).thenThrow(const AppException('Upload failed'));

    final c = ProviderContainer(
      overrides: [leaveRepositoryProvider.overrideWithValue(mock)],
    );
    addTearDown(c.dispose);

    // Prime myRequestsProvider once
    await c.read(myRequestsProvider.future);
    expect(listFetchCount, 1);

    await c.read(leaveActionsProvider.notifier).submit(newRequest(days: 1), []);
    expect(c.read(leaveActionsProvider).hasError, true);

    // Ensure myRequestsProvider was not invalidated after failed submit
    await c.read(myRequestsProvider.future);
    expect(listFetchCount, 1);
  });
}
