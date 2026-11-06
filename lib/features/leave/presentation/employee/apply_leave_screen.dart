import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/editorial_summary_header.dart';
import '../../../auth/data/auth_repository.dart' as auth_data;
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/attachment.dart';
import '../../domain/attachment_policy.dart';
import '../../domain/leave_policy.dart';
import '../../domain/leave_request.dart';
import '../../domain/leave_status.dart';
import '../leave_providers.dart';
import '../widgets/attachment_picker.dart';
import '../widgets/date_range_field.dart';

/// Two-tone employee form screen for submitting a new leave request with live
/// working-day calculation, two-stage approval warning banner, and proof
/// validation.
class ApplyLeaveScreen extends ConsumerStatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final LeaveType initialLeaveType;
  final VoidCallback? onSubmitted;

  const ApplyLeaveScreen({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.initialLeaveType = LeaveType.annual,
    this.onSubmitted,
  });

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  late LeaveType _leaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  final List<PickedAttachment> _files = [];
  String? _dateError;

  @override
  void initState() {
    super.initState();
    _leaveType = widget.initialLeaveType;
    if (widget.initialStartDate != null && widget.initialEndDate != null) {
      _startDate = widget.initialStartDate;
      _endDate = widget.initialEndDate;
    } else {
      final now = DateTime.now();
      var nextWeekday = DateTime(now.year, now.month, now.day + 1);
      while (nextWeekday.weekday == DateTime.saturday ||
          nextWeekday.weekday == DateTime.sunday) {
        nextWeekday = DateTime(
          nextWeekday.year,
          nextWeekday.month,
          nextWeekday.day + 1,
        );
      }
      _startDate = nextWeekday;
      _endDate = nextWeekday;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _workingDays {
    if (_startDate == null || _endDate == null) return 0;
    return LeavePolicy.countWorkingDays(_startDate!, _endDate!);
  }

  ProofRequirement get _proofRequirement =>
      AttachmentPolicy.proofRequirement(_leaveType, _workingDays);

  String? get _attachmentValidationError =>
      AttachmentPolicy.validateSet(_files, _proofRequirement);

  DateTime get _referenceToday =>
      widget.initialStartDate ?? DateTime.now();

  Future<void> _submit() async {
    final dateErr = LeavePolicy.validateDates(
      _startDate,
      _endDate,
      today: _referenceToday,
    );
    setState(() => _dateError = dateErr);

    final isFormValid = _formKey.currentState?.validate() ?? false;
    final attErr = _attachmentValidationError;
    if (dateErr != null || !isFormValid || attErr != null) {
      return;
    }

    final user =
        ref.read(currentUserProvider) ?? auth_data.DemoUsers.employee;

    final req = NewLeaveRequest(
      employeeId: user.id,
      leaveType: _leaveType,
      startDate: _startDate!,
      endDate: _endDate!,
      reason: _reasonController.text.trim(),
    );

    final created = await ref
        .read(leaveActionsProvider.notifier)
        .submit(req, List.unmodifiable(_files));

    if (!mounted) return;

    if (created != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created.requiresSecondApproval
                ? 'Request submitted! Sent for Stage 1 (Manager) & Stage 2 (HR) approval.'
                : 'Leave request submitted successfully!',
          ),
        ),
      );
      if (widget.onSubmitted != null) {
        widget.onSubmitted!();
      } else if (GoRouter.maybeOf(context) != null) {
        context.go(
          user.isEmployee ? '/employee/requests' : '/approver/history',
        );
      }
    } else {
      final err = ref.read(leaveActionsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err?.toString() ?? 'Failed to submit leave request.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider) ?? auth_data.DemoUsers.employee;
    final actionState = ref.watch(leaveActionsProvider);
    final isSubmitting = actionState.isLoading;
    final workingDays = _workingDays;
    final attError = _attachmentValidationError;
    final isSubmitDisabled =
        isSubmitting || workingDays <= 0 || attError != null;
    final firstName = user.fullName.split(' ').first;

    return ColoredBox(
      color: AppTheme.obsidian,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialSummaryHeader(
            greetingName: firstName,
            summarySpans: [
              const TextSpan(text: 'You are selecting '),
              EditorialSummaryHeader.highlightSpan(
                '$workingDays working ${workingDays == 1 ? 'day' : 'days'}',
              ),
              const TextSpan(text: ' of '),
              EditorialSummaryHeader.highlightSpan(_leaveType.label),
              TextSpan(
                text: workingDays > 3
                    ? ' — requires Manager & HR approval.'
                    : ' — single-stage Manager approval.',
              ),
            ],
            metrics: [
              EditorialMetric(
                icon: LucideIcons.calendarDays,
                label: '$workingDays working days',
              ),
              EditorialMetric(
                icon: LucideIcons.paperclip,
                label: '${_files.length}/5 files attached',
              ),
            ],
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.alabasterCanvas,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 110),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC8C3B7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Apply for Leave',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.inkDark,
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<LeaveType>(
                            key: const Key('leave_type_dropdown'),
                            initialValue: _leaveType,
                            dropdownColor: AppTheme.ivoryCard,
                            icon: const Icon(
                              LucideIcons.chevronDown,
                              size: 18,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Leave Type',
                              prefixIcon: Icon(LucideIcons.layers, size: 18),
                            ),
                            items: [
                              for (final type in LeaveType.values)
                                DropdownMenuItem(
                                  value: type,
                                  child: Text(type.label),
                                ),
                            ],
                            onChanged: isSubmitting
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() => _leaveType = val);
                                    }
                                  },
                          ),
                          const SizedBox(height: 14),
                          DateRangeField(
                            startDate: _startDate,
                            endDate: _endDate,
                            errorText: _dateError,
                            onRangeSelected: (range) {
                              setState(() {
                                _startDate = range.start;
                                _endDate = range.end;
                                _dateError = LeavePolicy.validateDates(
                                  _startDate,
                                  _endDate,
                                  today: _referenceToday,
                                );
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('leave_reason_field'),
                            controller: _reasonController,
                            enabled: !isSubmitting,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Reason for Leave',
                              hintText:
                                  'Provide at least 10 characters explaining your leave request…',
                              alignLabelWithHint: true,
                            ),
                            validator: LeavePolicy.validateReason,
                          ),
                          const SizedBox(height: 14),
                          AttachmentPicker(
                            leaveType: _leaveType,
                            workingDays: workingDays,
                            files: _files,
                            errorText: attError,
                            onFileAdded: (file) {
                              setState(() => _files.add(file));
                            },
                            onFileRemoved: (index) {
                              setState(() => _files.removeAt(index));
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              key: const Key('submit_leave_button'),
                              onPressed: isSubmitDisabled ? null : _submit,
                              icon: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(LucideIcons.send, size: 18),
                              label: Text(
                                isSubmitting
                                    ? (_files.isNotEmpty
                                          ? 'Uploading 1/${_files.length}…'
                                          : 'Submitting…')
                                    : 'Submit Leave Request',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
