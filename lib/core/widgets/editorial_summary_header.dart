import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact metric pill displayed in the dark [EditorialSummaryHeader].
class EditorialMetric {
  final IconData icon;
  final String label;
  final Color? accentColor;

  const EditorialMetric({
    required this.icon,
    required this.label,
    this.accentColor,
  });
}

/// Intentional dark obsidian summary header that presents a conversational
/// overview of the user's leave status or approval queue with terracotta
/// dotted-underline highlights and compact metric indicators.
class EditorialSummaryHeader extends StatelessWidget {
  final String greetingName;
  final List<InlineSpan> summarySpans;
  final List<EditorialMetric> metrics;

  const EditorialSummaryHeader({
    super.key,
    required this.greetingName,
    required this.summarySpans,
    required this.metrics,
  });

  /// Helper for creating a terracotta highlighted phrase with a dotted underline.
  static TextSpan highlightSpan(String text) {
    return TextSpan(
      text: text,
      style: const TextStyle(
        color: Color(0xFFE46E4B),
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: Color(0xFFE46E4B),
        decorationStyle: TextDecorationStyle.dotted,
        decorationThickness: 1.6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.obsidian,
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFF4F1EA),
                height: 1.45,
                fontWeight: FontWeight.w400,
                fontSize: 17,
              ),
              children: [
                TextSpan(text: 'Good day, $greetingName. '),
                ...summarySpans,
              ],
            ),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final m in metrics)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        m.icon,
                        size: 15,
                        color: m.accentColor ?? const Color(0xFFE46E4B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        m.label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color:
                                  m.accentColor ?? const Color(0xFFC5C0B7),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
