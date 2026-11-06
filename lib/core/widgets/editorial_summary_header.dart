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
  /// Replaces spaces with non-breaking spaces (`\u00A0`) so highlighted stats
  /// stay intact on the same line just like the editorial reference.
  static TextSpan highlightSpan(String text) {
    return TextSpan(
      text: text.replaceAll(' ', '\u00A0'),
      style: const TextStyle(
        fontFamily: AppTheme.bodyFontFamily,
        color: AppTheme.terracottaHighlight,
        fontWeight: FontWeight.w500,
        decoration: TextDecoration.underline,
        decorationColor: AppTheme.terracottaHighlight,
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
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                color: Color(0xFFF4F1EA),
                height: 1.56,
                fontWeight: FontWeight.w400,
                fontSize: 20,
                letterSpacing: -0.2,
              ),
              children: [
                TextSpan(text: 'Good afternoon, $greetingName. '),
                ...summarySpans,
              ],
            ),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < metrics.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          metrics[i].icon,
                          size: 15,
                          color:
                              metrics[i].accentColor ??
                              AppTheme.terracottaHighlight,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          metrics[i].label,
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFontFamily,
                            fontSize: 13,
                            color:
                                metrics[i].accentColor ??
                                const Color(0xFFC5C0B7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
