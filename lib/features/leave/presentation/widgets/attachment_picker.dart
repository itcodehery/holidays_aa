import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/attachment.dart';
import '../../domain/attachment_policy.dart';
import '../../domain/leave_status.dart';

/// Borderless attachment picker widget with dynamic proof requirement guidance,
/// file validation (`AttachmentPolicy.validateFile`), and removable file chips.
class AttachmentPicker extends StatelessWidget {
  final LeaveType leaveType;
  final int workingDays;
  final List<PickedAttachment> files;
  final ValueChanged<PickedAttachment> onFileAdded;
  final ValueChanged<int> onFileRemoved;
  final String? errorText;

  const AttachmentPicker({
    super.key,
    required this.leaveType,
    required this.workingDays,
    required this.files,
    required this.onFileAdded,
    required this.onFileRemoved,
    this.errorText,
  });

  String _inferMimeType(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickFiles(BuildContext context) async {
    if (files.length >= AttachmentPolicy.maxFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can attach up to 5 files per leave request.'),
        ),
      );
      return;
    }

    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: AttachmentPolicy.allowedExt.toList(),
      );
      if (pickedFiles.isEmpty || !context.mounted) return;

      for (final pf in pickedFiles) {
        if (files.length >= AttachmentPolicy.maxFiles) break;
        final bytes = await pf.xFile.readAsBytes();
        if (!context.mounted) return;

        final picked = PickedAttachment(
          pf.name,
          bytes,
          _inferMimeType(pf.name),
        );
        final err = AttachmentPolicy.validateFile(picked);
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
          continue;
        }
        onFileAdded(picked);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick file: $e')),
      );
    }
  }

  void _addSampleProof(BuildContext context) {
    final isSick = leaveType == LeaveType.sick;
    final sampleName = isSick
        ? 'medical_certificate_${files.length + 1}.pdf'
        : 'supporting_proof_${files.length + 1}.pdf';
    final bytes = Uint8List.fromList(
      utf8.encode('%PDF-1.4 Sample proof document for ${leaveType.label}'),
    );
    final picked = PickedAttachment(sampleName, bytes, 'application/pdf');
    final err = AttachmentPolicy.validateFile(picked);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    onFileAdded(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final req = AttachmentPolicy.proofRequirement(leaveType, workingDays);
    final helper = AttachmentPolicy.helperText(leaveType, workingDays);
    final isRequired = req == ProofRequirement.required;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.ivoryCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isRequired
                      ? AppTheme.terracottaSoft
                      : AppTheme.warmTaupe,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  LucideIcons.paperclip,
                  size: 18,
                  color: isRequired ? AppTheme.terracotta : AppTheme.inkDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Supporting Documents (${files.length}/${AttachmentPolicy.maxFiles})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isRequired
                      ? AppTheme.terracottaSoft
                      : AppTheme.warmTaupe,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  switch (req) {
                    ProofRequirement.required => 'Required',
                    ProofRequirement.optional => 'Optional',
                    ProofRequirement.none => 'None needed',
                  },
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isRequired
                        ? AppTheme.terracotta
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.alabasterCanvas,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommended for ${leaveType.label}:',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkDark,
                  ),
                ),
                const SizedBox(height: 6),
                for (final item in AttachmentPolicy.proofChecklist(leaveType))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          isRequired
                              ? LucideIcons.circleCheck
                              : LucideIcons.sparkles,
                          size: 13,
                          color: isRequired
                              ? AppTheme.terracotta
                              : AppTheme.inkMuted,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.inkMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('pick_attachment_button'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.alabasterCanvas,
                ),
                onPressed: files.length >= AttachmentPolicy.maxFiles
                    ? null
                    : () => _pickFiles(context),
                icon: const Icon(LucideIcons.upload, size: 16),
                label: const Text('Attach File (PDF / JPG / PNG)'),
              ),
              TextButton.icon(
                key: const Key('attach_sample_proof_button'),
                onPressed: files.length >= AttachmentPolicy.maxFiles
                    ? null
                    : () => _addSampleProof(context),
                icon: const Icon(LucideIcons.fileText, size: 16),
                label: const Text('Attach Demo Proof'),
              ),
            ],
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < files.length; i++)
                  InputChip(
                    backgroundColor: AppTheme.alabasterCanvas,
                    side: BorderSide.none,
                    avatar: Icon(
                      files[i].name.toLowerCase().endsWith('.pdf')
                          ? LucideIcons.fileText
                          : LucideIcons.image,
                      size: 15,
                    ),
                    deleteIcon: const Icon(LucideIcons.x, size: 14),
                    label: Text(
                      '${files[i].name} (${AppDateUtils.formatBytes(files[i].sizeBytes)})',
                    ),
                    onDeleted: () => onFileRemoved(i),
                  ),
              ],
            ),
          ],
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText!,
              key: const Key('attachment_validation_error'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
