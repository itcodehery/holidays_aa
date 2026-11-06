import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:holidays/features/leave/domain/attachment.dart';
import 'package:holidays/features/leave/domain/attachment_policy.dart';
import 'package:holidays/features/leave/domain/leave_status.dart';

PickedAttachment file(String name, int sizeBytes) {
  return PickedAttachment(name, Uint8List(sizeBytes), 'application/pdf');
}

void main() {
  group('proofRequirement', () {
    test('sick 2 days optional', () {
      expect(
        AttachmentPolicy.proofRequirement(LeaveType.sick, 2),
        ProofRequirement.optional,
      );
    });

    test('sick 3 days required', () {
      expect(
        AttachmentPolicy.proofRequirement(LeaveType.sick, 3),
        ProofRequirement.required,
      );
    });

    test('marriage always required', () {
      expect(
        AttachmentPolicy.proofRequirement(LeaveType.marriage, 1),
        ProofRequirement.required,
      );
    });

    test('bereavement always required', () {
      expect(
        AttachmentPolicy.proofRequirement(LeaveType.bereavement, 1),
        ProofRequirement.required,
      );
    });

    test('annual / casual / unpaid require no proof when <= 3 days, but require proof when > 3 days', () {
      expect(
        AttachmentPolicy.proofRequirement(LeaveType.annual, 3),
        ProofRequirement.none,
      );
      expect(
        AttachmentPolicy.proofRequirement(LeaveType.annual, 4),
        ProofRequirement.required,
      );
      expect(
        AttachmentPolicy.proofRequirement(LeaveType.casual, 2),
        ProofRequirement.none,
      );
      expect(
        AttachmentPolicy.proofRequirement(LeaveType.unpaid, 3),
        ProofRequirement.none,
      );
      expect(
        AttachmentPolicy.proofRequirement(LeaveType.unpaid, 4),
        ProofRequirement.required,
      );
    });
  });

  group('validateFile & validateSet', () {
    test('rejects .exe', () {
      expect(AttachmentPolicy.validateFile(file('a.exe', 10)), isNotNull);
    });

    test('rejects > 5MB', () {
      expect(
        AttachmentPolicy.validateFile(file('a.pdf', 5 * 1024 * 1024 + 1)),
        isNotNull,
      );
    });

    test('accepts 1MB pdf', () {
      expect(
        AttachmentPolicy.validateFile(file('a.pdf', 1024 * 1024)),
        isNull,
      );
    });

    test('required proof with zero files fails', () {
      expect(
        AttachmentPolicy.validateSet([], ProofRequirement.required),
        isNotNull,
      );
    });

    test('more than 5 files fails', () {
      expect(
        AttachmentPolicy.validateSet(
          List.generate(6, (_) => file('a.pdf', 10)),
          ProofRequirement.optional,
        ),
        isNotNull,
      );
    });
  });
}
