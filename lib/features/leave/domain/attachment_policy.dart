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
  ///
  /// Any leave request above 3 working days (`workingDays > 3`) requires at
  /// least one supporting document.
  static ProofRequirement proofRequirement(LeaveType type, int workingDays) {
    if (workingDays > 3) {
      return ProofRequirement.required;
    }
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
        if (type == LeaveType.sick && workingDays > 2) {
          return 'Required: attach a medical certificate or bills (sick leave > 2 working days).';
        }
        if (type == LeaveType.marriage) {
          return 'Required: attach a wedding invitation or marriage document.';
        }
        if (type == LeaveType.bereavement) {
          return 'Required: attach supporting documentation for bereavement leave.';
        }
        return 'Required: leaves above 3 working days require at least 1 supporting document.';
      case ProofRequirement.optional:
        return 'Optional: attach medical proof if available (PDF, JPG, PNG up to 5 MB).';
      case ProofRequirement.none:
        return 'No supporting document required (you may still attach up to 5 files).';
    }
  }

  /// Contextual checklist message per [LeaveType] (`⭐ Proof checklist per leave type`).
  static String proofChecklistText(LeaveType type) {
    switch (type) {
      case LeaveType.marriage:
        return 'Marriage leave: attach an invitation card or marriage registration certificate.';
      case LeaveType.bereavement:
        return 'Bereavement leave: attach a family notice, hospital slip, or travel confirmation.';
      case LeaveType.sick:
        return 'Sick leave: attach a doctor\'s prescription, medical certificate, or lab report.';
      case LeaveType.unpaid:
        return 'Unpaid leave: attach a manager-aligned handover note or supporting document.';
      case LeaveType.annual:
        return 'Annual leave: attach a handover plan or travel itinerary (mandatory if > 3 working days).';
      case LeaveType.casual:
        return 'Casual leave: attach supporting proof or handover summary (mandatory if > 3 working days).';
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
