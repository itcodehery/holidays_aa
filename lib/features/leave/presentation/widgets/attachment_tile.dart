import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../../domain/attachment.dart';
import 'attachment_viewer.dart';

/// List tile displaying an uploaded [Attachment] with file icon, size, and
/// tap-to-preview / launch support.
class AttachmentTile extends StatelessWidget {
  final Attachment attachment;

  const AttachmentTile({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPdf = attachment.isPdf;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPdf
                ? scheme.errorContainer.withValues(alpha: 0.4)
                : scheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
            color: isPdf ? scheme.error : scheme.primary,
          ),
        ),
        title: Text(
          attachment.fileName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${AppDateUtils.formatBytes(attachment.sizeBytes)} • ${attachment.mimeType}',
        ),
        trailing: TextButton.icon(
          onPressed: () => AttachmentViewer.open(context, attachment),
          icon: Icon(
            isPdf ? Icons.open_in_new_rounded : Icons.visibility_outlined,
            size: 18,
          ),
          label: Text(isPdf ? 'Open PDF' : 'Preview'),
        ),
        onTap: () => AttachmentViewer.open(context, attachment),
      ),
    );
  }
}
