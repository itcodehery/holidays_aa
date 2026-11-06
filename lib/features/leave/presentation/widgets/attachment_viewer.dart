import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/attachment.dart';
import '../leave_providers.dart';

/// Modal previewer for uploaded attachments.
/// - Images open in an in-app preview using the signed URL or in-memory bytes.
/// - PDFs open via `url_launcher` (with an in-app fallback dialog when running
///   with in-memory demo bytes).
class AttachmentViewer extends ConsumerWidget {
  final Attachment attachment;

  const AttachmentViewer({super.key, required this.attachment});

  static Future<void> open(BuildContext context, Attachment attachment) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AttachmentViewer(attachment: attachment),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inMemoryBytes = ref
        .read(inMemoryLeaveRepositoryProvider)
        .getAttachmentBytes(attachment.storagePath);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            attachment.isPdf
                ? Icons.picture_as_pdf_rounded
                : Icons.image_rounded,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.fileName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: FutureBuilder<Uri>(
          future: ref
              .read(leaveRepositoryProvider)
              .getAttachmentUrl(attachment),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Failed to generate signed URL: ${snapshot.error}');
            }
            final uri = snapshot.data!;

            if (attachment.isImage) {
              if (inMemoryBytes != null) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 340,
                    minHeight: 160,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.memory(
                            inMemoryBytes,
                            width: 96,
                            height: 96,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image, size: 48),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'In-App Image Preview (${attachment.fileName})',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: Image.network(uri.toString(), fit: BoxFit.contain),
              );
            }

            // PDF / Document preview
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Signed URL generated (valid for 60 seconds).',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final canLaunch = await canLaunchUrl(uri);
                    if (canLaunch) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Opened demo PDF attachment in viewer.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open PDF via URL Launcher'),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
