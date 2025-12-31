import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:simplaw/theme.dart';

/// A minimal, flexible header with optional back and settings actions.
///
/// - Left: back button (shown when the current route can pop)
/// - Center: app logo and name laid out in a Row (flex format)
/// - Right: settings button (optional)
class MinimalHeader extends StatelessWidget {
  final bool showSettingsButton;
  final EdgeInsetsGeometry padding;

  const MinimalHeader({
    super.key,
    this.showSettingsButton = true,
    this.padding = const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.lg, right: AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: padding,
      child: Row(
        children: [
          // Back button (only if we can pop)
          SizedBox(
            width: 40,
            height: 40,
            child: canPop
                ? IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Center logo + name in a flexible row (flex layout)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.balance_rounded, size: 22, color: colorScheme.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'SIMPLAW',
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Settings button
          SizedBox(
            width: 40,
            height: 40,
            child: showSettingsButton
                ? IconButton(
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                    icon: Icon(Icons.settings_rounded, color: colorScheme.onSurface),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
