import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/attachment.dart';
import 'attachment_viewer.dart';

/// Borderless list tile displaying an uploaded [Attachment] with squircle
/// Lucide icon, size, and tap-to-preview / launch support.
class AttachmentTile extends StatelessWidget {
  final Attachment attachment;

  const AttachmentTile({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    final isPdf = attachment.isPdf;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.alabasterCanvas,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isPdf ? AppTheme.terracottaSoft : AppTheme.warmTaupe,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            isPdf ? LucideIcons.fileText : LucideIcons.image,
            size: 18,
            color: isPdf ? AppTheme.terracotta : AppTheme.inkDark,
          ),
        ),
        title: Text(
          attachment.fileName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${AppDateUtils.formatBytes(attachment.sizeBytes)} · ${attachment.mimeType}',
        ),
        trailing: TextButton.icon(
          onPressed: () => AttachmentViewer.open(context, attachment),
          icon: Icon(
            isPdf ? LucideIcons.externalLink : LucideIcons.eye,
            size: 16,
          ),
          label: Text(isPdf ? 'Open PDF' : 'Preview'),
        ),
        onTap: () => AttachmentViewer.open(context, attachment),
      ),
    );
  }
}
