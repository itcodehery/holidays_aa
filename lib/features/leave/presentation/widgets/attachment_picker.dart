import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../../domain/attachment.dart';
import '../../domain/attachment_policy.dart';
import '../../domain/leave_status.dart';

/// Attachment picker widget with dynamic proof requirement guidance, file
/// validation (`AttachmentPolicy.validateFile`), and removable file chips.
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: errorText != null
              ? scheme.error
              : isRequired && files.isEmpty
                  ? scheme.tertiary
                  : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file_rounded,
                size: 20,
                color: isRequired ? scheme.tertiary : scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Supporting Documents (${files.length}/${AttachmentPolicy.maxFiles})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRequired
                      ? scheme.tertiaryContainer
                      : scheme.surfaceContainerHighest,
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
                        ? scheme.onTertiaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('pick_attachment_button'),
                onPressed: files.length >= AttachmentPolicy.maxFiles
                    ? null
                    : () => _pickFiles(context),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Attach File (PDF / JPG / PNG)'),
              ),
              TextButton.icon(
                key: const Key('attach_sample_proof_button'),
                onPressed: files.length >= AttachmentPolicy.maxFiles
                    ? null
                    : () => _addSampleProof(context),
                icon: const Icon(Icons.description_outlined, size: 18),
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
                    avatar: Icon(
                      files[i].name.toLowerCase().endsWith('.pdf')
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                      size: 16,
                    ),
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
