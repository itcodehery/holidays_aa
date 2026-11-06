import 'attachment.dart';
import 'leave_status.dart';

/// Pure Dart validator for leave attachments and proof requirements.
/// Has zero Flutter or database dependencies.
class AttachmentPolicy {
  const AttachmentPolicy._();

  static const int maxFiles = 5;
  static const int maxBytes = 5 * 1024 * 1024;
  static const Set<String> allowedExt = {'pdf', 'jpg', 'jpeg', 'png'};

  /// Determines whether proof documents are required, optional, or not needed
  /// based on the [type] of leave and [workingDays] duration.
  static ProofRequirement proofRequirement(LeaveType type, int workingDays) {
    switch (type) {
      case LeaveType.marriage:
      case LeaveType.bereavement:
        return ProofRequirement.required;
      case LeaveType.sick:
        return workingDays > 2
            ? ProofRequirement.required
            : ProofRequirement.optional;
      default:
        return ProofRequirement.none;
    }
  }

  /// Human-readable helper message explaining the proof rule in the Apply UI.
  static String helperText(LeaveType type, int workingDays) {
    final req = proofRequirement(type, workingDays);
    switch (req) {
      case ProofRequirement.required:
        if (type == LeaveType.sick) {
          return 'Required: attach a medical certificate or bills (sick leave > 2 working days).';
        }
        if (type == LeaveType.marriage) {
          return 'Required: attach a wedding invitation or marriage document.';
        }
        return 'Required: attach supporting documentation for bereavement leave.';
      case ProofRequirement.optional:
        return 'Optional: attach medical proof if available (PDF, JPG, PNG up to 5 MB).';
      case ProofRequirement.none:
        return 'No supporting document required (you may still attach up to 5 files).';
    }
  }

  /// Returns `null` if [f] is valid, otherwise a user-facing error message.
  static String? validateFile(PickedAttachment f) {
    final parts = f.name.split('.');
    final ext = parts.length > 1 ? parts.last.toLowerCase() : '';
    if (!allowedExt.contains(ext)) {
      return 'Only PDF, JPG or PNG files are allowed.';
    }
    if (f.sizeBytes > maxBytes) {
      return '${f.name} is larger than 5 MB.';
    }
    return null;
  }

  /// Validates the full set of [files] against [req] and per-file constraints.
  static String? validateSet(
    List<PickedAttachment> files,
    ProofRequirement req,
  ) {
    if (files.length > maxFiles) {
      return 'You can attach up to $maxFiles files.';
    }
    if (req == ProofRequirement.required && files.isEmpty) {
      return 'Supporting documents are required for this leave.';
    }
    for (final f in files) {
      final err = validateFile(f);
      if (err != null) return err;
    }
    return null;
  }
}
