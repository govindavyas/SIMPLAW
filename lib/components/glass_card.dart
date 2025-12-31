import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:simplaw/theme.dart';

/// A glassmorphism-style surface: blur + subtle border + low-opacity fill.
///
/// Use for premium panels on top of gradient backgrounds.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.lg)),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.70),
            borderRadius: radius,
            border: Border.all(color: scheme.outline.withValues(alpha: 0.22), width: 1),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
