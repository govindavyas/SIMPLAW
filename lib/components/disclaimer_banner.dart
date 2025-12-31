import 'package:flutter/material.dart';
import 'package:simplaw/theme.dart';

class DisclaimerBanner extends StatefulWidget {
  const DisclaimerBanner({super.key});

  @override
  State<DisclaimerBanner> createState() => _DisclaimerBannerState();
}

class _DisclaimerBannerState extends State<DisclaimerBanner> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Important Notice',
                        style: context.textStyles.labelMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                      icon: Icon(Icons.close_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                      onPressed: () => setState(() => _visible = false),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'SIMPLAW does not provide legal advice. This explanation is for informational purposes only. For legal guidance, please consult a qualified attorney.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
